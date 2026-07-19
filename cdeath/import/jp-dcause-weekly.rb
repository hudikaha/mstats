#!/usr/bin/ruby
# coding: utf-8

require 'csv'
require 'date'
require 'optparse'
require_relative 'mstats2026'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: jp-dcause-weekly.rb --population POP.csv DEATH.csv'
  opts.on('--population FILE', 'mstats2026 population CSV') do |file|
    options[:population] = file
  end
end.parse!

abort 'population CSV is required: --population FILE' unless options[:population]
abort 'one monthly death CSV is required' unless ARGV.length == 1

BASE_AGE_GROUPS = {
  age_all: %i[
    age_00_04 age_05_09 age_10_14 age_15_19 age_20_24 age_25_29
    age_30_34 age_35_39 age_40_44 age_45_49 age_50_54 age_55_59
    age_60_64 age_65_69 age_70_74 age_75_79 age_80_84 age_85_89
    age_90_94 age_95_99 age_100over
  ],
  age_00_14: %i[age_00_04 age_05_09 age_10_14],
  age_15_64: %i[
    age_15_19 age_20_24 age_25_29 age_30_34 age_35_39
    age_40_44 age_45_49 age_50_54 age_55_59 age_60_64
  ],
  age_65_74: %i[age_65_69 age_70_74],
  age_75_84: %i[age_75_79 age_80_84],
  age_85over: %i[age_85_89 age_90_94 age_95_99 age_100over],
  age_05_14: %i[age_05_09 age_10_14],
  age_15_29: %i[age_15_19 age_20_24 age_25_29],
  age_30_49: %i[age_30_34 age_35_39 age_40_44 age_45_49],
  age_50_64: %i[age_50_54 age_55_59 age_60_64]
}.freeze

RATE_AGE_GROUPS = BASE_AGE_GROUPS.merge(
  BASE_AGE_GROUPS[:age_all].to_h { |age| [age, [age]] }
).freeze

OUTPUT_AGES = (Mstats2026::AGE_FIELDS + Mstats2026::AGGREGATE_AGE_FIELDS).
                map(&:to_sym).uniq.freeze

# CSVの空欄を欠測のまま数値へ変換する。
# Convert CSV values to numbers while preserving empty fields as missing.
def number(value)
  return nil if value.nil? || value.empty? || %w[- ・].include?(value)

  value.include?('.') ? Float(value) : Integer(value)
rescue ArgumentError
  nil
end

# mstats2026 CSVをIDで検索できるレコードへ変換する。
# Read an mstats2026 CSV into records addressable by canonical ID.
def read_records(path)
  CSV.read(path, headers: true).to_h do |csv_row|
    row = csv_row.to_h.to_h do |key, value|
      converted = key.start_with?('age_') ? number(value) : value
      [key.to_sym, converted]
    end
    row[:year] = row[:year].to_i
    row[:month] = row[:month].to_i if row[:month]
    [row.fetch(:id), row]
  end
end

# 基礎年齢階級から表示用の集約年齢階級を作る。
# Build display age bands from the underlying five-year age groups.
def add_age_groups(row)
  BASE_AGE_GROUPS.each do |target, members|
    values = members.map { |age| row[age] }
    row[target] = values.compact.sum unless values.all?(&:nil?)
  end
  row
end

# 人口の年齢階級に合わせ、85歳以上一括または詳細階級を選ぶ。
# Select the aggregate or detailed 85-plus bands according to the population record.
def rate_age_groups(population)
  groups = RATE_AGE_GROUPS.dup
  return groups if population[:age_85_89]

  under_85 = BASE_AGE_GROUPS[:age_all].take_while { |age| age != :age_85_89 }
  groups[:age_all] = under_85 + [:age_85over]
  groups[:age_85over] = [:age_85over]
  groups
end

# 月次実数から旧mort.rb互換のadj・amr系列を作る。
# Derive the adj and amr series used by the existing mort.rb page.
def monthly_series(deaths, populations)
  populations.each_value { |row| add_age_groups(row) }
  latest_population = populations.values.
                        select { |row| row[:type] == 'conf' }.
                        group_by { |row| row[:sex] }.
                        transform_values { |rows| rows.max_by { |row| row[:yearmonth] } }

  deaths.each_with_object({}) do |(id, source), rows|
    raw = add_age_groups(source.dup)
    rows[id] = raw

    population_id = id.sub(/death__.*__/, 'pop__conf__')
    population = populations[population_id]
    population ||= populations[population_id.sub('pop__conf__', 'pop__est__')]
    standard = latest_population[source[:sex]]
    next unless population && standard

    %w[adj amr].each do |rate|
      derived_id = id.sub('_death_', "_death_#{rate}_")
      derived = raw.dup
      derived[:id] = derived_id
      derived[:rate] = rate

      OUTPUT_AGES.each { |age| derived[age] = nil }
      rate_age_groups(population).each do |target, members|
        adjusted = members.sum do |age|
          deaths_value = raw[age]
          current_population = population[age]
          standard_population = standard[age]
          next 0.0 unless deaths_value && current_population&.positive? && standard_population

          deaths_value * standard_population.to_f / current_population
        end
        if rate == 'adj'
          derived[target] = adjusted.round(2)
        else
          standard_total = members.sum { |age| standard[age].to_f }
          days_in_year = Date.leap?(source[:year]) ? 366 : 365
          days_in_month = Date.new(source[:year], source[:month], -1).day
          derived[target] = if standard_total.positive?
                              (adjusted * 100_000 * days_in_year /
                               (standard_total * days_in_month)).round(2)
                            end
        end
      end
      rows[derived_id] = derived
    end
  end
