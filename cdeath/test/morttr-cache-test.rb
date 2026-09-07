#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

target = File.expand_path(ARGV.fetch(0, '../../web/morttr2.rb'), __dir__)
query = ARGV.fetch(1, 'l=ja&start_year=2000&mode=series&period=calendar&metric=crude_rate&ages=all&dcodes=allcause&c=jpn')

def run_command(env, *command)
  stdout, stderr, status = Open3.capture3(env, *command)
  raise "#{command.join(' ')} failed: #{stderr}" unless status.success?

  stdout
end

def html_value(html, name, following)
  match = html.match(/const #{Regexp.escape(name)} = (.*?);\n\s*const #{Regexp.escape(following)}/m)
  raise "missing JavaScript value #{name}" unless match

  JSON.parse(match[1])
end

def calculation_engine(html)
  html[/const calculationEngine = "([^"]+)";/, 1] or raise 'missing calculationEngine'
end

def analytic_values(rows)
  fields = %w[series model train_to year observed expected pi_lower pi_upper pi99_lower pi99_upper dispersion deaths population]
  rows.select { |row| row['interval_method'] == 'analytic' }.
    map { |row| fields.to_h { |field| [field, row[field]] } }
end

Dir.mktmpdir('morttr-cache-test-') do |cache_dir|
  env = { 'REQUEST_METHOD' => 'GET', 'QUERY_STRING' => query, 'HTTP_ACCEPT_LANGUAGE' => 'ja' }
  command = [RbConfig.ruby, target, '--cache-dir', cache_dir]

  cold = run_command(env, *command)
  raise 'cold request did not select JavaScript' unless calculation_engine(cold) == 'js'
  cold_values = analytic_values(html_value(cold, 'rubyValues', 'calculationInputs'))
  cold_queue = Dir.glob(File.join(cache_dir, 'queue', '*', '*.json.gz'))
  raise "cold queue count #{cold_queue.length}, expected 1" unless cold_queue.length == 1
  queue_digest = Digest::SHA256.file(cold_queue.first).hexdigest

  queued = run_command(env, *command)
  raise 'queued request did not retain JavaScript calculation' unless calculation_engine(queued) == 'js'
  queued_files = Dir.glob(File.join(cache_dir, 'queue', '*', '*.json.gz'))
  raise 'queued request duplicated or removed the job' unless queued_files == cold_queue
  raise 'queued request rewrote the cache entry' unless Digest::SHA256.file(queued_files.first).hexdigest == queue_digest

  run_command({}, RbConfig.ruby, target, '--cache-dir', cache_dir, '--process-cache-jobs', 'all')
  raise 'worker left a queue file' unless Dir.glob(File.join(cache_dir, 'queue', '*', '*.json.gz')).empty?
  completed = Dir.glob(File.join(cache_dir, '[0-9a-f][0-9a-f]', '*.json.gz'))
  raise "completed cache count #{completed.length}, expected 1" unless completed.length == 1

  warm = run_command(env, *command)
  raise 'warm request did not select cached Ruby result' unless calculation_engine(warm) == 'ruby'
  warm_values = html_value(warm, 'rubyValues', 'calculationInputs')
  warm_analytic = analytic_values(warm_values)
  raise 'cold and warm analytic results differ' unless cold_values == warm_analytic
  raise 'warm result does not contain simulation rows' unless warm_values.any? { |row| row['interval_method'] == 'simulation' }

  verification = JSON.parse(run_command({}, RbConfig.ruby, target, '--cache-dir', cache_dir, '--verify-cache'))
  raise "cache verification failed: #{verification['errors'].inspect}" unless verification['errors'].empty?
  raise 'cache verifier did not inspect one file' unless verification['files'] == 1 && verification['entries'] == 1

  puts JSON.generate(cold: 'js', queued: 'js', warm: 'ruby', cache_files: completed.length,
                     analytic_rows: cold_values.length,
                     simulation_rows: warm_values.count { |row| row['interval_method'] == 'simulation' })
end
