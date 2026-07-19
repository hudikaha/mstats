#!/usr/bin/ruby
# coding: utf-8

require 'csv'
require_relative 'mstats2026'

TYPE_MAP = {
  'confirmed' => 'conf',
  'estimated' => 'est',
  'Japanese' => 'jpns',
}.freeze

rows = {}
ARGV.each do |file|
  CSV.foreach(file, headers: true) do |source|
    type = TYPE_MAP.fetch(source['type'])
    year = source['year'].to_i
    month = source['month'].to_i
    sex = source['sex']
    id = format('jpn_%<year>dm%<month>02d_pop__%<type>s__%<sex>s',
                year: year, month: month, type: type, sex: sex)
    row = {
      id: id,
      loc_code: source['loc_code'].downcase,
      location: source['location'],
      yearmonth: format('%dm%02d', year, month),
      category: 'pop',
      rate: '',
      death_code: '',
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
