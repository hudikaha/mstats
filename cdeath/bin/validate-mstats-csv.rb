#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require 'date'
require 'json'
require 'optparse'
require 'set'
require 'tempfile'
require_relative '../import/mstats2026'

options = { require_src_url: false }
OptionParser.new do |parser|
  parser.banner = 'Usage: validate-mstats-csv.rb [--require-src-url] CSV ...'
  parser.on('--require-src-url') { options[:require_src_url] = true }
end.parse!
abort 'one or more CSV files are required' if ARGV.empty?

ALLOWED_CATEGORIES = %w[death pop birth delivery fetal-death].freeze
SPECIAL_DEATH_CODES = %w[infant perm].freeze
LEGACY_RATES = %w[adj amr].freeze
LEGACY_TYPES = %w[conf jpns reconst unwpp2024proj unwpp2024expproj].freeze
NUMERIC = /\A-?(?:\d+(?:\.\d*)?|\.\d+)\z/

id_rows = Tempfile.new('mstats-validation-ids')
rate_rows = Tempfile.new('mstats-validation-rates')
total_rows = 0
counts = Hash.new(0)
cause_systems = Hash.new(0)
birth_keys = Set.new
delivery_keys = Set.new
infant_rate_keys = []
birth_denominator_keys = []
errors = []
warnings = []

def present?(value)
  !value.nil? && !value.empty?
end

def source_urls(value)
  return [] unless present?(value)
  return [value] unless value.start_with?('[')

  parsed = JSON.parse(value)
  raise JSON::ParserError, 'src_url JSON must be an array' unless parsed.is_a?(Array)

  parsed
end

