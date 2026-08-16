#!/usr/bin/ruby
# coding: utf-8

require 'json'
require 'net/http'
require 'uri'

index = ARGV.fetch(0, 'mstats20260816')
expected_total = Integer(ARGV.fetch(1, '3537810'))
password_file = File.expand_path('~/.config/mstats/espass.txt')
user = ENV.fetch('ES_USER', 'elastic')
password = ENV['ES_PASSWORD']
if password.to_s.empty? && File.file?(password_file)
  stored_user, stored_password = File.read(password_file).strip.split(':', 2)
  user = stored_user unless stored_user.to_s.empty?
  password = stored_password
end
abort 'ES_PASSWORD or ~/.config/mstats/espass.txt is required' if password.to_s.empty?

# 認証値を表示せずElasticsearchへJSON requestを送る。
# Send an Elasticsearch JSON request without exposing credentials.
def es_request(method, path, user, password, body = nil)
  uri = URI("http://localhost:9200#{path}")
  request = method.new(uri)
  request.basic_auth(user, password)
  if body
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(body)
  end
  response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
  abort "Elasticsearch HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

mapping = es_request(Net::HTTP::Get, "/#{index}/_mapping", user, password)
resolved_mapping = mapping[index] || (mapping.values.first if mapping.length == 1)
age_mapping = resolved_mapping&.dig('mappings', 'properties', 'age_all')
expected_mapping = { 'type' => 'scaled_float', 'scaling_factor' => 100.0 }
abort "wrong age_all mapping: #{age_mapping.inspect}" unless age_mapping == expected_mapping
puts 'mapping age_all=scaled_float scaling_factor=100'

properties = resolved_mapping.fetch('mappings').fetch('properties')
%w[loc area areaj].each do |field|
  abort "missing mapping field: #{field}" unless properties.key?(field)
end
%w[loc_code location world_region age_80over age_85over age_100over].each do |field|
  abort "legacy mapping field remains: #{field}" if properties.key?(field)
end
puts 'mapping canonical_fields=loc,area,areaj legacy_fields=none'

queries = {
  total: [{ 'match_all' => {} }, expected_total],
  pop_monthly: [
    { 'bool' => { 'must' => [{ 'term' => { 'category' => 'pop' } }, { 'exists' => { 'field' => 'yearmonth' } }] } },
    2235
  ],
  death_monthly: [
    { 'bool' => { 'must' => [{ 'term' => { 'category' => 'death' } }, { 'exists' => { 'field' => 'yearmonth' } }],
                  'must_not' => [{ 'term' => { 'type' => 'unmonth' } }] } },
    209_100
  ],
  death_monthly_un: [
    { 'term' => { 'type' => 'unmonth' } },
    81_768
  ],
  death_weekly_reconstructed_jpn: [
    { 'term' => { 'type' => 'stmfrecon' } },
    1_860_648
  ],
  death_weekly_stmf: [
    { 'term' => { 'type' => 'stmf' } },
    809_181
  ],
  yearly_wpp: [
    { 'terms' => { 'type' => %w[unwpp2024est unwpp2024expest unwpp2024prj unwpp2024expprj] } },
    521_454
  ],
  yearly_reconstructed: [
    { 'term' => { 'type' => 'recon' } },
    3_385
  ],
  who_standard: [
    { 'term' => { 'algo' => 'whostd' } },
    598_565
  ],
  japan_2015_standard: [
    { 'term' => { 'algo' => 'jp2015std' } },
    371_078
  ],
  canonical_locations: [
    { 'bool' => { 'must' => %w[loc area areaj].map { |field| { 'exists' => { 'field' => field } } } } },
    expected_total
  ]
}.freeze

queries.each do |label, (query, expected)|
  result = es_request(Net::HTTP::Post, "/#{index}/_count", user, password, 'query' => query)
  actual = result.fetch('count')
  abort "#{label}: expected #{expected}, got #{actual}" unless actual == expected
  puts "#{label}=#{actual}"
end

representatives = {
  'jpn_2024w09_death__allcause__stmfrecon_both' => %w[date age_all],
  'usa_2025w53_death__allcause__stmf_both' => %w[date age_all],
  'jpn_2009_death__allcause___both' => %w[date age_all src_url],
  'jpn_2014_death_asr_allcause_whostd__both' => %w[date age_all src_url],
  'swe_2023_death_asr_allcause_whostd_unwpp2024est_both' => %w[date age_all src_url],
  'usa_2024_birth____cfm_both' => %w[date age_all src_url],
  'usa_2024_death__allcause__cfm_both' => %w[date age_0 src_url],
  'usa_2022_death__perm__recon_both' => %w[date age_all src_url]
}.freeze
representatives.each do |id, fields|
  result = es_request(Net::HTTP::Get, "/#{index}/_doc/#{id}", user, password)
  abort "representative document not found: #{id}" unless result['found']
  values = fields.to_h { |field| [field, result.fetch('_source')[field]] }
  puts "#{id} #{values.map { |field, value| "#{field}=#{value}" }.join(' ')}"
end


invalid_ids = es_request(Net::HTTP::Post, "/#{index}/_count", user, password,
                         'query' => { 'script' => { 'script' => {
                           'lang' => 'painless',
                           'source' => 'doc["id"].value.splitOnToken("_").length != 8'
                         } } }).fetch('count')
abort "non-canonical IDs=#{invalid_ids}" unless invalid_ids.zero?
puts 'canonical_eight_component_ids=ok'

# 新形式へ旧語が混入していないことを確認する。
# Confirm that no legacy vocabulary remains in the canonical index.
legacy_query = {
  'bool' => {
    'should' => [
      { 'terms' => { 'rate' => %w[amr adj] } },
      { 'terms' => { 'death_code' => %w[00000 INFANT PERM] } },
      { 'terms' => { 'type' => %w[conf confirmed reconst unwpp2024proj unwpp2024expproj] } }
    ],
    'minimum_should_match' => 1
  }
}
legacy_count = es_request(Net::HTTP::Post, "/#{index}/_count", user, password,
                          'query' => legacy_query).fetch('count')
abort "legacy vocabulary documents=#{legacy_count}" unless legacy_count.zero?
puts 'legacy_vocabulary=none'
