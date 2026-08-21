#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require 'date'
require 'json'
require_relative 'mstats2026'

annual_death_path = nil
oldest_pop_path = nil
deaths_only = false
loop do
  case ARGV.first
  when '--annual-death'
    ARGV.shift
    annual_death_path = ARGV.shift
  when '--oldest-pop'
    ARGV.shift
    oldest_pop_path = ARGV.shift
  when '--deaths-only'
    ARGV.shift
    deaths_only = true
  else
    break
  end
end
abort 'Usage: jp-yearly.rb [--annual-death FILE] [--oldest-pop FILE] [--deaths-only] MONTHLY_DEATH.csv MONTHLY_POP.csv' unless ARGV.length == 2

def urls(value, fallback)
  return [fallback] if value.nil? || value.empty?
  value.start_with?('[') ? JSON.parse(value) : [value]
end

def number(value)
  return nil if value.nil? || value.empty?

  Float(value)
end

def clean_number(value)
  value&.round(9).then { |v| v == v.to_i ? v.to_i : v }
end

# 日本語: 人口が85歳以上一括の年は、死亡数と標準人口weightも85歳以上へ合算してASRを求める。
# English: When population has only an 85-plus band, combine deaths and standard weights at 85-plus for ASR.
def standard_groups(population, standard)
  groups = standard.to_h do |field, weight|
    members = field == 'age_95plus' ? %w[age_95_99 age_100plus] : [field]
    [members, weight.to_f]
  end
  if population['age_75plus']
    older = %w[age_75_79 age_80_84 age_85_89 age_90_94 age_95_99 age_100plus]
    younger = groups.reject { |members, _weight| (members & older).any? }
    older_weight = groups.sum { |members, weight| (members & older).any? ? weight : 0.0 }
    return younger.merge(%w[age_75plus] => older_weight)
  end
  return groups if population['age_85_89']

  older = %w[age_85_89 age_90_94 age_95_99 age_100plus]
  younger = groups.reject { |members, _weight| (members & older).any? }
  older_weight = groups.sum { |members, weight| (members & older).any? ? weight : 0.0 }
  younger.merge(%w[age_85plus] => older_weight)
end

def standardized_rate(ages, population, standard)
  groups = standard_groups(population, standard)
  weighted = groups.sum do |members, weight|
    count_values = members.map do |field|
      if field == 'age_85plus' && ages[field].nil?
        detailed = %w[age_85_89 age_90_94 age_95_99 age_100plus].map { |age| ages[age] }
        detailed.sum if detailed.all?
      elsif field == 'age_75plus' && ages[field].nil?
        detailed = %w[age_75_79 age_80_84 age_85_89 age_90_94 age_95_99 age_100plus].map { |age| ages[age] }
        detailed.sum if detailed.all?
      else
        ages[field]
      end
    end
    pop_values = members.map { |field| population[field] }
    break nil if count_values.any?(&:nil?) || pop_values.any? { |value| !value&.positive? }

    count_values.sum * 100_000.0 / pop_values.sum * weight
  end
  weighted && weighted / groups.values.sum
end

death_groups = Hash.new { |hash, key| hash[key] = [] }
CSV.foreach(ARGV[0], headers: true) do |row|
  next unless row['category'] == 'death' && row['rate'].to_s.empty?
  key = [row['loc'], row['area'], row['year'].to_i, row['dcode'],
         row['dname'], row['dnamej'], row['algo'], row['type'], row['sex']]
  death_groups[key] << row
end

pop_groups = Hash.new { |hash, key| hash[key] = [] }
CSV.foreach(ARGV[1], headers: true) do |row|
  next unless row['category'] == 'pop'
  key = [row['loc'], row['area'], row['year'].to_i, row['type'], row['sex']]
  pop_groups[key] << row
end

