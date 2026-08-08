#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'fileutils'

OUTPUT_HEADER = %w[id areacode area areaj cutoff cweek date age dose deaths pop].freeze
SOURCE_FIELDS = (OUTPUT_HEADER - ['pop']).freeze

abort 'Usage: cumd_wk_from_g.rb CUMD-WK-G.csv [...]' if ARGV.empty?

ARGV.each do |source_path|
  abort "Not a CUMD-WK-G file: #{source_path}" unless source_path.end_with?('_CUMD-WK-G.csv')

  output_path = source_path.sub(/_CUMD-WK-G\.csv\z/, '_CUMD-WK.csv')
  temporary_path = "#{output_path}.tmp"
  count = 0

  # Gamma計算用CSVから共通fieldと週開始時人口だけを新CUMD-WKへ移す。
  # Copy common fields and week-start population from the Gamma CSV into the new CUMD-WK.
  CSV.open(temporary_path, 'wb', write_headers: true, headers: OUTPUT_HEADER) do |output|
    CSV.foreach(source_path, headers: true) do |row|
      output << SOURCE_FIELDS.map { |field| row[field] } + [row['at_risk']]
      count += 1
    end
  end
  FileUtils.mv(temporary_path, output_path)
  warn "Created #{output_path} (#{count} records)"
rescue StandardError
  FileUtils.rm_f(temporary_path) if temporary_path
  raise
end