end

# 一つの月次系列をISO週へ日数按分する。
# Prorate one monthly series into ISO weeks according to days in each month.
def weekly_series(monthly)
  first = monthly.values.min_by { |row| row[:yearmonth] }
  last = monthly.values.max_by { |row| row[:yearmonth] }
  first_date = Date.new(first[:year], first[:month], 1)
  last_date = Date.new(last[:year], last[:month], -1)
  first_year = first_date.cwyear
  last_year = last_date.cwyear
  monthly_by_period = monthly.values.to_h { |row| [row[:yearmonth], row] }
  weeks = {}

  (first_year..last_year).each do |year|
    (1..53).each do |week|
      sunday = Date.commercial(year, week, 7)
      monday = sunday - 6
      next if sunday < first_date || monday > last_date

      days_by_month = (monday..sunday).group_by { |date| [date.year, date.month] }
      sources = days_by_month.map do |(calendar_year, month), days|
        period = format('%<year>04dm%<month>02d', year: calendar_year, month: month)
        [monthly_by_period[period], days.length]
      end
      next unless sources.all?(&:first)

      template = sources.first.first
      weekly_id = template[:id].sub(/\d{4}m\d{2}/, format('%04dw%02d', year, week))
      row = template.dup
      row.delete(:yearmonth)
      row.delete(:month)
      row[:id] = weekly_id
      row[:yearweek] = format('%04dw%02d', year, week)
      row[:year] = year
      row[:week] = week
      row[:date] = sunday.to_s

      OUTPUT_AGES.each do |age|
        values = sources.map { |source, days| [source[age], source, days] }
        if values.any? { |value, _source, _days| value.nil? }
          row[age] = nil
          next
        end
        row[age] = values.sum do |value, source, days|
          divisor = source[:rate] == 'amr' ? 7 : Date.new(source[:year], source[:month], -1).day
          value.to_f * days / divisor
        end.round(2)
      end
      weeks[weekly_id] = row
    rescue Date::Error
      next
    end
  end
  smooth(weeks)
end

# 旧処理と同じ境界補正を週次系列へ適用する。
# Apply the legacy month-boundary smoothing to a weekly series.
def smooth(rows)
  previous = []
  rows.sort.to_h.each_value do |row|
    month1 = Date.commercial(row[:year], row[:week], 1).month
    month7 = Date.commercial(row[:year], row[:week], 7).month

    if previous[1] && previous[0] && previous[1][1] != previous[0][1] &&
       previous[0][2] == month7
      smooth_triplet(previous[1][0], previous[0][0], row, :left)
    end
    if previous[1] && previous[0] && month7 != previous[0][2] &&
       previous[0][1] == previous[1][1]
      smooth_triplet(previous[1][0], previous[0][0], row, :right)
    end
    previous.unshift([row, month1, month7])
  end
  rows
end

# 月境界で同値となった二週へ差分の一部を戻す。
# Redistribute part of a month-boundary step across adjacent weeks.
def smooth_triplet(older, middle, newer, direction)
  OUTPUT_AGES.each do |age|
    values = [older[age], middle[age], newer[age]]
    next unless values.all? { |value| value.is_a?(Numeric) }

    edge, repeated = direction == :left ? [older[age], middle[age]] : [newer[age], middle[age]]
    next unless middle[age] == (direction == :left ? newer[age] : older[age])

    difference = edge - repeated
    next if difference.zero?

    one_day = middle[age] / 7.0
    shift = difference.abs * 0.33 < one_day ? difference * 0.33 : (difference.positive? ? one_day : -one_day)
    if direction == :left
      older[age] = (older[age] - shift).round(2)
      middle[age] = (middle[age] + shift).round(2)
    else
      newer[age] = (newer[age] - shift).round(2)
      middle[age] = (middle[age] + shift).round(2)
    end
  end
end

deaths = read_records(ARGV.first)
populations = read_records(options[:population])
monthly = monthly_series(deaths, populations)

weekly = monthly.values.group_by do |row|
  [row[:loc_code], row[:rate], row[:death_code], row[:sex]]
end.each_with_object({}) do |(_key, series), rows|
  rows.merge!(weekly_series(series.to_h { |row| [row[:id], row] }))
end

Mstats2026.output_weekly(weekly)
