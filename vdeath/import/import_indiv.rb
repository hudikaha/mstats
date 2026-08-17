#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'net/http'
require 'optparse'
require 'uri'

options = {
  index: 'indiv20260721',
  url: 'http://localhost:9200',
  credentials: File.expand_path('~/.config/mstats/espass.txt'),
  mapping: File.expand_path('../config/elasticsearch/indiv20260721.json', __dir__),
  batch_size: 1_000,
  replace: false
}

OptionParser.new do |parser|
  parser.on('--index NAME') { |value| options[:index] = value }
  parser.on('--url URL') { |value| options[:url] = value }
  parser.on('--credentials FILE') { |value| options[:credentials] = value }
  parser.on('--mapping FILE') { |value| options[:mapping] = value }
  parser.on('--batch-size N', Integer) { |value| options[:batch_size] = value }
  parser.on('--replace') { options[:replace] = true }
end.parse!
abort 'CSV file is required' if ARGV.empty?

account, password = File.read(options[:credentials]).strip.split(':', 2)
abort 'Invalid credentials file' if account.to_s.empty? || password.to_s.empty?
base_uri = URI(options[:url])

# Elasticsearchへ認証付きrequestを送り、応答を返す。
# Send an authenticated Elasticsearch request and return its response.
def es_response(base_uri, account, password, method, path, body = nil, content_type = 'application/json')
  uri = base_uri.dup
  uri.path = path
  request = method.new(uri)
  request.basic_auth(account, password)
  request['Content-Type'] = content_type
  request.body = body if body
  http = Net::HTTP.new(uri.hostname, uri.port)
  http.use_ssl = uri.scheme == 'https'
  http.start { |client| client.request(request) }
end

# 成功以外は秘密値を出さず終了する。
# Abort on failure without exposing credentials.
def es_request(base_uri, account, password, method, path, body = nil, content_type = 'application/json')
  response = es_response(base_uri, account, password, method, path, body, content_type)
  return response if response.is_a?(Net::HTTPSuccess)

  abort "Elasticsearch #{method::METHOD} #{path} failed: HTTP #{response.code} #{response.body}"
end

index_path = "/#{options[:index]}"
head = es_response(base_uri, account, password, Net::HTTP::Head, index_path)
if options[:replace] && head.is_a?(Net::HTTPSuccess)
  es_request(base_uri, account, password, Net::HTTP::Delete, index_path)
  head = nil
end
unless head.is_a?(Net::HTTPSuccess)
  abort "Cannot inspect #{options[:index]}: HTTP #{head.code}" if head && head.code != '404'

  es_request(base_uri, account, password, Net::HTTP::Put, index_path, File.read(options[:mapping]))
end

batch = []
count = 0

# bulk requestを一定件数ずつ送り、同じIDの再実行を安全な上書きにする。
# Send bounded bulk requests; reruns safely replace documents with the same ID.
flush = lambda do
  next if batch.empty?

  response = es_request(base_uri, account, password, Net::HTTP::Post, '/_bulk',
                        batch.join("\n") + "\n", 'application/x-ndjson')
  result = JSON.parse(response.body)
  if result['errors']
    failure = result.fetch('items').map { |item| item.fetch('index')['error'] }.compact.first
    abort "Bulk import failed: #{failure.to_json}"
  end
  batch.clear
end

ARGV.each do |path|
  CSV.foreach(path, headers: true) do |row|
    source = row.to_h
    id = source.fetch('id')
    source['dose_final'] = source['dose_final'].to_i if source['dose_final']
    source.delete_if { |_field, value| value.nil? || (value.respond_to?(:empty?) && value.empty?) }
    batch << JSON.generate(index: { _index: options[:index], _id: id })
    batch << JSON.generate(source)
    count += 1
    flush.call if count.modulo(options[:batch_size]).zero?
  end
end
flush.call
puts "Imported #{count} documents into #{options[:index]}"
