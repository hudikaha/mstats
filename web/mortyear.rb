#!/usr/bin/ruby
# coding: utf-8
# frozen_string_literal: true

require 'cgi'
require 'csv'
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

mort_vars = [
  File.expand_path('mort-vars.rb', __dir__),
  File.expand_path('../../../web/mort-vars.rb', __dir__)
].find { |path| File.file?(path) }
abort 'web/mort-vars.rb not found' unless mort_vars
require mort_vars

AGES = {
  'age_all' => { ja: '全年齢', en: 'All ages' },
  'age_0' => { ja: '0歳', en: 'Age 0' },
  'age_00_04' => { ja: '0～4歳', en: 'Ages 0–4' },
  'age_00_14' => { ja: '0～14歳', en: 'Ages 0–14' },
  'age_15_64' => { ja: '15～64歳', en: 'Ages 15–64' },
  'age_65_74' => { ja: '65～74歳', en: 'Ages 65–74' },
  'age_75_84' => { ja: '75～84歳', en: 'Ages 75–84' },
  'age_85over' => { ja: '85歳以上', en: 'Ages 85+' }
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
  'PERINATAL' => { ja: '周産期死亡率（近似）', en: 'Perinatal mortality rate (approximate)' }
}.freeze

HMD_URL = 'https://www.mortality.org/Data/STMF'
ESTAT_DEATH_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0'
ESTAT_POP_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0'
DAYS_PER_YEAR = 365.2425
Z95 = 1.959963984540054
MIN_TRAINING_YEARS = 4
POISSON_SIMULATIONS = 10_000
CACHE_SCHEMA = 1
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
selected_age = AGES.key?(cgi['age']) ? cgi['age'] : 'age_all'
selected_series = cgi.params.fetch('series', []).flat_map { |value| value.split(/[~,]/) }.
                  select { |age| AGES.key?(age) }
selected_series = %w[age_all age_00_14 age_65_74 age_85over] if selected_series.empty?
selected_sex = %w[both male female].include?(cgi['sex']) ? cgi['sex'] : 'both'
selected_metric = METRICS.key?(cgi['metric']) ? cgi['metric'] : 'deaths'
requested_causes = cgi.params.fetch('death_codes', []).flat_map { |value| value.split(/[~,]/) }.uniq

def location_names(code)
  Locs[code] || { ja: code, en: code }
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

def metric_available?(code, rates, metric)
  raw = rates.include?('')
  case metric
  when 'deaths' then raw
  when 'std_deaths' then code == 'JPN' && rates.include?('adj')
  when 'crude_rate' then code != 'JPN' && raw && rates.include?('amr')
  when 'asr' then code == 'JPN' && rates.include?('adj') && rates.include?('amr')
  when 'birth_rate' then code == 'USA'
  else false
  end
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
  namespace = File.join(cache_root, "mortyear-v#{CACHE_SCHEMA}")
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
          period: row[:year] <= cutoff ? 'training' : 'prediction',
          dispersion: fit[:dispersion]&.round(4), deaths: row[:deaths].round(2),
          population: row[:population].round, src_url: row[:src_url]
        }
      end
    end
  end
end

def build_scenarios(rows, series_key, label, use_cache:)
  return compute_scenarios(rows, series_key, label) unless use_cache

  cached_scenarios(rows, series_key, label) { compute_scenarios(rows, series_key, label) }
end

fixture_data = if opts[:fixture]
                 parsed = JSON.parse(File.read(opts[:fixture]), symbolize_names: true)
                 parsed = parsed.dig(:hits, :hits).map { |hit| hit.fetch(:_source) } if parsed.is_a?(Hash) && parsed[:hits]
                 parsed
               end
location_rates = available_location_rates(index: opts[:index], fixture: fixture_data)
metric_locations = location_rates.select { |code, rates| metric_available?(code, rates, selected_metric) }.keys.sort
metric_locations |= ['USA'] if selected_metric == 'birth_rate' && location_rates.key?('USA')
available_locations = location_rates.keys.sort
selected_locations = requested_locations.select { |code| available_locations.include?(code) }
selected_locations &= metric_locations
selected_locations = %w[DEU SWE ENG].select { |code| metric_locations.include?(code) } if selected_locations.empty?
selected_locations = [metric_locations.first].compact if selected_locations.empty?
selected_locations = [selected_locations.first] if mode == 'series'
available_causes = available_death_codes(index: opts[:index], fixture: fixture_data,
                                         locations: selected_locations, metric: selected_metric)
