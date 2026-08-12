#!/usr/bin/ruby
# coding: utf-8
# frozen_string_literal: true

require 'cgi'
require 'date'
require 'digest'
require 'fileutils'
require 'json'
require 'matrix'
require 'optparse'
require 'tmpdir'
require 'time'
require 'zlib'

mfacts = [
  File.expand_path('lib/mfacts.rb', __dir__),
  File.expand_path('../../../lib/mfacts.rb', __dir__),
  File.expand_path('../../lib/mfacts.rb', __dir__),
  File.expand_path('../lib/mfacts.rb', __dir__)
].find { |path| File.file?(path) }
abort 'lib/mfacts.rb not found' unless mfacts
require mfacts

country_names_library = [
  File.expand_path('mstats.rb', __dir__),
  File.expand_path('../vdeath/lib/mstats.rb', __dir__)
].find { |path| File.file?(path) }
abort 'country-name source mstats.rb not found' unless country_names_library
require country_names_library
COUNTRY_NAMES = Locs.transform_values(&:dup).freeze
Object.send(:remove_const, :Locs)
COUNTRY_NAME_OVERRIDES = {
  'XKX' => { ja: 'コソボ', en: 'Kosovo' },
  'PRK' => { ja: '北朝鮮', en: 'North Korea' }
}.freeze

mort_vars = [
  File.expand_path('mort-vars.rb', __dir__),
  File.expand_path('../../../web/mort-vars.rb', __dir__)
].find { |path| File.file?(path) }
abort 'web/mort-vars.rb not found' unless mort_vars
require mort_vars

AGES = {
  'age_all' => { ja: 'all', en: 'all' },
  'age_0' => { ja: '0', en: '0' },
  'age_00_04' => { ja: '00-04', en: '00-04' },
  'age_05_09' => { ja: '05-09', en: '05-09' },
  'age_10_14' => { ja: '10-14', en: '10-14' },
  'age_15_19' => { ja: '15-19', en: '15-19' },
  'age_20_24' => { ja: '20-24', en: '20-24' },
  'age_25_29' => { ja: '25-29', en: '25-29' },
  'age_30_34' => { ja: '30-34', en: '30-34' },
  'age_35_39' => { ja: '35-39', en: '35-39' },
  'age_40_44' => { ja: '40-44', en: '40-44' },
  'age_45_49' => { ja: '45-49', en: '45-49' },
  'age_50_54' => { ja: '50-54', en: '50-54' },
  'age_55_59' => { ja: '55-59', en: '55-59' },
  'age_60_64' => { ja: '60-64', en: '60-64' },
  'age_65_69' => { ja: '65-69', en: '65-69' },
  'age_70_74' => { ja: '70-74', en: '70-74' },
  'age_75_79' => { ja: '75-79', en: '75-79' },
  'age_80_84' => { ja: '80-84', en: '80-84' },
  'age_85_89' => { ja: '85-89', en: '85-89' },
  'age_90_94' => { ja: '90-94', en: '90-94' },
  'age_95_99' => { ja: '95-99', en: '95-99' },
  'age_100over' => { ja: '100+', en: '100+' }
}.freeze
STANDARD_AGES = AGES.keys.grep(/age_(?:\d{2}_\d{2}|100over)/).freeze
WHO_WORLD_STANDARD = {
  'age_00_04' => 8.86, 'age_05_09' => 8.69, 'age_10_14' => 8.60,
  'age_15_19' => 8.47, 'age_20_24' => 8.22, 'age_25_29' => 7.93,
  'age_30_34' => 7.61, 'age_35_39' => 7.15, 'age_40_44' => 6.59,
  'age_45_49' => 6.04, 'age_50_54' => 5.37, 'age_55_59' => 4.55,
  'age_60_64' => 3.72, 'age_65_69' => 2.96, 'age_70_74' => 2.21,
  'age_75_79' => 1.52, 'age_80_84' => 0.91, 'age_85_89' => 0.44,
  'age_90_94' => 0.15, 'age_95_99' => 0.04, 'age_100over' => 0.005
}.freeze

METRICS = {
  'deaths' => { ja: '実死亡数', en: 'Observed deaths' },
  'std_deaths' => { ja: '標準人口換算死亡数', en: 'Deaths standardized to the reference population' },
  'crude_rate' => { ja: '粗死亡率', en: 'Crude mortality rate' },
  'asr' => { ja: '年齢調整死亡率', en: 'Age-standardized mortality rate' },
  'birth_rate' => { ja: '出生関連死亡率', en: 'Birth-based mortality rate' }
}.freeze
SPECIAL_CAUSES = {
  'INFANT' => { ja: '乳児死亡率', en: 'Infant mortality rate' },
  'PERINATAL' => { ja: '周産期死亡率', en: 'Perinatal mortality rate' }
}.freeze
WORLD_REGIONS = {
  'Africa' => { ja: 'アフリカ', en: 'Africa' },
  'Asia' => { ja: 'アジア', en: 'Asia' },
  'Europe' => { ja: 'ヨーロッパ', en: 'Europe' },
  'Latin America and the Caribbean' => { ja: '中南米・カリブ', en: 'Latin America and the Caribbean' },
  'Northern America' => { ja: '北アメリカ', en: 'Northern America' },
  'Oceania' => { ja: 'オセアニア', en: 'Oceania' },
  'Other' => { ja: 'その他', en: 'Other' }
}.freeze

HMD_URL = 'https://www.mortality.org/Data/STMF'
WPP_URL = 'https://population.un.org/wpp/downloads'
ESTAT_DEATH_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0'
ESTAT_POP_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0'
DAYS_PER_YEAR = 365.2425
Z95 = 1.959963984540054
MIN_TRAINING_YEARS = 4
POISSON_SIMULATIONS = 10_000
CACHE_SCHEMA = 2
CACHE_MAX_BYTES = 1024 * 1024 * 1024
CACHE_MAX_AGE = 30 * 24 * 60 * 60

opts = { index: 'mstats', debug: false, fixture: nil, summary: false }
OptionParser.new do |parser|
  parser.on('--index INDEX') { |value| opts[:index] = value }
  parser.on('--debug') { opts[:debug] = true }
  parser.on('--fixture FILE') { |value| opts[:fixture] = value }
  parser.on('--summary') { opts[:summary] = true }
end.parse!(ARGV)

cgi = CGI.new
$l = cgi['l'] == 'en' ? :en : :ja
mode = cgi['mode'] == 'series' ? 'series' : 'country'
requested_locations = cgi.params.fetch('c', []).flat_map { |value| value.split(/[~,]/) }.
                      map(&:upcase).uniq
selected_ages = cgi.params.fetch('age', []).flat_map { |value| value.split(/[~,]/) }.
                select { |age| AGES.key?(age) }.uniq
selected_ages = ['age_all'] if selected_ages.empty?
selected_sex = %w[both male female].include?(cgi['sex']) ? cgi['sex'] : 'both'
selected_metric = METRICS.key?(cgi['metric']) ? cgi['metric'] : 'deaths'
selected_ages = ['age_all'] if selected_metric == 'asr' || selected_metric == 'birth_rate'
requested_causes = cgi.params.fetch('death_codes', []).flat_map { |value| value.split(/[~,]/) }.uniq
requested_start_year = cgi['start_year'].to_i
default_start_year = requested_start_year.between?(1950, 2015) ? requested_start_year : 2000

def location_names(code)
  known = COUNTRY_NAME_OVERRIDES[code] || COUNTRY_NAMES[code]
  source_name = $annual_catalog&.dig(code, :location).to_s
  return known if known
  { ja: source_name.empty? ? code : source_name, en: source_name.empty? ? code : source_name }
end

def location_sort_key(code, language)
  name = location_names(code).fetch(language)
  return name.downcase unless language == :ja

  [name.match?(/\A[ァ-ヿ]/) ? 0 : 1, name]
end

def default_source_urls(loc_code)
  loc_code.to_s.upcase == 'JPN' ? [ESTAT_DEATH_URL, ESTAT_POP_URL] : [HMD_URL]
end

# 日本語: 国ごとに存在する週次系列のrate値を返す。
# English: Return the weekly rate-field values available for each location.
def available_location_rates(index:, fixture:)
  if fixture
    rates = fixture.group_by { |row| row[:loc_code].to_s.upcase }.transform_values do |rows|
      rows.map { |row| row[:rate].to_s }.uniq
    end
    return rates
  end

  public_index = PUBLIC_ELASTIC_INDEXES[index.to_s]
  uri = if public_index
          URI.parse("http://localhost:8080/elastic/#{public_index}/_search")
        else
          URI.parse("http://localhost:9200/#{index}/_search")
        end
  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'
  elastic_basic_auth(request) unless public_index
  request.body = JSON.generate(
    size: 0,
    query: { bool: { filter: [
      { term: { category: 'death' } },
      { term: { death_code: '00000' } },
      { exists: { field: 'yearweek' } }
    ] } },
    aggs: { locations: { terms: { field: 'loc_code', size: 300 },
                         aggs: { rates: { terms: { field: 'rate', size: 20 } } } } }
  )
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  raise "Elasticsearch aggregation failed: HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).dig('aggregations', 'locations', 'buckets').to_h do |bucket|
    rates = bucket.dig('rates', 'buckets').map { |rate| rate['key'] }
    [bucket['key'].upcase, rates]
  end
end

# 日本語: HMD週次ではなく、年次recordから国・地域と利用可能な指標を列挙する。
# English: Enumerate locations and measures from annual records, not HMD weekly data.
def available_annual_catalog(index:, fixture:)
  if fixture
    annual = fixture.reject { |row| row[:yearmonth] || row[:yearweek] }
    return annual.group_by { |row| row[:loc_code].to_s.upcase }.transform_values do |rows|
      sample = rows.find { |row| row[:world_region] } || rows.first
      {
        location: sample[:location].to_s, world_region: sample[:world_region].to_s,
        rates: rows.map { |row| row[:rate].to_s }.uniq,
        categories: rows.map { |row| row[:category].to_s }.uniq,
        death_codes: rows.map { |row| row[:death_code].to_s }.reject(&:empty?).uniq,
        algos: rows.map { |row| row[:algo].to_s }.uniq
      }
    end
  end

  public_index = PUBLIC_ELASTIC_INDEXES[index.to_s]
  uri = URI.parse(public_index ? "http://localhost:8080/elastic/#{public_index}/_search" : "http://localhost:9200/#{index}/_search")
  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'
  elastic_basic_auth(request) unless public_index
  request.body = JSON.generate(
    size: 0,
    query: { bool: { must_not: [{ exists: { field: 'yearmonth' } }, { exists: { field: 'yearweek' } }] } },
    aggs: { locations: { terms: { field: 'loc_code', size: 300 }, aggs: {
      sample: { top_hits: { size: 1, _source: %w[location] } },
      region_sample: { filter: { exists: { field: 'world_region' } },
                       aggs: { hit: { top_hits: { size: 1, _source: %w[location world_region] } } } },
      rates: { terms: { field: 'rate', size: 20 } },
      categories: { terms: { field: 'category', size: 20 } },
      death_codes: { terms: { field: 'death_code', size: 1000 } },
      algos: { terms: { field: 'algo', size: 20 } }
    } } }
  )
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  raise "Elasticsearch annual catalog failed: HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).dig('aggregations', 'locations', 'buckets').to_h do |bucket|
    source = bucket.dig('region_sample', 'hit', 'hits', 'hits', 0, '_source') ||
             bucket.dig('sample', 'hits', 'hits', 0, '_source') || {}
    values = ->(name) { bucket.dig(name, 'buckets').map { |entry| entry['key'].to_s } }
    [bucket['key'].upcase, {
      location: source['location'].to_s, world_region: source['world_region'].to_s,
      rates: values.call('rates'), categories: values.call('categories'),
      death_codes: values.call('death_codes'), algos: values.call('algos')
    }]
  end
