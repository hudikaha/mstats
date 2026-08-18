#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'nkf'
require_relative 'mstats2026'

STAT_IDS = {
  1999 => '000002627476', 2000 => '000002626876', 2001 => '000002625243',
  2002 => '000002623600', 2003 => '000002621943', 2004 => '000002620281',
  2005 => '000002617153', 2006 => '000002615280', 2007 => '000001661538',
  2008 => '000003072560', 2009 => '000008186660', 2010 => '000011818452',
  2011 => '000014889258', 2012 => '000022220484', 2013 => '000027232585',
  2014 => '000031289533', 2015 => '000032023166', 2016 => '000032025476',
  2017 => '000032026007', 2018 => '000031884351', 2019 => '000031983168',
  2020 => '000032119741', 2021 => '000032243870', 2022 => '000040098715',
  2023 => '000040206551', 2024 => '000040316919'
}.freeze

def compact(value)
  value.to_s.tr('０-９', '0-9').gsub(/[ 　\t\r\n]/, '')
end

def number(value)
  text = compact(value).delete(',')
  return 0 if text == '-'
  return nil if text.empty? || %w[・ .].include?(text)
  raise "unexpected death value: #{value.inspect}" unless text.match?(/\A\d+\z/)

  text.to_i
end

def sex_name(value)
  text = compact(value).delete('．.')
  return 'both' if text.start_with?('総数')
  return 'male' if text.start_with?('男')
  return 'female' if text.start_with?('女')

  nil
end

def cause_from(first, previous_code, previous_cause)
  text = first.to_s.tr('０-９', '0-9')
  compact_text = compact(text)
  if text =~ /^\s*(\d{5})\s*(.*)$/
    [Regexp.last_match(1), Regexp.last_match(2).gsub(/[ 　]/, '')]
  elsif compact_text == '総数'
    %w[allcause 全死因]
  else
    [previous_code, previous_cause]
  end
end

def normalized_age(label)
  text = compact(label)
  return 'age_all' if text == '総数'
  return 'age_unknown' if text.include?('不詳')
  return "age_#{Regexp.last_match(1)}" if text =~ /\A(\d+)歳\z/
  if text =~ /\A(\d+)[〜～-](\d+)歳\z/
    return format('age_%02d_%02d', Regexp.last_match(1).to_i, Regexp.last_match(2).to_i)
  end
  return "age_#{Regexp.last_match(1)}plus" if text =~ /\A(\d+)歳[〜～以上]*\z/

  nil
end

def source_url(year)
  id = STAT_IDS.fetch(year)
  "https://www.e-stat.go.jp/stat-search/file-download?statInfId=#{id}&fileKind=1"
end

def record(year, month, code, cause, sex, ages)
  period = format('%04dm%02d', year, month)
  id = Mstats2026.record_id(loc: 'jpn', period: period, category: 'death',
                            dcode: code, type: 'cfm', sex: sex)
  [id, {
    id: id, loc: 'jpn', area: 'Japan', yearmonth: period, category: 'death',
    dcode: code, death_cause: cause, type: 'cfm', src_url: [source_url(year)],
    date: format('%04d-%02d-01', year, month), year: year, month: month, sex: sex
  }.merge(ages.transform_keys(&:to_sym))]
end

# 日本語: 各歳で掲載される0～4歳を、共通schemaの5歳階級へも集約する。
# English: Also aggregate single-year ages 0-4 into the shared five-year age band.
def add_source_age_groups(ages)
  values = (0..4).map { |age| ages["age_#{age}"] }
  ages['age_00_04'] = values.sum if ages['age_00_04'].nil? && values.none?(&:nil?)
  ages
end

