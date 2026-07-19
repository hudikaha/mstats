#!/usr/bin/env ruby
# coding: utf-8

require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'time'
require 'uri'

INDEX = ENV.fetch('KCOR_INDEX', 'kcor')
ES_URL = ENV.fetch('ES_URL', 'http://127.0.0.1:9200')
ES_USER = ENV.fetch('ES_USER', 'elastic')
ES_PASSWORD = ENV.fetch('ES_PASSWORD')
OUTPUT_DIR = ARGV.fetch(0)
PAGE_SIZE = 10_000
SOURCE_FIELDS = %w[areacode area areaj date age dose deaths].freeze

# 認証付きでKCOR indexへ検索要求を送り、JSON応答を返す。
# Send an authenticated request to the KCOR index and return its JSON response.
def es_request(path, body)
  uri = URI.join("#{ES_URL}/", path)
  request = Net::HTTP::Post.new(uri)
  request.basic_auth(ES_USER, ES_PASSWORD)
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(body)
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  abort "Elasticsearch #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

# indexに存在するcutoff日を昇順で取得する。
# Return the cutoff dates present in the index in ascending order.
def cutoff_values
  response = es_request("#{INDEX}/_search", {
    size: 0,
    aggs: { cutoffs: { terms: { field: 'cutoff', size: 100, order: { _key: 'asc' } } } }
  })
  response.dig('aggregations', 'cutoffs', 'buckets').map { |bucket| bucket.fetch('key_as_string')[0, 10] }
end

# 指定cutoffの公開対象フィールドをsearch_afterで全件取得する。
# Retrieve every public field for a cutoff using search_after pagination.
def documents_for(cutoff)
  documents = []
  search_after = nil
  loop do
    body = {
      size: PAGE_SIZE,
      _source: SOURCE_FIELDS,
      query: { term: { cutoff: cutoff } },
      sort: [{ id: 'asc' }]
    }
    body[:search_after] = search_after if search_after
    hits = es_request("#{INDEX}/_search", body).dig('hits', 'hits')
    break if hits.empty?
    documents.concat(hits.map { |hit| hit.fetch('_source') })
    search_after = hits.last.fetch('sort')
  end
  documents
end

# 辞書化に使う値を重複除去して安定順に並べる。
# Deduplicate and stably order values used by compact dictionaries.
def ordered(values)
  values.uniq.sort
end

FileUtils.mkdir_p(OUTPUT_DIR)
files = []

cutoff_values.each do |cutoff|
  documents = documents_for(cutoff)
  areas = documents.map { |row| [row.fetch('areacode'), row.fetch('area'), row.fetch('areaj')] }.uniq.sort
  dates = ordered(documents.map { |row| row.fetch('date')[0, 10] })
  ages = ordered(documents.map { |row| row.fetch('age') }).sort_by { |age| age.to_i }
  area_index = areas.each_with_index.to_h
  date_index = dates.each_with_index.to_h
  age_index = ages.each_with_index.to_h
  rows = documents.map do |row|
    [
      area_index.fetch([row.fetch('areacode'), row.fetch('area'), row.fetch('areaj')]),
      date_index.fetch(row.fetch('date')[0, 10]),
      age_index.fetch(row.fetch('age')),
      row.fetch('dose').to_i,
      row.fetch('deaths').to_i
    ]
  end

  payload = { version: 1, cutoff: cutoff, areas: areas, dates: dates, ages: ages, rows: rows }
  filename = "#{cutoff}.json"
  path = File.join(OUTPUT_DIR, filename)
  File.binwrite(path, JSON.generate(payload))
  files << {
    cutoff: cutoff,
    file: filename,
    rows: rows.length,
    bytes: File.size(path),
    sha256: Digest::SHA256.file(path).hexdigest
  }
  warn "#{cutoff}: #{rows.length} rows"
end

manifest = {
  version: 1,
  index: INDEX,
  generated_at: Time.now.utc.iso8601,
  anchor_date: '2024-03-03',
  default_cutoff: '2021-09-05',
  cutoffs: files
}
File.binwrite(File.join(OUTPUT_DIR, 'manifest.json'), JSON.generate(manifest))
