#!/usr/bin/ruby
# coding: utf-8

require 'csv'
require_relative 'mstats2026'

TYPE_MAP = {
  'confirmed' => 'cfm',
  'estimated' => 'est',
  'Japanese' => 'cfmjpns',
}.freeze

rows = {}
ARGV.each do |file|
  CSV.foreach(file, headers: true) do |source|
    type = TYPE_MAP.fetch(source['type'])
    year = source['year'].to_i
    month = source['month'].to_i
    sex = source['sex']
    id = Mstats2026.record_id(loc: 'jpn', period: format('%<year>dm%<month>02d', year: year, month: month),
                              category: 'pop', type: type, sex: sex)
    row = {
      id: id,
      loc: source['loc'].downcase,
      area: source['area'],
      yearmonth: format('%dm%02d', year, month),
      category: 'pop',
      rate: '',
      dcode: '',
      death_cause: '',
      algo: '',
      type: type,
      date: source['date'],
      year: year,
      month: month,
      sex: sex,
    }
    Mstats2026::AGE_FIELDS.each do |field|
      row[field.to_sym] = source[field]
    end
    rows[id] = row
  end
end

Mstats2026.output(rows)
