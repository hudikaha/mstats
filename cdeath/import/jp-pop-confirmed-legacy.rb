#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'set'
require_relative 'mstats2026'

sample = ARGV.delete('--sample')
oldest_output = nil
if (index = ARGV.index('--oldest-output'))
  ARGV.delete_at(index)
  oldest_output = ARGV.delete_at(index)
end
all_output = nil
if (index = ARGV.index('--all-output'))
  ARGV.delete_at(index)
  all_output = ARGV.delete_at(index)
end
exclude_ids_path = nil
if (index = ARGV.index('--exclude-ids'))
  ARGV.delete_at(index)
  exclude_ids_path = ARGV.delete_at(index)
end

STAT_IDS = {
  1999 => '000000090174', 2000 => '000000090186', 2001 => '000000090192',
  2002 => '000000090205', 2003 => '000000090227', 2004 => '000000090236',
  2005 => '000000090248', 2006 => '000001075409', 2007 => '000001191669',
  2008 => '000002630328', 2009 => '000007552526'
}.freeze

def compact(value)
  value.to_s.tr('０-９', '0-9').gsub(/[ 　\t\r\n]/, '')
end

def era_month(value)
  text = compact(value)
  return unless text =~ /平成(元|\d+)年(\d+)月/

  era = Regexp.last_match(1) == '元' ? 1 : Regexp.last_match(1).to_i
  [1988 + era, Regexp.last_match(2).to_i]
end

def filename_sex(path)
  name = File.basename(path, '.csv')
  return 'both' if name.include?('男女計')
  return 'female' if name.end_with?('女')
  return 'male' if name.end_with?('男')

  nil
end

records = {}
duplicate_differences = []

def age_field(value)
  text = compact(value)
  return 'age_all' if %w[総数 Total].include?(text)
  if text =~ /\A(\d+)[〜～-](\d+)(?:歳)?\z/
    return format('age_%02d_%02d', Regexp.last_match(1).to_i, Regexp.last_match(2).to_i)
  end
  return "age_#{Regexp.last_match(1).to_i}plus" if text =~ /\A(\d+)歳?(?:以上|[〜～-])\z/

  nil
end

ARGV.sort.each do |path|
  source_year = File.basename(path)[/\A\d{4}/].to_i
  content = File.read(path)
  has_ten_thousand = content.match?(/単位[^\n]*万人/)
  has_thousand = content.match?(/単位[^\n]*千人/)
  default_factor = has_ten_thousand && !has_thousand ? 10_000 : 1_000
  column_factors = {}
  dates = {}
  sex = filename_sex(path)
  total_population = false

  CSV.foreach(path) do |row|
    normalized = row.map { |cell| compact(cell) }
    found_dates = row.each_index.filter_map do |index|
      era_month(row[index])&.then { |date| [index, date] }
    end.to_h
    dates = found_dates unless found_dates.empty?

    if normalized.any? { |cell| cell.include?('単位') && (cell.include?('千人') || cell.include?('万人')) }
      current_factor = nil
      row.each_index do |index|
        cell = normalized[index]
        current_factor = 1_000 if cell.include?('千人')
        current_factor = 10_000 if cell.include?('万人')
        column_factors[index] = current_factor if current_factor
      end
    end

    sex = 'both' if normalized.any? { |cell| %w[男女計 Bothsexes].include?(cell) }
    sex = 'male' if normalized.any? { |cell| %w[男 Male].include?(cell) }
    sex = 'female' if normalized.any? { |cell| %w[女 Female].include?(cell) }
    total_population = true if normalized.any? { |cell| %w[総人口 Totalpopulation].include?(cell) }
    total_population = false if normalized.any? { |cell| %w[日本人人口 Japanesepopulation].include?(cell) }
    next unless total_population && sex && !dates.empty?
    field = row.filter_map { |cell| age_field(cell) }.first
    next unless field

    dates.each do |column, (year, month)|
      next unless year.between?(1999, 2008)
      raw = row[column].to_s.delete(',')
      next unless raw.match?(/\A\d+(?:\.\d+)?\z/)

      value = (raw.to_f * column_factors.fetch(column, default_factor)).round
      key = [sex, format('%04dm%02d', year, month)]
      records[key] ||= { ages: {}, source_years: {} }
      previous = records[key][:ages][field]
      previous_year = records[key][:source_years][field]
      if previous && previous != value
        duplicate_differences << [key + [field], previous, value, previous_year, source_year]
      end
      next if previous && previous_year > source_year

      records[key][:ages][field] = value
      records[key][:source_years][field] = source_year
    end
  end
end

expected_periods = (1999..2008).flat_map do |year|
  (1..12).map { |month| format('%04dm%02d', year, month) }
end
missing = %w[both male female].flat_map do |sex|
  expected_periods.map { |period| [sex, period] }
end.reject { |key| records.key?(key) }
abort "missing population months: #{missing.first(20).inspect} (#{missing.length})" unless sample || missing.empty?

rows = records.to_h do |(sex, period), item|
  year = period[0, 4].to_i
  month = period[-2, 2].to_i
  stat_id = STAT_IDS.fetch(item[:source_years].values.max)
  id = Mstats2026.record_id(loc_code: 'jpn', period: period, category: 'pop', type: 'cfm', sex: sex)
  [id, {
    id: id, loc_code: 'jpn', location: 'Japan', yearmonth: period, category: 'pop', type: 'cfm',
    src_url: ["https://www.e-stat.go.jp/stat-search/file-download?statInfId=#{stat_id}&fileKind=0"],
    date: format('%04d-%02d-01', year, month), year: year, month: month, sex: sex,
  }.merge(item[:ages].transform_keys(&:to_sym))]
end

# 日本語: 75歳以上人口はASR計算専用の補助CSVへ分離し、共通schemaには追加しない。
# English: Keep 75-plus population in an ASR-only sidecar, not in the shared schema.
if oldest_output
  CSV.open(oldest_output, 'w') do |csv|
    csv << %w[yearmonth sex age_75plus]
    records.sort.each do |(sex, period), item|
      value = item[:ages]['age_75plus']
      if value.nil?
        detailed = %w[age_75_79 age_80_84 age_85plus].map { |field| item[:ages][field] }
        value = detailed.sum if detailed.all?
      end
      csv << [period, sex, value] if value
    end
  end
end

warn "population records=#{rows.length} duplicate_differences=#{duplicate_differences.length}"
duplicate_differences.first(10).each { |difference| warn "population revision: #{difference.inspect}" }
warn "population revisions omitted=#{duplicate_differences.length - 10}" if duplicate_differences.length > 10

# 日本語: 接続先に同じIDがある月は内部計算用には残し、投入用出力からだけ除く。
# English: Retain overlapping months for calculations, but omit their IDs from the ingest output.
if all_output
  File.open(all_output, 'w') { |io| Mstats2026.output(rows, io) }
end
if exclude_ids_path
  existing = Set.new
  CSV.foreach(exclude_ids_path, headers: true) { |row| existing << row['id'] }
  rows = rows.reject { |id, _row| existing.include?(id) }
end
Mstats2026.output(rows)
