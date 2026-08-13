#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require_relative 'mstats2026'

abort 'Usage: oecd-infant-yearly.rb OECD_MIM.csv WPP_DEMOGRAPHIC.csv.gz > YEARLY.csv' unless ARGV.length == 2

OECD_URL = 'https://data-explorer.oecd.org/vis?df%5Bag%5D=OECD.ELS.HD&df%5Bid%5D=DSD_HEALTH_STAT%40DF_MIM&df%5Bvs%5D=1.1'
WPP_URL = 'https://population.un.org/wpp/downloads'
EXCLUDED = %w[JPN USA].freeze

# 日本語: WPPの中位系列から国・年別出生数を読み、千人単位を人数へ戻す。
# English: Read country-year births from the WPP medium variant and restore units from thousands.
births = {}
locations = {}
# WPP配布fileは連結gzip memberを含むため、全memberを展開できるgzipを使う。
# Use gzip itself because the WPP distribution contains concatenated gzip members.
IO.popen(['gzip', '-cd', '--', ARGV[1]]) do |io|
  CSV.new(io, headers: true).each do |row|
    iso = row['ISO3_code'].to_s
    next if iso.empty? || row['Variant'] != 'Medium'

    year = Integer(row['Time'])
    value = row['Births'].to_s
    next if value.empty?

    births[[iso, year]] = (Float(value) * 1000).round
    locations[iso] = row['Location'].to_s
  end
end
abort 'Failed to read WPP demographic data' unless $?.success?

observations = Hash.new { |hash, key| hash[key] = {} }
CSV.foreach(ARGV[0], headers: true) do |row|
  iso = row['REF_AREA'].to_s
  measure = row['MEASURE'].to_s
  next if EXCLUDED.include?(iso) || !%w[INM PERM].include?(measure)
  next unless row['FREQ'] == 'A'
  next unless (measure == 'INM' && row['UNIT_MEASURE'] == 'DT_10P3BR_L') ||
              (measure == 'PERM' && row['UNIT_MEASURE'] == 'DT_10P3BR')
  next if row['OBS_VALUE'].to_s.empty?

  year = Integer(row['TIME_PERIOD'])
  next unless births.key?([iso, year])

  # 同じ国・年・指標に複数定義があれば標準的なOECD系列だけを採用する。
  # Use only the standard OECD definition when multiple thresholds exist.
  threshold = row['GESTATION_THRESHOLD'].to_s
  next if measure == 'INM' && threshold != 'NONE'
  next if measure == 'PERM' && !%w[_Z NONE].include?(threshold)

  observations[[iso, year]][measure] = Float(row['OBS_VALUE'])
end

rows = {}
observations.sort.each do |(iso, year), measures|
  denominator = births.fetch([iso, year])
  loc = iso.downcase
  location = locations.fetch(iso, iso)
  common = { loc_code: loc, location: location, date: "#{year}-01-01", year: year,
             sex: 'both', type: 'recon' }

  birth_id = Mstats2026.record_id(loc_code: loc, period: year, category: 'birth',
                                  type: 'recon', sex: 'both')
  rows[birth_id] ||= common.merge(id: birth_id, category: 'birth',
                                  src_url: [WPP_URL], age_all: denominator)

  if measures.key?('INM')
    id = Mstats2026.record_id(loc_code: loc, period: year, category: 'death',
                              death_code: 'infant', type: 'recon', sex: 'both')
    rows[id] = common.merge(id: id, category: 'death', death_code: 'infant',
                            death_cause: 'Infant mortality', src_url: [OECD_URL, WPP_URL],
                            age_all: (measures.fetch('INM') * denominator / 1000.0).round)
  end
  if measures.key?('PERM')
    id = Mstats2026.record_id(loc_code: loc, period: year, category: 'death',
                              death_code: 'perm', type: 'recon', sex: 'both')
    rows[id] = common.merge(id: id, category: 'death', death_code: 'perm',
                            death_cause: 'Perinatal mortality', src_url: [OECD_URL, WPP_URL],
                            age_all: (measures.fetch('PERM') * denominator / 1000.0).round)
  end
end

Mstats2026.output_yearly(rows)