selected_causes = requested_causes.select { |code| available_causes.include?(code) }
selected_causes = ['00000'].select { |code| available_causes.include?(code) } if selected_causes.empty?
selected_causes = [available_causes.first].compact if selected_causes.empty?
selected_causes = [selected_causes.first] if mode == 'country'
if selected_metric == 'birth_rate' && selected_locations.include?('USA')
  available_causes = SPECIAL_CAUSES.keys
  selected_causes = requested_causes.select { |code| available_causes.include?(code) }
  selected_causes = ['INFANT'] if selected_causes.empty?
  selected_causes = [selected_causes.first] if mode == 'country'
end

locations_for_query = selected_locations.map(&:downcase)
ages_for_query = mode == 'country' ? [selected_age] : selected_series
source_fields = %w[id loc_code yearweek category rate death_code algo date year week sex src_url] + AGES.keys
common_filters = [
  { 'term' => { 'category' => 'death' } },
  { 'terms' => { 'loc_code' => locations_for_query } },
  { 'term' => { 'sex' => selected_sex } },
  { 'terms' => { 'death_code' => selected_causes.reject { |code| SPECIAL_CAUSES.key?(code) }.yield_self { |codes| codes.empty? ? ['__none__'] : codes } } },
  { 'exists' => { 'field' => 'yearweek' } }
]

if opts[:fixture]
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

series_specs = if mode == 'country'
                 selected_locations.map do |loc|
                   cause = selected_causes.first
                   cause_label = SPECIAL_CAUSES.fetch(cause, Death_codes.fetch(cause, { ja: cause, en: cause })).fetch($l)
                   [loc, selected_age, cause, "#{location_names(loc).fetch($l)} — #{cause_label}"]
                 end
               else
                 selected_causes.map do |cause|
                   key = "#{selected_locations.first}-#{selected_age}-#{cause}"
                   label = SPECIAL_CAUSES.fetch(cause, Death_codes.fetch(cause, { ja: cause, en: cause })).fetch($l)
                   [key, selected_age, cause, label]
                 end
               end

annual_by_age = AGES.keys.to_h do |age|
  annual = if %w[deaths std_deaths].include?(selected_metric)
             annualize_weekly_counts(count_rows, age)
           else
             annualize_weekly(count_rows, rate_rows, age)
           end
  [age, annual]
end

us_series_file = File.expand_path('data/mortyear-us-series.csv', __dir__)
us_special_rows = if File.file?(us_series_file)
                    CSV.read(us_series_file, headers: true).flat_map do |row|
                      SPECIAL_CAUSES.keys.map do |cause|
                        field = cause == 'INFANT' ? 'infant_deaths' : 'perinatal_deaths'
                        value = row[field].to_s.match?(/\A(?:|NA|\.)\z/) ? nil : row[field].to_f
                        next unless value
                        urls = row['src_url'].to_s.split('|')
                        urls = urls.take(1) if cause == 'INFANT'
                        births = row['births'].to_f
                        { loc_code: 'USA', sex: 'both', death_code: cause, year: row['year'].to_i,
                          deaths: value, population: births, observed: value / births * 1000.0, unit_scale: 1000.0,
                          src_url: urls }
                      end.compact
                    end
                  else
                    []
                  end