rows = {}
annual_pop = {}
pop_groups.each do |(loc, area, year, type, sex), months|
  # 日本語: 旧確定人口と現行人口が重なる月は、後から読んだ現行recordを採用する。
  # English: Where legacy and current population overlap, keep the later-read current record.
  months = months.to_h { |row| [row['yearmonth'], row] }.values
  next unless months.map { |row| row['month'].to_i }.uniq.length == 12

  days = months.sum { |row| Date.new(year, row['month'].to_i, -1).day }
  ages = Mstats2026::AGE_FIELDS.to_h do |field|
    weighted = months.map do |row|
      value = number(row[field])
      if value.nil? && field == 'age_85plus'
        detailed = %w[age_85_89 age_90_94 age_95_99 age_100plus].map { |age| number(row[age]) }
        value = detailed.sum if detailed.all?
      end
      value && value * Date.new(year, row['month'].to_i, -1).day
    end.compact
    [field, weighted.length == 12 ? clean_number(weighted.sum / days) : nil]
  end
  # 日本語: 75歳以上が原表にある場合は、その正確な値を年平均して保存する。
  # English: Preserve the exact annual average when the source provides a 75-plus total.
  id = Mstats2026.record_id(loc: loc, period: year, category: 'pop', type: type, sex: sex)
  src_url = months.flat_map { |row| urls(row['src_url'], Mstats2026::JPN_POP_URL) }.uniq
  rows[id] = { id: id, loc: loc, area: area, category: 'pop', type: type,
               src_url: src_url, date: "#{year}-01-01", year: year, sex: sex }.merge(ages.transform_keys(&:to_sym))
  annual_pop[[loc, year, type, sex]] = ages
end

if oldest_pop_path
  oldest = Hash.new { |hash, key| hash[key] = [] }
  CSV.foreach(oldest_pop_path, headers: true) do |row|
    year = row['yearmonth'][0, 4].to_i
    month = row['yearmonth'][-2, 2].to_i
    oldest[[year, row['sex']]] << [month, Float(row['age_75plus'])]
  end
  oldest.each do |(year, sex), values|
    next unless values.map(&:first).uniq.length == 12
    days = values.sum { |month, _value| Date.new(year, month, -1).day }
    weighted = values.sum { |month, value| value * Date.new(year, month, -1).day }
    %w[cfm est cfmjpns estjpns].each do |type|
      population = annual_pop[['jpn', year, type, sex]]
      next unless population

      value = weighted / days
      population['age_75plus'] = value
      pop_id = Mstats2026.record_id(loc: 'jpn', period: year, category: 'pop', type: type, sex: sex)
      rows[pop_id][:age_75plus] = clean_number(value) if rows[pop_id]
    end
  end
end

death_groups.each do |(loc, area, year, code, dname, dnamej, algo, type, sex), months|
  next unless months.map { |row| row['month'].to_i }.uniq.length == 12

  ages = Mstats2026::AGE_FIELDS.to_h do |field|
    values = months.map { |row| number(row[field]) }
    [field, values.all? ? clean_number(values.sum) : nil]
  end
  if ages['age_75plus'].nil?
    older = %w[age_75_79 age_80_84 age_85_89 age_90_94 age_95_99 age_100plus].map { |age| ages[age] }
    ages['age_75plus'] = older.sum if older.all?
  end
  src_url = months.flat_map { |row| urls(row['src_url'], Mstats2026::JPN_DEATH_URL) }.uniq
  id = Mstats2026.record_id(loc: loc, period: year, category: 'death',
                            dcode: code, algo: algo, type: type, sex: sex)
  base = { id: id, loc: loc, area: area, category: 'death', dcode: code,
           dname: dname, dnamej: dnamej, algo: algo, type: type, src_url: src_url,
           date: "#{year}-01-01", year: year, sex: sex }
  rows[id] = base.merge(ages.transform_keys(&:to_sym))

  pop_type = %w[cfm est cfmjpns estjpns].find { |candidate| annual_pop.key?([loc, year, candidate, sex]) }
  next unless pop_type
  population = annual_pop.fetch([loc, year, pop_type, sex])
  rates = ages.to_h do |field, count|
    denominator = population[field]
    [field, count && denominator&.positive? ? clean_number(count * 100_000.0 / denominator) : nil]
  end
  rate_id = Mstats2026.record_id(loc: loc, period: year, category: 'death', rate: 'crude',
                                 dcode: code, algo: algo, type: type, sex: sex)
  pop_id = Mstats2026.record_id(loc: loc, period: year, category: 'pop', type: pop_type, sex: sex)
  rows[rate_id] = base.merge(id: rate_id, rate: 'crude',
                             src_url: (src_url + rows.fetch(pop_id)[:src_url]).uniq)
                          .merge(rates.transform_keys(&:to_sym))

  asr_value = standardized_rate(ages, population, Mstats2026::WHO_WORLD_STANDARD)
  next unless asr_value
  asr_id = Mstats2026.record_id(loc: loc, period: year, category: 'death', rate: 'asr',
                                dcode: code, algo: 'whostd', type: type, sex: sex)
  rows[asr_id] = base.merge(id: asr_id, rate: 'asr', algo: 'whostd',
                            src_url: rows.fetch(rate_id)[:src_url], age_all: clean_number(asr_value))

  jp2015_value = standardized_rate(ages, population, Mstats2026::JPN_2015_STANDARD)
  next unless jp2015_value
  jp2015_id = Mstats2026.record_id(loc: loc, period: year, category: 'death', rate: 'asr',
                                   dcode: code, algo: 'jp2015std', type: type, sex: sex)
  rows[jp2015_id] = base.merge(id: jp2015_id, rate: 'asr', algo: 'jp2015std',
                               src_url: rows.fetch(rate_id)[:src_url], age_all: clean_number(jp2015_value))
