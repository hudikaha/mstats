#!/usr/bin/ruby
# coding: utf-8

require 'fileutils'
require 'optparse'
require 'tempfile'
require_relative 'jp-dcause'
require_relative 'jp-dcause-weekly'

options = {}
OptionParser.new do |opts|
  opts.banner = <<~USAGE
    Usage: causejp.rb --population POP.csv --monthly-out MONTHLY.csv \
                      --weekly-out WEEKLY.csv SOURCE.csv ...
  USAGE
  opts.on('--population FILE', 'mstats2026 population CSV') { |file| options[:population] = file }
  opts.on('--monthly-out FILE', 'monthly cause output CSV') { |file| options[:monthly] = file }
  opts.on('--weekly-out FILE', 'weekly cause output CSV') { |file| options[:weekly] = file }
end.parse!

%i[population monthly weekly].each do |option|
  abort "required option is missing: --#{option.to_s.tr('_', '-')}" unless options[option]
end
abort 'one or more monthly source CSVs are required' if ARGV.empty?
abort 'monthly and weekly output paths must differ' if options[:monthly] == options[:weekly]

# 二つの完成fileを同じ実行の成功時だけ公開できるよう、一時fileへ先に出力する。
# Write both outputs to temporary files before publishing either completed file.
def output_temp(path)
  directory = File.dirname(File.expand_path(path))
  FileUtils.mkdir_p(directory)
  Tempfile.new(['.causejp-', '.csv'], directory)
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
monthly_temp = output_temp(options[:monthly])
weekly_temp = output_temp(options[:weekly])

begin
  phase = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  deaths = JpDcause.read(ARGV, verbose: false)
  warn format('causejp read sources: %.2fs (%d records)',
              Process.clock_gettime(Process::CLOCK_MONOTONIC) - phase, deaths.size)

  phase = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Mstats2026.output(deaths, monthly_temp)
  monthly_temp.flush
  warn format('causejp monthly output: %.2fs',
              Process.clock_gettime(Process::CLOCK_MONOTONIC) - phase)

  phase = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  populations = read_records(options[:population])
  normalize_records(deaths)
  warn format('causejp population and normalization: %.2fs',
              Process.clock_gettime(Process::CLOCK_MONOTONIC) - phase)

  phase = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  weekly = build_weekly(deaths, populations)
  warn format('causejp weekly generation: %.2fs (%d records)',
              Process.clock_gettime(Process::CLOCK_MONOTONIC) - phase, weekly.size)

  phase = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Mstats2026.output_weekly(weekly, weekly_temp)
  weekly_temp.flush
  warn format('causejp weekly output: %.2fs',
              Process.clock_gettime(Process::CLOCK_MONOTONIC) - phase)

  monthly_temp.close
  weekly_temp.close
  File.rename(monthly_temp.path, options[:monthly])
  File.rename(weekly_temp.path, options[:weekly])
  File.chmod(0o644, options[:monthly])
  File.chmod(0o644, options[:weekly])
  warn format('causejp total: %.2fs',
              Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
ensure
  monthly_temp.close! if monthly_temp
  weekly_temp.close! if weekly_temp
end
