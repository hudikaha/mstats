#!/usr/bin/ruby
# coding: utf-8

require 'json'
require 'net/http'
require 'uri'

index = ARGV.fetch(0, 'mstats20260719')
expected_total = Integer(ARGV.fetch(1, '1446906'))
password_file = File.expand_path('~/.config/mstats/espass.txt')
password = ENV['ES_PASSWORD']
password = File.read(password_file).strip if password.to_s.empty? && File.file?(password_file)
abort 'ES_PASSWORD or ~/.config/mstats/espass.txt is required' if password.to_s.empty?

# 認証値を表示せずElasticsearchへJSON requestを送る。
# Send an Elasticsearch JSON request without exposing credentials.
def es_request(method, path, password, body = nil)
  uri = URI("http://localhost:9200#{path}")
  request = method.new(uri)
  request.basic_auth(ENV.fetch('ES_USER', 'elastic'), password)
  if body
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(body)
  end
  response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
  abort "Elasticsearch HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

mapping = es_request(Net::HTTP::Get, "/#{index}/_mapping", password)
resolved_mapping = mapping[index] || (mapping.values.first if mapping.length == 1)
age_mapping = resolved_mapping&.dig('mappings', 'properties', 'age_all')
expected_mapping = { 'type' => 'scaled_float', 'scaling_factor' => 100.0 }
abort "wrong age_all mapping: #{age_mapping.inspect}" unless age_mapping == expected_mapping
puts 'mapping age_all=scaled_float scaling_factor=100'

queries = {
  total: [{ 'match_all' => {} }, expected_total],
  pop_monthly: [
    { 'bool' => { 'must' => [{ 'term' => { 'category' => 'pop' } }, { 'exists' => { 'field' => 'yearmonth' } }] } },
    1890
  ],
  death_monthly: [
    { 'bool' => { 'must' => [{ 'term' => { 'category' => 'death' } }, { 'exists' => { 'field' => 'yearmonth' } }] } },
    83_748
  ],
  death_weekly_jpn: [
    { 'bool' => { 'must' => [{ 'term' => { 'category' => 'death' } }, { 'term' => { 'loc_code' => 'jpn' } }, { 'exists' => { 'field' => 'yearweek' } }] } },
    1_090_314
  ],
  death_weekly_stmf: [
    { 'bool' => { 'must' => [{ 'term' => { 'category' => 'death' } }, { 'exists' => { 'field' => 'yearweek' } }],
                  'must_not' => [{ 'term' => { 'loc_code' => 'jpn' } }] } },
    270_954
  ]
}.freeze

queries.each do |label, (query, expected)|
  result = es_request(Net::HTTP::Post, "/#{index}/_count", password, 'query' => query)
  actual = result.fetch('count')
  abort "#{label}: expected #{expected}, got #{actual}" unless actual == expected
  puts "#{label}=#{actual}"
end

representatives = {
  'jpn_2024w09_death__00000__both' => %w[date age_all],
  'usa_2025w53_death__00000__both' => %w[date age_all]
}.freeze
representatives.each do |id, fields|
  result = es_request(Net::HTTP::Get, "/#{index}/_doc/#{id}", password)
  abort "representative document not found: #{id}" unless result['found']
  values = fields.to_h { |field| [field, result.fetch('_source')[field]] }
  puts "#{id} #{values.map { |field, value| "#{field}=#{value}" }.join(' ')}"
end