end

def metric_available?(code, rates, metric)
  raw = rates.include?('')
  case metric
  when 'deaths' then raw
  when 'std_deaths' then code == 'JPN' && rates.include?('adj')
  when 'crude_rate' then code != 'JPN' && raw && rates.include?('amr')
  when 'asr' then code == 'JPN' && rates.include?('adj') && rates.include?('amr')
  when 'birth_rate' then true
  else false
  end
end

def annual_metric_available?(code, catalog, metric)
  rates = catalog.fetch(:rates)
  categories = catalog.fetch(:categories)
  codes = catalog.fetch(:death_codes)
  case metric
  when 'deaths' then categories.include?('death') && codes.include?('00000')
  when 'crude_rate' then rates.include?('crude_rate')
  when 'asr' then rates.include?('asr')
  when 'birth_rate'
    categories.include?('birth') &&
      (codes.include?('INFANT') || codes.include?('PERM') || (code == 'USA' && codes.include?('00000')))
  else false
  end
end

# 日本語: 米国乳児死亡は既存の全死因recordのage_0にあるため、表示可能性を保存codeから変換する。
# English: U.S. infant deaths use age_0 of the legacy all-cause record, so map storage codes to display availability.
def birth_cause_available?(location, catalog, cause)
  codes = catalog.fetch(:death_codes)
  return codes.include?('PERM') if cause == 'PERINATAL'
  codes.include?('INFANT') || (location == 'USA' && codes.include?('00000'))
end

def available_death_codes(index:, fixture:, locations:, metric:)
  wanted_rate = %w[std_deaths asr].include?(metric) ? 'adj' : ''
  if fixture
    return fixture.select do |row|
      locations.include?(row[:loc_code].to_s.upcase) && row[:yearweek] && row[:rate].to_s == wanted_rate
    end.map { |row| row[:death_code].to_s }.uniq.sort
  end
  public_index = PUBLIC_ELASTIC_INDEXES[index.to_s]
  uri = URI.parse(public_index ? "http://localhost:8080/elastic/#{public_index}/_search" : "http://localhost:9200/#{index}/_search")
  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'
  elastic_basic_auth(request) unless public_index
  rate_filter = wanted_rate.empty? ? {
    bool: { should: [{ term: { rate: '' } }, { bool: { must_not: [{ exists: { field: 'rate' } }] } }], minimum_should_match: 1 }
  } : { term: { rate: wanted_rate } }
  request.body = JSON.generate(size: 0, query: { bool: { filter: [
    { term: { category: 'death' } }, { terms: { loc_code: locations.map(&:downcase) } },
    { exists: { field: 'yearweek' } }, rate_filter
  ] } }, aggs: { codes: { terms: { field: 'death_code', size: 1000 } } })
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  raise "Elasticsearch cause aggregation failed: HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body).dig('aggregations', 'codes', 'buckets').map { |bucket| bucket['key'] }.sort
end

def available_annual_death_codes(index:, fixture:, locations:, metric:)
  wanted_rate = { 'crude_rate' => 'crude_rate', 'asr' => 'asr' }.fetch(metric, '')
  if fixture
    return fixture.select do |row|
      locations.include?(row[:loc_code].to_s.upcase) && !row[:yearmonth] && !row[:yearweek] &&
        row[:category] == 'death' && row[:rate].to_s == wanted_rate
    end.map { |row| row[:death_code].to_s }.reject(&:empty?).uniq.sort
  end
  public_index = PUBLIC_ELASTIC_INDEXES[index.to_s]
  uri = URI.parse(public_index ? "http://localhost:8080/elastic/#{public_index}/_search" : "http://localhost:9200/#{index}/_search")
  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'
  elastic_basic_auth(request) unless public_index
  rate_filter = wanted_rate.empty? ? {
    bool: { should: [{ term: { rate: '' } }, { bool: { must_not: [{ exists: { field: 'rate' } }] } }], minimum_should_match: 1 }
  } : { term: { rate: wanted_rate } }
  request.body = JSON.generate(size: 0, query: { bool: {
    filter: [{ term: { category: 'death' } }, { terms: { loc_code: locations.map(&:downcase) } }, rate_filter],
    must_not: [{ exists: { field: 'yearmonth' } }, { exists: { field: 'yearweek' } }]
  } }, aggs: { codes: { terms: { field: 'death_code', size: 1000 } } })
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  raise "Elasticsearch annual cause aggregation failed: HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body).dig('aggregations', 'codes', 'buckets').map { |bucket| bucket['key'] }.sort
end

# 日本語: 2x2行列の逆行列を、回帰処理で外部gemなしに利用する。
# English: Invert a 2x2 matrix without an external statistics gem.
def inverse_2x2(matrix)
  determinant = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]
  raise 'singular regression matrix' if determinant.abs < 1e-12

  [
    [matrix[1][1] / determinant, -matrix[0][1] / determinant],
    [-matrix[1][0] / determinant, matrix[0][0] / determinant]
  ]
end

# 日本語: 人口offset付きPoisson回帰をIRLSで推定する。
# English: Fit a population-offset Poisson regression by IRLS.
def poisson_fit(rows)
  center = rows.sum { |row| row[:year] }.fdiv(rows.length)
  beta = [Math.log(rows.sum { |row| row[:deaths] }.fdiv(rows.sum { |row| row[:population] })), 0.0]
  covariance = nil

  100.times do
    xtwx = [[0.0, 0.0], [0.0, 0.0]]
    xtwz = [0.0, 0.0]
    rows.each do |row|
      x = [1.0, row[:year] - center]
      eta = beta[0] + beta[1] * x[1] + Math.log(row[:population])
      mu = Math.exp(eta)
      z = eta + (row[:deaths] - mu) / mu - Math.log(row[:population])
      2.times do |i|
        xtwz[i] += x[i] * mu * z
        2.times { |j| xtwx[i][j] += x[i] * mu * x[j] }
      end
    end
    covariance = inverse_2x2(xtwx)
    updated = 2.times.map { |i| covariance[i][0] * xtwz[0] + covariance[i][1] * xtwz[1] }
    difference = 2.times.map { |i| (updated[i] - beta[i]).abs }.max
    beta = updated
    break if difference < 1e-10
  end

  pearson = rows.sum do |row|
    mu = Math.exp(beta[0] + beta[1] * (row[:year] - center)) * row[:population]
    (row[:deaths] - mu)**2 / mu
  end
  dispersion = rows.length > 2 ? pearson / (rows.length - 2) : nil
  { beta: beta, covariance: covariance, center: center, dispersion: dispersion }
end

# 日本語: 係数不確実性とPoisson観測分散を含む近似95%予測区間を作る。
# English: Build an approximate 95% PI including coefficient and Poisson observation variance.
def poisson_prediction(row, fit, variance_scale = 1.0)
  x = [1.0, row[:year] - fit[:center]]
  eta = fit[:beta][0] + fit[:beta][1] * x[1]
  scale = row.fetch(:unit_scale, 100_000)
  rate = Math.exp(eta) * scale
  mu = Math.exp(eta) * row[:population]
  var_eta = 2.times.sum do |i|
    2.times.sum { |j| x[i] * fit[:covariance][i][j] * x[j] }
  end
  se_count = Math.sqrt(variance_scale * mu + mu * mu * variance_scale * var_eta)
  lower = [0.0, mu - Z95 * se_count].max / row[:population] * scale
  upper = (mu + Z95 * se_count) / row[:population] * scale
  { expected: rate, lower: lower, upper: upper }
end

def poisson_random(random, lambda)
  if lambda < 30.0
    limit = Math.exp(-lambda)
    product = 1.0
    count = 0
    begin
      count += 1
      product *= random.rand
    end while product > limit
    return count - 1
  end

  root = Math.sqrt(lambda)
  log_lambda = Math.log(lambda)
  b = 0.931 + 2.53 * root
  a = -0.059 + 0.02483 * b
  inverse_alpha = 1.1239 + 1.1328 / (b - 3.4)
  vr = 0.9277 - 3.6224 / (b - 2.0)
  loop do
    u = random.rand - 0.5
    v = random.rand
    us = 0.5 - u.abs
    k = ((2.0 * a / us + b) * u + lambda + 0.43).floor
    return k if us >= 0.07 && v <= vr
    next if k.negative? || (us < 0.013 && v > us)
    return k if Math.log(v * inverse_alpha / (a / (us * us) + b)) <= -lambda + k * log_lambda - Math.lgamma(k + 1).first
  end
end

def coefficient_draws(fit, count, random)
  covariance = fit[:covariance]
  l00 = Math.sqrt([covariance[0][0], 0.0].max)
  l10 = covariance[1][0] / l00
  l11 = Math.sqrt([covariance[1][1] - l10 * l10, 0.0].max)
  Array.new(count) do
    radius = Math.sqrt(-2.0 * Math.log([random.rand, Float::MIN].max))
    angle = 2.0 * Math::PI * random.rand
    z0 = radius * Math.cos(angle)
    z1 = radius * Math.sin(angle)
    [fit[:beta][0] + l00 * z0, fit[:beta][1] + l10 * z0 + l11 * z1]
  end
end

def poisson_simulation_predictions(rows, fit, seed)
  random = Random.new(seed)
  betas = coefficient_draws(fit, POISSON_SIMULATIONS, random)
  rows.to_h do |row|
    x = row[:year] - fit[:center]
    scale = row.fetch(:unit_scale, 100_000.0)
    simulations = betas.map do |beta|
      mu = Math.exp(beta[0] + beta[1] * x) * row[:population]
      poisson_random(random, mu) / row[:population] * scale
    end.sort
    lower = simulations[(POISSON_SIMULATIONS * 0.025).floor]
    upper = simulations[(POISSON_SIMULATIONS * 0.975).floor - 1]
    expected = Math.exp(fit[:beta][0] + fit[:beta][1] * x) * scale
    [[row[:year], row[:death_code]], { expected: expected, lower: lower, upper: upper }]
  end
end

def canonical_value(value)
  case value
  when Hash
    value.to_h { |key, item| [key.to_s, canonical_value(item)] }.sort.to_h
  when Array
    value.map { |item| canonical_value(item) }
  else
    value
  end
end

def canonical_json(value)
  JSON.generate(canonical_value(value))
end

def gzip_write(path, value)
  temporary = "#{path}.#{Process.pid}.tmp"
  Zlib::GzipWriter.open(temporary) { |gzip| gzip.write(JSON.generate(value)) }
  File.rename(temporary, path)
end

def gzip_read(path)
  Zlib::GzipReader.open(path) { |gzip| JSON.parse(gzip.read, symbolize_names: true) }
end

def cache_root
  ENV.fetch('MEDICALFACTS_CACHE_ROOT', File.join(Dir.tmpdir, 'medicalfacts-cache'))
end

