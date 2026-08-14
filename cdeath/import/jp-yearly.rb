#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require 'date'
require 'json'
require_relative 'mstats2026'

abort 'Usage: jp-yearly.rb MONTHLY_DEATH.csv MONTHLY_POP.csv > YEARLY.csv' unless ARGV.length == 2

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
    members = field == 'age_95over' ? %w[age_95_99 age_100over] : [field]
    [members, weight.to_f]
  end
  return groups if population['age_85_89']

  older = %w[age_85_89 age_90_94 age_95_99 age_100over]
  younger = groups.reject { |members, _weight| (members & older).any? }
  older_weight = groups.sum { |members, weight| (members & older).any? ? weight : 0.0 }
  younger.merge(%w[age_85over] => older_weight)
end

def standardized_rate(ages, population, standard)
  groups = standard_groups(population, standard)
  weighted = groups.sum do |members, weight|
    count_values = members.map do |field|
      if field == 'age_85over' && ages[field].nil?
        detailed = %w[age_85_89 age_90_94 age_95_99 age_100over].map { |age| ages[age] }
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
  key = [row['loc_code'], row['location'], row['year'].to_i, row['death_code'],
         row['death_cause'], row['algo'], row['type'], row['sex']]
  death_groups[key] << row
end

pop_groups = Hash.new { |hash, key| hash[key] = [] }
CSV.foreach(ARGV[1], headers: true) do |row|
  next unless row['category'] == 'pop'
  key = [row['loc_code'], row['location'], row['year'].to_i, row['type'], row['sex']]
  pop_groups[key] << row
end

rows = {}
annual_pop = {}
pop_groups.each do |(loc, location, year, type, sex), months|
  next unless months.map { |row| row['month'].to_i }.uniq.length == 12

  days = months.sum { |row| Date.new(year, row['month'].to_i, -1).day }
  ages = Mstats2026::AGE_FIELDS.to_h do |field|
    weighted = months.map do |row|
      value = number(row[field])
      value && value * Date.new(year, row['month'].to_i, -1).day
    end.compact
    [field, weighted.length == 12 ? clean_number(weighted.sum / days) : nil]
  end
  id = Mstats2026.record_id(loc_code: loc, period: year, category: 'pop', type: type, sex: sex)
  src_url = months.flat_map { |row| urls(row['src_url'], Mstats2026::JPN_POP_URL) }.uniq
  rows[id] = { id: id, loc_code: loc, location: location, category: 'pop', type: type,
               src_url: src_url, date: "#{year}-01-01", year: year, sex: sex }.merge(ages.transform_keys(&:to_sym))
  annual_pop[[loc, year, type, sex]] = ages
end

death_groups.each do |(loc, location, year, code, cause, algo, type, sex), months|
  next unless months.map { |row| row['month'].to_i }.uniq.length == 12

  ages = Mstats2026::AGE_FIELDS.to_h do |field|
    values = months.map { |row| number(row[field]) }
    [field, values.all? ? clean_number(values.sum) : nil]
  end
  src_url = months.flat_map { |row| urls(row['src_url'], Mstats2026::JPN_DEATH_URL) }.uniq
  id = Mstats2026.record_id(loc_code: loc, period: year, category: 'death',
                            death_code: code, algo: algo, type: type, sex: sex)
  base = { id: id, loc_code: loc, location: location, category: 'death', death_code: code,
           death_cause: cause, algo: algo, type: type, src_url: src_url,
           date: "#{year}-01-01", year: year, sex: sex }
  rows[id] = base.merge(ages.transform_keys(&:to_sym))

  pop_type = %w[cfm est cfmjpns estjpns].find { |candidate| annual_pop.key?([loc, year, candidate, sex]) }
  next unless pop_type
  population = annual_pop.fetch([loc, year, pop_type, sex])
  rates = ages.to_h do |field, count|
    denominator = population[field]
    [field, count && denominator&.positive? ? clean_number(count * 100_000.0 / denominator) : nil]
  end
  rate_id = Mstats2026.record_id(loc_code: loc, period: year, category: 'death', rate: 'crude',
                                 death_code: code, algo: algo, type: type, sex: sex)
  pop_id = Mstats2026.record_id(loc_code: loc, period: year, category: 'pop', type: pop_type, sex: sex)
  rows[rate_id] = base.merge(id: rate_id, rate: 'crude',
                             src_url: (src_url + rows.fetch(pop_id)[:src_url]).uniq)
                          .merge(rates.transform_keys(&:to_sym))

  asr_value = standardized_rate(ages, population, Mstats2026::WHO_WORLD_STANDARD)
  next unless asr_value
  asr_id = Mstats2026.record_id(loc_code: loc, period: year, category: 'death', rate: 'asr',
                                death_code: code, algo: 'whostd', type: type, sex: sex)
  rows[asr_id] = base.merge(id: asr_id, rate: 'asr', algo: 'whostd',
                            src_url: rows.fetch(rate_id)[:src_url], age_all: clean_number(asr_value))

  jp2015_value = standardized_rate(ages, population, Mstats2026::JPN_2015_STANDARD)
  next unless jp2015_value
  jp2015_id = Mstats2026.record_id(loc_code: loc, period: year, category: 'death', rate: 'asr',
                                   death_code: code, algo: 'jp2015std', type: type, sex: sex)
  rows[jp2015_id] = base.merge(id: jp2015_id, rate: 'asr', algo: 'jp2015std',
                               src_url: rows.fetch(rate_id)[:src_url], age_all: clean_number(jp2015_value))
end

Mstats2026.output_yearly(rows)
