#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'optparse'
require 'uri'

$stdout.sync = true

options = {
  base: 'https://medicalfacts.info/',
  cases: File.expand_path('../test/web-tests.json', __dir__),
  timeout: 180
}
OptionParser.new do |parser|
  parser.on('--base URL') { |value| options[:base] = value }
  parser.on('--cases PATH') { |value| options[:cases] = value }
  parser.on('--ids LIST') { |value| options[:ids] = value.split(',') }
  parser.on('--formal') { options[:formal] = true }
end.parse!

cases = JSON.parse(File.read(options[:cases]))
if options[:formal]
  cases.each { |item| item['url'] = item.fetch('url').sub(/\Amortyear2\.rb/, 'mortyear.rb').sub(/\Amort2\.rb/, 'mort.rb').sub(/\Acodtr2\.rb/, 'codtr.rb').sub(/\Acod2\.rb/, 'cod.rb') }
end
cases.select! { |item| options[:ids].include?(item.fetch('id')) } if options[:ids]
failures = []
suite_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
elapsed_by_case = []
observed_by_case = {}

cases.each_with_index do |item, index|
  uri = URI.join(options[:base], item.fetch('url'))
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  errors = []
  body = ''
  begin
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                               open_timeout: 20, read_timeout: options[:timeout]) do |http|
      http.get(uri.request_uri, 'Accept-Encoding' => 'identity')
    end
    body = response.body.to_s.force_encoding(Encoding::UTF_8)
    errors << "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    errors << "short HTML #{body.bytesize}" if body.bytesize < 20_000
    errors << 'gateway/error page' if body.match?(/Bad Gateway|Internal Server Error|Application error/i)
    errors << 'Vega data missing' unless body.match?(/vegaEmbed|vega-lite|vlSpec/i)
    item.fetch('expect', []).each { |text| errors << "missing #{text.inspect}" unless body.include?(text) }
    item.fetch('reject', []).each { |text| errors << "unexpected #{text.inspect}" if body.include?(text) }
    item.fetch('series_years', {}).each do |series, required_years|
      years = body.scan(/"series":"#{Regexp.escape(series)}".{0,500}?"year":(\d{4})/).flatten.map(&:to_i).uniq
      errors << "series missing #{series.inspect}" if years.empty?
      required_years.each do |year|
        errors << "missing #{series} year=#{year}" unless years.include?(year)
      end
    end
    item.fetch('series_absent', []).each do |series|
      errors << "unexpected series #{series.inspect}" if body.include?(%Q{"series":"#{series}"})
    end
    observed_by_case[item.fetch('id')] = item.fetch('observed_at', {}).to_h do |series, year|
      match = body.match(/"series":"#{Regexp.escape(series)}".{0,500}?"year":#{year}.{0,300}?"observed":(-?\d+(?:\.\d+)?)/)
      errors << "missing observed #{series} year=#{year}" unless match
      [series, match && match[1].to_f]
    end
  rescue StandardError => e
    errors << "#{e.class}: #{e.message}"
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  elapsed_by_case << [item.fetch('id'), elapsed]
  status = errors.empty? ? 'ok' : 'FAIL'
  puts format('%02d/%02d %-4s %-4s %7d bytes %6.2fs %s', index + 1, cases.length,
              item.fetch('id'), status, body.bytesize, elapsed, item.fetch('summary'))
  failures << [item.fetch('id'), errors] unless errors.empty?
end

cases.each do |item|
  item.fetch('compare', []).each do |comparison|
    series = comparison.fetch('series')
    left = observed_by_case.dig(item.fetch('id'), series)
    right = observed_by_case.dig(comparison.fetch('id'), series)
    unless left && right
      failures << [item.fetch('id'), ["comparison value missing: #{comparison.fetch('id')} #{series}"]]
      next
    end
    relation = comparison.fetch('relation')
    valid = relation == 'equal' ? left == right : left != right
    failures << [item.fetch('id'), ["comparison #{relation} failed: #{left} vs #{right}"]] unless valid
  end
end

suite_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - suite_started
average = cases.empty? ? 0 : suite_elapsed / cases.length
slowest = elapsed_by_case.max_by { |(_id, elapsed)| elapsed }
puts format('elapsed=%.2fs average=%.2fs slowest=%s %.2fs', suite_elapsed, average,
            slowest&.first || '-', slowest&.last || 0)

unless failures.empty?
  warn failures.map { |id, errors| "#{id}: #{errors.join(', ')}" }.join("\n")
  exit 1
end

puts "all=#{cases.length} passed=#{cases.length}"
