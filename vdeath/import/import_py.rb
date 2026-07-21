#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'net/http'
require 'optparse'
require 'uri'

options = {
  index: 'vdeath2026',
  url: 'http://localhost:9200',
  credentials: File.expand_path('~/.config/mstats/espass.txt'),
  mapping: File.expand_path('../config/elasticsearch/vdeath2026.json', __dir__),
  batch_size: 1_000,
  replace: false
}

OptionParser.new do |parser|
  parser.banner = 'Usage: import_py.rb [options] CSV ...'
  parser.on('--index NAME', 'Destination index') { |v| options[:index] = v }
  parser.on('--url URL', 'Elasticsearch URL') { |v| options[:url] = v }
  parser.on('--credentials FILE', 'account:password file') { |v| options[:credentials] = v }
  parser.on('--mapping FILE', 'Index mapping JSON') { |v| options[:mapping] = v }
  parser.on('--batch-size N', Integer, 'Documents per bulk request') { |v| options[:batch_size] = v }
  parser.on('--replace', 'Delete and recreate the destination index') { options[:replace] = true }
end.parse!
abort 'CSV file is required' if ARGV.empty?

credential = File.read(options[:credentials]).delete_suffix("\n").delete_suffix("\r")
account, password = credential.split(':', 2)
abort "Invalid credentials file: #{options[:credentials]}" if account.to_s.empty? || password.to_s.empty?

base_uri = URI(options[:url])

# Elasticsearchへ認証付きrequestを送り、失敗時は秘密値を出さずに終了する。
# Send an authenticated Elasticsearch request and fail without exposing credentials.
def es_request(base_uri, account, password, method, path, body = nil, content_type = 'application/json')
  uri = base_uri.dup
  uri.path = path
  request = method.new(uri)
  request.basic_auth(account, password)
  request['Content-Type'] = content_type
  request.body = body if body
  http = Net::HTTP.new(uri.hostname, uri.port, nil)
  http.use_ssl = uri.scheme == 'https'
  response = http.start { |client| client.request(request) }
  return response if response.is_a?(Net::HTTPSuccess)

  abort "Elasticsearch #{request.method} #{path} failed: HTTP #{response.code} #{response.body}"
end

index_path = "/#{options[:index]}"
head_uri = base_uri.dup
head_uri.path = index_path
head_request = Net::HTTP::Head.new(head_uri)
head_request.basic_auth(account, password)
head_http = Net::HTTP.new(head_uri.hostname, head_uri.port, nil)
head_http.use_ssl = head_uri.scheme == 'https'
head = head_http.start { |http| http.request(head_request) }
if options[:replace] && head.is_a?(Net::HTTPSuccess)
  es_request(base_uri, account, password, Net::HTTP::Delete, index_path)
  head = nil
end
unless head.is_a?(Net::HTTPSuccess)
  abort "Cannot inspect #{options[:index]}: HTTP #{head.code}" if head && head.code != '404'

  es_request(base_uri, account, password, Net::HTTP::Put, index_path, File.read(options[:mapping]))
end

integer_fields = %w[lives persondays deaths].freeze
float_fields = %w[lb0 ub0 rr0 lbm ubm mortality].freeze
batch = []
count = 0

# bulk requestは一定件数ずつ送り、同じIDの再実行を安全な上書きにする。
# Send bounded bulk requests; reruns safely replace documents with the same ID.
flush = lambda do
  next if batch.empty?

  body = batch.join("\n") + "\n"
  response = es_request(base_uri, account, password, Net::HTTP::Post, '/_bulk', body, 'application/x-ndjson')
  result = JSON.parse(response.body)
  if result['errors']
    failure = result.fetch('items').filter_map { |item| item.fetch('index')['error'] }.first
    abort "Bulk import failed: #{failure.to_json}"
  end
  batch.clear
end

ARGV.each do |path|
  CSV.foreach(path, headers: true) do |row|
    source = row.to_h
    id = source.fetch('id')
    source['doc_id'] = id
    integer_fields.each { |field| source[field] = source[field].to_i }
    float_fields.each do |field|
      value = source[field]
      value.nil? || value.empty? || value == '-' ? source.delete(field) : source[field] = value.to_f
    end
    batch << JSON.generate(index: { _index: options[:index], _id: id })
    batch << JSON.generate(source)
    count += 1
    flush.call if count.modulo(options[:batch_size]).zero?
  end
end
flush.call
puts "Imported #{count} documents into #{options[:index]}"
