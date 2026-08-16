#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'nkf'
require_relative 'mstats2026'

STAT_IDS = {
  1999 => '000002627475', 2000 => '000002625839', 2001 => '000002624196',
  2002 => '000002622553', 2003 => '000002620891', 2004 => '000002619229',
  2005 => '000002615960', 2006 => '000002614008', 2007 => '000001266664',
  2008 => '000003071252'
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
  if text =~ /^\s*(\d{5})\s*(.*)$/
    [Regexp.last_match(1), Regexp.last_match(2).gsub(/[ 　]/, '')]
  elsif compact(text) == '総数'
    %w[allcause 全死因]
  else
    [previous_code, previous_cause]
  end
end


def normalized_age(label)
  text = compact(label)
  return 'age_all' if text == '総数'
  return 'age_unknown' if text.include?('不詳')
  return "age_#{Regexp.last_match(1).to_i}" if text =~ /\A(\d+)歳\z/
  if text =~ /\A(\d+)[〜～-](\d+)歳\z/
    return format('age_%02d_%02d', Regexp.last_match(1).to_i, Regexp.last_match(2).to_i)
  end
  return "age_#{Regexp.last_match(1).to_i}plus" if text =~ /\A(\d+)歳[-〜～以上]*\z/

  nil
end


def source_url(path, year)
  sidecar = "#{path}.url"
  return File.read(sidecar).strip if File.file?(sidecar)

  id = STAT_IDS[year]
  return "https://www.e-stat.go.jp/stat-search/file-download?statInfId=#{id}&fileKind=1" if id

  "https://www.e-stat.go.jp/stat-search/files?layout=datalist&year=#{year}&toukei=00450011"
end


# 日本語: 年次確定表の年齢×死因を、年次死亡数recordへ変換する。
# English: Convert the annual confirmed age-by-cause table into annual death-count records.
def parse(path)
  year = File.basename(path)[/\A\d{4}/].to_i
  csv = CSV.parse(NKF.nkf('-w --fb-subchar', File.binread(path)))
  header_index = csv.index do |row|
    values = row.compact.map { |cell| compact(cell) }
    values.include?('総数') && values.any? { |cell| cell.include?('不詳') }
  end
  raise "age header not found: #{path}" unless header_index

  ages = csv[header_index].drop(2).map { |label| normalized_age(label) }
  rows = {}
  previous_code = previous_cause = nil
  csv.drop(header_index + 1).each do |row|
    previous_code, previous_cause = cause_from(row[0], previous_code, previous_cause)
    next unless previous_code
    sex = sex_name(row[1])
    next unless sex

    values = ages.zip(row.drop(2)).filter_map { |age, value| [age, number(value)] if age }.to_h
    id = Mstats2026.record_id(loc: 'jpn', period: year, category: 'death',
                              death_code: previous_code, type: 'cfm', sex: sex)
    raise "duplicate ID: #{id}" if rows.key?(id)
    rows[id] = {
      id: id, loc: 'jpn', area: 'Japan', category: 'death',
      death_code: previous_code, death_cause: previous_cause, type: 'cfm',
      src_url: [source_url(path, year)], date: "#{year}-01-01", year: year, sex: sex
    }.merge(values.transform_keys(&:to_sym))
  end
  [year, rows]
end


all_rows = {}
ARGV.sort.each do |path|
  year, rows = parse(path)
  overlap = all_rows.keys & rows.keys
  abort "duplicate IDs across files: #{overlap.first}" unless overlap.empty?
  all_rows.merge!(rows)
  causes = rows.values.map { |row| row[:death_code] }.uniq.length
  expected = causes * 3
  abort "incomplete annual death cube #{year}: rows=#{rows.length} expected=#{expected}" unless rows.length == expected
  warn "#{year}: annual rows=#{rows.length} causes=#{causes}"
end

warn "confirmed annual death records=#{all_rows.length}"
Mstats2026.output_yearly(all_rows)
