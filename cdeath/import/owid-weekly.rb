#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require 'date'
require 'json'
require_relative 'mstats2026'

abort 'Usage: owid-weekly.rb CASES_DEATHS.csv VACCINATIONS.csv PREFECTURE.ndjson' unless ARGV.length == 3

CASES_URL = 'https://catalog.ourworldindata.org/garden/covid/latest/cases_deaths/cases_deaths.csv'.freeze
VACCINATIONS_URL = 'https://catalog.ourworldindata.org/garden/covid/latest/vaccinations_global/vaccinations_global.csv'.freeze
VRS_URL = 'https://info.vrs.digital.go.jp/dashboard'.freeze

SERIES = {
  'new_cases' => ['case', 'u07', 'COVID-19 cases', '新型コロナ症例'],
  'new_deaths' => ['death', 'u07', 'COVID-19 deaths', '新型コロナ死亡']
}.freeze
VAX_NAMES = {
  'dose1' => ['First vaccine doses', 'ワクチン1回目接種'],
  'dose2' => ['Second vaccine doses', 'ワクチン2回目接種'],
  'booster' => ['Vaccine booster doses', 'ワクチン追加接種'],
  'doseall' => ['All vaccine doses', 'ワクチン全体接種']
}.freeze

def number(value)
  return nil if value.nil? || value.empty?

  Float(value)
end

def clean(value)
  value.round(9).then { |item| item == item.to_i ? item.to_i : item }
end

def sunday(date)
  date + (7 - date.cwday)
end

def add_row(rows, loc:, date:, category:, dcode:, type:, sex:, age_values:, src_url:, dname:, dnamej:)
  period = format('%04dw%02d', date.cwyear, date.cweek)
  id = Mstats2026.record_id(loc: loc, period: period, category: category,
                            dcode: dcode, type: type, sex: sex)
  raise "duplicate ID: #{id}" if rows.key?(id)

  rows[id] = {
    id: id, loc: loc, yearweek: period, category: category, dcode: dcode,
    dname: dname, dnamej: dnamej, type: type, src_url: [src_url], date: date.iso8601,
    year: date.cwyear, week: date.cweek, sex: sex
  }.merge(age_values.transform_keys(&:to_sym))
end

areas = JSON.parse(File.read(Mstats2026::AREA_FILE))
loc_by_area = areas.each_with_object({}) do |(loc, names), result|
  result[names['area']] = loc unless names['area'].to_s.empty?
end
loc_by_area.merge!(
  'United States' => 'usa', 'South Korea' => 'kor', 'East Timor' => 'tls',
  'Faroe Islands' => 'fro', 'Reunion' => 'reu', 'Saint Barthelemy' => 'blm'
)

rows = {}

# 日本語: OWIDの日次増分をISO週（月曜から日曜）へ固定集計し、末尾の補完zeroは最終報告週の後で切る。
# English: Aggregate OWID daily increments into fixed ISO weeks and trim trailing filled zeros after the last reported week.
daily = Hash.new { |hash, key| hash[key] = {} }
last_report = {}
CSV.foreach(ARGV[0], headers: true) do |source|
  loc = loc_by_area[source['country']]
  next unless loc
  date = Date.iso8601(source['date'])
  SERIES.each_key do |field|
    value = number(source[field])
    next unless value
    daily[[loc, field]][date] = value
    last_report[[loc, field]] = date unless value.zero?
  end
end

daily.each do |(loc, field), values|
  cutoff = last_report[[loc, field]]
  next unless cutoff
  values.group_by { |date, _value| [date.cwyear, date.cweek] }.sort.each do |(_year, _week), points|
    dates = points.map(&:first)
    week_end = sunday(dates.first)
    next if week_end > sunday(cutoff)
    next unless dates.uniq.length == 7 && dates.min.cwday == 1 && dates.max.cwday == 7
    category, dcode, name, namej = SERIES.fetch(field)
    add_row(rows, loc: loc, date: week_end, category: category, dcode: dcode,
            type: 'owid', sex: 'both', age_values: { 'age_all' => clean(points.sum(&:last)) },
            src_url: CASES_URL, dname: name, dnamej: namej)
  end
end

