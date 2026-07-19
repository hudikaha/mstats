#!/usr/bin/ruby
# coding: utf-8

require 'csv'
require 'date'
require_relative 'mstats2026'

abort 'Usage: stmf-weekly.rb STMF.csv' unless ARGV.length == 1

CODE_REPLACEMENTS = {
  'DEUTNP' => 'DEU',
  'FRATNP' => 'FRA',
  'GBRTENW' => 'ENG',
  'GBR_NIR' => 'NIR',
  'GBR_SCO' => 'SCO',
  'NZL_NP' => 'NZL'
}.freeze

LOCATIONS = {
  'AUS' => 'Australia', 'AUT' => 'Austria', 'BEL' => 'Belgium',
  'BGR' => 'Bulgaria', 'CAN' => 'Canada', 'CHE' => 'Switzerland',
  'CHL' => 'Chile', 'CZE' => 'Czechia', 'DEU' => 'Germany',
  'DNK' => 'Denmark', 'ESP' => 'Spain', 'EST' => 'Estonia',
  'FIN' => 'Finland', 'FRA' => 'France', 'ENG' => 'England and Wales',
  'NIR' => 'Northern Ireland', 'SCO' => 'Scotland', 'GRC' => 'Greece',
  'HRV' => 'Croatia', 'HUN' => 'Hungary', 'ISL' => 'Iceland',
  'ISR' => 'Israel', 'ITA' => 'Italy', 'KOR' => 'Republic of Korea',
  'LTU' => 'Lithuania', 'LUX' => 'Luxembourg', 'LVA' => 'Latvia',
  'NLD' => 'Netherlands', 'NOR' => 'Norway', 'NZL' => 'New Zealand',
  'POL' => 'Poland', 'PRT' => 'Portugal', 'RUS' => 'Russia',
  'SVK' => 'Slovakia', 'SVN' => 'Slovenia', 'SWE' => 'Sweden',
  'TWN' => 'Taiwan', 'USA' => 'United States of America'
}.freeze

SEXES = { 'b' => 'both', 'm' => 'male', 'f' => 'female' }.freeze

AGE_COLUMNS = {
  age_all: %w[DTotal RTotal],
  age_00_14: %w[D0_14 R0_14],
  age_15_64: %w[D15_64 R15_64],
  age_65_74: %w[D65_74 R65_74],
  age_75_84: %w[D75_84 R75_84],
  age_85over: %w[D85p R85p]
}.freeze

# STMFの欠測記号を保持して数値だけを変換する。
# Preserve STMF missing markers and convert only numeric values.
def stmf_number(value)
  return nil if value.nil? || value.empty? || value == '.'

  Float(value)
rescue ArgumentError
  nil
end

text = File.read(ARGV.first).gsub(/\r\n?/, "\n").
       lines.reject { |line| line.start_with?('#') || line.strip.empty? }.join
rows = {}
source_rows = CSV.parse(text, headers: true, row_sep: :auto)

# 国別定義による非ISOの第53週を検出する。
# Detect country-specific week 53 records that are outside the ISO calendar.
extra_week_years = source_rows.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |source, years|
  next unless source['Week'].to_i == 53

  Date.commercial(source['Year'].to_i, 53, 7)
rescue ArgumentError
  code = CODE_REPLACEMENTS.fetch(source['CountryCode'], source['CountryCode'])
  years[code] << source['Year'].to_i
end
extra_week_years.each_value(&:uniq!)

# ISO週を基本に、国別の追加週があれば後続日付を連続させる。
# Use ISO weeks while keeping dates continuous after country-specific extra weeks.
def week_date(code, year, week, extra_week_years)
  prior_extra_weeks = extra_week_years.fetch(code, []).count { |extra_year| extra_year < year }
  Date.commercial(year, week, 7) + prior_extra_weeks * 7
rescue ArgumentError
  raise unless week == 53 && extra_week_years.fetch(code, []).include?(year)

  Date.commercial(year, 52, 7) + (prior_extra_weeks + 1) * 7
end

source_rows.each do |source|
  original_code = source['CountryCode']
  canonical_code = CODE_REPLACEMENTS.fetch(original_code, original_code)
  loc_code = canonical_code.downcase
  year = source['Year'].to_i
  week = source['Week'].to_i
  sex = SEXES[source['Sex']]
  next unless sex

  ['', 'amr'].each_with_index do |rate, column_index|
    id = format('%<loc>s_%<year>04dw%<week>02d_death_%<rate>s_00000__%<sex>s',
                loc: loc_code, year: year, week: week, rate: rate, sex: sex)
    row = {
      id: id,
      loc_code: loc_code,
      location: LOCATIONS.fetch(canonical_code, canonical_code),
      yearweek: format('%04dw%02d', year, week),
      category: 'death',
      rate: rate,
      death_code: '00000',
      death_cause: 'All causes',
      algo: '',
      date: week_date(canonical_code, year, week, extra_week_years).to_s,
      year: year,
      week: week,
      sex: sex
    }
    AGE_COLUMNS.each do |age, columns|
      value = stmf_number(source[columns[column_index]])
      row[age] = rate == 'amr' && value ? (value * 100_000).round(2) : value&.round(2)
    end
    rows[id] = row
  end
end

Mstats2026.output_weekly(rows)
