#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require 'date'
require 'json'
require 'optparse'
require 'set'

options = { require_src_url: false }
OptionParser.new do |parser|
  parser.banner = 'Usage: validate-mstats-csv.rb [--require-src-url] CSV ...'
  parser.on('--require-src-url') { options[:require_src_url] = true }
end.parse!
abort 'one or more CSV files are required' if ARGV.empty?

ALLOWED_CATEGORIES = %w[death pop birth fetal-death].freeze
SPECIAL_DEATH_CODES = %w[PERM].freeze
NUMERIC = /\A-?(?:\d+(?:\.\d*)?|\.\d+)\z/

ids = {}
counts = Hash.new(0)
cause_systems = Hash.new(0)
death_rates = Hash.new { |hash, key| hash[key] = Set.new }
birth_keys = Set.new
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

  CSV.foreach(file, headers: true).with_index(2) do |row, line|
    where = "#{file}:#{line}"
    id = row['id'].to_s
    if id.empty?
      errors << "#{where}: id is missing"
    elsif ids[id]
      errors << "#{where}: duplicate id #{id} (first: #{ids[id]})"
    else
      ids[id] = where
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
    rescue Date::Error
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
    if category == 'death'
      errors << "#{where}: death_code is missing" if death_code.empty?
      system = if death_code == '00000'
                 'all'
               elsif SPECIAL_DEATH_CODES.include?(death_code)
                 'indicator'
               elsif death_code.match?(/\A\d/)
                 'japan'
               elsif death_code.match?(/\A[A-Z]/)
                 'icd10'
               else
                 'unknown'
               end
      cause_systems[system] += 1
      errors << "#{where}: unrecognized death_code #{death_code.inspect}" if system == 'unknown'
      key = [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], death_code,
             row['algo'], row['type'], row['sex']]
      death_rates[key] << row['rate'].to_s
    elsif present?(death_code)
      warnings << "#{where}: death_code is ignored for category #{category}"
    end

    birth_keys << [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], row['sex']] if category == 'birth'
    if category == 'birth'
      errors << "#{where}: birth age_all must be positive" unless row['age_all'].to_s.match?(NUMERIC) && row['age_all'].to_f.positive?
    elsif category == 'death' && row['rate'] == 'imr'
      errors << "#{where}: infant mortality rate requires age_0" unless row['age_0'].to_s.match?(NUMERIC)
      infant_rate_keys << [where, [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], row['sex']]]
    elsif category == 'death' && death_code == 'PERM'
      errors << "#{where}: PERM requires algo=reconstructed" unless row['algo'] == 'reconstructed'
      errors << "#{where}: PERM age_all must be positive" unless row['age_all'].to_s.match?(NUMERIC) && row['age_all'].to_f.positive?
      birth_denominator_keys << [where, [row['loc_code'], unit, row['yearmonth'] || row['yearweek'] || row['year'], row['sex']]]
    end

    row.headers.grep(/\Aage_/).each do |field|
      value = row[field]
      next unless present?(value)

      errors << "#{where}: #{field} is not numeric: #{value.inspect}" unless value.match?(NUMERIC)
      errors << "#{where}: #{field} is negative: #{value}" if value.match?(NUMERIC) && value.to_f.negative?
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
end

infant_rate_keys.each do |where, key|
  errors << "#{where}: infant mortality rate has no matching birth denominator" unless birth_keys.include?(key)
end
birth_denominator_keys.each do |where, key|
  errors << "#{where}: reconstructed indicator has no matching birth denominator" unless birth_keys.include?(key)
end

death_rates.each do |key, rates|
  next unless (rates & Set.new(%w[adj amr crude_rate])).any?
  warnings << "derived death series has no raw-count row: #{key.join('/')}" unless rates.include?('')
end

puts "files=#{ARGV.length} rows=#{ids.length}"
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
