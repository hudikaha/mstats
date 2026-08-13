#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require_relative 'mstats2026'

abort 'Usage: us-infant-yearly.rb US_MORTYEAR_SERIES.csv > YEARLY.csv' unless ARGV.length == 1

rows = {}
CSV.foreach(ARGV[0], headers: true) do |input|
  year = Integer(input.fetch('year'))
  births = Integer(input.fetch('births'))
  infant_deaths = Integer(input.fetch('infant_deaths'))
  src_urls = input.fetch('src_url').split('|').reject(&:empty?)
  vital_stats_url = src_urls.fetch(0, Mstats2026::US_VITAL_STATS_URL)
  perinatal_url = src_urls.fetch(1, Mstats2026::OECD_DATA_EXPLORER_URL)
  common = { loc_code: 'usa', location: 'United States',
             date: "#{year}-01-01", year: year, sex: 'both' }

  birth_id = Mstats2026.record_id(loc_code: 'usa', period: year, category: 'birth', type: 'conf', sex: 'both')
  rows[birth_id] = common.merge(id: birth_id, category: 'birth', type: 'conf',
                                src_url: [vital_stats_url], age_all: births)

  death_id = Mstats2026.record_id(loc_code: 'usa', period: year, category: 'death',
                                  death_code: '00000', type: 'conf', sex: 'both')
  rows[death_id] = common.merge(id: death_id, category: 'death', type: 'conf', death_code: '00000',
                                death_cause: 'All causes', src_url: [vital_stats_url], age_0: infant_deaths)

  # 日本語: PERMはICD死因ではなく、OECDの周産期死亡指標codeである。
  # English: PERM is the OECD perinatal-mortality indicator code, not an ICD cause.
  perinatal = input['perinatal_deaths'].to_s
  next if perinatal.empty? || %w[NA .].include?(perinatal)

  perinatal_id = Mstats2026.record_id(loc_code: 'usa', period: year, category: 'death',
                                      death_code: 'PERM', type: 'reconst', sex: 'both')
  rows[perinatal_id] = common.merge(id: perinatal_id, category: 'death', death_code: 'PERM',
                                    death_cause: 'Perinatal mortality', type: 'reconst',
                                    src_url: [perinatal_url], age_all: Integer(perinatal))
end

Mstats2026.output_yearly(rows)