# 日本語: 累積接種数の補間値の日差をISO週へ合計する。日本は詳細なVRSを優先する。
# English: Sum daily differences of interpolated cumulative doses by ISO week; detailed VRS replaces Japan.
vax_daily = Hash.new { |hash, key| hash[key] = {} }
previous = {}
CSV.foreach(ARGV[1], headers: true) do |source|
  loc = loc_by_area[source['country']]
  next unless loc && loc != 'jpn'
  date = Date.iso8601(source['date'])
  totals = {
    'doseall' => number(source['total_vaccinations_interpolated']),
    'booster' => number(source['total_boosters_interpolated'])
  }
  totals.each do |dcode, total|
    old = previous[[loc, dcode]]
    vax_daily[[loc, dcode]][date] = total - old[:value] if total && old && date == old[:date] + 1
    previous[[loc, dcode]] = { date: date, value: total } if total
  end
end

vax_daily.each do |(loc, dcode), values|
  values.group_by { |date, _value| [date.cwyear, date.cweek] }.sort.each do |(_year, _week), points|
    dates = points.map(&:first)
    next unless dates.uniq.length == 7 && dates.min.cwday == 1 && dates.max.cwday == 7
    value = points.sum(&:last)
    next if value.negative?
    name, namej = VAX_NAMES.fetch(dcode)
    add_row(rows, loc: loc, date: dates.max, category: 'vaxx', dcode: dcode,
            type: 'owid', sex: 'both', age_values: { 'age_all' => clean(value) },
            src_url: VACCINATIONS_URL, dname: name, dnamej: namej)
  end
end

# 日本語: VRSの3〜7回目をboosterへまとめ、都道府県別と全国、性別と総数を同じ週で作る。
# English: Combine VRS doses 3-7 as booster and build prefectural/national, sex-specific/total weeks.
vrs = Hash.new { |hash, key| hash[key] = Hash.new(0) }
vrs_min = vrs_max = nil
File.foreach(ARGV[2]) do |line|
  source = JSON.parse(line)
  next if source['deceased']
  status = Integer(source['status'].to_s, 10)
  next unless (1..7).cover?(status)
  date = Date.iso8601(source['date'])
  vrs_min = date if vrs_min.nil? || date < vrs_min
  vrs_max = date if vrs_max.nil? || date > vrs_max
  loc = format('jp%02d', Integer(source['prefecture'].to_s, 10))
  sex = { 'F' => 'female', 'M' => 'male', 'U' => 'unknown' }.fetch(source['gender'])
  age = { '-64' => 'age_00_64', '65-' => 'age_65plus', 'UNK' => 'age_unknown' }.fetch(source['age'])
  dcode = status == 1 ? 'dose1' : (status == 2 ? 'dose2' : 'booster')
  count = Integer(source['count'].to_s, 10)
  [[loc, sex], [loc, 'both'], ['jpn', sex], ['jpn', 'both']].each do |area_loc, area_sex|
    key = [area_loc, sunday(date), area_sex, dcode]
    vrs[key]['age_all'] += count
    vrs[key][age] += count
  end
end

first_full_week = vrs_min + (8 - vrs_min.cwday) % 7
first_full_week += 6
last_full_week = vrs_max - vrs_max.cwday
vrs.keys.each do |loc, week_end, sex, dcode|
  next if week_end < first_full_week || week_end > last_full_week
  values = vrs[[loc, week_end, sex, dcode]]
  name, namej = VAX_NAMES.fetch(dcode)
  add_row(rows, loc: loc, date: week_end, category: 'vaxx', dcode: dcode,
          type: 'vrs', sex: sex, age_values: values, src_url: VRS_URL, dname: name, dnamej: namej)
end

vrs.keys.map { |loc, week_end, sex, _dcode| [loc, week_end, sex] }.uniq.each do |loc, week_end, sex|
  values = Hash.new(0)
  %w[dose1 dose2 booster].each do |dcode|
    vrs[[loc, week_end, sex, dcode]].each { |age, count| values[age] += count }
  end
  name, namej = VAX_NAMES.fetch('doseall')
  add_row(rows, loc: loc, date: week_end, category: 'vaxx', dcode: 'doseall',
          type: 'vrs', sex: sex, age_values: values, src_url: VRS_URL, dname: name, dnamej: namej)
end

Mstats2026.output_weekly(rows)
