#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require 'date'
require 'json'
require 'set'
require 'unicode_normalize/normalize'
require_relative 'mstats2026'

abort 'Usage: un-monthly-mortality.rb UNDATA.csv WPP-MSTATS.csv' unless ARGV.length == 2

UN_URL = 'https://data.un.org/Data.aspx?d=POP&f=tableCode%3A65'
WPP_URL = 'https://population.un.org/wpp/downloads'
TYPE = 'unmonth'
MONTHS = Date::MONTHNAMES.compact.to_h { |name| [name, Date::MONTHNAMES.index(name)] }.freeze
ALIASES = {
  'aland islands' => 'aland islands',
  'bolivia plurinational state of' => 'bolivia plurinational state of',
  'brunei darussalam' => 'brunei darussalam',
  'cabo verde' => 'cabo verde',
  'china hong kong sar' => 'china hong kong sar',
  'china macao sar' => 'china macao sar',
  'czech republic' => 'czechia',
  'iran islamic republic of' => 'iran islamic republic of',
  'lao peoples democratic republic' => 'lao peoples democratic republic',
  'micronesia federated states of' => 'micronesia federated states of',
  'republic of korea' => 'republic of korea',
  'republic of moldova' => 'republic of moldova',
  'russian federation' => 'russian federation',
  'syrian arab republic' => 'syrian arab republic',
  'turkey' => 'turkiye',
  'united republic of tanzania' => 'united republic of tanzania',
  'united states' => 'united states of america',
  'venezuela bolivarian republic of' => 'venezuela bolivarian republic of',
  'viet nam' => 'viet nam'
}.freeze
EXTRA_LOCATIONS = {
  'aland islands' => { code: 'ala', location: 'Åland Islands' },
  'norfolk island' => { code: 'nfk', location: 'Norfolk Island' },
  'netherlands kingdom of the' => { code: 'nld', location: 'Netherlands' },
  'saint helena ex dep' => { code: 'shn', location: 'Saint Helena' },
  'united kingdom of great britain and northern ireland' => { code: 'gbr', location: 'United Kingdom' }
}.freeze
SKIP_LOCATIONS = Set.new(['saint helena ascension']).freeze

def normalized_name(value)
  normalized = value.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase
  normalized = normalized.gsub('&', ' and ').gsub(/[^a-z0-9]+/, ' ').strip.gsub(/\s+/, ' ')
  ALIASES.fetch(normalized, normalized)
end

def population_kind_rank(row)
  type = row['type'].to_s
  algo = row['algo'].to_s
  return 4 if %w[unwpp2024expest exposure_estimate].include?(type)
  return 3 if %w[unwpp2024expproj exposure_projection].include?(type)
  return 2 if %w[unwpp2024est estimate].include?(type)
  return 1 if %w[unwpp2024proj projection].include?(type)
  return 0 unless algo.include?('wpp2024')

  type.include?('exposure') ? 3 : 1
end

# 日本語: WPP年次人口から国名対応表と死亡率分母を作る。
# English: Build country-name mappings and mortality denominators from annual WPP population records.
locations = {}
populations = {}
CSV.foreach(ARGV[1], headers: true) do |row|
  next unless row['category'] == 'pop' && row['sex'] == 'both'
  next if row['age_all'].to_s.empty?

  rank = population_kind_rank(row)
  next if rank.zero?

  code = row['loc_code'].to_s.downcase
  location = row['location'].to_s
  locations[normalized_name(location)] = { code: code, location: location }
  key = [code, row['year'].to_i]
  current = populations[key]
  populations[key] = { value: row['age_all'].to_f, rank: rank } if current.nil? || rank > current[:rank]
end
locations.merge!(EXTRA_LOCATIONS)

def reliability_rank(value)
  text = value.to_s.downcase
  return 4 if text.include?('final figure, complete')
  return 3 if text.include?('final')
  return 2 if text.include?('provisional')

  1
end

def record_type_rank(value)
  text = value.to_s.downcase
  return 2 if text.include?('occurrence')
  return 1 if text.include?('registration')

  0
end

# 日本語: 同じ国・年月が複数ある場合は発生年、確定度、最新source yearの順に選ぶ。
# English: Resolve duplicate country-month rows by occurrence basis, reliability, then latest source year.
observations = {}
unmatched = Set.new
CSV.foreach(ARGV[0], headers: true).with_index(2) do |row, line|
  next unless row['Area'].to_s == 'Total'
  month = MONTHS[row['Month'].to_s]
  next unless month
  next unless row['Year'].to_s.match?(/\A\d{4}\z/)
  next unless row['Value'].to_s.delete(',').match?(/\A\d+(?:\.0+)?\z/)

  normalized_country = normalized_name(row['Country or Area'])
  next if SKIP_LOCATIONS.include?(normalized_country)
  country = locations[normalized_country]
  unless country
    unmatched << row['Country or Area'].to_s
    next
  end

  year = row['Year'].to_i
  key = [country[:code], year, month]
  rank = [record_type_rank(row['Record Type']), reliability_rank(row['Reliability']), row['Source Year'].to_i]
  current = observations[key]
  next if current && (current[:rank] <=> rank) >= 0

  observations[key] = {
    rank: rank, code: country[:code], location: country[:location], year: year, month: month,
    deaths: row['Value'].delete(',').to_f, line: line
  }
end

unless unmatched.empty?
  warn "UN countries absent from WPP mapping (#{unmatched.length}): #{unmatched.to_a.sort.join(', ')}"
end

rows = {}
observations.each_value do |item|
  year = item[:year]
  month = item[:month]
  period = format('%04dm%02d', year, month)
  common = {
    loc_code: item[:code], location: item[:location], yearmonth: period,
    category: 'death', death_code: '00000', death_cause: 'All causes', algo: '', type: TYPE,
    date: format('%04d-%02d-01', year, month), year: year, month: month, sex: 'both'
  }
  count_id = Mstats2026.record_id(loc_code: item[:code], period: period, category: 'death',
                                  death_code: '00000', type: TYPE, sex: 'both')
  rows[count_id] = common.merge(id: count_id, rate: '', src_url: [UN_URL], age_all: item[:deaths].round)

  population = populations[[item[:code], year]]
  next unless population && population[:value].positive?

  days = Date.new(year, month, -1).day
  amr = item[:deaths] * 365.2425 / days / population[:value] * 100_000
  amr_id = Mstats2026.record_id(loc_code: item[:code], period: period, category: 'death', rate: 'amr',
                                death_code: '00000', type: TYPE, sex: 'both')
  rows[amr_id] = common.merge(id: amr_id, rate: 'amr', src_url: [UN_URL, WPP_URL], age_all: amr.round(2))
end

abort 'no monthly UN mortality records were generated' if rows.empty?
Mstats2026.output(rows)