# 日本語: 1999～2008年の死亡月×死因表から、全年齢月次recordを作る。
# English: Build all-age monthly records from the 1999-2008 month-by-cause tables.
def parse_legacy(path, year)
  csv = CSV.parse(NKF.nkf('-w --fb-subchar', File.binread(path)))
  header = csv.find { |row| row.compact.map { |cell| compact(cell) }.include?('01月') }
  raise "month header not found: #{path}" unless header
  annual_column = header.index { |value| compact(value) == '総数' }
  month_columns = header.each_index.filter_map do |index|
    text = compact(header[index])
    [index, Regexp.last_match(1).to_i] if text =~ /\A(\d{1,2})月\z/
  end.to_h
  raise "wrong months: #{path}" unless month_columns.values.sort == (1..12).to_a

  rows = {}
  mismatches = []
  previous_code = previous_cause = nil
  csv.each do |row|
    previous_code, previous_cause = cause_from(row[0], previous_code, previous_cause)
    next unless previous_code
    sex = sex_name(row[1])
    next unless sex

    monthly = month_columns.to_h { |column, month| [month, number(row[column])] }
    annual = number(row[annual_column])
    if !annual.nil? && monthly.values.none?(&:nil?) && annual != monthly.values.sum
      mismatches << [previous_code, sex, annual, monthly.values.sum]
    end
    monthly.each do |month, value|
      id, item = record(year, month, previous_code, previous_cause, sex, age_all: value)
      raise "duplicate ID: #{id}" if rows.key?(id)
      rows[id] = item
    end
  end
  [rows, mismatches]
end

# 日本語: 2009年以降の死亡月×年齢×死因表から、年齢field付き月次recordを作る。
# English: Build monthly records with age fields from the detailed tables available since 2009.
def parse_detailed(path, year)
  csv = CSV.parse(NKF.nkf('-w --fb-subchar', File.binread(path)))
  header_index = csv.index do |row|
    normalized = row.compact.map { |cell| compact(cell) }
    normalized.include?('総数') && normalized.any? { |cell| cell.include?('不詳') }
  end
  raise "age header not found: #{path}" unless header_index
  ages = csv[header_index].drop(2).map { |label| normalized_age(label) }

  source_values = {}
  rows = {}
  previous_code = previous_cause = nil
  month = nil
  csv.drop(header_index + 1).each do |row|
    first = compact(row[0])
    if first =~ /全国.*\*(総数|\d{1,2})月?/
      month = Regexp.last_match(1) == '総数' ? 0 : Regexp.last_match(1).to_i
      previous_code = previous_cause = nil
      next
    end
    next unless month

    previous_code, previous_cause = cause_from(row[0], previous_code, previous_cause)
    next unless previous_code
    sex = sex_name(row[1])
    next unless sex
    values = ages.zip(row.drop(2)).filter_map do |age, value|
      [age, number(value)] if age
    end.to_h.then { |items| add_source_age_groups(items) }
    source_values[[month, previous_code, sex]] = values
    next if month.zero?

    id, item = record(year, month, previous_code, previous_cause, sex, values)
    raise "duplicate ID: #{id}" if rows.key?(id)
    rows[id] = item
  end

  mismatches = []
  source_values.each do |(source_month, code, sex), annual|
    next unless source_month.zero?
    annual.each do |age, annual_value|
      monthly = (1..12).map { |item_month| source_values.dig([item_month, code, sex], age) }
      if !annual_value.nil? && monthly.none?(&:nil?) && annual_value != monthly.sum
        mismatches << [code, sex, age, annual_value, monthly.sum]
      end
    end
  end
  [rows, mismatches]
end

all_rows = {}
ARGV.sort.each do |path|
  year = File.basename(path)[/\A\d{4}/].to_i
  parser = year < 2009 ? method(:parse_legacy) : method(:parse_detailed)
  rows, mismatches = parser.call(path, year)
  overlap = all_rows.keys & rows.keys
  abort "duplicate IDs across files: #{overlap.first}" unless overlap.empty?
  all_rows.merge!(rows)
  causes = rows.values.map { |row| row[:dcode] }.uniq.length
  periods = rows.values.map { |row| row[:yearmonth] }.uniq.length
  expected = causes * periods * 3
  abort "incomplete death cube #{year}: rows=#{rows.length} expected=#{expected}" unless rows.length == expected
  warn "#{year}: rows=#{rows.length} causes=#{causes} annual_mismatches=#{mismatches.length}"
  mismatches.first(10).each { |item| warn "#{year} annual mismatch: #{item.inspect}" }
end

warn "confirmed death records=#{all_rows.length}"
Mstats2026.output(all_rows)