ARGV.each do |file|
  abort "CSV not found: #{file}" unless File.file?(file)

  file_rows = 0
  CSV.foreach(file, headers: true).with_index(2) do |row, line|
    file_rows += 1
    total_rows += 1
    where = "#{file}:#{line}"
    id = row['id'].to_s
    if id.empty?
      errors << "#{where}: id is missing"
    else
      id_rows.puts "#{id}\t#{where}"
    end

    begin
      expected_id = Mstats2026.record_id_for(row)
      errors << "#{where}: id differs from canonical 8-component ID #{expected_id}" unless id == expected_id
    rescue ArgumentError => e
      errors << "#{where}: #{e.message}"
    end

    %w[loc_code category date year sex].each do |field|
      errors << "#{where}: #{field} is missing" unless present?(row[field])
    end

    category = row['category'].to_s
    errors << "#{where}: unsupported category #{category.inspect}" unless ALLOWED_CATEGORIES.include?(category)

    monthly = present?(row['yearmonth'])
    weekly = present?(row['yearweek'])
    period_count = [monthly, weekly].count(true)
    errors << "#{where}: yearmonth and yearweek cannot coexist" if period_count > 1
    unit = monthly ? 'monthly' : weekly ? 'weekly' : 'yearly'
    counts[[unit, category]] += 1

    year = row['year'].to_i
    errors << "#{where}: invalid year #{row['year'].inspect}" unless row['year'].to_s.match?(/\A\d{4}\z/)
    begin
      date = Date.iso8601(row['date'].to_s)
      errors << "#{where}: date year #{date.year} differs from year #{year}" if unit != 'weekly' && date.year != year
    rescue ArgumentError
      errors << "#{where}: invalid date #{row['date'].inspect}"
    end

    if monthly
      errors << "#{where}: invalid yearmonth #{row['yearmonth'].inspect}" unless row['yearmonth'].match?(/\A\d{4}m(?:0[1-9]|1[0-2])\z/)
      errors << "#{where}: month is missing" unless row['month'].to_s.match?(/\A(?:0?[1-9]|1[0-2])\z/)
      errors << "#{where}: week must be empty for monthly data" if present?(row['week'])
    elsif weekly
      errors << "#{where}: invalid yearweek #{row['yearweek'].inspect}" unless row['yearweek'].match?(/\A\d{4}w\d{2}\z/)
      errors << "#{where}: week is missing" unless row['week'].to_s.match?(/\A(?:[1-9]|[1-4]\d|5[0-3])\z/)
      errors << "#{where}: month must be empty for weekly data" if present?(row['month'])
    else
      errors << "#{where}: month and week must be empty for yearly data" if present?(row['month']) || present?(row['week'])
    end

    death_code = row['death_code'].to_s
    %w[loc_code category rate death_code algo type sex].each do |field|
      value = row[field].to_s
      errors << "#{where}: #{field} must be lowercase: #{value.inspect}" unless value == value.downcase
    end
    errors << "#{where}: legacy rate is forbidden: #{row['rate']}" if LEGACY_RATES.include?(row['rate'])
    errors << "#{where}: legacy type is forbidden: #{row['type']}" if LEGACY_TYPES.include?(row['type'])
    if category == 'death'
      errors << "#{where}: death_code is missing" if death_code.empty?
      system = if death_code == 'allcause'
                 'all'
               elsif SPECIAL_DEATH_CODES.include?(death_code)
                 'indicator'
               elsif death_code.match?(/\A\d/)
                 'japan'
               elsif death_code.match?(/\A[a-z]/)
                 'icd10'
               else
                 'unknown'
               end
      cause_systems[system] += 1
      errors << "#{where}: unrecognized death_code #{death_code.inspect}" if system == 'unknown'
      key = [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], death_code,
             row['type'], row['sex']]
      rate_rows.puts "#{key.join("\t")}\t#{row['rate']}"
    elsif present?(death_code)
      warnings << "#{where}: death_code is ignored for category #{category}"
    end

    birth_keys << [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], row['sex']] if category == 'birth'
    delivery_keys << [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], row['sex']] if category == 'delivery'
    if category == 'birth'
      errors << "#{where}: birth age_all must be positive" unless row['age_all'].to_s.match?(NUMERIC) && row['age_all'].to_f.positive?
    elsif category == 'delivery'
      errors << "#{where}: delivery age_all must be positive" unless row['age_all'].to_s.match?(NUMERIC) && row['age_all'].to_f.positive?
    elsif category == 'death' && row['rate'] == 'imr'
      errors << "#{where}: infant mortality rate requires age_0" unless row['age_0'].to_s.match?(NUMERIC)
      infant_rate_keys << [where, [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], row['sex']]]
    elsif category == 'death' && death_code == 'perm'
      errors << "#{where}: perm age_all must be positive" unless row['age_all'].to_s.match?(NUMERIC) && row['age_all'].to_f.positive?
      denominator = row['type'] == 'recon' ? birth_keys : delivery_keys
      birth_denominator_keys << [where, denominator,
                                 [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], row['sex']]]
    end

    row.headers.grep(/\Aage_/).each do |field|
      value = row[field]
      next unless present?(value)

      errors << "#{where}: #{field} is not numeric: #{value.inspect}" unless value.match?(NUMERIC)
      errors << "#{where}: #{field} is negative: #{value}" if value.match?(NUMERIC) && value.to_f.negative?
    end
    if row['rate'] == 'asr'
      populated = row.headers.grep(/\Aage_/).reject { |field| field == 'age_all' }.
                    select { |field| present?(row[field]) }
      errors << "#{where}: ASR may populate only age_all: #{populated.join(',')}" unless populated.empty?
    end

    begin
      urls = source_urls(row['src_url'])
      errors << "#{where}: src_url is required" if options[:require_src_url] && urls.empty?
      urls.each do |url|
        errors << "#{where}: invalid src_url #{url.inspect}" unless url.is_a?(String) && url.match?(%r{\Ahttps?://})
      end
    rescue JSON::ParserError => e
      errors << "#{where}: invalid src_url JSON: #{e.message}"
    end
  rescue CSV::MalformedCSVError => e
    errors << "#{where}: malformed CSV: #{e.message}"
  end
  errors << "#{file}: no data rows" if file_rows.zero?
end

id_rows.flush
previous_id = previous_where = nil
IO.popen(['sort', id_rows.path], 'r') do |sorted|
  sorted.each_line do |line|
    id, where = line.chomp.split("\t", 2)
    errors << "#{where}: duplicate id #{id} (first: #{previous_where})" if id == previous_id
    previous_id = id
    previous_where = where
  end
end

infant_rate_keys.each do |where, key|
  errors << "#{where}: infant mortality rate has no matching birth denominator" unless birth_keys.include?(key)
end
birth_denominator_keys.each do |where, denominators, key|
  errors << "#{where}: perinatal indicator has no matching denominator" unless denominators.include?(key)
end

rate_rows.flush
previous_key = nil
rates = Set.new
check_rates = lambda do |key, values|
  next if key.nil? || (values & Set.new(%w[crude asr])).empty?
  warnings << "derived death series has no raw-count row: #{key.tr("\t", '/')}" unless values.include?('')
end
IO.popen(['sort', rate_rows.path], 'r') do |sorted|
  sorted.each_line do |line|
    parts = line.chomp.split("\t", -1)
    rate = parts.pop
    key = parts.join("\t")
    if previous_key && key != previous_key
      check_rates.call(previous_key, rates)
      rates = Set.new
    end
    previous_key = key
    rates << rate
  end
end
check_rates.call(previous_key, rates)

puts "files=#{ARGV.length} rows=#{total_rows}"
counts.sort.each { |(unit, category), count| puts "#{unit}.#{category}=#{count}" }
puts "cause_systems=#{cause_systems.sort.to_h.to_json}"
warnings.first(100).each { |message| warn "warning: #{message}" }
warn "warnings truncated: #{warnings.length}" if warnings.length > 100
unless errors.empty?
  errors.first(100).each { |message| warn "error: #{message}" }
  warn "errors truncated: #{errors.length}" if errors.length > 100
  exit 1
end

puts "validation=ok warnings=#{warnings.length}"