def clean_mortyear_cache(namespace)
  stamp = File.join(namespace, '.cleanup')
  return if File.file?(stamp) && Time.now - File.mtime(stamp) < 86_400

  FileUtils.mkdir_p(namespace, mode: 0o700)
  File.open(File.join(namespace, '.cleanup.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
    return unless lock.flock(File::LOCK_EX | File::LOCK_NB)
    now = Time.now
    entries = Dir.glob(File.join(namespace, '[0-9a-f][0-9a-f]', '[0-9a-f]' * 64)).select { |path| File.directory?(path) }
    entries.each do |entry|
      access_files = Dir.glob(File.join(entry, 'access*')).select { |path| File.file?(path) }
      last_used = access_files.empty? ? File.mtime(entry) : access_files.map { |path| File.mtime(path) }.max
      FileUtils.rm_r(entry) if now - last_used > CACHE_MAX_AGE
    end
    entries = entries.select { |entry| File.directory?(entry) }
    sizes = entries.to_h do |entry|
      [entry, Dir.glob(File.join(entry, '**', '*'), File::FNM_DOTMATCH).sum { |path| File.file?(path) ? File.size(path) : 0 }]
    end
    total = sizes.values.sum
    if total > CACHE_MAX_BYTES
      entries.sort_by do |entry|
        access_files = Dir.glob(File.join(entry, 'access*')).select { |path| File.file?(path) }
        access_files.empty? ? File.mtime(entry) : access_files.map { |path| File.mtime(path) }.max
      end.each do |entry|
        break if total <= CACHE_MAX_BYTES
        total -= sizes.fetch(entry)
        FileUtils.rm_r(entry)
      end
    end
    FileUtils.touch(stamp)
  end
end

def cached_scenarios(rows, series_key, label)
  input = rows.map { |row| canonical_value(row) }
  input_json = canonical_json(input)
  input_digest = Digest::SHA256.hexdigest(input_json)
  key_material = canonical_value(
    cache_schema: CACHE_SCHEMA,
    algorithm: 'poisson-linear-trend-simulation-v1',
    simulations: POISSON_SIMULATIONS,
    series_key: series_key,
    label: label,
    input_digest: input_digest,
    seed_method: 'sha256-series-cutoff-v1'
  )
  key_json = canonical_json(key_material)
  digest = Digest::SHA256.hexdigest(key_json)
  # 日本語: schemaはcache keyに含め、実行userが変わっても既存namespaceを共有する。
  # English: Keep schema in the cache key and reuse the writable namespace across execution users.
  namespace = File.join(cache_root, 'mortyear-v1')
  directory = File.join(namespace, digest[0, 2], digest)
  FileUtils.mkdir_p(directory, mode: 0o700)

  File.open(File.join(directory, 'lock'), File::RDWR | File::CREAT, 0o600) do |lock|
    lock.flock(File::LOCK_EX)
    metadata_path = File.join(directory, 'metadata.json')
    suffix = ''
    if File.file?(metadata_path)
      saved = JSON.parse(File.read(metadata_path))
      suffix = "-#{Digest::SHA512.hexdigest(key_json)}" unless saved['key_material'] == key_material
    end
    metadata_path = File.join(directory, "metadata#{suffix}.json")
    input_path = File.join(directory, "input#{suffix}.json.gz")
    result_path = File.join(directory, "result#{suffix}.json.gz")
    access_path = File.join(directory, "access#{suffix}")
    if File.file?(metadata_path) && File.file?(input_path) && File.file?(result_path)
      saved = JSON.parse(File.read(metadata_path))
      if saved['key_material'] == key_material && Digest::SHA256.hexdigest(canonical_json(gzip_read(input_path))) == input_digest
        FileUtils.touch(access_path)
        return gzip_read(result_path)
      end
    end

    result = yield
    metadata = {
      cache_schema: CACHE_SCHEMA, created_at: Time.now.utc.iso8601,
      key: digest, collision_suffix: suffix.empty? ? nil : suffix.delete_prefix('-'),
      key_material: key_material
    }
    temporary = "#{metadata_path}.#{Process.pid}.tmp"
    File.write(temporary, JSON.pretty_generate(metadata))
    File.rename(temporary, metadata_path)
    gzip_write(input_path, input)
    gzip_write(result_path, result)
    FileUtils.touch(access_path)
    clean_mortyear_cache(namespace)
    result
  end
end

# 日本語: 完全な暦年について週次の実数を日数按分して合計する。
# English: Prorate weekly counts by days and sum complete calendar years.
def annualize_weekly_counts(rows, age)
  annual = Hash.new do |hash, key|
    hash[key] = { value: 0.0, covered_days: {}, src_url: [] }
  end
  rows.each do |row|
    value = row[age.to_sym]
    next if value.nil?
    week_end = Date.parse(row[:date].to_s)
    (week_end - 6..week_end).group_by(&:year).each do |year, dates|
      target = annual[[row[:loc_code], row[:sex], row[:death_code], year]]
      target[:value] += value.to_f * dates.length / 7.0
      dates.each { |date| target[:covered_days][date] = true }
      target[:src_url] |= Array(row[:src_url]).compact
    end
  end
  annual.map do |(loc_code, sex, death_code, year), values|
    required_days = Date.leap?(year) ? 366 : 365
    next unless year >= 2000 && values[:covered_days].length == required_days
    {
      loc_code: loc_code.upcase, sex: sex, death_code: death_code, year: year,
      deaths: values[:value], population: 1.0, observed: values[:value], unit_scale: 1.0,
      src_url: values[:src_url].empty? ? default_source_urls(loc_code) : values[:src_url]
    }
  end.compact.sort_by { |row| [row[:loc_code], row[:year]] }
end

# 日本語: 週の7日を暦年へ配分する。死亡数だけを日数按分し、人口は週率から逆算する。
# English: Split a seven-day week across calendar years; prorate deaths only and infer weekly population from the annualized rate.
def annualize_weekly(count_rows, rate_rows, age)
  rates = rate_rows.to_h { |row| [[row[:loc_code], row[:yearweek], row[:sex], row[:death_code]], row] }
  annual = Hash.new do |hash, key|
    hash[key] = { deaths: 0.0, population_days: 0.0, covered_days: {}, src_url: [] }
  end

  count_rows.each do |count|
    value = count[age.to_sym]
    rate = rates[[count[:loc_code], count[:yearweek], count[:sex], count[:death_code]]]
    rate_value = rate && rate[age.to_sym]
    next if value.nil? || rate_value.nil? || rate_value.to_f <= 0

    week_end = Date.parse(count[:date].to_s)
    week_start = week_end - 6
    weekly_population = value.to_f * DAYS_PER_YEAR * 100_000 / (7 * rate_value.to_f)
    (week_start..week_end).group_by(&:year).each do |year, dates|
      target = annual[[count[:loc_code], count[:sex], count[:death_code], year]]
      target[:deaths] += value.to_f * dates.length / 7.0
      target[:population_days] += weekly_population * dates.length
      dates.each { |date| target[:covered_days][date] = true }
      urls = [count[:src_url], rate[:src_url]].flatten.compact.reject { |url| url.to_s.empty? }
      target[:src_url] |= (urls.empty? ? default_source_urls(count[:loc_code]) : urls)
    end
  end

  annual.map do |(loc_code, sex, death_code, year), values|
    required_days = Date.leap?(year) ? 366 : 365
    next unless year >= 2000 && values[:covered_days].length == required_days

    population = values[:population_days] / required_days
    next unless population.positive?

    {
      loc_code: loc_code.upcase, sex: sex, death_code: death_code, year: year,
      deaths: values[:deaths], population: population,
      observed: values[:deaths] / population * 100_000, unit_scale: 100_000.0,
      src_url: values[:src_url].empty? ? default_source_urls(loc_code) : values[:src_url]
    }
  end.compact.sort_by { |row| [row[:loc_code], row[:year]] }
end

# 日本語: 年次recordを直接使い、同じ指標では各国公式系列をWPPより優先する。
# English: Read annual records directly and prefer national series over WPP for the same measure.
def annual_record_rows(records, locations, sex, causes, metric, ages)
  relevant = records.select do |row|
    locations.include?(row[:loc_code].to_s.upcase) && row[:sex] == sex &&
      !row[:type].to_s.include?('projection')
  end
  rank = ->(row) { row[:algo].to_s.start_with?('un_wpp2024') ? 1 : 0 }
  rate_name = metric == 'asr' ? 'asr' : ''
  value_groups = relevant.select do |row|
    row[:category] == 'death' && causes.include?(row[:death_code].to_s) &&
      row[:rate].to_s == rate_name
  end.group_by { |row| [row[:loc_code].to_s.upcase, row[:year].to_i, row[:death_code].to_s] }
  raw_groups = relevant.select do |row|
    row[:category] == 'death' && causes.include?(row[:death_code].to_s) && row[:rate].to_s.empty?
  end.group_by { |row| [row[:loc_code].to_s.upcase, row[:year].to_i, row[:death_code].to_s] }
  populations = relevant.select { |row| row[:category] == 'pop' }.group_by do |row|
    [row[:loc_code].to_s.upcase, row[:year].to_i]
  end

  value_groups.filter_map do |(loc, year, cause), candidates|
    values_for = lambda do |record|
      next nil unless record
      fields = ages.include?('age_all') ? ['age_all'] : ages
      values = fields.map { |field| record[field.to_sym] }
      values.all? ? values.sum(&:to_f) : nil
    end
    # 日本語: 必要な年齢fieldを持つrecordの中で各国公式値をWPPより優先する。
    # English: Prefer national data among records that contain every requested age field.
    row = candidates.select { |candidate| !values_for.call(candidate).nil? }.min_by(&rank)
    next unless row
    observed = values_for.call(row)
    raw = raw_groups.fetch([loc, year, cause], []).
          select { |candidate| !values_for.call(candidate).nil? }.min_by(&rank)
    population_candidates = populations.fetch([loc, year], []).
                            select { |candidate| !values_for.call(candidate).nil? }
    population = if ages.include?('age_all')
                   population_candidates.reject { |item| item[:type].to_s.start_with?('exposure_') }.min_by(&rank)
                 else
                   population_candidates.reject { |item| item[:algo].to_s.start_with?('un_wpp2024') }.min_by(&rank) ||
                     population_candidates.select { |item| item[:type].to_s.start_with?('exposure_') }.min_by(&rank)
                 end
    deaths = values_for.call(raw)
    denominator = values_for.call(population)
    if metric == 'deaths'
      deaths = observed
      denominator = 1.0
    elsif metric == 'crude_rate'
      next unless deaths && denominator && denominator.to_f.positive?
      observed = deaths / denominator * 100_000
    elsif metric == 'asr'
      deaths = observed
      denominator = 100_000.0
    end
    next unless deaths && denominator && denominator.to_f.positive?

    {
      loc_code: loc, sex: sex, death_code: cause, year: year,
      deaths: deaths.to_f, population: denominator.to_f, observed: observed.to_f,
      unit_scale: metric == 'deaths' ? 1.0 : 100_000.0,
      src_url: (Array(row[:src_url]) + Array(raw&.dig(:src_url)) + Array(population&.dig(:src_url))).compact.uniq
    }
  end.sort_by { |row| [row[:loc_code], row[:year]] }
end

# 日本語: 年齢階級別の死亡数と人口を組み合わせ、ASR回帰用の入力を作る。
# 同じ階級に各国公式値があればWPPより優先し、人口はWPPではpopulation exposureを使う。
# English: Build ASR regression inputs from age-specific deaths and populations.
# Prefer national values for each stratum and use WPP population exposure as the fallback denominator.
def stratified_asr_rows(records, locations, sex, causes)
  relevant = records.select do |row|
    locations.include?(row[:loc_code].to_s.upcase) && row[:sex] == sex &&
      !row[:type].to_s.include?('projection')
  end
  source_rank = lambda do |row, population: false|
    wpp = row[:algo].to_s.start_with?('un_wpp2024')
    exposure = row[:type].to_s.start_with?('exposure_')
    wpp ? (population && exposure ? 1 : 2) : 0
  end
  death_groups = relevant.select do |row|
    row[:category] == 'death' && row[:rate].to_s.empty? && causes.include?(row[:death_code].to_s)
  end.group_by { |row| [row[:loc_code].to_s.upcase, row[:year].to_i, row[:death_code].to_s] }
  population_groups = relevant.select { |row| row[:category] == 'pop' }.
                      group_by { |row| [row[:loc_code].to_s.upcase, row[:year].to_i] }
  weight_total = WHO_WORLD_STANDARD.values.sum

  death_groups.filter_map do |(loc, year, cause), death_candidates|
    population_candidates = population_groups.fetch([loc, year], [])
    strata = WHO_WORLD_STANDARD.filter_map do |age, weight|
      death_row = death_candidates.select { |row| !row[age.to_sym].nil? }.min_by { |row| source_rank.call(row) }
      population_row = population_candidates.select { |row| !row[age.to_sym].nil? }.
                       min_by { |row| source_rank.call(row, population: true) }
      next unless death_row && population_row
      deaths = death_row[age.to_sym].to_f
      population = population_row[age.to_sym].to_f
      next unless population.positive?
      { age: age, deaths: deaths, population: population, weight: weight / weight_total,
        src_url: (Array(death_row[:src_url]) + Array(population_row[:src_url])).compact.uniq }
    end
    next unless strata.length == WHO_WORLD_STANDARD.length

    {
      loc_code: loc, sex: sex, death_code: cause, year: year, strata: strata,
      deaths: strata.sum { |item| item[:deaths] }, population: strata.sum { |item| item[:population] },
      observed: strata.sum { |item| item[:deaths] / item[:population] * 100_000.0 * item[:weight] },
      unit_scale: 100_000.0, src_url: strata.flat_map { |item| item[:src_url] }.uniq
    }
  end.sort_by { |row| [row[:loc_code], row[:year]] }
end

# 日本語: 学習終了年ごとの計算済み系列を生成し、ブラウザは選択だけを行う。
# English: Precompute every training-cutoff scenario so the browser only switches views.
def compute_scenarios(rows, series_key, label)
  return [] if rows.empty?

  last_year = rows.map { |row| row[:year] }.max
  candidates = (2015..(last_year - 2)).select do |cutoff|
    rows.count { |row| row[:year].between?(2000, cutoff) } >= MIN_TRAINING_YEARS
  end
  return [] if candidates.empty?

  candidates.flat_map do |cutoff|
    training = rows.select { |row| row[:year].between?(2000, cutoff) }
    fit = poisson_fit(training)
    seed = Digest::SHA256.hexdigest("#{series_key}:#{cutoff}:#{POISSON_SIMULATIONS}")[0, 8].to_i(16)
    poisson_predictions = poisson_simulation_predictions(rows, fit, seed)
    %w[poisson quasi_poisson].flat_map do |model|
      variance_scale = model == 'quasi_poisson' ? [fit[:dispersion].to_f, 1.0].max : 1.0
      rows.map do |row|
        prediction = if model == 'poisson'
                       poisson_predictions.fetch([row[:year], row[:death_code]])
                     else
                       poisson_prediction(row, fit, variance_scale)
                     end
        {
          series: series_key, label: label, model: model, train_to: cutoff,
          year: row[:year], observed: row[:observed],
          expected: prediction[:expected], pi_lower: prediction[:lower],
          pi_upper: prediction[:upper], outside_pi: row[:observed] < prediction[:lower] || row[:observed] > prediction[:upper],
          period: row[:year].between?(2000, cutoff) ? 'training' : row[:year] < 2000 ? 'historical' : 'prediction',
          dispersion: fit[:dispersion]&.round(4), deaths: row[:deaths].round(2),
          population: row[:population].round, src_url: row[:src_url]
        }
      end
    end
  end
end

# 日本語: 年齢階級別回帰の予測率をWHO標準人口で直接法により合成する。
# English: Combine age-specific regression predictions by direct WHO-standard weighting.
def compute_stratified_asr_scenarios(rows, series_key, label)
  return [] if rows.empty?

  last_year = rows.map { |row| row[:year] }.max
  candidates = (2015..(last_year - 2)).select do |cutoff|
    rows.count { |row| row[:year].between?(2000, cutoff) } >= MIN_TRAINING_YEARS
  end
  candidates.flat_map do |cutoff|
    training = rows.select { |row| row[:year].between?(2000, cutoff) }
    fits = WHO_WORLD_STANDARD.keys.to_h do |age|
      age_rows = training.map do |row|
        stratum = row[:strata].find { |item| item[:age] == age }
        { year: row[:year], deaths: stratum[:deaths], population: stratum[:population] }
      end
      [age, poisson_fit(age_rows)]
    end
    residual_df = [training.length - 2, 0].max
    total_df = residual_df * fits.length
    dispersion = if total_df.positive?
                   fits.values.sum { |fit| fit[:dispersion].to_f * residual_df } / total_df
                 end
    predictions = rows.to_h do |row|
      expected = 0.0
      poisson_variance = 0.0
      row[:strata].each do |stratum|
        fit = fits.fetch(stratum[:age])
        x = row[:year] - fit[:center]
        population = stratum[:population]
        weight = stratum[:weight]
        eta = fit[:beta][0] + fit[:beta][1] * x
        mu = Math.exp(eta) * population
        rate = mu / population * 100_000.0
        expected += weight * rate
        var_eta = 2.times.sum do |i|
          xi = i.zero? ? 1.0 : x
          2.times.sum do |j|
            xj = j.zero? ? 1.0 : x
            xi * fit[:covariance][i][j] * xj
          end
        end
        poisson_variance += weight * weight * (mu + mu * mu * var_eta) /
                            (population * population) * 100_000.0**2
      end
      poisson_se = Math.sqrt(poisson_variance)
      poisson = { expected: expected, lower: [0.0, expected - Z95 * poisson_se].max,
                  upper: expected + Z95 * poisson_se }
      quasi_se = Math.sqrt([dispersion.to_f, 1.0].max * poisson_variance)
      quasi = { expected: expected, lower: [0.0, expected - Z95 * quasi_se].max,
                upper: expected + Z95 * quasi_se }
      [row[:year], { poisson: poisson, quasi_poisson: quasi }]
    end

    %w[poisson quasi_poisson].flat_map do |model|
      rows.map do |row|
        prediction = predictions.fetch(row[:year]).fetch(model.to_sym)
        {
          series: series_key, label: label, model: model, train_to: cutoff,
          year: row[:year], observed: row[:observed], expected: prediction[:expected],
          pi_lower: prediction[:lower], pi_upper: prediction[:upper],
          outside_pi: row[:observed] < prediction[:lower] || row[:observed] > prediction[:upper],
          period: row[:year].between?(2000, cutoff) ? 'training' : row[:year] < 2000 ? 'historical' : 'prediction',
          dispersion: dispersion&.round(4), deaths: row[:deaths].round(2),
          population: row[:population].round, src_url: row[:src_url]
        }
      end
    end
  end
end

def build_scenarios(rows, series_key, label, use_cache:)
  calculator = rows.first&.key?(:strata) ? method(:compute_stratified_asr_scenarios) : method(:compute_scenarios)
  return calculator.call(rows, series_key, label) unless use_cache

  cached_scenarios(rows, series_key, label) { calculator.call(rows, series_key, label) }
end

fixture_data = if opts[:fixture]
                 parsed = JSON.parse(File.read(opts[:fixture]), symbolize_names: true)
                 parsed = parsed.dig(:hits, :hits).map { |hit| hit.fetch(:_source) } if parsed.is_a?(Hash) && parsed[:hits]
                 parsed
               end
location_rates = {}
annual_catalog = available_annual_catalog(index: opts[:index], fixture: fixture_data)
$annual_catalog = annual_catalog
metric_locations = annual_catalog.select do |code, catalog|
  annual_metric_available?(code, catalog, selected_metric)
end.keys.sort
metric_locations = ['JPN'].select { |code| annual_catalog.key?(code) } if selected_metric == 'std_deaths'
available_locations = annual_catalog.keys.sort
selected_locations = requested_locations.select { |code| available_locations.include?(code) }
selected_locations &= metric_locations
selected_locations = %w[JPN USA DEU].select { |code| metric_locations.include?(code) } if selected_locations.empty?
selected_locations = [metric_locations.first].compact if selected_locations.empty?
selected_locations = [selected_locations.first] if mode == 'series'
available_causes = if selected_metric == 'std_deaths'
                     available_death_codes(index: opts[:index], fixture: fixture_data,
                                           locations: selected_locations, metric: selected_metric)
                   else
                     available_annual_death_codes(index: opts[:index], fixture: fixture_data,
                                                  locations: selected_locations, metric: selected_metric)
                   end
selected_causes = requested_causes.select { |code| available_causes.include?(code) }
selected_causes = ['00000'].select { |code| available_causes.include?(code) } if selected_causes.empty?
selected_causes = [available_causes.first].compact if selected_causes.empty?
selected_causes = [selected_causes.first] if mode == 'country'
if selected_metric == 'birth_rate'
  available_causes = SPECIAL_CAUSES.keys.select do |cause|
    selected_locations.all? { |loc| birth_cause_available?(loc, annual_catalog.fetch(loc), cause) }
  end
  selected_causes = requested_causes.select { |code| available_causes.include?(code) }
  selected_causes = mode == 'series' ? SPECIAL_CAUSES.keys : ['INFANT'] if selected_causes.empty?
  selected_causes = [selected_causes.first] if mode == 'country'
end
# 日本語: 複数国比較では死因選択を使わず、共通の全死因へ固定する。
# English: Multi-country comparisons use the common all-cause series without a cause selector.
if mode == 'country' && selected_locations.length > 1 && available_causes.include?('00000')
  selected_causes = ['00000']
end

locations_for_query = selected_locations.map(&:downcase)
ages_for_query = selected_ages
annual_source_fields = %w[id loc_code location world_region category rate death_code algo type date year sex src_url] + AGES.keys
annual_records_all = if opts[:fixture]
                       fixture_data.reject { |row| row[:yearmonth] || row[:yearweek] }
                     elsif selected_metric == 'std_deaths'
                       []
                     else
                       elastic_search(
                         index: opts[:index], size: 100_000,
                         filter: [{ 'terms' => { 'loc_code' => locations_for_query } },
                                  { 'term' => { 'sex' => selected_sex } }],
                         must_not: [{ 'exists' => { 'field' => 'yearmonth' } },
                                    { 'exists' => { 'field' => 'yearweek' } }],
                         source: annual_source_fields
                       )
                     end
source_fields = %w[id loc_code yearweek category rate death_code algo date year week sex src_url] + AGES.keys
common_filters = [
  { 'term' => { 'category' => 'death' } },
  { 'terms' => { 'loc_code' => locations_for_query } },
  { 'term' => { 'sex' => selected_sex } },
  { 'terms' => { 'death_code' => selected_causes.reject { |code| SPECIAL_CAUSES.key?(code) }.yield_self { |codes| codes.empty? ? ['__none__'] : codes } } },
  { 'exists' => { 'field' => 'yearweek' } }
]

if selected_metric != 'std_deaths'
  count_rows = []
  rate_rows = []
elsif opts[:fixture]
  fixture = fixture_data.dup
  fixture.select! do |row|
    locations_for_query.include?(row[:loc_code].to_s.downcase) &&
      row[:category] == 'death' && selected_causes.include?(row[:death_code]) &&
      row[:sex] == selected_sex && row[:yearweek]
  end
  count_rate = %w[std_deaths asr].include?(selected_metric) ? 'adj' : ''
  count_rows = fixture.select { |row| row[:rate].to_s == count_rate }
  rate_rows = fixture.select { |row| row[:rate] == 'amr' }
else
  count_rate = %w[std_deaths asr].include?(selected_metric) ? 'adj' : ''
  count_rate_filter = if count_rate.empty?
                        {
                          'bool' => {
                            'should' => [
                              { 'term' => { 'rate' => '' } },
                              { 'bool' => { 'must_not' => [{ 'exists' => { 'field' => 'rate' } }] } }
                            ],
                            'minimum_should_match' => 1
                          }
                        }
                      else
                        { 'term' => { 'rate' => count_rate } }
                      end
  count_rows = elastic_search(
    index: opts[:index], size: 100_000,
    filter: common_filters + [count_rate_filter],
    source: source_fields, debug: opts[:debug] ? 'SHOWONLY_QUERY' : nil
  )
  rate_rows = opts[:debug] ? [] : elastic_search(
    index: opts[:index], size: 100_000,
    filter: common_filters + [{ 'term' => { 'rate' => 'amr' } }],
    source: source_fields
  )
end

sex_labels = {
  'male' => { ja: '男性', en: 'Male' },
  'female' => { ja: '女性', en: 'Female' }
}.freeze
age_selection_label = if selected_ages.include?('age_all')
                        $l == :ja ? '全年齢' : 'All ages'
                      elsif selected_ages == ['age_0']
                        $l == :ja ? '0歳' : 'Age 0'
                      else
                        indexes = selected_ages.filter_map { |age| STANDARD_AGES.index(age) }.sort
                        if indexes.any? && indexes.each_cons(2).all? { |left, right| right == left + 1 }
                          lower = format('%02d', indexes.first * 5)
                          upper = indexes.last == STANDARD_AGES.length - 1 ? '100+' : format('%02d', indexes.last * 5 + 4)
                          "#{lower}-#{upper}"
                        else
                          selected_ages.map { |age| AGES.fetch(age).fetch($l) }.join(', ')
                        end
                      end
panel_label = lambda do |loc, cause|
  cause_name = SPECIAL_CAUSES.fetch(cause, Death_codes.fetch(cause, { ja: cause, en: cause })).fetch($l)
  parts = if selected_metric == 'birth_rate'
            [location_names(loc).fetch($l)]
          else
            [location_names(loc).fetch($l), METRICS.fetch(selected_metric).fetch($l), age_selection_label]
          end
  parts << sex_labels.fetch(selected_sex).fetch($l) unless selected_sex == 'both'
  parts << cause_name
  parts.join(' ')
end

series_specs = if mode == 'country'
                 selected_locations.map do |loc|
                   cause = selected_causes.first
                   [loc, selected_ages, cause, panel_label.call(loc, cause)]
                 end
               else
                 selected_causes.map do |cause|
                   key = "#{selected_locations.first}-#{selected_ages.join('+')}-#{cause}"
                   [key, selected_ages, cause, panel_label.call(selected_locations.first, cause)]
                 end
               end

annual_by_age = { selected_ages => begin
  annual = if selected_metric == 'asr'
             stratified_asr_rows(annual_records_all, selected_locations, selected_sex, selected_causes)
           elsif selected_metric != 'std_deaths'
             annual_record_rows(annual_records_all, selected_locations, selected_sex,
                                selected_causes, selected_metric, selected_ages)
           elsif %w[deaths std_deaths].include?(selected_metric)
             annualize_weekly_counts(count_rows, selected_ages.first)
           else
             annualize_weekly(count_rows, rate_rows, selected_ages.first)
           end
  annual
end }

# 日本語: 年次の出生分母と乳児・周産期死亡分子を同じmstats indexから取得する。
# English: Read annual birth denominators and infant/perinatal numerators from the shared mstats index.
annual_source_fields = %w[id loc_code category rate death_code algo date year sex src_url age_all age_0]
annual_records = selected_metric == 'birth_rate' ? annual_records_all : []
births_by_key = annual_records.select { |row| row[:category] == 'birth' }.
                to_h { |row| [[row[:loc_code].to_s.upcase, row[:year].to_i], row] }
deliveries_by_key = annual_records.select { |row| row[:category] == 'delivery' }.
                   to_h { |row| [[row[:loc_code].to_s.upcase, row[:year].to_i], row] }
special_rows = annual_records.filter_map do |row|
  loc = row[:loc_code].to_s.upcase
  # 日本語: 日本はINFANT/PERM公式数、米国は既存の乳児数と再構成PERMを使う。
  # English: Use Japan's official INFANT/PERM counts and the existing U.S. infant/reconstructed PERM series.
  cause, value = if row[:category] == 'death' && row[:death_code] == 'INFANT'
                   ['INFANT', row[:age_all]]
                 elsif loc == 'USA' && row[:category] == 'death' && row[:death_code] == '00000' &&
                       row[:rate].to_s.empty? && row[:algo].to_s.empty?
                   ['INFANT', row[:age_0]]
                 elsif row[:category] == 'death' && row[:death_code] == 'PERM'
                   ['PERINATAL', row[:age_all]]
                 end
  next unless cause && value

  key = [loc, row[:year].to_i]
  denominator = cause == 'PERINATAL' ? deliveries_by_key[key] || births_by_key[key] : births_by_key[key]
  next unless denominator && denominator[:age_all].to_f.positive?

  population = denominator[:age_all].to_f
  urls = (Array(denominator[:src_url]) + Array(row[:src_url])).compact.uniq
  { loc_code: loc, sex: 'both', death_code: cause, year: row[:year].to_i,
    deaths: value.to_f, population: population, observed: value.to_f / population * 1000.0,
    unit_scale: 1000.0, src_url: urls }
end

chart_data = series_specs.flat_map do |series_key, age, cause, label|
  loc = mode == 'country' ? series_key : selected_locations.first
  rows = if SPECIAL_CAUSES.key?(cause)
           special_rows.select { |row| row[:loc_code] == loc && row[:death_code] == cause }
         else
           annual_by_age.fetch(age).select { |row| row[:loc_code] == loc && row[:death_code] == cause }
         end
  build_scenarios(rows, series_key, label,
                  use_cache: !opts[:fixture] || ENV['MORTYEAR_CACHE_FIXTURE'] == '1')
end

cutoffs = chart_data.map { |row| row[:train_to] }.uniq.sort
requested_cutoff = cgi['train_to'].to_i
default_cutoff = if cutoffs.include?(requested_cutoff)
                   requested_cutoff
                 elsif cutoffs.include?(2019)
                   2019
                 else
                   cutoffs.last
                 end
available_specs = series_specs.select { |key, _age, _cause, _label| chart_data.any? { |row| row[:series] == key } }

if opts[:summary]
  summary = available_specs.to_h do |key, _age, _cause, label|
    values = chart_data.select { |row| row[:series] == key }
    last_cutoff = values.map { |row| row[:train_to] }.max
    requested_summary_cutoff = values.map { |row| row[:train_to] }.include?(default_cutoff) ? default_cutoff : last_cutoff
    poisson_latest = values.select { |row| row[:model] == 'poisson' && row[:train_to] == requested_summary_cutoff }.
                     max_by { |row| row[:year] }
    latest = values.select { |row| row[:model] == 'quasi_poisson' && row[:train_to] == last_cutoff }.
             max_by { |row| row[:year] }
    [label, {
      years: values.map { |row| row[:year] }.uniq.minmax,
      training_cutoffs: values.map { |row| row[:train_to] }.uniq.sort,
      complete_years: values.map { |row| row[:year] }.uniq.length,
      poisson: poisson_latest && poisson_latest.slice(:train_to, :year, :observed, :expected, :pi_lower, :pi_upper),
      poisson_simulations: POISSON_SIMULATIONS,
      latest_quasi_poisson: latest && latest.slice(:year, :observed, :expected, :pi_lower, :pi_upper, :dispersion),
      source_urls: values.flat_map { |row| row[:src_url] }.uniq
    }]
  end
  puts JSON.pretty_generate(summary)
  exit
end

metric_label = METRICS.fetch(selected_metric).fetch($l)
metric_label = $l == :ja ? '0歳人口当たり死亡率' : 'Mortality rate per age-0 population' if selected_metric == 'crude_rate' && selected_ages == ['age_0']
title = $l == :ja ? '各国の死亡数・死亡率と予測区間' : 'Deaths, mortality rates, and prediction intervals by country'
print_header(title: title, iframe: false)

def checked(condition)
  condition ? 'checked' : ''
end

def disabled(condition)
  condition ? 'disabled' : ''
end

puts <<~HTML
  <style>
    .mortyear-form { text-align:left; padding:.8em; border:1px solid #ccc; border-radius:.4em; }
    .mortyear-form fieldset { display:inline-block; vertical-align:top; margin:.3em; }
    .mortyear-form label { margin-right:.7em; white-space:nowrap; }
    .mortyear-form details { margin:.25em 0 .25em .4em; }
    .mortyear-form summary { cursor:pointer; }
    .mortyear-options { padding:.3em 0 .2em 1.2em; line-height:1.8; }
    .age-scroll { max-width:100%; overflow-x:auto; }
    #age-scale { width:max-content; min-width:100%; }
    #age-options { display:flex; flex-wrap:nowrap; gap:.55em; align-items:flex-start; }
    #age-options label { display:inline-flex; flex-direction:column; align-items:center; margin:0; }
    #age-options .age-terminal { align-items:flex-start; }
    #age-options .age-terminal input { margin-left:4px; }
    #age-options .age-special { margin-left:.8em; }
    #age-slider-row { display:flex; align-items:center; gap:.7em; }
    #age-range-slider { position:relative; height:28px; }
    #age-range-output { min-width:5.2em; white-space:nowrap; font-variant-numeric:tabular-nums; }
    #age-range-slider.unmatched { opacity:.32; }
    #age-range-slider::before { content:""; position:absolute; left:0; right:0; top:13px; height:3px; background:#9aa0aa; }
    #age-range-slider input { position:absolute; left:-8px; top:0; width:calc(100% + 16px); height:28px; margin:0; appearance:none; -webkit-appearance:none; background:transparent; pointer-events:none; }
    #age-range-slider input::-webkit-slider-runnable-track { height:3px; background:transparent; }
    #age-range-slider input::-webkit-slider-thumb { appearance:none; -webkit-appearance:none; pointer-events:auto; width:16px; height:16px; margin-top:-6px; border:1px solid #666; border-radius:50%; background:#687080; }
    #age-range-slider input::-moz-range-thumb { pointer-events:auto; width:16px; height:16px; border:1px solid #666; border-radius:50%; background:#687080; }
    .location-region-toggle { margin-left:.55em; vertical-align:middle; }
    .mortyear-note { text-align:left; background:#f5f7f8; padding:.8em 1em; }
    #mortyear-vis { width:100%; max-width:100%; box-sizing:border-box; overflow:hidden; }
    #mortyear-vis .vega-embed, #mortyear-vis .vega-embed > div { width:100%; max-width:100%; }
    #mortyear-vis svg { display:block; max-width:100%; height:auto; }
    .mortyear-loading { min-height:12em; display:flex; align-items:center; justify-content:center; font-size:1.2em; font-weight:bold; }
  </style>
  <form class="mortyear-form" method="get">
    <input type="hidden" name="l" value="#{$l}">
    <input id="train-to-hidden" type="hidden" name="train_to" value="#{default_cutoff}">
    <input id="start-year-hidden" type="hidden" name="start_year" value="#{default_start_year}">
    <p>
      <button class="language-button" type="button" data-language="ja">日本語</button>
      <button class="language-button" type="button" data-language="en">English</button>
    </p>
    <fieldset><legend>#{ $l == :ja ? '比較方法' : 'Comparison mode' }</legend>
      <label><input class="comparison-mode" type="radio" name="mode" value="country" #{checked(mode == 'country')}>#{ $l == :ja ? '複数国・共通条件' : 'Countries, common condition' }</label>
      <label><input class="comparison-mode" type="radio" name="mode" value="series" #{checked(mode == 'series')}>#{ $l == :ja ? '一国・複数系列' : 'One country, multiple series' }</label>
    </fieldset><br>
    <fieldset><legend>#{ $l == :ja ? '指標' : 'Measure' }</legend>
HTML
METRICS.each do |metric, names|
  hidden_style = metric == 'std_deaths' ? ' style="display:none"' : ''
  puts %(<label#{hidden_style}><input class="metric-option" type="radio" name="metric" value="#{metric}" #{checked(selected_metric == metric)}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts <<~HTML
    </fieldset><br>
    <fieldset id="location-fieldset"><legend>#{ $l == :ja ? '国・地域' : 'Country or area' }</legend>
HTML
location_groups = available_locations.group_by do |code|
  annual_catalog.dig(code, :world_region).to_s.then { |region| WORLD_REGIONS.key?(region) ? region : 'Other' }
end
WORLD_REGIONS.each do |region, region_names|
  codes = location_groups.fetch(region, []).sort_by { |code| location_sort_key(code, $l) }
  next if codes.empty?
  open = codes.any? { |code| selected_locations.include?(code) }
  toggle_label = $l == :ja ? 'この地域をすべて選択・解除' : 'Select or clear this region'
  puts %(<details class="location-region" #{open ? 'open' : ''}><summary>#{CGI.escapeHTML(region_names.fetch($l))}（#{codes.length}）<input class="location-region-toggle" type="checkbox" title="#{CGI.escapeHTML(toggle_label)}" aria-label="#{CGI.escapeHTML(toggle_label)}"></summary><div class="mortyear-options">)
  codes.each do |code|
    names = location_names(code)
    metrics = METRICS.keys.select do |metric|
      metric == 'std_deaths' ? code == 'JPN' :
        annual_metric_available?(code, annual_catalog.fetch(code), metric)
    end
    hidden = !metrics.include?(selected_metric)
    type = mode == 'country' ? 'checkbox' : 'radio'
    puts %(<label class="location-label" data-metrics="#{metrics.join(' ')}" style="#{hidden ? 'display:none' : ''}"><input class="location-option" type="#{type}" name="c" value="#{code}" #{checked(selected_locations.include?(code))} #{disabled(hidden)}>#{CGI.escapeHTML(names.fetch($l))}</label>)
  end
  puts %(</div></details>)
end
puts <<~HTML
    </fieldset><br>
    <fieldset id="age-fieldset" style="#{selected_metric == 'birth_rate' ? 'display:none' : ''}"><legend>#{ $l == :ja ? '年齢' : 'Age' }</legend>
      <div class="age-scroll"><div id="age-scale">
        <div id="age-slider-row"><div id="age-range-slider"><input id="age-start" type="range" min="0" max="#{STANDARD_AGES.length - 1}" step="1"><input id="age-end" type="range" min="0" max="#{STANDARD_AGES.length - 1}" step="1"></div><output id="age-range-output"></output></div>
        <div id="age-options">
HTML
STANDARD_AGES.each_with_index do |age, index|
  active = selected_ages.include?('age_all') || selected_ages.include?(age)
  short_label = index == STANDARD_AGES.length - 1 ? '100+' : format('%02d', index * 5)
  terminal_class = index == STANDARD_AGES.length - 1 ? ' class="age-terminal"' : ''
  puts %(<label#{terminal_class}><input class="age-option age-standard" type="checkbox" name="age" value="#{age}" #{checked(active)}>#{short_label}</label>)
end
%w[age_0 age_all].each do |age|
  names = AGES.fetch(age)
  puts %(<label class="age-special"><input class="age-option age-special-option" type="checkbox" name="age" value="#{age}" #{checked(selected_ages.include?(age))}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts <<~HTML
        </div>
      </div></div>
    </fieldset><br>
HTML
show_cause_fieldset = if selected_metric == 'birth_rate'
                        selected_locations.any?
                      else
                        selected_locations == ['JPN']
                      end
puts <<~HTML
    <fieldset id="cause-fieldset" style="#{show_cause_fieldset ? '' : 'display:none'}"><legend>#{ $l == :ja ? '死因・症例' : 'Cause of death' }</legend>
HTML
japan_causes = annual_catalog.dig('JPN', :death_codes).to_a.select { |cause| cause.match?(/\A\d{5}\z/) }
japan_causes.each do |cause|
  next unless cause == '00000'
  names = Death_codes.fetch(cause, { ja: cause, en: cause })
  type = mode == 'country' ? 'radio' : 'checkbox'
  puts %(<label><input class="cause-option" data-cause-scope="japan" type="#{type}" name="death_codes" value="#{cause}" #{checked(selected_causes.include?(cause))}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts %(<details open><summary>#{CGI.escapeHTML($l == :ja ? '出生関連指標' : 'Birth-related measures')}</summary><div class="mortyear-options">)
SPECIAL_CAUSES.each do |cause, names|
  type = mode == 'country' ? 'radio' : 'checkbox'
  locations = annual_catalog.select { |loc, catalog| birth_cause_available?(loc, catalog, cause) }.keys
  puts %(<label><input class="cause-option" data-cause-scope="birth" data-locations="#{locations.join(' ')}" type="#{type}" name="death_codes" value="#{cause}" #{checked(selected_causes.include?(cause))}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts %(</div></details>)
top_causes = japan_causes.select { |cause| cause.match?(/\A\d{2}000\z/) && cause != '00000' }
top_causes.each do |parent|
  children = japan_causes.select { |cause| cause != parent && cause.start_with?(parent[0, 2]) }
  names = Death_codes.fetch(parent, { ja: parent, en: parent })
  open = ([parent] + children).any? { |cause| selected_causes.include?(cause) }
  puts %(<details #{open ? 'open' : ''}><summary>)
  type = mode == 'country' ? 'radio' : 'checkbox'
  puts %(<label><input class="cause-option" data-cause-scope="japan" type="#{type}" name="death_codes" value="#{parent}" #{checked(selected_causes.include?(parent))}>#{parent}: #{CGI.escapeHTML(names.fetch($l))}</label></summary>)
  unless children.empty?
    puts %(<div class="mortyear-options">)
    children.each do |cause|
      child_names = Death_codes.fetch(cause, { ja: cause, en: cause })
      puts %(<label><input class="cause-option" data-cause-scope="japan" type="#{type}" name="death_codes" value="#{cause}" #{checked(selected_causes.include?(cause))}>#{cause}: #{CGI.escapeHTML(child_names.fetch($l))}</label>)
    end
    puts %(</div>)
  end
  puts %(</details>)
end
puts <<~HTML
    </fieldset><br>
    <button type="submit">#{ $l == :ja ? '表示' : 'Show' }</button>
  </form>
  <script>
    (function () {
      function showLoading() {
        const vis = document.getElementById('mortyear-vis');
        if (vis) vis.innerHTML = '<div class="mortyear-loading">#{ $l == :ja ? '読み込み中……' : 'Loading…' }</div>';
      }
      document.querySelector('.mortyear-form').addEventListener('submit', () => {
        // 日本語: all選択時は個別年齢をGET parameterに重複して送らない。
        // English: When all ages is selected, omit redundant individual age parameters.
        const allAges = document.querySelector('.age-special-option[value="age_all"]');
        if (allAges.checked) standardInputs().forEach(input => { input.disabled = true; });
        showLoading();
      });
      function setInputMode(inputs, type, name) {
        inputs.forEach(input => {
          input.type = type;
          input.name = name;
        });
        if (type === "radio") {
          const checked = inputs.filter(input => input.checked && !input.disabled);
          checked.slice(1).forEach(input => { input.checked = false; });
          if (checked.length === 0) {
            const first = inputs.find(input => !input.disabled);
            if (first) first.checked = true;
          }
        }
      }
      function syncComparisonMode() {
        const selected = document.querySelector('.comparison-mode:checked').value;
        const locations = Array.from(document.querySelectorAll('.location-option'));
        const causes = Array.from(document.querySelectorAll('.cause-option'));
        if (selected === 'country') {
          setInputMode(locations, 'checkbox', 'c');
          setInputMode(causes, 'radio', 'death_codes');
        } else {
          setInputMode(locations, 'radio', 'c');
          setInputMode(causes, 'checkbox', 'death_codes');
        }
        document.querySelectorAll('.location-region-toggle').forEach(toggle => {
          toggle.style.display = selected === 'country' ? '' : 'none';
        });
        updateRegionToggles();
        syncCauseVisibility();
      }
      function updateRegionToggles() {
        document.querySelectorAll('.location-region').forEach(region => {
          const toggle = region.querySelector('.location-region-toggle');
          const inputs = Array.from(region.querySelectorAll('.location-label')).filter(label =>
            label.style.display !== 'none' && !label.querySelector('.location-option').disabled
          ).map(label => label.querySelector('.location-option'));
          const selected = inputs.filter(input => input.checked).length;
          toggle.checked = inputs.length > 0 && selected === inputs.length;
          toggle.indeterminate = selected > 0 && selected < inputs.length;
          toggle.disabled = inputs.length === 0;
        });
      }
      document.querySelectorAll('.location-region-toggle').forEach(toggle => {
        toggle.addEventListener('click', event => {
          event.stopPropagation();
        });
        toggle.addEventListener('change', () => {
          const region = toggle.closest('.location-region');
          region.querySelectorAll('.location-label').forEach(label => {
            const input = label.querySelector('.location-option');
            if (!input.disabled && label.style.display !== 'none') input.checked = toggle.checked;
          });
          rememberLocations();
          updateRegionToggles();
          syncCauseVisibility();
        });
      });
      function syncCauseVisibility() {
        const fieldset = document.getElementById('cause-fieldset');
        const causes = Array.from(document.querySelectorAll('.cause-option'));
        const selectedLocations = Array.from(document.querySelectorAll('.location-option:checked:not(:disabled)')).map(input => input.value);
        const metric = document.querySelector('input[name="metric"]:checked').value;
        const birthLocations = selectedLocations.length > 0 && selectedLocations.every(location => {
          const input = document.querySelector(`.location-option[value="${location}"]`);
          return input && input.closest('label').dataset.metrics.split(' ').includes('birth_rate');
        });
        const scope = selectedLocations.length === 1 && selectedLocations[0] === 'JPN' && metric !== 'birth_rate' ? 'japan' :
          birthLocations && metric === 'birth_rate' ? 'birth' : null;
        const hidden = scope === null;
        fieldset.style.display = hidden ? 'none' : '';
        causes.forEach(input => {
          const supportedLocations = (input.dataset.locations || '').split(' ').filter(Boolean);
          const supported = input.dataset.causeScope !== 'birth' ||
            selectedLocations.every(location => supportedLocations.includes(location));
          const active = !hidden && input.dataset.causeScope === scope && supported;
          input.disabled = !active;
          input.closest('label').style.display = active ? '' : 'none';
        });
        fieldset.querySelectorAll('details').forEach(details => {
          details.style.display = details.querySelector('.cause-option:not(:disabled)') ? '' : 'none';
        });
        const active = causes.filter(input => !input.disabled);
        if (active.length && !active.some(input => input.checked)) {
          if (scope === 'birth' && document.querySelector('.comparison-mode:checked').value === 'series') {
            active.forEach(input => { input.checked = true; });
          } else {
            const preferred = active.find(input => input.value === (scope === 'birth' ? 'INFANT' : '00000')) || active[0];
            preferred.checked = true;
          }
        }
      }
      const standardAges = #{JSON.generate(STANDARD_AGES)};
      const ageStart = document.getElementById('age-start');
      const ageEnd = document.getElementById('age-end');
      const ageSlider = document.getElementById('age-range-slider');
      const ageRangeOutput = document.getElementById('age-range-output');
      function ageRangeText(start, finish) {
        const lower = String(start * 5).padStart(2, '0');
        const upper = finish === standardAges.length - 1 ? '100+' : String(finish * 5 + 4).padStart(2, '0');
        return `${lower}-${upper}`;
      }
      function standardInputs() {
        return standardAges.map(value => document.querySelector(`.age-standard[value="${value}"]`));
      }
      function alignAgeSlider() {
        const inputs = standardInputs();
        const boxes = inputs.map(input => input && input.getBoundingClientRect());
        if (boxes.some(box => !box)) return;
        const scale = document.getElementById('age-scale').getBoundingClientRect();
        const centers = boxes.map(box => box.left + box.width / 2);
        ageSlider.style.marginLeft = `${centers[0] - scale.left}px`;
        ageSlider.style.width = `${centers.at(-1) - centers[0]}px`;
      }
      function syncAgeSlider() {
        const selected = standardInputs().map((input, index) => input.checked ? index : null).filter(index => index !== null);
        const contiguous = selected.length && selected.at(-1) - selected[0] + 1 === selected.length;
        const age0 = document.querySelector('.age-special-option[value="age_0"]').checked;
        if (contiguous && !age0) {
          ageStart.value = selected[0]; ageEnd.value = selected.at(-1);
          ageRangeOutput.value = ageRangeText(selected[0], selected.at(-1));
        } else {
          ageRangeOutput.value = '';
        }
        ageSlider.classList.toggle('unmatched', !contiguous || age0);
        requestAnimationFrame(alignAgeSlider);
      }
      function applyAgeRange() {
        let start = Number(ageStart.value), finish = Number(ageEnd.value);
        if (start > finish) [start, finish] = [finish, start];
        standardInputs().forEach((input, index) => { input.checked = index >= start && index <= finish; });
        document.querySelector('.age-special-option[value="age_0"]').checked = false;
        document.querySelector('.age-special-option[value="age_all"]').checked = start === 0 && finish === standardAges.length - 1;
        ageSlider.classList.remove('unmatched');
        ageRangeOutput.value = ageRangeText(start, finish);
        alignAgeSlider();
      }
      document.querySelectorAll('.age-standard').forEach(input => input.addEventListener('change', () => {
        document.querySelector('.age-special-option[value="age_0"]').checked = false;
        document.querySelector('.age-special-option[value="age_all"]').checked = standardInputs().every(item => item.checked);
        syncAgeSlider();
      }));
      document.querySelectorAll('.age-special-option').forEach(input => input.addEventListener('change', () => {
        if (input.value === 'age_all' && input.checked) {
          standardInputs().forEach(item => { item.checked = true; });
          document.querySelector('.age-special-option[value="age_0"]').checked = false;
        } else if (input.value === 'age_0' && input.checked) {
          standardInputs().forEach(item => { item.checked = false; });
          document.querySelector('.age-special-option[value="age_all"]').checked = false;
        } else if (!input.checked) {
          standardInputs().forEach(item => { item.checked = false; });
        }
        syncAgeSlider();
      }));
      ageStart.addEventListener('input', () => {
        if (Number(ageStart.value) > Number(ageEnd.value)) ageEnd.value = ageStart.value;
        applyAgeRange();
      });
      ageEnd.addEventListener('input', () => {
        if (Number(ageEnd.value) < Number(ageStart.value)) ageStart.value = ageEnd.value;
        applyAgeRange();
      });
      const storageKey = "mortyear-location-selection";
      const hasRequestedLocations = #{requested_locations.empty? ? 'false' : 'true'};
      function rememberLocations() {
        const values = Array.from(document.querySelectorAll('.location-option:checked')).map(input => input.value);
        sessionStorage.setItem(storageKey, JSON.stringify(values));
      }
      function restoreLocations() {
        if (hasRequestedLocations) return;
        let values = [];
        try { values = JSON.parse(sessionStorage.getItem(storageKey) || "[]"); } catch (_error) {}
        document.querySelectorAll('.location-option').forEach(input => {
          if (values.includes(input.value)) input.checked = true;
        });
      }
      function syncMetric() {
        const metric = document.querySelector('.metric-option:checked').value;
        const fixedAllAges = metric === 'asr' || metric === 'birth_rate';
        document.getElementById('age-fieldset').style.display = metric === 'birth_rate' ? 'none' : '';
        document.querySelectorAll('.age-option').forEach(input => {
          input.disabled = metric === 'birth_rate' || (metric === 'asr' && input.value !== 'age_all');
          if (fixedAllAges) input.checked = input.value === 'age_all';
        });
        if (!fixedAllAges && document.querySelector('.age-special-option[value="age_all"]').checked) {
          standardInputs().forEach(input => { input.checked = true; });
        }
        ageSlider.style.display = fixedAllAges ? 'none' : '';
        document.querySelectorAll('.location-label').forEach(label => {
          const available = label.dataset.metrics.split(/\s+/).includes(metric);
          label.style.display = available ? "" : "none";
          label.querySelector('input').disabled = !available;
        });
        document.querySelectorAll('.location-region').forEach(details => {
          const visible = Array.from(details.querySelectorAll('.location-label')).some(label => label.style.display !== 'none');
          details.style.display = visible ? '' : 'none';
        });
        const enabled = Array.from(document.querySelectorAll('.location-option:not(:disabled)'));
        if (!enabled.some(input => input.checked) && enabled[0]) enabled[0].checked = true;
        syncAgeSlider();
        syncComparisonMode();
      }
      document.querySelectorAll('.comparison-mode').forEach(input => {
        input.addEventListener('change', syncComparisonMode);
      });
      document.querySelectorAll('.language-button').forEach(button => {
        button.addEventListener('click', () => {
          const form = button.closest('form');
          form.querySelector('input[name="l"]').value = button.dataset.language;
          showLoading();
          form.submit();
        });
      });
      document.querySelectorAll('.location-option').forEach(input => input.addEventListener('change', () => {
        rememberLocations();
        updateRegionToggles();
        syncCauseVisibility();
      }));
      document.querySelectorAll('.metric-option').forEach(input => input.addEventListener('change', () => {
        rememberLocations();
        syncMetric();
      }));
      restoreLocations();
      syncAgeSlider();
      syncMetric();
      window.addEventListener('resize', alignAgeSlider);
    }());
  </script>
HTML

if chart_data.empty?
  message = $l == :ja ? '学習に使える完全な暦年が4年以上そろう系列がありません。条件を変更してください。' : 'No series has at least four complete calendar years for training. Change the selection.'
  puts "<p class=\"mortyear-note\">#{message}</p>"
else
  y_axis_title = metric_label
  count_metric = %w[deaths std_deaths].include?(selected_metric)
  birth_metric = selected_metric == 'birth_rate'
  denominator_title = if birth_metric
                        $l == :ja ? '出生数または出産数' : 'Births or deliveries'
                      elsif selected_ages == ['age_0']
                        $l == :ja ? '0歳人口' : 'Age-0 population'
                      else
                        $l == :ja ? '人口' : 'Population'
                      end
  oecd_reconstructed = chart_data.any? do |row|
    urls = Array(row[:src_url])
    urls.any? { |url| url.to_s.include?('data-explorer.oecd.org') } &&
      urls.any? { |url| url.to_s.include?('population.un.org') }
  end
  approximation_note = if oecd_reconstructed && (selected_locations - %w[JPN USA]).any?
                         $l == :ja ? ' OECD公表率とUN WPP 2024の出生数から死亡数を逆算した近似系列です。欠測年は補間していません。' : ' Approximate death counts are reconstructed from OECD-published rates and UN WPP 2024 births. Missing years are not interpolated.'
                       elsif selected_locations.include?('USA') && selected_causes.include?('PERINATAL')
                         $l == :ja ? ' 米国の周産期死亡数は、丸められた公表率と出生数から逆算した近似値です。2006年と2010年は欠測のままです。' : ' U.S. perinatal death counts are approximate values reconstructed from rounded published rates and births; 2006 and 2010 remain missing.'
                       else
                         ''
                       end
  sources_by_location = available_specs.each_with_object({}) do |(key, _age, _cause, _label), sources|
    loc = mode == 'country' ? key : selected_locations.first
    urls = chart_data.select { |row| row[:series] == key }.flat_map { |row| row[:src_url] }.uniq
    sources[loc] ||= []
    sources[loc] |= urls
  end
  source_entries = []
  if sources_by_location['JPN']&.any? { |url| url.include?('e-stat.go.jp') }
    method = if selected_metric == 'birth_rate' &&
                selected_causes.include?('INFANT') && selected_causes.include?('PERINATAL') && $l == :ja
               'e-Statの確定数を使用。乳児死亡率の分母は出生数、周産期死亡率の分母は出産数（出生数＋妊娠満22週以後の死産数）です。'
             elsif selected_metric == 'birth_rate' &&
                   selected_causes.include?('INFANT') && selected_causes.include?('PERINATAL')
               'Uses final e-Stat counts. Infant mortality uses births as the denominator; perinatal mortality uses deliveries (births plus fetal deaths at 22 completed weeks or later).'
             elsif selected_metric == 'birth_rate' && selected_causes.include?('PERINATAL') && $l == :ja
               'e-Statの確定数を使用。周産期死亡率の分母は出産数（出生数＋妊娠満22週以後の死産数）です。'
             elsif selected_metric == 'birth_rate' && selected_causes.include?('PERINATAL')
               'Uses final e-Stat counts and deliveries (births plus fetal deaths at 22 completed weeks or later) as the denominator.'
             elsif selected_metric == 'birth_rate' && $l == :ja
               'e-Statの確定出生数と乳児死亡数を使用しています。'
             elsif selected_metric == 'birth_rate'
               'Uses final annual birth and infant death counts from e-Stat.'
             elsif selected_metric == 'asr' && $l == :ja
               'e-Statの年齢階級別死亡数・人口を優先し、不足階級はUN WPP 2024で補完。WHO世界標準人口で直接法により年齢調整している。'
             elsif selected_metric == 'asr'
               'Age-specific e-Stat deaths and populations take priority, with UN WPP 2024 filling unavailable strata; direct standardization uses the WHO world standard population.'
             elsif selected_metric == 'crude_rate' && selected_ages != ['age_all'] && $l == :ja
               'e-Statの年齢別死亡数とUN WPP 2024の年齢別人口を使用。'
             elsif selected_metric == 'crude_rate' && selected_ages != ['age_all']
               'Uses age-specific deaths from e-Stat and age-specific population from UN WPP 2024.'
             elsif $l == :ja
               'e-Statの月次死亡数と月次人口が原資料。'
             else
               'Source data are monthly deaths and population from e-Stat.'
             end
    source_entries << { loc: 'JPN', method: method, urls: sources_by_location['JPN'] }
  end
  sources_by_location.each do |loc, urls|
    next if loc == 'JPN' && urls.any? { |url| url.include?('e-stat.go.jp') }

    method = if loc == 'USA' && selected_metric == 'birth_rate' &&
                selected_causes.include?('INFANT') && selected_causes.include?('PERINATAL')
               if $l == :ja
                 '乳児死亡率には米国CDCの年次出生数・乳児死亡数を使用しています。周産期死亡率には米国の年次出生数と、OECD公表率から逆算した近似死亡数を使用しています。'
               else
                 'Infant mortality uses annual U.S. CDC birth and infant death counts. Perinatal mortality uses annual U.S. births and approximate death counts reconstructed from OECD-published rates.'
               end
             elsif loc == 'USA' && selected_metric == 'birth_rate' && selected_causes.include?('PERINATAL')
               if $l == :ja
                 '米国の年次出生数と、OECD公表率から逆算した周産期死亡数を使用しています。死亡数は近似値です。'
               else
                 'Uses annual U.S. births and perinatal death counts reconstructed from OECD-published rates. The death counts are approximate.'
               end
             elsif loc == 'USA' && selected_metric == 'birth_rate'
               if $l == :ja
                 '米国CDCの年次出生数と乳児死亡数を使用しています。'
               else
                 'Uses annual birth and infant death counts from the U.S. CDC.'
               end
             elsif selected_metric == 'birth_rate' && urls.any? { |url| url.include?('data-explorer.oecd.org') }
               if $l == :ja
                 'OECD公表率とUN WPP 2024の出生数から再構成した近似死亡数を使用しています。'
               else
                 'Uses approximate death counts reconstructed from OECD-published rates and UN WPP 2024 births.'
               end
             elsif urls.include?(WPP_URL)
               $l == :ja ? 'UN WPP 2024の年次推計値（2023年まで）。' : 'UN WPP 2024 annual estimates through 2023.'
             else
               $l == :ja ? 'リンク先の公表年次値を使用しています。' : 'Uses the published annual values at the linked source.'
             end
    source_entries << { loc: loc, method: method, urls: urls }
  end
  # 日本語: 同じ処理説明の地域は一項目にまとめ、大量の国名列挙を避ける。
  # English: Group locations with the same processing note and avoid listing a large number of country names.
  source_items = source_entries.group_by { |entry| entry[:method] }.map do |method, entries|
    locations = entries.map { |entry| location_names(entry[:loc]).fetch($l) }
    location_label = if locations.length > 8
                       $l == :ja ? 'それ以外' : 'Other locations'
                     else
                       locations.join($l == :ja ? '、' : ', ')
                     end
    urls = entries.flat_map { |entry| entry[:urls] }.uniq
    links = urls.map { |url| %(<a href="#{CGI.escapeHTML(url)}" target="_blank">#{CGI.escapeHTML(url)}</a>) }.join('<br>')
    "<li><strong>#{CGI.escapeHTML(location_label)}</strong>: #{CGI.escapeHTML(method)}<br>#{links}</li>"
  end.join("\n")
  wpp_note = if source_entries.any? { |entry| entry[:urls].include?(WPP_URL) }
               if $l == :ja
                 'UNは国際連合、WPPは国連人口部が公表するWorld Population Prospects（世界人口推計）です。'
               else
                 'UN WPP means the United Nations World Population Prospects, published by the UN Population Division.'
               end
             end
  display_year_max = chart_data.map { |row| row[:year] }.max + 11.0 / 12.0
  standard_age_indexes = selected_ages.filter_map { |age| STANDARD_AGES.index(age) }.sort
  selected_80_plus = standard_age_indexes == (STANDARD_AGES.index('age_80_84')...STANDARD_AGES.length).to_a
  default_model = if birth_metric
                    'poisson'
                  elsif selected_ages.include?('age_all') || selected_80_plus || standard_age_indexes.length * 5 >= 35
                    'quasi_poisson'
                  else
                    'poisson'
                  end
  dispersion_labels = available_specs.to_h do |key, _age, cause, _label|
    short_label = if mode == 'country'
                    location_names(key).fetch($l)
                  else
                    SPECIAL_CAUSES.fetch(cause, Death_codes.fetch(cause, { ja: cause, en: cause })).fetch($l)
                  end
    [key, short_label]
  end
  interval_note = if selected_metric == 'asr'
                    if $l == :ja
                      ' Poissonの青帯は年齢階級別の回帰係数分散と観測分散をWHO標準人口weightで合成した近似95%予測区間です。準Poissonは全階級の残差から推定した過分散を反映します。'
                    else
                      ' The Poisson band is an approximate 95% prediction interval combining age-specific coefficient and observation variance with WHO standard-population weights. Quasi-Poisson reflects overdispersion estimated across all strata.'
                    end
                  elsif $l == :ja
                    ' Poissonの青帯は回帰係数と観測変動を含む10,000回シミュレーションによる95%予測区間です。準Poissonは過分散補正による近似95%予測区間です。'
                  else
                    ' The Poisson band is a 95% prediction interval from 10,000 simulations including coefficient and observation uncertainty. The quasi-Poisson band is an approximate overdispersion-adjusted 95% prediction interval.'
                  end
  puts <<~HTML
    <p class="mortyear-note">
      #{ ($l == :ja ? (birth_metric ? '指標に対応する分母をoffsetとしたPoisson回帰で、1,000当たりを表示しています。' : selected_metric == 'std_deaths' ? '日本の週次派生系列を完全な暦年へ集計しています。年境界週の死亡数は日数按分しました。' : '') : (birth_metric ? 'Poisson regression uses the denominator for each measure as the offset and displays rates per 1,000.' : selected_metric == 'std_deaths' ? 'Japanese derived weekly series are aggregated into complete calendar years; boundary weeks are prorated by days.' : '')) + interval_note + (selected_metric == 'crude_rate' && selected_ages == ['age_0'] ? ($l == :ja ? ' 通常の乳児死亡率は出生数を分母としますが、この指標は0歳人口を分母とします。' : ' Unlike the conventional infant mortality rate, which uses births as the denominator, this measure uses the age-0 population.') : '') + approximation_note }
    </p>
    <p id="mortyear-controls" style="text-align:left">
      <label>#{ $l == :ja ? '表示開始年' : 'Display from' }
        <input id="start-year-slider" type="range" min="1950" max="2015" step="1" value="#{default_start_year}">
        <output id="start-year-output">#{default_start_year}</output>
      </label>
      &nbsp;
      <label>#{ $l == :ja ? '学習終了年' : 'Training end' }
        <input id="train-to-slider" type="range" min="#{cutoffs.min}" max="#{cutoffs.max}" step="1" value="#{default_cutoff}">
        <output id="train-to-output">#{default_cutoff}</output>
      </label>
      &nbsp;
      <label>#{ $l == :ja ? 'モデル' : 'Model' }
        <select id="model-selector">
          <option value="poisson" #{'selected' if default_model == 'poisson'}>Poisson</option>
          <option value="quasi_poisson" #{'selected' if default_model == 'quasi_poisson'}>#{ $l == :ja ? '準Poisson' : 'Quasi-Poisson' }</option>
        </select>
      </label>
      <!-- 推定φの計算値はchart dataに残すが、画面には表示しない。
           Keep estimated dispersion in chart data, but do not display it. -->
      <!-- <output id="dispersion-output"></output> -->
      &nbsp;
      <label><input id="zero-base-checkbox" type="checkbox">
        #{ $l == :ja ? 'Y軸を0から表示' : 'Start Y-axis at zero' }
      </label>
    </p>
    <div id="mortyear-vis"></div>
    <script>
      const values = #{JSON.generate(chart_data)};
      const displayStartDefault = #{default_start_year};
      const trainMin = #{cutoffs.min};
      const trainMax = #{cutoffs.max};
      const trainDefault = #{default_cutoff};
      const modelDefault = #{JSON.generate(default_model)};
      const panels = #{JSON.generate(available_specs.map { |key, _age, _cause, label| [key, label] })};
      const dispersionLabels = #{JSON.generate(dispersion_labels)};
      const panelSpecs = panels.map(([key, label]) => ({
        title: {text: label, anchor: "start"},
        width: "container", height: 260,
        transform: [
          {filter: `datum.series == '${key}'`},
          {filter: "datum.year >= display_start"},
          {filter: "datum.train_to == train_to"},
          {filter: "datum.model == model"}
        ],
        encoding: {
          x: {field: "year", type: "quantitative", scale: {domainMin: {expr: "display_start"}, domainMax: #{[display_year_max, 2025 + 11.0 / 12.0].max}, nice: false, zero: false}, axis: {format: "d", tickMinStep: 1}, title: #{JSON.generate($l == :ja ? '年' : 'Year')}}
        },
        layer: [
          {mark: {type: "area", color: "#dceaf5"}, encoding: {y: {field: "pi_lower", type: "quantitative", title: #{JSON.generate(y_axis_title)}, scale: {zero: {expr: "zero_base"}}}, y2: {field: "pi_upper"}}},
          {mark: {type: "line", color: "#246a9e", strokeDash: [6,4], strokeWidth: 2}, encoding: {y: {field: "expected", type: "quantitative"}}},
          {mark: {type: "line", color: "#c83e4d", strokeWidth: 2, point: true}, encoding: {y: {field: "observed", type: "quantitative"}, tooltip: [
            {field:"year", type:"quantitative", title:#{JSON.generate($l == :ja ? '年' : 'Year')}},
            {field:"observed", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '観測値' : 'Observed')}},
            {field:"expected", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '予測値' : 'Expected')}},
            {field:"pi_lower", type:"quantitative", format:".2f", title:"PI lower"},
            {field:"pi_upper", type:"quantitative", format:".2f", title:"PI upper"},
            {field:"deaths", type:"quantitative", format:",.2f", title:#{JSON.generate($l == :ja ? '年境界按分後死亡数' : 'Prorated deaths')}},
            {field:"population", type:"quantitative", format:",d", title:#{JSON.generate(denominator_title)}}
            ,{field:"dispersion", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '分散比' : 'Dispersion')}}
          ]}},
          {transform:[{filter:"datum.outside_pi"}], mark:{type:"point", color:"#111", filled:false, size:100, strokeWidth:2}, encoding:{y:{field:"observed",type:"quantitative"}}},
          {transform:[{filter:"datum.year == train_to"}], mark:{type:"rule", color:"#555", strokeDash:[3,3]}, encoding:{x:{field:"year",type:"quantitative"}}}
        ]
      }));
      const spec = {
        $schema: "https://vega.github.io/schema/vega-lite/v5.json",
        data: {values},
        params: [
          {name:"display_start", value:displayStartDefault},
          {name:"train_to", value:trainDefault},
          {name:"model", value:modelDefault},
          {name:"zero_base", value:false}
        ],
        vconcat: panelSpecs,
        autosize: {type:"fit-x", contains:"padding", resize:true},
        resolve: {scale: {y: "independent"}},
        config: {view:{stroke:null}, axis:{labelFontSize:15,titleFontSize:17}, axisY:{minExtent:84,maxExtent:84}, title:{fontSize:19}}
      };
      vegaEmbed("#mortyear-vis", spec, {mode:"vega-lite", actions:false}).then(result => {
        const slider = document.getElementById("train-to-slider");
        const startSlider = document.getElementById("start-year-slider");
        const startOutput = document.getElementById("start-year-output");
        const output = document.getElementById("train-to-output");
        const model = document.getElementById("model-selector");
        const zeroBase = document.getElementById("zero-base-checkbox");
        /* 推定φ表示を再開するときのために残す。Keep for restoring the estimated-phi display.
        const dispersionOutput = document.getElementById("dispersion-output");
        function updateDispersion(value) {
          const parts = panels.map(([key]) => {
            const row = values.find(item => item.series === key && item.train_to === value && item.model === "quasi_poisson");
            return row && row.dispersion != null ? `${dispersionLabels[key]} ${Number(row.dispersion).toFixed(2)}` : null;
          }).filter(Boolean);
          dispersionOutput.value = parts.length ? `#{ $l == :ja ? '推定φ' : 'Estimated φ' }: ${parts.join(' / ')}` : '';
        }
        updateDispersion(trainDefault);
        */
        startSlider.addEventListener("input", () => {
          const value = Number(startSlider.value);
          startOutput.value = value;
          document.getElementById("start-year-hidden").value = value;
          result.view.signal("display_start", value).runAsync();
        });
        slider.addEventListener("input", () => {
          const value = Number(slider.value);
          output.value = value;
          // updateDispersion(value); // 推定φは現在非表示。Estimated phi is currently hidden.
          result.view.signal("train_to", value).runAsync();
        });
        model.addEventListener("change", () => {
          result.view.signal("model", model.value).runAsync();
        });
        zeroBase.addEventListener("change", () => {
          result.view.signal("zero_base", zeroBase.checked).runAsync();
        });
        result.view.addSignalListener("train_to", (_name, value) => {
          const url = new URL(window.location.href);
          url.searchParams.set("train_to", value);
          history.replaceState(null, "", url);
          document.getElementById("train-to-hidden").value = value;
        });
      }).catch(console.warn);
    </script>
    <section class="mortyear-sources" style="text-align:left">
      <h2>#{ $l == :ja ? 'グラフに使用したデータ' : 'Data used for the graphs' }</h2>
      #{wpp_note ? %(<p class="mortyear-note">#{CGI.escapeHTML(wpp_note)}</p>) : ''}
      <ul>#{source_items}</ul>
    </section>
  HTML
end

puts <<~HTML
  </div>
  </div>
  </body>
  </html>
HTML
