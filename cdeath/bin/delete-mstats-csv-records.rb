#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'net/http'
require 'optparse'
require 'uri'

options = {
  endpoint: ENV.fetch('MSTATS_ES_URL', 'http://127.0.0.1:9200'),
  batch_size: 5_000
}
OptionParser.new do |parser|
  parser.on('--index INDEX') { |value| options[:index] = value }
  parser.on('--endpoint URL') { |value| options[:endpoint] = value }
  parser.on('--batch-size N', Integer) { |value| options[:batch_size] = value }
end.parse!

abort 'usage: delete-mstats-csv-records.rb --index INDEX CSV...' unless options[:index] && !ARGV.empty?
abort 'MSTATS_ES_USER and ES_PASSWORD are required' unless ENV['MSTATS_ES_USER'] && ENV['ES_PASSWORD']

endpoint = URI(options[:endpoint])
http = Net::HTTP.new(endpoint.host, endpoint.port)
http.use_ssl = endpoint.scheme == 'https'
bulk_uri = URI.join(options[:endpoint].sub(%r{/*\z}, '') + '/', '_bulk?refresh=false')
deleted = 0
missing = 0

# 日本語: CSVに存在するIDだけをbulk削除し、別系列のrecordを巻き込まない。
# English: Bulk-delete only IDs present in the CSVs so unrelated series remain untouched.
send_batch = lambda do |ids|
  return if ids.empty?

  body = ids.map { |id| JSON.generate(delete: { _index: options[:index], _id: id }) }.join("\n") + "\n"
  request = Net::HTTP::Post.new(bulk_uri)
  request.basic_auth(ENV.fetch('MSTATS_ES_USER'), ENV.fetch('ES_PASSWORD'))
  request['Content-Type'] = 'application/x-ndjson'
  request.body = body
  response = http.request(request)
  abort "bulk delete HTTP #{response.code}: #{response.body[0, 500]}" unless response.is_a?(Net::HTTPSuccess)

  result = JSON.parse(response.body)
  abort "bulk delete response has errors: #{response.body[0, 1000]}" if result['errors']
  result.fetch('items').each do |item|
    status = item.fetch('delete').fetch('status')
    status == 404 ? missing += 1 : deleted += 1
  end
end

ids = []
ARGV.each do |path|
  CSV.foreach(path, headers: true) do |row|
    id = row['id'].to_s
    abort "missing id in #{path}" if id.empty?
    ids << id
    next unless ids.length >= options[:batch_size]

    send_batch.call(ids)
    ids.clear
  end
end
send_batch.call(ids)

refresh_uri = URI.join(options[:endpoint].sub(%r{/*\z}, '') + '/', "#{options[:index]}/_refresh")
refresh = Net::HTTP::Post.new(refresh_uri)
refresh.basic_auth(ENV.fetch('MSTATS_ES_USER'), ENV.fetch('ES_PASSWORD'))
response = http.request(refresh)
abort "refresh HTTP #{response.code}: #{response.body[0, 500]}" unless response.is_a?(Net::HTTPSuccess)

puts "deleted=#{deleted} missing=#{missing}"
