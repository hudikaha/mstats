#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require_relative 'mstats2026'

abort 'Usage: jp-infant-yearly.rb INFANT_6-1.csv PERINATAL_8-1.csv > YEARLY.csv' unless ARGV.length == 2

INFANT_URL = 'https://www.e-stat.go.jp/stat-search/file-download?fileKind=1&statInfId=000040316556'
PERINATAL_URL = 'https://www.e-stat.go.jp/stat-search/file-download?fileKind=1&statInfId=000040316620'
FROM_YEAR = 2000

# 日本語: e-Statの複数行headerを飛ばし、年次を先頭列に持つ行だけを読む。
# English: Skip the multi-line e-Stat header and read rows whose first column is a year.
def yearly_rows(path)
  CSV.read(path, encoding: 'Windows-31J:UTF-8').map do |row|
    next unless row[0].to_s.match?(/\A\d{4}\z/)
    year = row[0].to_i
    next if year < FROM_YEAR
    [year, row]
  end.compact.to_h
end

infant = yearly_rows(ARGV[0])
perinatal = yearly_rows(ARGV[1])
common_years = (infant.keys & perinatal.keys).sort
abort 'No common infant/perinatal years' if common_years.empty?

rows = {}
common_years.each do |year|
  infant_row = infant.fetch(year)
  perinatal_row = perinatal.fetch(year)
  births = Integer(infant_row.fetch(1))
  infant_deaths = Integer(infant_row.fetch(2))
  perinatal_deaths = Integer(perinatal_row.fetch(1))
  late_fetal_deaths = Integer(perinatal_row.fetch(5))
  deliveries = births + late_fetal_deaths
  common = { loc: 'jpn', area: 'Japan', date: "#{year}-01-01", year: year,
             sex: 'both', type: 'cfm' }

  birth_id = Mstats2026.record_id(loc: 'jpn', period: year, category: 'birth', type: 'cfm', sex: 'both')
  rows[birth_id] = common.merge(id: birth_id, category: 'birth',
                                src_url: [INFANT_URL], age_all: births)

  delivery_id = Mstats2026.record_id(loc: 'jpn', period: year, category: 'delivery', type: 'cfm', sex: 'both')
  rows[delivery_id] = common.merge(id: delivery_id, category: 'delivery',
                                   src_url: [INFANT_URL, PERINATAL_URL], age_all: deliveries)

  infant_id = Mstats2026.record_id(loc: 'jpn', period: year, category: 'death',
                                   dcode: 'infant', type: 'cfm', sex: 'both')
  rows[infant_id] = common.merge(id: infant_id, category: 'death', dcode: 'infant',
                                 dname: 'Infant mortality', dnamej: '乳児死亡',
                                 src_url: [INFANT_URL], age_all: infant_deaths)

  perinatal_id = Mstats2026.record_id(loc: 'jpn', period: year, category: 'death',
                                      dcode: 'perm', type: 'cfm', sex: 'both')
  rows[perinatal_id] = common.merge(id: perinatal_id, category: 'death', dcode: 'perm',
                                    dname: 'Perinatal mortality', dnamej: '周産期死亡',
                                    src_url: [PERINATAL_URL], age_all: perinatal_deaths)
end

Mstats2026.output_yearly(rows)