end

# 日本語: 年次確定表がある年は、月次合計を年次確定表の年齢×死因recordで置換する。
# English: Where an annual confirmed table exists, replace monthly sums with its age-by-cause records.
if annual_death_path
  annual_rows = CSV.read(annual_death_path, headers: true)
  annual_years = annual_rows.map { |row| row['year'].to_i }.uniq
  rows.delete_if { |_id, row| row[:category] == 'death' && annual_years.include?(row[:year]) }

  annual_rows.each do |source|
    loc = source['loc']
    area = source['area']
    year = source['year'].to_i
    code = source['dcode']
    dname = source['dname']
    dnamej = source['dnamej']
    algo = source['algo'].to_s
    type = source['type'].to_s
    sex = source['sex']
    ages = Mstats2026::AGE_FIELDS.to_h { |field| [field, number(source[field])] }
    if ages['age_75plus'].nil?
      older = %w[age_75_79 age_80_84 age_85_89 age_90_94 age_95_99 age_100plus].map { |age| ages[age] }
      ages['age_75plus'] = older.sum if older.all?
    end
    src_url = urls(source['src_url'], Mstats2026::JPN_DEATH_URL)
    id = Mstats2026.record_id(loc: loc, period: year, category: 'death',
                              dcode: code, algo: algo, type: type, sex: sex)
    base = { id: id, loc: loc, area: area, category: 'death', dcode: code,
             dname: dname, dnamej: dnamej, algo: algo, type: type, src_url: src_url,
             date: "#{year}-01-01", year: year, sex: sex }
    rows[id] = base.merge(ages.transform_keys(&:to_sym))

    pop_type = %w[cfm est cfmjpns estjpns].find { |candidate| annual_pop.key?([loc, year, candidate, sex]) }
    next unless pop_type
    population = annual_pop.fetch([loc, year, pop_type, sex])
    pop_id = Mstats2026.record_id(loc: loc, period: year, category: 'pop', type: pop_type, sex: sex)
    rate_urls = (src_url + rows.fetch(pop_id)[:src_url]).uniq
    rates = ages.to_h do |field, count|
      denominator = population[field]
      [field, count && denominator&.positive? ? clean_number(count * 100_000.0 / denominator) : nil]
    end
    rate_id = Mstats2026.record_id(loc: loc, period: year, category: 'death', rate: 'crude',
                                   dcode: code, algo: algo, type: type, sex: sex)
    rows[rate_id] = base.merge(id: rate_id, rate: 'crude', src_url: rate_urls)
                         .merge(rates.transform_keys(&:to_sym))

    { 'whostd' => Mstats2026::WHO_WORLD_STANDARD,
      'jp2015std' => Mstats2026::JPN_2015_STANDARD }.each do |standard_name, standard|
      value = standardized_rate(ages, population, standard)
      next unless value
      asr_id = Mstats2026.record_id(loc: loc, period: year, category: 'death', rate: 'asr',
                                    dcode: code, algo: standard_name, type: type, sex: sex)
      rows[asr_id] = base.merge(id: asr_id, rate: 'asr', algo: standard_name,
                                src_url: rate_urls, age_all: clean_number(value))
    end
  end
end

# 日本語: 確定死亡系列では人口を分母として使うが、共通年次人口recordは別経路で一度だけ出力する。
# English: Confirmed deaths use population denominators, while annual population records are emitted once elsewhere.
rows.delete_if { |_id, row| row[:category] == 'pop' } if deaths_only
Mstats2026.output_yearly(rows)
