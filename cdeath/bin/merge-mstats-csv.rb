#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'

abort 'Usage: merge-mstats-csv.rb HEADER_SOURCE.csv CSV ...' if ARGV.length < 2

headers = CSV.open(ARGV.first, &:readline)
csv = CSV.new($stdout)
csv << headers
ARGV.drop(1).each do |path|
  CSV.foreach(path, headers: true) do |row|
    csv << headers.map { |field| row[field] }
  end
end