chart_data = series_specs.flat_map do |series_key, age, cause, label|
  loc = mode == 'country' ? series_key : selected_locations.first
  rows = if SPECIAL_CAUSES.key?(cause)
           us_special_rows.select { |row| row[:loc_code] == loc && row[:death_code] == cause }
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
title = $l == :ja ? "年次#{metric_label}と予測区間" : "Annual #{metric_label.downcase} and prediction intervals"
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
    .mortyear-note { text-align:left; background:#f5f7f8; padding:.8em 1em; }
    #mortyear-vis { width:95%; }
  </style>
  <form class="mortyear-form" method="get">
    <input type="hidden" name="l" value="#{$l}">
    <input id="train-to-hidden" type="hidden" name="train_to" value="#{default_cutoff}">
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
  puts %(<label><input class="metric-option" type="radio" name="metric" value="#{metric}" #{checked(selected_metric == metric)}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts <<~HTML
    </fieldset><br>
    <fieldset><legend>#{ $l == :ja ? '国・地域' : 'Country or area' }</legend>
HTML
Locs.each_key do |code|
  names = location_names(code)
  unavailable = !available_locations.include?(code)
  metrics = METRICS.keys.select { |metric| metric_available?(code, location_rates.fetch(code, []), metric) }
  hidden = !metrics.include?(selected_metric)
  type = mode == 'country' ? 'checkbox' : 'radio'
  title = unavailable ? ($l == :ja ? '現在のmstatsに週次死亡データがありません' : 'No weekly deaths in the current mstats data') : ''
  style = hidden ? 'display:none' : ''
  puts %(<label class="location-label" data-metrics="#{metrics.join(' ')}" style="#{style}" title="#{CGI.escapeHTML(title)}"><input class="location-option" type="#{type}" name="c" value="#{code}" #{checked(selected_locations.include?(code))} #{disabled(unavailable || hidden)}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts <<~HTML
    </fieldset><br>
    <fieldset><legend>#{ $l == :ja ? '年齢' : 'Age' }</legend>
HTML
AGES.each do |age, names|
  puts %(<label><input class="age-option" type="radio" name="age" value="#{age}" #{checked(selected_age == age)}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts <<~HTML
    </fieldset><br>
    <fieldset id="cause-fieldset" style="#{available_causes.length <= 1 ? 'display:none' : ''}"><legend>#{ $l == :ja ? '死因・症例' : 'Cause of death' }</legend>
HTML
available_causes.each do |cause|
  names = SPECIAL_CAUSES.fetch(cause, Death_codes.fetch(cause, { ja: cause, en: cause }))
  type = mode == 'country' ? 'radio' : 'checkbox'
  puts %(<label><input class="cause-option" type="#{type}" name="death_codes" value="#{cause}" #{checked(selected_causes.include?(cause))}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts <<~HTML
    </fieldset><br>
    <button type="submit">#{ $l == :ja ? '表示' : 'Show' }</button>
  </form>
  <script>
    (function () {
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
      }
      const storageKey = "mortyear-location-selection";
      function rememberLocations() {
        const values = Array.from(document.querySelectorAll('.location-option:checked')).map(input => input.value);
        sessionStorage.setItem(storageKey, JSON.stringify(values));
      }
      function restoreLocations() {
        let values = [];
        try { values = JSON.parse(sessionStorage.getItem(storageKey) || "[]"); } catch (_error) {}
        document.querySelectorAll('.location-option').forEach(input => {
          if (values.includes(input.value)) input.checked = true;
        });
      }
      function syncMetric() {
        const metric = document.querySelector('.metric-option:checked').value;
        document.querySelectorAll('.location-label').forEach(label => {
          const available = label.dataset.metrics.split(/\s+/).includes(metric);
          label.style.display = available ? "" : "none";
          label.querySelector('input').disabled = !available;
        });
        const enabled = Array.from(document.querySelectorAll('.location-option:not(:disabled)'));
        if (!enabled.some(input => input.checked) && enabled[0]) enabled[0].checked = true;
        syncComparisonMode();
      }
      document.querySelectorAll('.comparison-mode').forEach(input => {
        input.addEventListener('change', syncComparisonMode);
      });
      document.querySelectorAll('.language-button').forEach(button => {
        button.addEventListener('click', () => {
          const form = button.closest('form');
          form.querySelector('input[name="l"]').value = button.dataset.language;
          form.submit();
        });
      });
      document.querySelectorAll('.location-option').forEach(input => input.addEventListener('change', rememberLocations));
      document.querySelectorAll('.metric-option').forEach(input => input.addEventListener('change', () => {
        rememberLocations();
        syncMetric();
      }));
      restoreLocations();
      syncMetric();
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
  denominator_title = birth_metric ? ($l == :ja ? '出生数（近似分母を含む）' : 'Births (including approximate denominator)') : ($l == :ja ? '年平均人口' : 'Mean population')
  approximation_note = if selected_causes.include?('PERINATAL')
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
  source_items = []
  if sources_by_location['JPN']
    method = if $l == :ja
               'e-Statの月次死亡数と月次人口が原資料。既存の月次→週次変換による派生系列を年次へ再集計している。年齢調整には日本の最新確定人口を標準人口として使用。'
             else
               'Source data are monthly deaths and population from e-Stat. The current implementation reaggregates the derived monthly-to-weekly series into annual values.'
             end
    links = sources_by_location['JPN'].map { |url| %(<a href="#{CGI.escapeHTML(url)}" target="_blank">#{CGI.escapeHTML(url)}</a>) }.join('<br>')
    source_items << "<li><strong>#{CGI.escapeHTML(location_names('JPN').fetch($l))}</strong>: #{CGI.escapeHTML(method)}<br>#{links}</li>"
  end
  hmd_locations = sources_by_location.select { |loc, urls| loc != 'JPN' && urls.include?(HMD_URL) }.keys
  unless hmd_locations.empty?
    labels = hmd_locations.map { |loc| location_names(loc).fetch($l) }.join($l == :ja ? '、' : ', ')
    method = $l == :ja ? 'HMD STMFの週次データを完全な暦年へ集計。年境界週の死亡数は日数按分した。' : 'HMD STMF weekly data aggregated into complete calendar years; deaths in boundary weeks were prorated by days.'
    source_items << "<li><strong>#{CGI.escapeHTML($l == :ja ? 'その他の国・地域' : 'Other countries and areas')}</strong>（#{CGI.escapeHTML(labels)}）: #{CGI.escapeHTML(method)}<br><a href=\"#{HMD_URL}\" target=\"_blank\">#{HMD_URL}</a></li>"
  end
  sources_by_location.each do |loc, urls|
    next if loc == 'JPN' || urls.include?(HMD_URL)

    links = urls.map { |url| %(<a href="#{CGI.escapeHTML(url)}" target="_blank">#{CGI.escapeHTML(url)}</a>) }.join('<br>')
    method = $l == :ja ? '各リンクの原データを完全な暦年へ集計した。' : 'Source data at the links were aggregated into complete calendar years.'
    source_items << "<li><strong>#{CGI.escapeHTML(location_names(loc).fetch($l))}</strong>: #{CGI.escapeHTML(method)}<br>#{links}</li>"
  end
  source_items = source_items.join("\n")
  display_year_max = chart_data.map { |row| row[:year] }.max + 11.0 / 12.0
  puts <<~HTML
    <p class="mortyear-note">
      #{ ($l == :ja ? (birth_metric ? '出生数をoffsetとしたPoisson回帰で、出生1,000当たりを表示しています。' : count_metric ? '横軸は2000年以降の完全な暦年だけです。年境界週の死亡数は日数按分しました。' : '横軸は2000年以降の完全な暦年だけです。年境界週の死亡数は日数按分し、人口は週死亡数と年率換算死亡率から逆算した週人口の時間加重平均です。') : (birth_metric ? 'Poisson regression uses births as the offset and displays rates per 1,000 births.' : count_metric ? 'Only complete calendar years since 2000 are shown. Deaths in boundary weeks were prorated by days.' : 'Only complete calendar years since 2000 are shown. Deaths in boundary weeks are prorated by days; annual population is the time-weighted mean of weekly populations inferred from deaths and annualized rates.')) + ($l == :ja ? ' Poissonの青帯は回帰係数と観測変動を含む10,000回シミュレーションによる95%予測区間です。準Poissonは過分散補正による近似95%予測区間です。' : ' The Poisson band is a 95% prediction interval from 10,000 simulations including coefficient and observation uncertainty. The quasi-Poisson band is an approximate overdispersion-adjusted 95% prediction interval.') + approximation_note }
    </p>
    <p id="mortyear-controls" style="text-align:left">
      <label>#{ $l == :ja ? '学習終了年' : 'Training end' }
        <input id="train-to-slider" type="range" min="#{cutoffs.min}" max="#{cutoffs.max}" step="1" value="#{default_cutoff}">
        <output id="train-to-output">#{default_cutoff}</output>
      </label>
      &nbsp;
      <label>#{ $l == :ja ? 'モデル' : 'Model' }
        <select id="model-selector">
          <option value="poisson">#{ $l == :ja ? 'Poisson（標準）' : 'Poisson (standard)' }</option>
          <option value="quasi_poisson">#{ $l == :ja ? '準Poisson（感度分析）' : 'Quasi-Poisson (sensitivity)' }</option>
        </select>
      </label>
      &nbsp;
      <label><input id="zero-base-checkbox" type="checkbox">
        #{ $l == :ja ? 'Y軸を0から表示' : 'Start Y-axis at zero' }
      </label>
    </p>
    <div id="mortyear-vis"></div>
    <script>
      const values = #{JSON.generate(chart_data)};
      const trainMin = #{cutoffs.min};
      const trainMax = #{cutoffs.max};
      const trainDefault = #{default_cutoff};
      const panels = #{JSON.generate(available_specs.map { |key, _age, _cause, label| [key, label] })};
      const panelSpecs = panels.map(([key, label]) => ({
        title: {text: label, anchor: "start"},
        width: "container", height: 260,
        transform: [
          {filter: `datum.series == '${key}'`},
          {filter: "datum.train_to == train_to"},
          {filter: "datum.model == model"}
        ],
        encoding: {
          x: {field: "year", type: "quantitative", scale: {domain: [2000, #{display_year_max}], nice: false}, axis: {format: "d", tickMinStep: 1}, title: #{JSON.generate($l == :ja ? '年' : 'Year')}}
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
          {name:"train_to", value:trainDefault},
          {name:"model", value:"poisson"},
          {name:"zero_base", value:false}
        ],
        vconcat: panelSpecs,
        resolve: {scale: {y: "independent"}},
        config: {view:{stroke:null}, axis:{labelFontSize:12,titleFontSize:13}, axisY:{minExtent:72,maxExtent:72}, title:{fontSize:15}}
      };
      vegaEmbed("#mortyear-vis", spec, {mode:"vega-lite", actions:false}).then(result => {
        const slider = document.getElementById("train-to-slider");
        const output = document.getElementById("train-to-output");
        const model = document.getElementById("model-selector");
        const zeroBase = document.getElementById("zero-base-checkbox");
        slider.addEventListener("input", () => {
          const value = Number(slider.value);
          output.value = value;
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
