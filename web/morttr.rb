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
  'PRK' => { ja: '北朝鮮', en: 'North Korea' },
  'MYT' => { ja: 'マヨット', en: 'Mayotte' },
  'REU' => { ja: 'レユニオン', en: 'Réunion' },
  'ESH' => { ja: '西サハラ', en: 'Western Sahara' },
  'GUF' => { ja: 'フランス領ギアナ', en: 'French Guiana' },
  'GLP' => { ja: 'グアドループ', en: 'Guadeloupe' },
  'MTQ' => { ja: 'マルティニーク', en: 'Martinique' },
  'PRI' => { ja: 'プエルトリコ', en: 'Puerto Rico' },
  'BLM' => { ja: 'サン・バルテルミー', en: 'Saint Barthélemy' },
  'MAF' => { ja: 'サン・マルタン（フランス領）', en: 'Saint Martin (French part)' },
  'VIR' => { ja: 'アメリカ領ヴァージン諸島', en: 'United States Virgin Islands' },
  'ASM' => { ja: 'アメリカ領サモア', en: 'American Samoa' },
  'GUM' => { ja: 'グアム', en: 'Guam' },
  'MNP' => { ja: '北マリアナ諸島', en: 'Northern Mariana Islands' },
  'ENG' => { ja: 'イングランド・ウェールズ（英国）', en: 'England and Wales (GBR)' },
  'SCO' => { ja: 'スコットランド（英国）', en: 'Scotland (GBR)' }
}.freeze

mort_vars = [
  File.expand_path('mort-vars.rb', __dir__),
  File.expand_path('../../../web/mort-vars.rb', __dir__)
].find { |path| File.file?(path) }
abort 'web/mort-vars.rb not found' unless mort_vars
require mort_vars

region_file = [
  File.expand_path('mort-regions.json', __dir__),
  File.expand_path('../cdeath/config/regions.json', __dir__)
].find { |path| File.file?(path) }
abort 'mortyear region grouping not found' unless region_file
MORTYEAR_REGIONS = JSON.parse(File.read(region_file)).transform_keys(&:upcase).freeze

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
  'age_100plus' => { ja: '100+', en: '100+' }
}.freeze
STANDARD_AGES = AGES.keys.grep(/age_(?:\d{2}_\d{2}|100plus)/).freeze
STMF_AGES = %w[age_00_14 age_15_64 age_65_74 age_75_84 age_85plus age_all].freeze
STMF_AGE_LABELS = {
  'age_00_14' => '00-14', 'age_15_64' => '15-64', 'age_65_74' => '65-74',
  'age_75_84' => '75-84', 'age_85plus' => '85+', 'age_all' => 'all'
}.freeze
STMF_ASR_AGES = %w[age_00_14 age_15_64 age_65_74 age_75_84 age_85plus].freeze
WHO_WORLD_STANDARD = {
  'age_00_04' => 8.86, 'age_05_09' => 8.69, 'age_10_14' => 8.60,
  'age_15_19' => 8.47, 'age_20_24' => 8.22, 'age_25_29' => 7.93,
  'age_30_34' => 7.61, 'age_35_39' => 7.15, 'age_40_44' => 6.59,
  'age_45_49' => 6.04, 'age_50_54' => 5.37, 'age_55_59' => 4.55,
  'age_60_64' => 3.72, 'age_65_69' => 2.96, 'age_70_74' => 2.21,
  'age_75_79' => 1.52, 'age_80_84' => 0.91, 'age_85_89' => 0.44,
  'age_90_94' => 0.15, 'age_95_99' => 0.04, 'age_100plus' => 0.005
}.freeze
JPN_2015_STANDARD_GROUPS = [
  [%w[age_00_04], 5_026_000], [%w[age_05_09], 5_369_000],
  [%w[age_10_14], 5_711_000], [%w[age_15_19], 6_053_000],
  [%w[age_20_24], 6_396_000], [%w[age_25_29], 6_738_000],
  [%w[age_30_34], 7_081_000], [%w[age_35_39], 7_423_000],
  [%w[age_40_44], 7_766_000], [%w[age_45_49], 8_108_000],
  [%w[age_50_54], 8_451_000], [%w[age_55_59], 8_793_000],
  [%w[age_60_64], 9_135_000], [%w[age_65_69], 9_246_000],
  [%w[age_70_74], 7_892_000], [%w[age_75_79], 6_306_000],
  [%w[age_80_84], 4_720_000], [%w[age_85_89], 3_134_000],
  [%w[age_90_94], 1_548_000], [%w[age_95_99 age_100plus], 423_000]
].freeze

# 日本語: 選択年齢だけの標準人口weightを取り出し、後段で選択範囲内へ再正規化する。
# English: Select standard-population weights for the requested ages; downstream code renormalizes them.
def selected_standard_groups(groups, ages)
  return groups if ages.include?('age_all')

  groups.filter_map do |members, weight|
    selected = members & ages
    [selected, weight] unless selected.empty?
  end
end

# 日本語: 5歳階級の標準人口weightをSTMF共通年齢階級へ合算する。
# English: Aggregate five-year standard-population weights into the common STMF age bands.
def stmf_standard_weights(groups)
  members = {
    'age_00_14' => %w[age_00_04 age_05_09 age_10_14],
    'age_15_64' => %w[age_15_19 age_20_24 age_25_29 age_30_34 age_35_39 age_40_44 age_45_49 age_50_54 age_55_59 age_60_64],
    'age_65_74' => %w[age_65_69 age_70_74],
    'age_75_84' => %w[age_75_79 age_80_84],
    'age_85plus' => %w[age_85_89 age_90_94 age_95_99 age_100plus]
  }
  members.to_h do |target, source_ages|
    weight = groups.sum { |ages, value| (ages & source_ages).empty? ? 0 : value }
    [target, weight]
  end
end

METRICS = {
  'deaths' => { ja: '実死亡数', en: 'Observed deaths' },
  'std_deaths' => { ja: '標準人口換算死亡数', en: 'Deaths standardized to the reference population' },
  'crude_rate' => { ja: '粗死亡率', en: 'Crude mortality rate' },
  'asr' => { ja: '年齢調整死亡率', en: 'Age-standardized mortality rate' },
  'birth_rate' => { ja: '出生関連死亡率', en: 'Birth-based mortality rate' }
}.freeze
SPECIAL_CAUSES = {
  'infant' => { ja: '乳児死亡率', en: 'Infant mortality rate' },
  'perm' => { ja: '周産期死亡率', en: 'Perinatal mortality rate' }
}.freeze
CANCER_DATASETS = {
  'vital' => { category: 'death', types: nil,
               ja: '人口動態統計・死亡', en: 'Vital Statistics mortality' },
  'cancer-incidence' => { category: 'incidence', types: %w[mcij ncr],
                          ja: 'がん統計・罹患', en: 'Cancer Statistics incidence' },
  'cancer-death' => { category: 'death', types: %w[ncc],
                      ja: 'がん統計・死亡', en: 'Cancer Statistics mortality' }
}.freeze
CANCER_SITES = {
  'allcancer' => { ja: '全部位の癌', en: 'All cancer sites' },
  'c00-c14' => { ja: '口腔・咽頭癌', en: 'Oral cavity and pharynx cancer' },
  'c15' => { ja: '食道癌', en: 'Esophageal cancer' }, 'c16' => { ja: '胃癌', en: 'Stomach cancer' },
  'c18-c20' => { ja: '大腸癌', en: 'Colorectal cancer' }, 'c18' => { ja: '結腸癌', en: 'Colon cancer' },
  'c19-c20' => { ja: '直腸癌', en: 'Rectal cancer' }, 'c22' => { ja: '肝癌', en: 'Liver cancer' },
  'c23-c24' => { ja: '胆嚢・胆管癌', en: 'Gallbladder and bile duct cancer' },
  'c25' => { ja: '膵癌', en: 'Pancreatic cancer' }, 'c32' => { ja: '喉頭癌', en: 'Laryngeal cancer' },
  'c33-c34' => { ja: '肺癌', en: 'Lung cancer' }, 'c43-c44' => { ja: '皮膚癌', en: 'Skin cancer' },
  'c50' => { ja: '乳癌', en: 'Breast cancer' }, 'c53-c55' => { ja: '子宮癌', en: 'Uterine cancer' },
  'c53' => { ja: '子宮頸癌', en: 'Cervical cancer' }, 'c54' => { ja: '子宮体癌', en: 'Cancer of the uterine corpus' },
  'c56' => { ja: '卵巣癌', en: 'Ovarian cancer' }, 'c61' => { ja: '前立腺癌', en: 'Prostate cancer' },
  'c67' => { ja: '膀胱癌', en: 'Bladder cancer' },
  'c64-c66c68' => { ja: '腎・尿路癌（膀胱を除く）', en: 'Kidney and urinary tract cancer excluding bladder' },
  'c70-c72' => { ja: '脳・中枢神経系癌', en: 'Brain and central nervous system cancer' },
  'c73' => { ja: '甲状腺癌', en: 'Thyroid cancer' },
  'c81-c85c96' => { ja: '悪性リンパ腫', en: 'Malignant lymphoma' },
  'c88-c90' => { ja: '多発性骨髄腫', en: 'Multiple myeloma' },
  'c91-c95' => { ja: '白血病', en: 'Leukemia' }
}.freeze
CANCER_SITE_CHILDREN = {
  'allcancer' => CANCER_SITES.keys - ['allcancer'],
  'c18-c20' => %w[c18 c19-c20],
  'c53-c55' => %w[c53 c54]
}.freeze
FEMALE_SPECIFIC_CANCER_SITES = %w[c53-c55 c53 c54 c56].freeze
MALE_SPECIFIC_CANCER_SITES = %w[c61].freeze
REGION_LABELS = {
  'Africa' => { ja: 'アフリカ', en: 'Africa' },
  'Asia' => { ja: 'アジア', en: 'Asia' },
  'Europe' => { ja: 'ヨーロッパ', en: 'Europe' },
  'Latin America and the Caribbean' => { ja: '中南米・カリブ', en: 'Latin America and the Caribbean' },
  'Northern America' => { ja: '北アメリカ', en: 'Northern America' },
  'Oceania' => { ja: 'オセアニア', en: 'Oceania' },
  'Other' => { ja: 'その他', en: 'Other' }
}.freeze

HMD_HOME_URL = 'https://www.mortality.org/'
HMD_URL = 'https://www.mortality.org/Data/STMF'
WPP_URL = 'https://population.un.org/wpp/downloads'
WHO_STANDARD_URL = 'https://cdn.who.int/media/docs/default-source/gho-documents/global-health-estimates/gpe_discussion_paper_series_paper31_2001_age_standardization_rates.pdf'
ESTAT_DEATH_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0'
ESTAT_ANNUAL_DEATH_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053074&tclass4=000001053089&tclass5val=0'
ESTAT_POP_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0'
DAYS_PER_YEAR = 365.2425
Z95 = 1.959963984540054
MIN_TRAINING_YEARS = 4
POISSON_SIMULATIONS = 10_000
CACHE_SCHEMA = 4
CACHE_MAX_BYTES = 1024 * 1024 * 1024
CACHE_MAX_AGE = 30 * 24 * 60 * 60
DEFAULT_CACHE_DIR = '/var/cache/medicalfacts/mortyear'

opts = { index: 'mstats20260821', debug: false, fixture: nil, catalog_csv: [], summary: false,
         process_cache_jobs: nil, verify_cache: false, rebuild_catalog: false,
         cache_dir: DEFAULT_CACHE_DIR }
OptionParser.new do |parser|
  parser.on('--index INDEX') { |value| opts[:index] = value }
  parser.on('--debug') { opts[:debug] = true }
  parser.on('--fixture FILE') { |value| opts[:fixture] = value }
  parser.on('--catalog-csv FILE', 'Read a CSV file when rebuilding the catalog; repeatable') do |value|
    opts[:catalog_csv] << File.expand_path(value)
  end
  parser.on('--summary') { opts[:summary] = true }
  parser.on('--process-cache-jobs N', 'Maximum jobs or all') do |value|
    opts[:process_cache_jobs] = value == 'all' ? :all : Integer(value, 10).then do |number|
      raise ArgumentError unless number.positive?
      number
    end
  rescue ArgumentError
    raise OptionParser::InvalidArgument, 'use a positive integer or all'
  end
  parser.on('--verify-cache') { opts[:verify_cache] = true }
  parser.on('--rebuild-catalog', 'Rebuild menu availability catalog') { opts[:rebuild_catalog] = true }
  parser.on('--cache-dir DIR') { |value| opts[:cache_dir] = File.expand_path(value) }
end.parse!(ARGV)
$mortyear_cache_dir = opts[:cache_dir]

cgi = CGI.new
requested_language = cgi['l']
$l = if requested_language.match?(/^(en|english)/i) ||
        (requested_language.empty? && ENV['HTTP_ACCEPT_LANGUAGE'].to_s !~ /^ja/i)
       :en
     else
       :ja
     end
mode = cgi['mode'] == 'series' ? 'series' : 'country'
# 日本語: 公開URLではdatasetを選ばせず、人口動態死亡と癌統計を同じ画面で扱う。
# English: Do not expose a dataset URL parameter; combine vital and cancer series on one screen.
selected_dataset = 'vital'
$mortyear_category = CANCER_DATASETS.fetch(selected_dataset).fetch(:category)
$mortyear_types = CANCER_DATASETS.fetch(selected_dataset).fetch(:types)
requested_locations = cgi.params.fetch('c', []).flat_map { |value| value.split(/[~,]/) }.
                      map(&:upcase).uniq
selected_period = %w[calendar flu27 flu36 weekly].include?(cgi['period']) ? cgi['period'] : 'calendar'
if selected_dataset != 'vital'
  selected_period = 'calendar'
  mode = 'series'
  requested_locations = ['JPN']
end
# 日本語: cod.rb互換のages範囲表記と旧来の反復age parameterを内部field名へ展開する。
# English: Expand cod.rb-compatible age ranges and legacy repeated age parameters into field names.
age_values = cgi.params.fetch('ages', []) + cgi.params.fetch('age', [])
selected_ages = age_values.flat_map { |value| value.split(/[~,]/) }.flat_map do |token|
  token = token.sub(/over\z/, 'plus')
  next 'age_all' if %w[all age_all].include?(token)
  next 'age_0' if %w[0 age_0].include?(token)
  next token if AGES.key?(token) || STMF_AGES.include?(token)

  if selected_period != 'calendar'
    stmf_age = STMF_AGE_LABELS.key(token)
    next stmf_age if stmf_age
  end
  normalized = token.start_with?('age_') ? token : "age_#{token}"
  next normalized if STANDARD_AGES.include?(normalized)

  match = token.match(/\A(\d+)-(\d+|100plus)\z/)
  next [] unless match

  lower = match[1].to_i
  upper = match[2] == '100plus' ? '100plus' : match[2].to_i
  first = STANDARD_AGES.index do |age|
    age == 'age_100plus' ? lower == 100 : age[/\Aage_(\d{2})_/, 1].to_i == lower
  end
  last = STANDARD_AGES.index do |age|
    age == 'age_100plus' ? upper == '100plus' : age[/_(\d{2})\z/, 1].to_i == upper
  end
  first && last && first <= last ? STANDARD_AGES[first..last] : []
end.flatten.select { |age| AGES.key?(age) || STMF_AGES.include?(age) }.uniq
selected_ages = ['age_all'] if selected_ages.empty?
selected_sex = %w[both male female].include?(cgi['sex']) ? cgi['sex'] : 'both'
selected_metric = METRICS.key?(cgi['metric']) ? cgi['metric'] : 'deaths'
selected_metric = 'deaths' if selected_dataset != 'vital' && !%w[deaths crude_rate asr].include?(selected_metric)
selected_ages = ['age_all'] if selected_dataset != 'vital' && selected_metric == 'asr'
selected_sex = 'both' if selected_metric == 'birth_rate'
interval_mode = cgi['interval'] == 'analytic' ? 'analytic' : 'auto'
include_deficit = %w[1 true yes on].include?(cgi['include_deficit'].downcase)
zero_base = %w[1 true yes on].include?(cgi['zero_base'].downcase)
covid_overlay = %w[1 true yes on].include?(cgi['covid_overlay'].downcase)
vaxx_overlay = %w[1 true yes on].include?(cgi['vaxx_overlay'].downcase)
selected_chart_model = %w[quasi_poisson poisson].include?(cgi['chart_model']) ? cgi['chart_model'] : 'quasi_poisson'
weekly_methods = cgi.params.fetch('weekly_method', []).flat_map { |value| value.split(/[~,]/) } &
                 %w[five_year farrington euromomo]
weekly_baselines = cgi.params.fetch('weekly_baseline', []).flat_map { |value| value.split(/[~,]/) }.
                   map { |value| value == 'fixed' ? 'fixed_2015_2019' : value } &
                   %w[fixed_2015_2019 fixed_2016_2020 rolling]
weekly_methods = ['five_year'] if weekly_methods.empty?
weekly_baselines = ['fixed_2015_2019'] if weekly_baselines.empty?
weekly_methods = [weekly_methods.first] if mode == 'country'
weekly_baselines = [weekly_baselines.first] if mode == 'country'
weekly_method = weekly_methods.first
weekly_baseline = weekly_baselines.first
$mortyear_period = selected_period
$mortyear_training_start = selected_period == 'calendar' ? 2000 : 1999
# 日本語: 暦年の英国とSTMF週次の英国地域を期間切替時に相互変換する。
# English: Map annual UK and STMF weekly UK-region codes when switching periods.
requested_locations = requested_locations.flat_map do |code|
  if selected_period == 'calendar' && %w[ENG SCO].include?(code)
    'GBR'
  elsif selected_period != 'calendar' && code == 'GBR'
    'ENG'
  else
    code
  end
end.uniq
selected_ages = ['age_all'] if selected_metric == 'birth_rate'
selected_metric = 'deaths' if selected_period != 'calendar' && !%w[deaths crude_rate asr].include?(selected_metric)
selected_ages &= STMF_AGES if selected_period != 'calendar'
selected_ages = ['age_all'] if selected_ages.empty?
selected_ages = ['age_all'] if selected_period != 'calendar' && selected_ages.include?('age_all')
selected_ages = ['age_all'] if selected_period != 'calendar' && selected_metric == 'asr'
selected_ages = [selected_ages.first] if selected_period != 'calendar' && mode == 'country'
requested_dcodes = cgi.params.fetch('dcodes', [])
requested_dcodes = cgi.params.fetch('death_codes', []) if requested_dcodes.empty?
requested_causes = requested_dcodes.flat_map { |value| value.split(/[~,]/) }.
                   map do |code|
                     normalized = code.downcase
                     %w[all 00000].include?(normalized) ? 'allcause' :
                       (normalized == 'perinatal' ? 'perm' : normalized)
                   end.uniq
include_incidence = %w[1 true yes on].include?(cgi['include_incidence'].downcase) ||
                    selected_dataset == 'cancer-incidence'
if selected_dataset != 'vital' && selected_sex == 'both'
  requested_site_codes = requested_causes.empty? ? ['c53'] : requested_causes
  selected_sex = 'female' if (requested_site_codes - %w[c53-c55 c53 c54 c56]).empty?
  selected_sex = 'male' if requested_site_codes == ['c61']
end
requested_start_year = cgi['start_year'].to_i
period_start_year = selected_period == 'calendar' ? 2000 : (selected_period == 'weekly' ? 2015 : 1999)
default_start_year = requested_start_year.between?(1950, 2020) ? requested_start_year : period_start_year

def location_names(code)
  known = COUNTRY_NAME_OVERRIDES[code] || COUNTRY_NAMES[code]
  source_name = $annual_catalog&.dig(code, :area).to_s
  return known if known
  { ja: source_name.empty? ? code : source_name, en: source_name.empty? ? code : source_name }
end

def location_sort_key(code, language)
  name = location_names(code).fetch(language)
  return name.downcase unless language == :ja

  [name.match?(/\A[ァ-ヿ]/) ? 0 : 1, name]
end

def default_source_urls(loc)
  loc.to_s.upcase == 'JPN' ? [ESTAT_DEATH_URL, ESTAT_POP_URL] : [HMD_URL]
end

# 日本語: 国ごとに存在する週次系列のrate値を返す。
# English: Return the weekly rate-field values available for each location.
def available_location_rates(index:, fixture:)
  if fixture
    rates = fixture.group_by { |row| row[:loc].to_s.upcase }.transform_values do |rows|
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
      { term: { dcode: 'allcause' } },
      { exists: { field: 'yearweek' } }
    ] } },
    aggs: { locations: { terms: { field: 'loc', size: 300 },
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
    return annual.group_by { |row| row[:loc].to_s.upcase }.transform_values do |rows|
      sample = rows.first
      {
        area: sample[:area].to_s, areaj: sample[:areaj].to_s,
        rates: rows.map { |row| row[:rate].to_s }.uniq,
        categories: rows.map { |row| row[:category].to_s }.uniq,
        dcodes: rows.map { |row| row[:dcode].to_s }.reject(&:empty?).uniq,
        dcode_max_years: rows.select { |row| !row[:dcode].to_s.empty? }.
                              group_by { |row| row[:dcode].to_s }.
                              transform_values { |items| items.map { |row| row[:year].to_i }.max },
        infant_all_cause_max_year: rows.select do |row|
          row[:category] == 'death' && row[:dcode] == 'allcause' && row[:type] == 'cfm' &&
            row[:rate].to_s.empty? && row[:algo].to_s.empty? && !row[:age_0].nil?
        end.map { |row| row[:year].to_i }.max.to_i,
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
    aggs: { locations: { terms: { field: 'loc', size: 300 }, aggs: {
      sample: { top_hits: { size: 1, _source: %w[area areaj] } },
      rates: { terms: { field: 'rate', size: 20 } },
      categories: { terms: { field: 'category', size: 20 } },
      dcodes: { terms: { field: 'dcode', size: 1000 },
                     aggs: { max_year: { max: { field: 'year' } } } },
      infant_all_cause: { filter: { bool: { filter: [
        { term: { category: 'death' } }, { term: { dcode: 'allcause' } },
        { term: { type: 'cfm' } }, { exists: { field: 'age_0' } }
      ], must_not: [{ exists: { field: 'rate' } }, { exists: { field: 'algo' } }] } },
                          aggs: { max_year: { max: { field: 'year' } } } },
      algos: { terms: { field: 'algo', size: 20 } }
    } } }
  )
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  raise "Elasticsearch annual catalog failed: HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).dig('aggregations', 'locations', 'buckets').to_h do |bucket|
    source = bucket.dig('sample', 'hits', 'hits', 0, '_source') || {}
    values = ->(name) { bucket.dig(name, 'buckets').map { |entry| entry['key'].to_s } }
    [bucket['key'].upcase, {
      area: source['area'].to_s, areaj: source['areaj'].to_s,
      rates: values.call('rates'), categories: values.call('categories'),
      dcodes: values.call('dcodes'),
      dcode_max_years: bucket.dig('dcodes', 'buckets').to_h do |entry|
        [entry['key'].to_s, entry.dig('max_year', 'value').to_i]
      end,
      infant_all_cause_max_year: bucket.dig('infant_all_cause', 'max_year', 'value').to_i,
      algos: values.call('algos')
    }]
  end
end

def metric_available?(code, rates, metric)
  raw = rates.include?('')
  case metric
  when 'deaths' then raw
  when 'std_deaths' then false
  when 'crude_rate' then raw && rates.include?('crude')
  when 'asr' then raw && rates.include?('crude')
  when 'birth_rate' then true
  else false
  end
end

# UN WPP由来か、予測値か、人口曝露量かをtypeだけから判定する。
# Identify UN WPP, projected, and population-exposure records from type alone.
def wpp_record?(row)
  row[:type].to_s.start_with?('unwpp2024')
end

def projected_record?(row)
  row[:type].to_s.end_with?('prj')
end

def exposure_record?(row)
  row[:type].to_s.start_with?('unwpp2024exp')
end

def annual_metric_available?(code, catalog, metric)
  if catalog[:series]
    return catalog[:series].any? do |item|
      (item[:period] || 'calendar') == 'calendar' && item[:metric] == metric && item[:displayable]
    end
  end

  rates = catalog.fetch(:rates)
  categories = catalog.fetch(:categories)
  codes = catalog.fetch(:dcodes)
  case metric
  when 'deaths' then categories.include?('death') && codes.include?('allcause')
  when 'crude_rate' then rates.include?('crude')
  when 'asr' then rates.include?('asr')
  when 'birth_rate'
    categories.include?('birth') &&
      (codes.include?('infant') || codes.include?('perm') || catalog.fetch(:infant_all_cause_max_year, 0).positive?)
  else false
  end
end

def period_metric_available?(catalog, metric, period)
  catalog.fetch(:series, []).any? do |item|
    (item[:period] || 'calendar') == period && item[:metric] == metric && item[:displayable]
  end
end

# 日本語: 明示的な乳児死亡recordか、公式全死因recordのage_0から表示可能性を判定する。
# English: Determine availability from an explicit infant record or age_0 of an official all-cause record.
def birth_cause_available?(_location, catalog, cause)
  if catalog[:series]
    return catalog[:series].any? do |item|
      item[:metric] == 'birth_rate' && item[:cause] == cause && item[:displayable]
    end
  end

  codes = catalog.fetch(:dcodes)
  # 日本語: 最短cutoff 2015と、その後2年の予測評価を作れる系列だけを表示対象にする。
  # English: Require enough data for the earliest 2015 cutoff plus two evaluation years.
  max_years = catalog.fetch(:dcode_max_years, {})
  if cause == 'perm'
    codes.include?('perm') && max_years.fetch('perm', 0) >= 2017
  else
    explicit = codes.include?('infant') && max_years.fetch('infant', 0) >= 2017
    explicit || catalog.fetch(:infant_all_cause_max_year, 0) >= 2017
  end
end

def available_dcodes(index:, fixture:, locations:, metric:)
  wanted_rate = metric == 'asr' ? 'asr' : ''
  if fixture
    return fixture.select do |row|
      locations.include?(row[:loc].to_s.upcase) && row[:yearweek] && row[:rate].to_s == wanted_rate
    end.map { |row| row[:dcode].to_s }.uniq.sort
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
    { term: { category: 'death' } }, { terms: { loc: locations.map(&:downcase) } },
    { exists: { field: 'yearweek' } }, rate_filter
  ] } }, aggs: { codes: { terms: { field: 'dcode', size: 1000 } } })
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  raise "Elasticsearch cause aggregation failed: HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body).dig('aggregations', 'codes', 'buckets').map { |bucket| bucket['key'] }.sort
end

def available_annual_dcodes(index:, fixture:, locations:, metric:)
  wanted_rate = if $mortyear_category == 'incidence' || $mortyear_types == %w[ncc]
                  metric == 'asr' ? 'asr' : ''
                else
                  { 'crude_rate' => 'crude', 'asr' => 'asr' }.fetch(metric, '')
                end
  if fixture
    return fixture.select do |row|
      locations.include?(row[:loc].to_s.upcase) && !row[:yearmonth] && !row[:yearweek] &&
        row[:category] == $mortyear_category &&
        (!$mortyear_types || $mortyear_types.include?(row[:type].to_s)) && row[:rate].to_s == wanted_rate
    end.map { |row| row[:dcode].to_s }.reject(&:empty?).uniq.sort
  end
  public_index = PUBLIC_ELASTIC_INDEXES[index.to_s]
  uri = URI.parse(public_index ? "http://localhost:8080/elastic/#{public_index}/_search" : "http://localhost:9200/#{index}/_search")
  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'
  elastic_basic_auth(request) unless public_index
  rate_filter = wanted_rate.empty? ? {
    bool: { should: [{ term: { rate: '' } }, { bool: { must_not: [{ exists: { field: 'rate' } }] } }], minimum_should_match: 1 }
  } : { term: { rate: wanted_rate } }
  filters = [{ term: { category: $mortyear_category } }, { terms: { loc: locations.map(&:downcase) } }, rate_filter]
  filters << { terms: { type: $mortyear_types } } if $mortyear_types
  request.body = JSON.generate(size: 0, query: { bool: {
    filter: filters,
    must_not: [{ exists: { field: 'yearmonth' } }, { exists: { field: 'yearweek' } }]
  } }, aggs: { codes: { terms: { field: 'dcode', size: 1000 } } })
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  raise "Elasticsearch annual cause aggregation failed: HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body).dig('aggregations', 'codes', 'buckets').map { |bucket| bucket['key'] }.sort
end

# 日本語: categoryとtypeを組み合わせ、現在選択中の統計系列だけを採用する。
# English: Match the selected statistical series by its category and type together.
def mortyear_stat_record?(row, category: $mortyear_category, types: $mortyear_types)
  row[:category] == category && (!types || types.include?(row[:type].to_s))
end

# 日本語: 男女表示の性特有癌は該当する性の公表系列から全体表示を補完する。
# English: In a both-sex view, supplement the overall display from the applicable published sex-specific series.
def cancer_series_sex(selected_sex, cause)
  return selected_sex unless selected_sex == 'both'
  return 'female' if FEMALE_SPECIFIC_CANCER_SITES.include?(cause)
  return 'male' if MALE_SPECIFIC_CANCER_SITES.include?(cause)

  selected_sex
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

# 日本語: 年次傾向を識別できない疎な系列には、一定率の切片のみモデルを使う。
# English: Use a constant-rate intercept-only model when a sparse series cannot identify a time trend.
def poisson_intercept_fit(rows, center)
  total_deaths = rows.sum { |row| row[:deaths] }
  total_population = rows.sum { |row| row[:population] }
  rate = total_deaths.fdiv(total_population)
  pearson = rows.sum do |row|
    mu = rate * row[:population]
    mu.positive? ? (row[:deaths] - mu)**2 / mu : 0.0
  end
  dispersion = rows.length > 1 ? pearson / (rows.length - 1) : nil
  { beta: [Math.log(rate), 0.0], covariance: [[1.0 / total_deaths, 0.0], [0.0, 0.0]],
    center: center, dispersion: dispersion, intercept_only: true }
end

# 日本語: 人口offset付きPoisson回帰をIRLSで推定する。
# English: Fit a population-offset Poisson regression by IRLS.
def poisson_fit(rows)
  center = rows.sum { |row| row[:year] }.fdiv(rows.length)
  total_deaths = rows.sum { |row| row[:deaths] }
  # 日本語: 学習期間が全て0件なら、期待値・分散とも0の境界モデルとして扱う。
  # English: Treat an all-zero training period as a boundary model with zero expectation and variance.
  if total_deaths.zero?
    return { beta: [-Float::INFINITY, 0.0], covariance: [[0.0, 0.0], [0.0, 0.0]],
             center: center, dispersion: 0.0, zero: true }
  end
  return poisson_intercept_fit(rows, center) if rows.count { |row| row[:deaths].positive? } < 2

  beta = [Math.log(total_deaths.fdiv(rows.sum { |row| row[:population] })), 0.0]
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
    begin
      covariance = inverse_2x2(xtwx)
    rescue RuntimeError => error
      raise unless error.message == 'singular regression matrix'
      return poisson_intercept_fit(rows, center)
    end
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
  return Array.new(count) { fit[:beta].dup } if fit[:zero]

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
    [[row[:year], row[:dcode]], { expected: expected, lower: lower, upper: upper }]
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

def gzip_write(path, value, mode: 0o644)
  temporary = "#{path}.#{Process.pid}.tmp"
  Zlib::GzipWriter.open(temporary) { |gzip| gzip.write(JSON.generate(value)) }
  File.chmod(mode, temporary)
  File.rename(temporary, path)
end

def gzip_read(path)
  Zlib::GzipReader.open(path) { |gzip| JSON.parse(gzip.read, symbolize_names: true) }
end

def cache_root
  $mortyear_cache_dir
end

def cache_key(rows, calculator_type)
  canonical_value(
    cache_schema: CACHE_SCHEMA,
    algorithm: 'poisson-linear-trend-dual-cache-v2',
    period: { type: $mortyear_period, aggregation_version: 2 },
    calculator_type: calculator_type,
    simulations: POISSON_SIMULATIONS,
    seed_method: 'sha256-input-cutoff-v1',
    input: rows
  )
end

def cache_digest(key)
  Digest::SHA256.hexdigest(canonical_json(key))
end

def cache_file(digest, queue: false)
  base = queue ? File.join(cache_root, 'queue') : cache_root
  File.join(base, digest[0, 2], "#{digest}.json.gz")
end

def cache_entry(path, key)
  return unless File.file?(path)

  document = gzip_read(path)
  Array(document[:entries]).find { |entry| canonical_value(entry[:key]) == key }
rescue JSON::ParserError, Zlib::GzipFile::Error, Errno::ENOENT
  nil
end

def write_queue_entry(path, entry)
  # 日本語: CGIとcron workerが同じgroupを継承できるよう、queue directoryにsetgidを付ける。
  # English: Set setgid on queue directories so the CGI and cron worker inherit the shared group.
  FileUtils.mkdir_p(File.dirname(path), mode: 0o2770)
  lock_path = File.join(cache_root, 'queue', '.write.lock')
  File.open(lock_path, File::RDWR | File::CREAT, 0o666) do |lock|
    lock.flock(File::LOCK_EX)
    document = File.file?(path) ? gzip_read(path) : { schema: CACHE_SCHEMA, entries: [] }
    entries = Array(document[:entries])
    entries << entry unless entries.any? { |item| canonical_value(item[:key]) == canonical_value(entry[:key]) }
    gzip_write(path, { schema: CACHE_SCHEMA, entries: entries })
  end
end

# 日本語: 近似値は要求中に返し、一fileのqueueをmagicianのcron workerへ渡す。
# English: Return analytic results in-request and queue one self-describing file for the magician cron worker.
def cached_scenarios(rows, calculator_type, analytic_calculator)
  key = cache_key(rows, calculator_type)
  digest = cache_digest(key)
  completed = cache_entry(cache_file(digest), key)
  return [completed[:analytic], Array(completed[:simulation])] if completed

  queue_path = cache_file(digest, queue: true)
  queued = cache_entry(queue_path, key)
  return [queued[:analytic], []] if queued

  analytic = analytic_calculator.call(rows, '', '')
  begin
    write_queue_entry(queue_path, {
      key: key, analytic: analytic, simulation: nil,
      created_at: Time.now.utc.iso8601, simulated_at: nil
    })
  rescue SystemCallError => error
    warn "mortyear cache queue write failed: #{error.message}"
  end
  [analytic, []]
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
      target = annual[[row[:loc], row[:sex], row[:dcode], year]]
      target[:value] += value.to_f * dates.length / 7.0
      dates.each { |date| target[:covered_days][date] = true }
      target[:src_url] |= Array(row[:src_url]).compact
    end
  end
  annual.map do |(loc, sex, dcode, year), values|
    required_days = Date.leap?(year) ? 366 : 365
    next unless year >= 2000 && values[:covered_days].length == required_days
    {
      loc: loc.upcase, sex: sex, dcode: dcode, year: year,
      deaths: values[:value], population: 1.0, observed: values[:value], unit_scale: 1.0,
      src_url: values[:src_url].empty? ? default_source_urls(loc) : values[:src_url]
    }
  end.compact.sort_by { |row| [row[:loc], row[:year]] }
end

# 日本語: 週の7日を暦年へ配分する。死亡数だけを日数按分し、人口は週率から逆算する。
# English: Split a seven-day week across calendar years; prorate deaths only and infer weekly population from the annualized rate.
def annualize_weekly(count_rows, rate_rows, age)
  rates = rate_rows.to_h { |row| [[row[:loc], row[:yearweek], row[:sex], row[:dcode]], row] }
  annual = Hash.new do |hash, key|
    hash[key] = { deaths: 0.0, population_days: 0.0, covered_days: {}, src_url: [] }
  end

  count_rows.each do |count|
    value = count[age.to_sym]
    rate = rates[[count[:loc], count[:yearweek], count[:sex], count[:dcode]]]
    rate_value = rate && rate[age.to_sym]
    next if value.nil? || rate_value.nil? || rate_value.to_f <= 0

    week_end = Date.parse(count[:date].to_s)
    week_start = week_end - 6
    weekly_population = value.to_f * DAYS_PER_YEAR * 100_000 / (7 * rate_value.to_f)
    (week_start..week_end).group_by(&:year).each do |year, dates|
      target = annual[[count[:loc], count[:sex], count[:dcode], year]]
      target[:deaths] += value.to_f * dates.length / 7.0
      target[:population_days] += weekly_population * dates.length
      dates.each { |date| target[:covered_days][date] = true }
      urls = [count[:src_url], rate[:src_url]].flatten.compact.reject { |url| url.to_s.empty? }
      target[:src_url] |= (urls.empty? ? default_source_urls(count[:loc]) : urls)
    end
  end

  annual.map do |(loc, sex, dcode, year), values|
    required_days = Date.leap?(year) ? 366 : 365
    next unless year >= 2000 && values[:covered_days].length == required_days

    population = values[:population_days] / required_days
    next unless population.positive?

    {
      loc: loc.upcase, sex: sex, dcode: dcode, year: year,
      deaths: values[:deaths], population: population,
      observed: values[:deaths] / population * 100_000, unit_scale: 100_000.0,
      src_url: values[:src_url].empty? ? default_source_urls(loc) : values[:src_url]
    }
  end.compact.sort_by { |row| [row[:loc], row[:year]] }
end

def influenza_year_start(date, start_week)
  start = Date.commercial(date.cwyear, start_week, 1)
  date < start ? Date.commercial(date.cwyear - 1, start_week, 1) : start
end

# 日本語: 週次死亡数と率を、第27週または第36週開始の完全なインフルエンザ年へ集計する。
# English: Aggregate weekly deaths and rates into complete influenza years starting in W27 or W36.
def annualize_influenza_year(count_rows, rate_rows, ages, start_week, metric = 'crude_rate')
  rates = rate_rows.to_h { |row| [[row[:loc], row[:yearweek], row[:sex], row[:dcode]], row] }
  count_metric = metric == 'deaths'
  seasons = Hash.new do |hash, key|
    hash[key] = { deaths: 0.0, population_days: 0.0, covered_days: {}, src_url: [] }
  end
  count_rows.each do |count|
    rate = rates[[count[:loc], count[:yearweek], count[:sex], count[:dcode]]]
    count_values = ages.map { |age| count[age.to_sym] }
    next if count_values.any?(&:nil?)

    deaths = count_values.sum(&:to_f)
    rate_values = ages.map { |age| rate&.dig(age.to_sym) }
    next if !count_metric && (rate.nil? || rate_values.any? { |value| value.nil? || value.to_f <= 0 })

    populations = if count_metric
                    0.0
                  else
                    ages.each_index.sum do |index|
                      count_values[index].to_f * DAYS_PER_YEAR * 100_000 / (7 * rate_values[index].to_f)
                    end
                  end
    week_end = Date.parse(count[:date].to_s)
    week_start = week_end - 6
    (week_start..week_end).group_by { |date| influenza_year_start(date, start_week) }.each do |season_start, dates|
      key = [count[:loc], count[:sex], count[:dcode], season_start]
      target = seasons[key]
      target[:deaths] += deaths * dates.length / 7.0
      target[:population_days] += populations * dates.length unless count_metric
      dates.each { |date| target[:covered_days][date] = true }
      target[:src_url] |= (Array(count[:src_url]) + Array(rate&.dig(:src_url))).compact
    end
  end
  seasons.filter_map do |(loc, sex, cause, season_start), values|
    season_end = Date.commercial(season_start.cwyear + 1, start_week, 1) - 1
    required_days = (season_start..season_end).count
    next unless season_start.cwyear >= 1999 && values[:covered_days].length == required_days
    population = count_metric ? 1.0 : values[:population_days] / required_days
    next unless count_metric || population.positive?

    crude_rate = count_metric ? nil : values[:deaths] / population * 100_000
    { loc: loc.upcase, sex: sex, dcode: cause, year: season_start.cwyear,
      season: "#{season_start.cwyear}/#{format('%02d', (season_start.cwyear + 1) % 100)}",
      deaths: values[:deaths], population: count_metric ? 1.0 : population,
      observed: count_metric ? values[:deaths] : crude_rate,
      unit_scale: count_metric ? 1.0 : 100_000.0,
      src_url: values[:src_url].empty? ? default_source_urls(loc) : values[:src_url] }
  end.sort_by { |row| [row[:loc], row[:year]] }
end

# 日本語: 選択したSTMF年齢階級を標準人口で加重し、インフルエンザ年ASRを計算する。
# English: Calculate influenza-year ASR over the selected STMF ages using the chosen standard population.
def annualize_influenza_asr(count_rows, rate_rows, start_week, ages, weights)
  selected = ages.include?('age_all') ? STMF_ASR_AGES : ages
  weight_total = selected.sum { |age| weights.fetch(age) }
  grouped = selected.flat_map do |age|
    annualize_influenza_year(count_rows, rate_rows, [age], start_week, 'crude_rate').map do |row|
      [row, age]
    end
  end.group_by { |row, _age| [row[:loc], row[:sex], row[:dcode], row[:year]] }

  grouped.filter_map do |(_loc, _sex, _cause, _year), items|
    next unless items.map(&:last).sort == selected.sort

    strata = items.map do |row, age|
      { age: age, deaths: row[:deaths], population: row[:population],
        weight: weights.fetch(age).to_f / weight_total, src_url: row[:src_url] }
    end
    first = items.first.first
    first.merge(
      strata: strata, deaths: strata.sum { |item| item[:deaths] },
      population: strata.sum { |item| item[:population] },
      observed: strata.sum { |item| item[:deaths] / item[:population] * 100_000 * item[:weight] },
      unit_scale: 100_000.0, src_url: strata.flat_map { |item| item[:src_url] }.uniq
    )
  end.sort_by { |row| [row[:loc], row[:year]] }
end

# 日本語: 選択系列の週次死亡率を年率換算のまま補助表示用に作る。
# English: Build annualized weekly mortality rates for the contextual view.
def weekly_rate_rows(count_rows, rate_rows, metric, ages, asr_weights: nil)
  rates = rate_rows.to_h { |row| [[row[:loc], row[:yearweek], row[:sex], row[:dcode]], row] }
  age_members = {
    'age_00_14' => %w[age_00_04 age_05_09 age_10_14],
    'age_15_64' => %w[age_15_19 age_20_24 age_25_29 age_30_34 age_35_39 age_40_44 age_45_49 age_50_54 age_55_59 age_60_64],
    'age_65_74' => %w[age_65_69 age_70_74], 'age_75_84' => %w[age_75_79 age_80_84],
    'age_85plus' => %w[age_85_89 age_90_94 age_95_99 age_100plus]
  }
  weights = asr_weights || age_members.transform_values { |members| members.sum { |age| WHO_WORLD_STANDARD.fetch(age) } }
  selected_asr_ages = ages.include?('age_all') ? STMF_ASR_AGES : ages
  weight_total = selected_asr_ages.sum { |age| weights.fetch(age) }
  count_rows.filter_map do |count|
    rate = rates[[count[:loc], count[:yearweek], count[:sex], count[:dcode]]]
    next unless rate

    observed = if metric == 'asr'
                 next unless selected_asr_ages.all? { |age| rate[age.to_sym]&.to_f&.positive? }
                 selected_asr_ages.sum { |age| rate[age.to_sym].to_f * weights.fetch(age).to_f / weight_total }
               else
                 values = ages.map { |age| count[age.to_sym] }
                 rate_values = ages.map { |age| rate[age.to_sym] }
                 next if values.any?(&:nil?) || rate_values.any? { |value| value.nil? || value.to_f <= 0 }
                 deaths = values.sum(&:to_f)
                 population = ages.each_index.sum do |index|
                   values[index].to_f * DAYS_PER_YEAR * 100_000 / (7 * rate_values[index].to_f)
                 end
                 deaths * DAYS_PER_YEAR * 100_000 / (7 * population)
               end
    strata = if metric == 'asr'
               selected_asr_ages.map do |age|
                 deaths = count[age.to_sym].to_f
                 age_rate = rate[age.to_sym].to_f
                 population = deaths * DAYS_PER_YEAR * 100_000 / (7 * age_rate)
                 { age: age, deaths: deaths, population: population,
                   weight: weights.fetch(age).to_f / weight_total }
               end
             else
               values = ages.map { |age| count[age.to_sym].to_f }
               rate_values = ages.map { |age| rate[age.to_sym].to_f }
               population = ages.each_index.sum do |index|
                 values[index] * DAYS_PER_YEAR * 100_000 / (7 * rate_values[index])
               end
               [{ age: 'combined', deaths: values.sum, population: population, weight: 1.0 }]
             end
    { loc: count[:loc].to_s.upcase, dcode: count[:dcode],
      date: count[:date], observed: observed, model_strata: strata,
      src_url: (Array(count[:src_url]) + Array(rate[:src_url])).compact.uniq }
  end.sort_by { |row| [row[:loc], row[:date].to_s] }
end

# 日本語: 週次主表示では死亡数を率へ変換せず、その週の選択年齢死亡数として返す。
# English: For the primary weekly view, return selected-age weekly death counts without rate conversion.
def weekly_display_rows(count_rows, rate_rows, metric, ages, asr_weights: nil)
  return weekly_rate_rows(count_rows, rate_rows, metric, ages, asr_weights: asr_weights) unless metric == 'deaths'

  count_rows.filter_map do |count|
    values = ages.map { |age| count[age.to_sym] }
    next if values.any?(&:nil?)

    deaths = values.sum(&:to_f)
    { loc: count[:loc].to_s.upcase, dcode: count[:dcode], date: count[:date],
      observed: deaths, model_strata: [{ age: 'combined', deaths: deaths, population: 1.0, weight: 1.0 }],
      src_url: Array(count[:src_url]).compact.uniq }
  end.sort_by { |row| [row[:loc], row[:date].to_s] }
end

# 日本語: offset付きPoisson回帰をIRLSで当て、予測分散に過分散と係数推定誤差を含める。
# English: Fit an offset Poisson GLM by IRLS and include overdispersion and coefficient uncertainty in predictions.
def fit_weekly_poisson(samples, robust: false)
  return nil if samples.length < 4

  active = samples
  fit = nil
  (robust ? 2 : 1).times do
    p = active.first[:features].length
    beta = Vector.elements(Array.new(p, 0.0))
    40.times do
      xtwx = Matrix.zero(p)
      xtwz = Vector.elements(Array.new(p, 0.0))
      active.each do |sample|
        x = Vector.elements(sample[:features])
        offset = Math.log([sample[:exposure].to_f, 1e-12].max)
        eta = [[offset + x.inner_product(beta), 20.0].min, -20.0].max
        mu = Math.exp(eta)
        z = eta + (sample[:deaths].to_f - mu) / mu
        xtwx += x.to_matrix * x.to_matrix.transpose * mu
        xtwz += x * (mu * (z - offset))
      end
      updated = xtwx.inverse * xtwz
      break beta = updated if (updated - beta).magnitude < 1e-8
      beta = updated
    rescue ExceptionForMatrix::ErrNotRegular, ExceptionForMatrix::ErrDimensionMismatch
      return nil
    end
    mus = active.map do |sample|
      Math.exp(Math.log([sample[:exposure].to_f, 1e-12].max) +
               Vector.elements(sample[:features]).inner_product(beta))
    end
    pearson = active.each_index.sum do |index|
      (active[index][:deaths].to_f - mus[index])**2 / [mus[index], 1e-12].max
    end
    phi = [pearson / [active.length - p, 1].max, 1.0].max
    xtwx = Matrix.zero(p)
    active.each_with_index do |sample, index|
      x = Vector.elements(sample[:features])
      xtwx += x.to_matrix * x.to_matrix.transpose * mus[index]
    end
    covariance = xtwx.inverse * phi
    fit = { beta: beta, covariance: covariance, dispersion: phi }
    break unless robust

    filtered = active.each_with_index.filter_map do |sample, index|
      residual = (sample[:deaths].to_f - mus[index]) / Math.sqrt([phi * mus[index], 1e-12].max)
      sample if residual.abs <= 2.58
    end
    break if filtered.length < [p + 2, 4].max || filtered.length == active.length
    active = filtered
  rescue ExceptionForMatrix::ErrNotRegular, ExceptionForMatrix::ErrDimensionMismatch
    return nil
  end
  fit
end

def weekly_poisson_prediction(fit, features, exposure)
  x = Vector.elements(features)
  mu = Math.exp(Math.log([exposure.to_f, 1e-12].max) + x.inner_product(fit[:beta]))
  coefficient_variance = (x.to_matrix.transpose * fit[:covariance] * x.to_matrix)[0, 0]
  [mu, fit[:dispersion] * mu + mu**2 * [coefficient_variance, 0.0].max]
end

def weekly_reference_years(target_year, baseline)
  case baseline
  when 'fixed_2015_2019' then (2015..2019).to_a
  when 'fixed_2016_2020' then (2016..2020).to_a
  else ((target_year - 5)..(target_year - 1)).to_a
  end
end

def circular_week_distance(left, right)
  [(left - right).abs, 52 - (left - right).abs, 53 - (left - right).abs].min
end

# 日本語: 週次観測値に固定2015–2019年または直前5年の基準線を計算する。
# English: Calculate a fixed 2015-2019 or preceding-five-year baseline for weekly observations.
def weekly_baseline_analysis(rows, method:, baseline:, metric:)
  rows.group_by { |row| row[:series] }.flat_map do |series, series_rows|
    usable = series_rows.select { |row| row[:model_strata] && row[:date] }.sort_by { |row| row[:date] }
    by_age = Hash.new { |hash, age| hash[age] = [] }
    fit_cache = {}
    usable.each do |row|
      date = Date.iso8601(row[:date].to_s)
      row[:model_strata].each do |stratum|
        by_age[stratum[:age]] << stratum.merge(date: date, year: date.cwyear, week: date.cweek)
      end
    end
    usable.filter_map do |row|
      target_date = Date.iso8601(row[:date].to_s)
      target_year = target_date.cwyear
      fixed_end_year = { 'fixed_2015_2019' => 2019, 'fixed_2016_2020' => 2020 }[baseline]
      next if fixed_end_year && target_year <= fixed_end_year
      reference_years = weekly_reference_years(target_year, baseline)
      estimates = row[:model_strata].filter_map do |target|
        history = by_age[target[:age]].select { |item| reference_years.include?(item[:year]) }
        next if history.empty?
        exposure = metric == 'deaths' ? 1.0 : target[:population].to_f * 7.0 / DAYS_PER_YEAR
        if method == 'five_year'
          refs = history.select { |item| item[:week] == target_date.cweek }
          next unless refs.length == reference_years.length
          values = refs.map { |item| item[:deaths].to_f }
          { age: target[:age], weight: target[:weight].to_f, population: target[:population].to_f,
            expected: values.sum / values.length, variance: nil, lower: values.min, upper: values.max }
        else
          samples = if method == 'farrington'
                      history.select { |item| circular_week_distance(item[:week], target_date.cweek) <= 3 }
                    else
                      history.select { |item| (16..25).cover?(item[:week]) || (37..44).cover?(item[:week]) }
                    end
          next if samples.length < 10
          cache_key = [target[:age], method, reference_years,
                       method == 'farrington' ? target_date.cweek : nil]
          cached = fit_cache[cache_key]
          origin = cached ? cached[:origin] : samples.map { |item| item[:date] }.min
          features_for = lambda do |item|
            trend = (item[:date] - origin).to_f / DAYS_PER_YEAR
            if method == 'euromomo'
              angle = 2 * Math::PI * item[:week].to_f / 52.1775
              [1.0, trend, Math.sin(angle), Math.cos(angle)]
            else
              [1.0, trend]
            end
          end
          fit_samples = samples.map do |item|
            item_exposure = metric == 'deaths' ? 1.0 : item[:population].to_f * 7.0 / DAYS_PER_YEAR
            { deaths: item[:deaths], exposure: item_exposure, features: features_for.call(item) }
          end
          fit = cached ? cached[:fit] : fit_weekly_poisson(fit_samples, robust: method == 'farrington')
          next unless fit
          fit_cache[cache_key] ||= { fit: fit, origin: origin }
          target_item = target.merge(date: target_date, week: target_date.cweek)
          expected, variance = weekly_poisson_prediction(fit, features_for.call(target_item), exposure)
          { age: target[:age], weight: target[:weight].to_f, population: target[:population].to_f,
            expected: expected, variance: variance }
        end
      end
      next unless estimates.length == row[:model_strata].length

      if metric == 'deaths'
        expected = estimates.sum { |item| item[:expected] }
        variance = estimates.any? { |item| item[:variance].nil? } ? nil : estimates.sum { |item| item[:variance] }
        lower = estimates.sum { |item| item[:lower].to_f }
        upper = estimates.sum { |item| item[:upper].to_f }
      elsif metric == 'crude_rate'
        population = estimates.sum { |item| item[:population] }
        factor = DAYS_PER_YEAR * 100_000.0 / (7.0 * population)
        expected = estimates.sum { |item| item[:expected] } * factor
        variance = estimates.any? { |item| item[:variance].nil? } ? nil : estimates.sum { |item| item[:variance] } * factor**2
        lower = estimates.sum { |item| item[:lower].to_f } * factor
        upper = estimates.sum { |item| item[:upper].to_f } * factor
      else
        expected = estimates.sum do |item|
          item[:expected] * DAYS_PER_YEAR * 100_000.0 / (7.0 * item[:population]) * item[:weight]
        end
        variance = if estimates.any? { |item| item[:variance].nil? }
                     nil
                   else
                     estimates.sum do |item|
                       factor = DAYS_PER_YEAR * 100_000.0 / (7.0 * item[:population]) * item[:weight]
                       item[:variance] * factor**2
                     end
                   end
        lower = estimates.sum do |item|
          item[:lower].to_f * DAYS_PER_YEAR * 100_000.0 / (7.0 * item[:population]) * item[:weight]
        end
        upper = estimates.sum do |item|
          item[:upper].to_f * DAYS_PER_YEAR * 100_000.0 / (7.0 * item[:population]) * item[:weight]
        end
      end
      if variance
        margin = 1.96 * Math.sqrt([variance, 0.0].max)
        lower = [expected - margin, 0.0].max
        upper = expected + margin
      end
      observed = row[:observed].to_f
      outside_deviation = if observed > upper
                            observed - upper
                          elsif observed < lower
                            observed - lower
                          else
                            0.0
                          end
      { series: series, date: row[:date], expected: expected, lower: lower, upper: upper,
        excess: observed - expected,
        outside_deviation: outside_deviation,
        excess_lower: [observed - upper, 0.0].max,
        excess_upper: [observed - expected, 0.0].max,
        method: method, baseline: baseline }
    end
  end
end

# 日本語: 日本の週次粗死亡率を週死亡数と各月の公式人口から人口日で再計算する。
# English: Recalculate Japanese weekly crude rates from weekly deaths and official monthly population-days.
def replace_japan_weekly_crude_rates(count_rows, rate_rows, population_rows)
  populations = {}
  population_rows.each do |row|
    key = row[:yearmonth].to_s
    current = populations[key]
    rank = row[:type] == 'cfm' ? 2 : 1
    populations[key] = [rank, row] if current.nil? || rank > current.first
  end

  corrected = count_rows.filter_map do |count|
    next unless count[:loc].to_s.casecmp('JPN').zero?
    deaths = count[:age_all]
    next if deaths.nil?

    sunday = Date.iso8601(count[:date].to_s)
    population_days = (sunday - 6..sunday).sum do |date|
      period = format('%04dm%02d', date.year, date.month)
      populations.dig(period, 1, :age_all).to_f
    end
    next unless population_days.positive?

    count.merge(rate: 'crude', age_all: (deaths.to_f * DAYS_PER_YEAR * 100_000 /
                                       population_days).round(2))
  end
  rate_rows.reject { |row| row[:loc].to_s.casecmp('JPN').zero? } + corrected
end

# 日本語: UN月次crude rateを、同じ系列のSTMF週次値が始まる前だけ短期変動表示へ加える。
# English: Add UN monthly crude rate to the detailed view only before the matching STMF weekly series begins.
def prepend_monthly_crude(weekly_rows, monthly_rows, mode, selected_locations, selected_ages)
  weekly_first = weekly_rows.group_by { |row| [row[:loc], row[:dcode]] }
                            .transform_values { |rows| rows.map { |row| Date.iso8601(row[:date].to_s) }.min }
  monthly_rows.filter_map do |row|
    loc = row[:loc].to_s.upcase
    cause = row[:dcode].to_s
    first_week = weekly_first[[loc, cause]]

    date = Date.iso8601(row[:date].to_s)
    next if first_week && Date.new(date.year, date.month, -1) >= first_week

    # 月初ではなく月の中央へ置き、月全体の平均的な率であることをtemporal軸へ反映する。
    # Place the monthly average at mid-month instead of the first day of the month.
    midpoint = date + (Date.new(date.year, date.month, -1).day - 1) / 2
    series_key = mode == 'country' ? loc :
      "#{selected_locations.first}-#{selected_ages.join('+')}-vital-#{cause}"
    { loc: loc, dcode: cause, date: midpoint.iso8601,
      observed: row[:age_all].to_f, series: series_key,
      detail_period: $l == :ja ? '月' : 'Month' }
  end + weekly_rows.map { |row| row.merge(detail_period: $l == :ja ? '週' : 'Week') }
end

# 日本語: 欠測月・欠測週にはnull点を置き、Vegaが存在しない期間を直線で跨がないようにする。
# English: Insert null points at missing months or weeks so Vega does not bridge absent periods.
def insert_detail_gaps(rows)
  rows.group_by { |row| row[:series] }.flat_map do |_series, series_rows|
    sorted = series_rows.sort_by { |row| row[:date].to_s }
    sorted.each_cons(2).flat_map do |left, right|
      left_date = Date.iso8601(left[:date].to_s)
      right_date = Date.iso8601(right[:date].to_s)
      same_period = left[:detail_period] == right[:detail_period]
      max_days = same_period && %w[週 Week].include?(left[:detail_period]) ? 10 : 45
      if (right_date - left_date).to_i > max_days
        [left, left.merge(date: (left_date + 1).iso8601, observed: nil,
                          detail_period: $l == :ja ? '欠測' : 'Missing')]
      else
        [left]
      end
    end.then { |items| sorted.empty? ? [] : items + [sorted.last] }
  end
end

# 日本語: 同じ週・条件に実週次と月次按分週次があれば実週次だけを採用する。
# English: Prefer actual weekly records when reconstructed monthly allocations overlap.
def prefer_actual_weekly(rows, required_fields)
  rank = { 'stmf' => 0, 'stmfrecon' => 1 }
  rows.group_by do |row|
    [row[:loc].to_s.downcase, row[:yearweek], row[:category], row[:rate].to_s,
     row[:dcode], row[:algo].to_s, row[:sex]]
  end.values.map do |candidates|
    complete = candidates.select { |row| required_fields.all? { |field| !row[field.to_sym].nil? } }
    (complete.empty? ? candidates : complete).min_by { |row| rank.fetch(row[:type].to_s, 2) }
  end
end

# 日本語: 年次recordを直接使い、同じ指標では各国公式系列をWPPより優先する。
# English: Read annual records directly and prefer national series over WPP for the same measure.
def annual_record_rows(records, locations, sex, causes, metric, ages, category: $mortyear_category,
                       types: $mortyear_types, population_sex: sex)
  relevant = records.select do |row|
    locations.include?(row[:loc].to_s.upcase) && [sex, population_sex].include?(row[:sex]) &&
      !projected_record?(row)
  end
  # 日本語: 同一年の確定値・速報値・国際推計が共存するときは、この順で選ぶ。
  # English: Prefer confirmed, then provisional national, then international estimates.
  rank = lambda do |row|
    if row[:type].to_s == 'cfm'
      0
    elsif wpp_record?(row)
      2
    else
      1
    end
  end
  rate_name = metric == 'asr' ? 'asr' : ''
  value_groups = relevant.select do |row|
    row[:sex] == sex && mortyear_stat_record?(row, category: category, types: types) && causes.include?(row[:dcode].to_s) &&
      row[:rate].to_s == rate_name
  end.group_by { |row| [row[:loc].to_s.upcase, row[:year].to_i, row[:dcode].to_s] }
  raw_groups = relevant.select do |row|
    row[:sex] == sex && mortyear_stat_record?(row, category: category, types: types) &&
      causes.include?(row[:dcode].to_s) && row[:rate].to_s.empty?
  end.group_by { |row| [row[:loc].to_s.upcase, row[:year].to_i, row[:dcode].to_s] }
  populations = relevant.select { |row| row[:category] == 'pop' && row[:sex] == population_sex }.group_by do |row|
    [row[:loc].to_s.upcase, row[:year].to_i]
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
                   population_candidates.reject { |item| exposure_record?(item) }.min_by(&rank)
                 else
                   population_candidates.reject { |item| wpp_record?(item) }.min_by(&rank) ||
                     population_candidates.select { |item| exposure_record?(item) }.min_by(&rank)
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
      loc: loc, sex: sex, dcode: cause, year: year,
      deaths: deaths.to_f, population: denominator.to_f, observed: observed.to_f,
      unit_scale: metric == 'deaths' ? 1.0 : 100_000.0,
      src_url: (Array(row[:src_url]) + Array(raw&.dig(:src_url)) + Array(population&.dig(:src_url))).compact.uniq
    }
  end.sort_by { |row| [row[:loc], row[:year]] }
end

# 日本語: 年齢階級別の死亡数と人口を組み合わせ、ASR回帰用の入力を作る。
# 同じ階級に各国公式値があればWPPより優先し、人口はWPPではpopulation exposureを使う。
# English: Build ASR regression inputs from age-specific deaths and populations.
# Prefer national values for each stratum and use WPP population exposure as the fallback denominator.
def stratified_asr_rows(records, locations, sex, causes, standard_groups: nil,
                        category: $mortyear_category, types: $mortyear_types, population_sex: sex)
  relevant = records.select do |row|
    locations.include?(row[:loc].to_s.upcase) && [sex, population_sex].include?(row[:sex]) &&
      !projected_record?(row)
  end
  source_rank = lambda do |row, population: false|
    wpp = wpp_record?(row)
    exposure = exposure_record?(row)
    if row[:type].to_s == 'cfm'
      0
    elsif wpp
      population && exposure ? 2 : 3
    else
      1
    end
  end
  death_groups = relevant.select do |row|
    row[:sex] == sex && mortyear_stat_record?(row, category: category, types: types) &&
      row[:rate].to_s.empty? && causes.include?(row[:dcode].to_s)
  end.group_by { |row| [row[:loc].to_s.upcase, row[:year].to_i, row[:dcode].to_s] }
  population_groups = relevant.select { |row| row[:category] == 'pop' && row[:sex] == population_sex }.
                      group_by { |row| [row[:loc].to_s.upcase, row[:year].to_i] }
  standard_groups ||= WHO_WORLD_STANDARD.map { |age, weight| [[age], weight] }
  # 日本語: 資料ごとの最高齢階級（75歳以上・85歳以上・5歳階級）に合わせて値を合算する。
  # English: Aggregate values to each source's oldest age band (75+, 85+, or five-year groups).
  stratum_value = lambda do |row, age|
    value = row[age.to_sym]
    next value unless value.nil?

    lower, parts = case age
                   when 'age_75plus'
                     [%w[age_00_04 age_05_09 age_10_14 age_15_19 age_20_24 age_25_29
                         age_30_34 age_35_39 age_40_44 age_45_49 age_50_54 age_55_59
                         age_60_64 age_65_69 age_70_74],
                      %w[age_75_79 age_80_84 age_85_89 age_90_94 age_95_99 age_100plus]]
                   when 'age_85plus'
                     [%w[age_00_04 age_05_09 age_10_14 age_15_19 age_20_24 age_25_29
                         age_30_34 age_35_39 age_40_44 age_45_49 age_50_54 age_55_59
                         age_60_64 age_65_69 age_70_74 age_75_79 age_80_84],
                      %w[age_85_89 age_90_94 age_95_99 age_100plus]]
                   else
                     next nil
                   end
    values = parts.map { |field| row[field.to_sym] }
    next values.sum(&:to_f) if values.all? { |part| !part.nil? }

    # 日本語: 85歳以上だけは、詳細階級または全年齢との差から既存recordとの互換値を作る。
    # English: For 85-plus only, retain compatibility by using detailed bands or subtraction from all ages.
    next nil if age == 'age_75plus'

    younger = lower.map { |field| row[field.to_sym] }
    row[:age_all] && younger.all? { |part| !part.nil? } ? row[:age_all].to_f - younger.sum(&:to_f) : nil
  end

  death_groups.filter_map do |(loc, year, cause), death_candidates|
    population_candidates = population_groups.fetch([loc, year], [])
    groups_for_year = standard_groups
    covered = lambda do |candidates, groups|
      groups.all? do |ages, _weight|
        candidates.any? { |row| ages.all? { |age| !stratum_value.call(row, age).nil? } }
      end
    end
    [%w[age_85_89 age_90_94 age_95_99 age_100plus],
     %w[age_75_79 age_80_84 age_85plus]].each_with_index do |tail, index|
      break if covered.call(death_candidates, groups_for_year) &&
               covered.call(population_candidates, groups_for_year)

      tail_groups, other_groups = groups_for_year.partition { |ages, _weight| (ages - tail).empty? }
      next if tail_groups.empty?

      aggregate = index.zero? ? 'age_85plus' : 'age_75plus'
      groups_for_year = other_groups + [[[aggregate], tail_groups.sum { |_ages, weight| weight }]]
    end
    group_weight_total = groups_for_year.sum { |_ages, weight| weight }
    strata = groups_for_year.filter_map do |ages, weight|
      death_row = death_candidates.select { |row| ages.all? { |age| !stratum_value.call(row, age).nil? } }.
                  min_by { |row| source_rank.call(row) }
      population_row = population_candidates.select { |row| ages.all? { |age| !stratum_value.call(row, age).nil? } }.
                       min_by { |row| source_rank.call(row, population: true) }
      next unless death_row && population_row
      deaths = ages.sum { |age| stratum_value.call(death_row, age).to_f }
      population = ages.sum { |age| stratum_value.call(population_row, age).to_f }
      next unless population.positive?
      { age: ages.join('+'), deaths: deaths, population: population, weight: weight.to_f / group_weight_total,
        src_url: (Array(death_row[:src_url]) + Array(population_row[:src_url])).compact.uniq }
    end
    next unless strata.length == groups_for_year.length

    {
      loc: loc, sex: sex, dcode: cause, year: year, strata: strata,
      deaths: strata.sum { |item| item[:deaths] }, population: strata.sum { |item| item[:population] },
      observed: strata.sum { |item| item[:deaths] / item[:population] * 100_000.0 * item[:weight] },
      unit_scale: 100_000.0, src_url: strata.flat_map { |item| item[:src_url] }.uniq
    }
  end.sort_by { |row| [row[:loc], row[:year]] }
end

def scenario_cutoffs(years, training_start = 2000)
  return [] if years.empty?

  (2015..(years.max - 2)).select do |cutoff|
    years.count { |year| year.between?(training_start, cutoff) } >= MIN_TRAINING_YEARS
  end
end

# 日本語: 出生分母と乳児・周産期死亡分子を結合し、回帰用の最終系列を作る。
# English: Join birth denominators to infant/perinatal numerators into final regression series.
def birth_rate_rows(records)
  # 日本語: 同じ年の公式値と国際推計が共存するときは公式値を優先する。
  # English: Prefer official values when international estimates coexist for the same year.
  source_rank = lambda do |row|
    case row[:type].to_s
    when 'cfm' then 0
    when 'recon' then 1
    else 2
    end
  end
  choose_by_year = lambda do |category|
    records.select { |row| row[:category] == category }.
      group_by { |row| [row[:loc].to_s.upcase, row[:year].to_i] }.
      transform_values { |rows| rows.min_by(&source_rank) }
  end
  births = choose_by_year.call('birth')
  deliveries = choose_by_year.call('delivery')
  numerators = records.filter_map do |row|
    loc = row[:loc].to_s.upcase
    cause, value = if row[:category] == 'death' && row[:dcode] == 'infant'
                     ['infant', row[:age_all]]
                   elsif row[:category] == 'death' && row[:dcode] == 'allcause' &&
                         row[:rate].to_s.empty? && row[:algo].to_s.empty? && row[:type].to_s == 'cfm'
                     ['infant', row[:age_0]]
                   elsif row[:category] == 'death' && row[:dcode] == 'perm'
                     ['perm', row[:age_all]]
                   end
    next unless cause && value

    key = [loc, row[:year].to_i]
    denominator = cause == 'perm' ? deliveries[key] || births[key] : births[key]
    next unless denominator && denominator[:age_all].to_f.positive?

    population = denominator[:age_all].to_f
    urls = (Array(denominator[:src_url]) + Array(row[:src_url])).compact.uniq
    numerator_rank = [row[:dcode] == 'allcause' ? 1 : 0, source_rank.call(row)]
    { loc: loc, sex: 'both', dcode: cause, year: row[:year].to_i,
      deaths: value.to_f, population: population, observed: value.to_f / population * 1000.0,
      unit_scale: 1000.0, src_url: urls, source_rank: numerator_rank }
  end
  numerators.group_by { |row| [row[:loc], row[:year], row[:dcode]] }.
    values.map do |rows|
      selected = rows.min_by { |row| row[:source_rank] }.dup
      selected.delete(:source_rank)
      selected
    end
end

# 日本語: 学習終了年ごとの計算済み系列を生成し、ブラウザは選択だけを行う。
# English: Precompute every training-cutoff scenario so the browser only switches views.
def compute_analytic_scenarios(rows, series_key, label)
  return [] if rows.empty?

  last_year = rows.map { |row| row[:year] }.max
  candidates = (2015..(last_year - 2)).select do |cutoff|
    rows.count { |row| row[:year].between?($mortyear_training_start, cutoff) } >= MIN_TRAINING_YEARS
  end
  return [] if candidates.empty?

  candidates.flat_map do |cutoff|
    training = rows.select { |row| row[:year].between?($mortyear_training_start, cutoff) }
    fit = poisson_fit(training)
    %w[poisson quasi_poisson].flat_map do |model|
      variance_scale = model == 'quasi_poisson' ? [fit[:dispersion].to_f, 1.0].max : 1.0
      rows.map do |row|
        prediction = poisson_prediction(row, fit, variance_scale)
        {
          series: series_key, label: label, model: model, train_to: cutoff,
          year: row[:year], season: row[:season], observed: row[:observed],
          expected: prediction[:expected], pi_lower: prediction[:lower],
          pi_upper: prediction[:upper], outside_pi: row[:observed] < prediction[:lower] || row[:observed] > prediction[:upper],
          period: row[:year].between?($mortyear_training_start, cutoff) ? 'training' : row[:year] < $mortyear_training_start ? 'historical' : 'prediction',
          dispersion: fit[:dispersion]&.round(4), deaths: row[:deaths].round(2),
          population: row[:population].round, src_url: row[:src_url]
        }
      end
    end
  end
end

# 日本語: Poissonのsimulation版だけを後処理用に生成する。
# English: Generate only the simulated Poisson version for deferred processing.
def compute_simulation_scenarios(rows, series_key, label)
  return [] if rows.empty?

  input_digest = Digest::SHA256.hexdigest(canonical_json(rows.map { |row| canonical_value(row) }))
  last_year = rows.map { |row| row[:year] }.max
  candidates = (2015..(last_year - 2)).select do |cutoff|
    rows.count { |row| row[:year].between?($mortyear_training_start, cutoff) } >= MIN_TRAINING_YEARS
  end
  candidates.flat_map do |cutoff|
    training = rows.select { |row| row[:year].between?($mortyear_training_start, cutoff) }
    fit = poisson_fit(training)
    seed = Digest::SHA256.hexdigest("#{input_digest}:#{cutoff}:#{POISSON_SIMULATIONS}")[0, 8].to_i(16)
    predictions = poisson_simulation_predictions(rows, fit, seed)
    rows.map do |row|
      prediction = predictions.fetch([row[:year], row[:dcode]])
      {
        series: series_key, label: label, model: 'poisson', train_to: cutoff,
        year: row[:year], season: row[:season], observed: row[:observed], expected: prediction[:expected],
        pi_lower: prediction[:lower], pi_upper: prediction[:upper],
        outside_pi: row[:observed] < prediction[:lower] || row[:observed] > prediction[:upper],
        period: row[:year].between?($mortyear_training_start, cutoff) ? 'training' : row[:year] < $mortyear_training_start ? 'historical' : 'prediction',
        dispersion: fit[:dispersion]&.round(4), deaths: row[:deaths].round(2),
        population: row[:population].round, src_url: row[:src_url]
      }
    end
  end
end

# 日本語: 年齢階級別回帰の予測率をWHO標準人口で直接法により合成する。
# English: Combine age-specific regression predictions by direct WHO-standard weighting.
def compute_stratified_asr_analytic_scenarios(rows, series_key, label)
  return [] if rows.empty?

  stratum_ages = rows.flat_map { |row| row.fetch(:strata).map { |item| item.fetch(:age) } }.uniq
  last_year = rows.map { |row| row[:year] }.max
  candidates = (2015..(last_year - 2)).select do |cutoff|
    training = rows.select { |row| row[:year].between?($mortyear_training_start, cutoff) }
    training.length >= MIN_TRAINING_YEARS && stratum_ages.all? do |age|
      training.count { |row| row[:strata].any? { |item| item[:age] == age } } >= MIN_TRAINING_YEARS
    end
  end
  candidates.flat_map do |cutoff|
    training = rows.select { |row| row[:year].between?($mortyear_training_start, cutoff) }
    fits = stratum_ages.to_h do |age|
      age_rows = training.filter_map do |row|
        stratum = row[:strata].find { |item| item[:age] == age }
        next unless stratum
        { year: row[:year], deaths: stratum[:deaths], population: stratum[:population] }
      end
      [age, poisson_fit(age_rows)]
    end
    residual_dfs = stratum_ages.to_h do |age|
      count = training.count { |row| row[:strata].any? { |item| item[:age] == age } }
      [age, [count - 2, 0].max]
    end
    total_df = residual_dfs.values.sum
    dispersion = if total_df.positive?
                   fits.sum { |age, fit| fit[:dispersion].to_f * residual_dfs.fetch(age) } / total_df
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
          year: row[:year], season: row[:season], observed: row[:observed], expected: prediction[:expected],
          pi_lower: prediction[:lower], pi_upper: prediction[:upper],
          outside_pi: row[:observed] < prediction[:lower] || row[:observed] > prediction[:upper],
          period: row[:year].between?($mortyear_training_start, cutoff) ? 'training' : row[:year] < $mortyear_training_start ? 'historical' : 'prediction',
          dispersion: dispersion&.round(4), deaths: row[:deaths].round(2),
          population: row[:population].round, src_url: row[:src_url]
        }
      end
    end
  end
end

# 日本語: 年齢階級別の係数・観測変動をsimulationし、標準人口weightで合成する。
# English: Simulate stratum-specific coefficient and observation uncertainty, then combine by standard weights.
def compute_stratified_asr_simulation_scenarios(rows, series_key, label)
  return [] if rows.empty?

  stratum_ages = rows.flat_map { |row| row.fetch(:strata).map { |item| item.fetch(:age) } }.uniq
  input_digest = Digest::SHA256.hexdigest(canonical_json(rows.map { |row| canonical_value(row) }))
  last_year = rows.map { |row| row[:year] }.max
  candidates = (2015..(last_year - 2)).select do |cutoff|
    training = rows.select { |row| row[:year].between?($mortyear_training_start, cutoff) }
    training.length >= MIN_TRAINING_YEARS && stratum_ages.all? do |age|
      training.count { |row| row[:strata].any? { |item| item[:age] == age } } >= MIN_TRAINING_YEARS
    end
  end
  candidates.flat_map do |cutoff|
    training = rows.select { |row| row[:year].between?($mortyear_training_start, cutoff) }
    fits = stratum_ages.to_h do |age|
      age_rows = training.filter_map do |row|
        stratum = row[:strata].find { |item| item[:age] == age }
        next unless stratum
        { year: row[:year], deaths: stratum[:deaths], population: stratum[:population] }
      end
      [age, poisson_fit(age_rows)]
    end
    seed = Digest::SHA256.hexdigest("#{input_digest}:asr:#{cutoff}:#{POISSON_SIMULATIONS}")[0, 8].to_i(16)
    random = Random.new(seed)
    draws = fits.to_h { |age, fit| [age, coefficient_draws(fit, POISSON_SIMULATIONS, random)] }
    rows.map do |row|
      simulations = Array.new(POISSON_SIMULATIONS, 0.0)
      expected = 0.0
      row[:strata].each do |stratum|
        fit = fits.fetch(stratum[:age])
        x = row[:year] - fit[:center]
        population = stratum[:population]
        weight = stratum[:weight]
        expected += weight * Math.exp(fit[:beta][0] + fit[:beta][1] * x) * 100_000.0
        draws.fetch(stratum[:age]).each_with_index do |beta, index|
          mu = Math.exp(beta[0] + beta[1] * x) * population
          simulations[index] += weight * poisson_random(random, mu) / population * 100_000.0
        end
      end
      simulations.sort!
      lower = simulations[(POISSON_SIMULATIONS * 0.025).floor]
      upper = simulations[(POISSON_SIMULATIONS * 0.975).floor - 1]
      {
        series: series_key, label: label, model: 'poisson', train_to: cutoff,
        year: row[:year], season: row[:season], observed: row[:observed], expected: expected,
        pi_lower: lower, pi_upper: upper, outside_pi: row[:observed] < lower || row[:observed] > upper,
        period: row[:year].between?($mortyear_training_start, cutoff) ? 'training' : row[:year] < $mortyear_training_start ? 'historical' : 'prediction',
        dispersion: nil, deaths: row[:deaths].round(2), population: row[:population].round,
        src_url: row[:src_url]
      }
    end
  end
end

def scenario_display_rows(rows, series_key, label, interval_method, auto_selected)
  rows.map do |row|
    interval_style = if interval_method == 'simulation'
                       'simulation'
                     elsif row[:model] == 'quasi_poisson'
                       'quasi_poisson'
                     else
                       'poisson'
                     end
    interval_label = case interval_style
                     when 'simulation'
                       $l == :ja ? 'シミュレーション' : 'Simulation'
                     when 'quasi_poisson'
                       $l == :ja ? '準ポアソン近似' : 'Quasi-Poisson approximation'
                     else
                       $l == :ja ? 'ポアソン近似' : 'Poisson approximation'
                     end
    row.merge(series: series_key, label: label, interval_method: interval_method,
              interval_style: interval_style, interval_label: interval_label,
              auto_selected: auto_selected)
  end
end

def build_scenarios(rows, series_key, label, use_cache:)
  stratified = rows.first&.key?(:strata)
  analytic_calculator = stratified ? method(:compute_stratified_asr_analytic_scenarios) : method(:compute_analytic_scenarios)
  unless use_cache
    analytic = analytic_calculator.call(rows, series_key, label)
    return scenario_display_rows(analytic, series_key, label, 'analytic', true)
  end

  analytic, simulation = cached_scenarios(rows, stratified ? 'stratified_asr' : 'scalar', analytic_calculator)
  simulation_ready = !simulation.empty?
  analytic_rows = scenario_display_rows(analytic, series_key, label, 'analytic', !simulation_ready)
  # 日本語: 準Poissonにはsimulation版がないため、常に近似結果を自動選択する。
  # English: Quasi-Poisson has no simulated version, so auto mode always selects its analytic result.
  analytic_rows.each { |row| row[:auto_selected] = true if row[:model] == 'quasi_poisson' }
  analytic_rows + scenario_display_rows(simulation, series_key, label, 'simulation', true)
end

# 日本語: 完成cacheを30日・1GB以内に保つ。atimeとmtimeの新しい方を最終参照とする。
# English: Keep completed cache within 30 days and 1 GB, using the newer of atime and mtime.
def clean_mortyear_cache
  paths = Dir.glob(File.join(cache_root, '[0-9a-f][0-9a-f]', '[0-9a-f]' * 64 + '.json.gz')).
          select { |path| File.file?(path) }
  now = Time.now
  paths.each do |path|
    File.unlink(path) if now - [File.atime(path), File.mtime(path)].max > CACHE_MAX_AGE
  end
  paths.select! { |path| File.file?(path) }
  total = paths.sum { |path| File.size(path) }
  paths.sort_by { |path| [File.atime(path), File.mtime(path)].max }.each do |path|
    break if total <= CACHE_MAX_BYTES
    total -= File.size(path)
    File.unlink(path)
  end
end

# 日本語: queueを少数ずつsimulationし、magician所有の完成cacheをatomicに作る。
# English: Simulate a bounded number of queued entries and atomically create magician-owned cache files.
def process_mortyear_cache_jobs(limit)
  queue_paths = Dir.glob(File.join(cache_root, 'queue', '[0-9a-f][0-9a-f]', '[0-9a-f]' * 64 + '.json.gz')).
                sort_by { |path| File.mtime(path) }
  queue_paths = queue_paths.first([limit, 0].max) unless limit == :all
  queue_paths.each do |queue_path|
    digest = File.basename(queue_path, '.json.gz')
    document = gzip_read(queue_path)
    completed_entries = Array(document[:entries]).map do |entry|
      key = entry.fetch(:key)
      raise "Queue key does not match file name: #{queue_path}" unless cache_digest(key) == digest

      calculator = case key.fetch(:calculator_type)
                   when 'scalar' then method(:compute_simulation_scenarios)
                   when 'stratified_asr' then method(:compute_stratified_asr_simulation_scenarios)
                   else raise "Unknown calculator_type: #{key[:calculator_type]}"
                   end
      entry.merge(
        simulation: calculator.call(key.fetch(:input), '', ''),
        simulated_at: Time.now.utc.iso8601
      )
    end
    completed_path = cache_file(digest)
    FileUtils.mkdir_p(File.dirname(completed_path), mode: 0o755)
    existing = File.file?(completed_path) ? Array(gzip_read(completed_path)[:entries]) : []
    completed_entries.each do |entry|
      existing.reject! { |item| canonical_value(item[:key]) == canonical_value(entry[:key]) }
      existing << entry
    end
    gzip_write(completed_path, { schema: CACHE_SCHEMA, entries: existing })
    File.unlink(queue_path)
  rescue StandardError => error
    warn "mortyear cache job failed: #{queue_path}: #{error.class}: #{error.message}"
  end
  clean_mortyear_cache if Time.now.hour == 3 && Time.now.min.zero?
end

# 日本語: 通常読込とは別に全cacheのgzip・構造・file名hashを検査する。
# English: Separately verify gzip, structure, and filename hashes for every cache file.
def verify_mortyear_cache
  paths = Dir.glob(File.join(cache_root, '{,queue/}', '[0-9a-f][0-9a-f]', '*.json.gz'))
  errors = []
  entries = 0
  paths.each do |path|
    digest = File.basename(path, '.json.gz')
    begin
      document = gzip_read(path)
      raise 'schema mismatch' unless document[:schema] == CACHE_SCHEMA
      raise 'entries is not an array' unless document[:entries].is_a?(Array)
      document[:entries].each do |entry|
        entries += 1
        raise 'missing key' unless entry[:key].is_a?(Hash)
        raise 'filename hash mismatch' unless cache_digest(entry[:key]) == digest
        raise 'analytic is not an array' unless entry[:analytic].is_a?(Array)
        unless entry[:simulation].nil? || entry[:simulation].is_a?(Array)
          raise 'simulation is neither null nor an array'
        end
      end
    rescue StandardError => error
      errors << "#{path}: #{error.class}: #{error.message}"
    end
  end
  puts JSON.pretty_generate(files: paths.length, entries: entries, errors: errors)
  errors.empty?
end

def mortyear_catalog_file(index = nil)
  # 正式aliasと並行検査用の物理indexでcatalogを分離する。
  # Keep the formal alias catalog separate from physical-index test catalogs.
  filename = index && index.to_s != 'mstats' ? "catalog-#{index.to_s.gsub(/[^a-zA-Z0-9.-]/, '_')}.json" : 'catalog.json'
  File.join(cache_root, filename)
end

def load_mortyear_catalog(index)
  document = JSON.parse(File.read(mortyear_catalog_file(index)), symbolize_names: true)
  return unless document[:schema] == 1 && document[:index].to_s == index.to_s

  document.fetch(:locations).to_h { |code, entry| [code.to_s.upcase, entry] }
rescue Errno::ENOENT, JSON::ParserError, KeyError
  nil
end

def catalog_combination_available?(entry, metric, cause, sex, ages, period = 'calendar')
  series = entry.fetch(:series).select do |item|
    item_period = item[:period] || 'calendar'
    item[:metric] == metric && item[:cause] == cause && item[:sex] == sex &&
      item_period == period && ages.include?(item[:age])
  end
  return false unless ages.all? { |age| series.any? { |item| item[:age] == age } }

  years = ages.map do |age|
    catalog_years(series.find { |item| item[:age] == age }.fetch(:years))
  end.reduce { |common, values| common & values }
  scenario_cutoffs(years || [], period == 'calendar' ? 2000 : 1999).any?
end

def catalog_years(span)
  return span if span.is_a?(Array)
  return [] unless span && span[:from] && span[:to]

  (span[:from]..span[:to]).to_a - Array(span[:missing])
end

def catalog_year_span(years)
  return { from: nil, to: nil, missing: [] } if years.empty?

  { from: years.min, to: years.max, missing: (years.min..years.max).to_a - years }
end

def catalog_available_causes(catalog, locations, metric, sex, ages, period = 'calendar')
  candidates = locations.flat_map do |loc|
    catalog.fetch(loc).fetch(:series).select do |item|
      item_period = item[:period] || 'calendar'
      item[:metric] == metric && item[:sex] == sex && item_period == period
    end.
      map { |item| item[:cause] }
  end.uniq
  candidates.select do |cause|
    locations.all? { |loc| catalog_combination_available?(catalog.fetch(loc), metric, cause, sex, ages, period) }
  end.sort
end

def catalog_series(metric, cause, sex, age, rows, period: 'calendar')
  years = rows.map { |row| row[:year].to_i }.uniq.sort
  cutoffs = scenario_cutoffs(years, period == 'calendar' ? 2000 : 1999)
  {
    period: period, metric: metric, cause: cause, sex: sex, age: age, years: catalog_year_span(years),
    train_to: catalog_year_span(cutoffs), displayable: !cutoffs.empty?
  }
end

def catalog_location_series(records, loc)
  relevant = records.reject { |row| projected_record?(row) }
  rank = ->(row) { wpp_record?(row) ? 1 : 0 }
  deaths = relevant.select { |row| row[:category] == 'death' && row[:rate].to_s.empty? }.
           group_by { |row| [row[:sex].to_s, row[:dcode].to_s, row[:year].to_i] }
  populations = relevant.select { |row| row[:category] == 'pop' }.
                group_by { |row| [row[:sex].to_s, row[:year].to_i] }
  rows_by_series = Hash.new { |hash, key| hash[key] = [] }
  deaths.each do |(sex, cause, year), candidates|
    next if sex.empty? || cause.empty?

    population_candidates = populations.fetch([sex, year], [])
    AGES.each_key do |age|
      death = candidates.select { |row| !row[age.to_sym].nil? }.min_by(&rank)
      next unless death
      rows_by_series[['deaths', cause, sex, age]] << { year: year }
      population = if age == 'age_all'
                     population_candidates.reject { |row| exposure_record?(row) }.
                     select { |row| !row[age.to_sym].nil? }.min_by(&rank)
                   else
                     population_candidates.reject { |row| wpp_record?(row) }.
                     select { |row| !row[age.to_sym].nil? }.min_by(&rank) ||
                       population_candidates.select { |row| exposure_record?(row) && !row[age.to_sym].nil? }.
                       min_by(&rank)
                   end
      if population && population[age.to_sym].to_f.positive?
        rows_by_series[['crude_rate', cause, sex, age]] << { year: year }
      end
    end
    strata_complete = WHO_WORLD_STANDARD.keys.all? do |age|
      death = candidates.select { |row| !row[age.to_sym].nil? }.min_by(&rank)
      population = population_candidates.select do |row|
        (!wpp_record?(row) || exposure_record?(row)) &&
          !row[age.to_sym].nil? && row[age.to_sym].to_f.positive?
      end.min_by(&rank)
      death && population
    end
    rows_by_series[['asr', cause, sex, 'age_all']] << { year: year } if strata_complete
  end
  birth_rate_rows(records).each do |row|
    rows_by_series[['birth_rate', row[:dcode], 'both', 'age_all']] << { year: row[:year] }
  end
  rows_by_series.map do |(metric, cause, sex, age), rows|
    catalog_series(metric, cause, sex, age, rows)
  end
end

# 日本語: 国ごとに最終表示系列を作り、menu判定用catalogをatomicに更新する。
# English: Build final display series per location and atomically update the menu catalog.
def load_mortyear_catalog_csv(paths)
  fields = (%w[loc area areaj yearweek category rate dcode algo type src_url date year week sex] +
            AGES.keys + STMF_AGES).uniq
  rows = []
  paths.each do |path|
    CSV.foreach(path, headers: true) do |source|
      weekly = !source['yearweek'].to_s.empty?
      next if !source['yearmonth'].to_s.empty?
      next if weekly && !(source['category'] == 'death' && source['dcode'] == 'allcause' && ['', 'crude'].include?(source['rate'].to_s))
      next if !weekly && !%w[death pop birth delivery].include?(source['category'])
      next if !weekly && source['category'] == 'death' && !source['rate'].to_s.empty?

      row = fields.to_h do |field|
        value = source[field]
        [field.to_sym, value.nil? || value.empty? ? nil : value]
      end
      row[:year] = row[:year].to_i if row[:year]
      row[:week] = row[:week].to_i if row[:week]
      rows << row
    end
  end
  rows
end

def rebuild_mortyear_catalog(index, fixture: nil)
  base = available_annual_catalog(index: index, fixture: fixture)
  weekly_rates = available_location_rates(index: index, fixture: fixture&.select { |row| row[:yearweek] })
  fixture_by_loc = fixture&.group_by { |row| row[:loc].to_s.upcase }
  stmf_weights = stmf_standard_weights(WHO_WORLD_STANDARD.map { |age, weight| [[age], weight] })
  {
    'ENG' => { area: 'England and Wales', areaj: 'イングランド・ウェールズ（英国）' },
    'SCO' => { area: 'Scotland', areaj: 'スコットランド（英国）' }
  }.each do |code, entry|
    base[code] ||= entry if weekly_rates.key?(code)
  end
  fields = %w[loc area areaj category rate dcode algo type year sex src_url] + AGES.keys
  locations = {}
  total = base.length
  next_report = 10
  base.keys.sort.each_with_index do |loc, position|
    records = if fixture_by_loc
                fixture_by_loc.fetch(loc, []).reject { |row| row[:yearweek] }
              else
                elastic_search(
                  index: index, size: 100_000,
                  filter: [{ 'term' => { 'loc' => loc.downcase } }],
                  must_not: [{ 'exists' => { 'field' => 'yearmonth' } }, { 'exists' => { 'field' => 'yearweek' } }],
                  source: fields
                )
              end
    series = catalog_location_series(records, loc)
    if weekly_rates.fetch(loc, []).include?('') && weekly_rates.fetch(loc, []).include?('crude')
      weekly = if fixture_by_loc
                 fixture_by_loc.fetch(loc, []).select { |row| row[:yearweek] }
               else
                 elastic_search(
                   index: index, size: 100_000,
                   filter: [{ 'term' => { 'loc' => loc.downcase } },
                            { 'term' => { 'category' => 'death' } }, { 'term' => { 'dcode' => 'allcause' } },
                            { 'exists' => { 'field' => 'yearweek' } }],
                   source: %w[loc yearweek category rate dcode date year week sex src_url] + STMF_AGES
                 )
               end
      weekly.group_by { |row| row[:sex].to_s }.each do |sex, sex_rows|
        counts = sex_rows.select { |row| row[:rate].to_s.empty? }
        rates = sex_rows.select { |row| row[:rate].to_s == 'crude' }
        { 'flu27' => 27, 'flu36' => 36 }.each do |period, start_week|
          STMF_AGES.each do |age|
            rows = annualize_influenza_year(counts, rates, [age], start_week, 'crude_rate')
            next if rows.empty?
            %w[deaths crude_rate].each do |metric|
              series << catalog_series(metric, 'allcause', sex, age, rows, period: period)
            end
          end
          asr_rows = annualize_influenza_asr(counts, rates, start_week, ['age_all'], stmf_weights)
          series << catalog_series('asr', 'allcause', sex, 'age_all', asr_rows, period: period) unless asr_rows.empty?
        end
      end
    end
    locations[loc] = { area: base.dig(loc, :area), areaj: base.dig(loc, :areaj), series: series }
    percent = ((position + 1) * 100 / total)
    if percent >= next_report
      warn "mortyear catalog: #{next_report}% (#{position + 1}/#{total})"
      next_report += 10
    end
  end
  document = {
    schema: 1, generated_at: Time.now.utc.iso8601, index: index,
    rules: { first_training_year: { calendar: 2000, flu27: 1999, flu36: 1999 }, first_cutoff: 2015,
             min_training_years: MIN_TRAINING_YEARS, min_evaluation_years: 2 },
    locations: locations
  }
  path = mortyear_catalog_file(index)
  FileUtils.mkdir_p(File.dirname(path), mode: 0o755)
  tmp = "#{path}.#{Process.pid}.tmp"
  File.write(tmp, JSON.generate(document) + "\n")
  File.chmod(0o644, tmp)
  JSON.parse(File.read(tmp))
  File.rename(tmp, path)
  summary = METRICS.keys.to_h do |metric|
    [metric, locations.count { |_loc, entry| entry[:series].any? { |item| item[:metric] == metric && item[:displayable] } }]
  end
  puts JSON.pretty_generate(file: path, locations: locations.length,
                            series: locations.values.sum { |entry| entry[:series].length },
                            displayable_locations: summary)
ensure
  File.unlink(tmp) if defined?(tmp) && tmp && File.file?(tmp)
end

if opts[:process_cache_jobs]
  process_mortyear_cache_jobs(opts[:process_cache_jobs])
  exit
end

exit(verify_mortyear_cache ? 0 : 1) if opts[:verify_cache]

if opts[:rebuild_catalog]
  fixture = opts[:catalog_csv].empty? ? nil : load_mortyear_catalog_csv(opts[:catalog_csv])
  rebuild_mortyear_catalog(opts[:index], fixture: fixture)
  exit
end

fixture_data = if opts[:fixture]
                 parsed = JSON.parse(File.read(opts[:fixture]), symbolize_names: true)
                 parsed = parsed.dig(:hits, :hits).map { |hit| hit.fetch(:_source) } if parsed.is_a?(Hash) && parsed[:hits]
                 parsed
               end
menu_catalog = fixture_data ? nil : load_mortyear_catalog(opts[:index])
vital_menu_catalog = menu_catalog
annual_catalog = menu_catalog || available_annual_catalog(index: opts[:index], fixture: fixture_data)
if selected_dataset != 'vital'
  menu_catalog = nil
  annual_catalog.select! { |code, _entry| code == 'JPN' }
end
location_rates = available_location_rates(index: opts[:index], fixture: fixture_data)
weekly_codes = location_rates.select { |_code, rates| rates.include?('') && rates.include?('crude') }.keys
if selected_period != 'calendar'
  if menu_catalog
    period_codes = weekly_codes.select do |code|
      menu_catalog.fetch(code, {}).fetch(:series, []).any? do |item|
        (selected_period == 'weekly' || item[:period] == selected_period) &&
          item[:metric] == selected_metric && item[:displayable]
      end
    end
    weekly_codes = period_codes
  end
end
$annual_catalog = annual_catalog
metric_locations = annual_catalog.select do |code, catalog|
  selected_period == 'calendar' ? annual_metric_available?(code, catalog, selected_metric) :
    weekly_codes.include?(code) && %w[deaths crude_rate asr].include?(selected_metric)
end.keys.sort
metric_locations = ['JPN'] if selected_dataset != 'vital' && annual_catalog.key?('JPN')
metric_locations = ['JPN'].select { |code| annual_catalog.key?(code) } if selected_metric == 'std_deaths'
available_locations = annual_catalog.keys.sort
selected_locations = requested_locations.select { |code| available_locations.include?(code) }
selected_locations &= metric_locations
default_locations = selected_period == 'calendar' ? %w[JPN GBR SWE USA] : %w[JPN ENG SWE USA]
selected_locations = default_locations.select { |code| metric_locations.include?(code) } if selected_locations.empty?
selected_locations = [metric_locations.first].compact if selected_locations.empty?
requested_birth_causes = requested_causes.select { |cause| SPECIAL_CAUSES.key?(cause) }
if selected_metric == 'birth_rate' && requested_birth_causes.any?
  selected_locations.select! do |loc|
    requested_birth_causes.all? { |cause| birth_cause_available?(loc, annual_catalog.fetch(loc), cause) }
  end
  if selected_locations.empty?
    selected_locations = metric_locations.select do |loc|
      requested_birth_causes.all? { |cause| birth_cause_available?(loc, annual_catalog.fetch(loc), cause) }
    end.first(1)
  end
end
selected_locations = [selected_locations.first] if mode == 'series'
mixed_japan_series = mode == 'series' && selected_period == 'calendar' &&
                     selected_locations == ['JPN'] && selected_metric != 'birth_rate'
# 日本語: 日本2015年モデル人口は95歳以上が一括なので、片方だけの選択を一組へそろえる。
# English: The Japan 2015 model has one 95-plus weight, so keep 95-99 and 100+ together.
if selected_metric == 'asr' && selected_locations == ['JPN'] &&
   (selected_ages & %w[age_95_99 age_100plus]).length == 1
  selected_ages |= %w[age_95_99 age_100plus]
  selected_ages.sort_by! { |age| STANDARD_AGES.index(age) || -1 }
end
catalog_metric = selected_metric == 'asr' && selected_ages != ['age_all'] ? 'crude_rate' : selected_metric
catalog_ages = if selected_metric == 'asr' && selected_locations == ['JPN'] &&
                  (selected_ages & %w[age_95_99 age_100plus]).any?
                 selected_ages - ['age_100plus']
               else
                 selected_ages
               end
available_causes = if mixed_japan_series
                     vital = if menu_catalog
                               catalog_available_causes(menu_catalog, selected_locations, catalog_metric,
                                                        selected_sex, catalog_ages)
                             else
                               available_annual_dcodes(index: opts[:index], fixture: fixture_data,
                                                      locations: selected_locations, metric: selected_metric)
                             end
                     vital.select { |code| code == 'allcause' || code.match?(/\A\d{5}\z/) } + CANCER_SITES.keys
                   elsif selected_period != 'calendar' && selected_metric == 'asr'
                     ['allcause']
                   elsif selected_period != 'calendar'
                     available_dcodes(index: opts[:index], fixture: fixture_data,
                                           locations: selected_locations, metric: selected_metric)
                   elsif selected_metric == 'std_deaths'
                     available_dcodes(index: opts[:index], fixture: fixture_data,
                                           locations: selected_locations, metric: selected_metric)
                   elsif selected_dataset != 'vital'
                     available_annual_dcodes(index: opts[:index], fixture: fixture_data,
                                                  locations: selected_locations, metric: selected_metric)
                   elsif menu_catalog
                     catalog_available_causes(menu_catalog, selected_locations, catalog_metric,
                                              selected_sex, catalog_ages)
                   else
                     available_annual_dcodes(index: opts[:index], fixture: fixture_data,
                                                  locations: selected_locations, metric: selected_metric)
                   end
selected_causes = requested_causes.select { |code| available_causes.include?(code) }
default_dcode = selected_dataset == 'vital' ? 'allcause' : 'c53'
selected_causes = [default_dcode].select { |code| available_causes.include?(code) } if selected_causes.empty?
selected_causes = [available_causes.first].compact if selected_causes.empty?
selected_causes = [selected_causes.first] if mode == 'country'
if selected_dataset != 'vital' && !mixed_japan_series
  CANCER_SITE_CHILDREN.each do |parent, children|
    selected_causes.delete(parent) if selected_causes.include?(parent) && (selected_causes & children).any?
  end
end
selected_vital_causes = selected_causes.reject { |code| CANCER_SITES.key?(code) }
selected_cancer_causes = selected_causes.select { |code| CANCER_SITES.key?(code) }
if selected_metric == 'birth_rate'
  available_causes = SPECIAL_CAUSES.keys.select do |cause|
    selected_locations.all? { |loc| birth_cause_available?(loc, annual_catalog.fetch(loc), cause) }
  end
  selected_causes = requested_causes.select { |code| available_causes.include?(code) }
  selected_causes = mode == 'series' ? SPECIAL_CAUSES.keys : ['infant'] if selected_causes.empty?
  selected_causes = [selected_causes.first] if mode == 'country'
end
available_menu_ages = AGES.keys
if menu_catalog && !mixed_japan_series && selected_period == 'calendar' &&
   selected_metric != 'birth_rate' && selected_metric != 'std_deaths'
  available_menu_ages = AGES.keys.select do |age|
    age_metric = selected_metric == 'asr' && age != 'age_all' ? 'crude_rate' : selected_metric
    catalog_age = selected_metric == 'asr' && selected_locations == ['JPN'] &&
                  age == 'age_100plus' ? 'age_95_99' : age
    selected_locations.all? do |loc|
      selected_causes.all? do |cause|
        catalog_combination_available?(menu_catalog.fetch(loc), age_metric, cause, selected_sex, [catalog_age])
      end
    end
  end
  selected_ages &= available_menu_ages
  selected_ages = ['age_all'].select { |age| available_menu_ages.include?(age) } if selected_ages.empty?
  selected_ages = [available_menu_ages.first].compact if selected_ages.empty?
end
# 日本語: 複数国比較では死因選択を使わず、共通の全死因へ固定する。
# English: Multi-country comparisons use the common all-cause series without a cause selector.
if mode == 'country' && selected_locations.length > 1 && available_causes.include?('allcause')
  selected_causes = ['allcause']
end

locations_for_query = selected_locations.map(&:downcase)
ages_for_query = selected_ages
annual_source_fields = %w[id loc area areaj category rate dcode algo type date year sex src_url] +
                       (AGES.keys + STMF_AGES).uniq
annual_records_all = if selected_period != 'calendar'
                       []
                     elsif opts[:fixture]
                       fixture_data.reject { |row| row[:yearmonth] || row[:yearweek] }
                     elsif selected_metric == 'std_deaths'
                       []
                     else
                       elastic_search(
                         index: opts[:index], size: 100_000,
                         filter: [{ 'terms' => { 'loc' => locations_for_query } },
                                  { 'terms' => { 'sex' => if mixed_japan_series && selected_sex == 'both'
                                                           %w[both female male]
                                                         else
                                                           [selected_sex]
                                                         end } }],
                         must_not: [{ 'exists' => { 'field' => 'yearmonth' } },
                                    { 'exists' => { 'field' => 'yearweek' } }],
                         source: annual_source_fields
                       )
                     end
source_fields = %w[id loc yearweek category rate dcode algo type date year week sex src_url] + (AGES.keys + STMF_AGES).uniq
# 日本語: 暦年の英国年次系列はGBR、STMFはENGなので、詳細表示の検索時だけ対応付ける。
# English: Annual UK records use GBR while STMF uses ENG, so map them only for detailed-view queries.
weekly_locations_for_query = locations_for_query.flat_map { |code| code == 'gbr' ? %w[gbr eng] : [code] }.uniq
common_filters = [
  { 'term' => { 'category' => 'death' } },
  { 'terms' => { 'loc' => weekly_locations_for_query } },
  { 'term' => { 'sex' => selected_sex } },
  { 'terms' => { 'dcode' => selected_causes.reject { |code| SPECIAL_CAUSES.key?(code) }.yield_self { |codes| codes.empty? ? ['__none__'] : codes } } },
  { 'exists' => { 'field' => 'yearweek' } }
]

# 日本語: 暦年の詳細表示は、ASRでは全死因、粗死亡率では全年齢の通常死因系列を対象にする。
# English: In calendar mode, detail all-cause ASR and all-age crude rates for ordinary causes.
detailed_calendar_rate = selected_period == 'calendar' &&
                         ((selected_metric == 'asr' && selected_ages == ['age_all'] &&
                           selected_causes == ['allcause']) ||
                          (selected_metric == 'crude_rate' && selected_ages == ['age_all'] &&
                           selected_causes.none? { |cause| SPECIAL_CAUSES.key?(cause) }))
if selected_period == 'calendar' && !detailed_calendar_rate
  count_rows = []
  rate_rows = []
elsif opts[:fixture]
  fixture = fixture_data.dup
  fixture.select! do |row|
    weekly_locations_for_query.include?(row[:loc].to_s.downcase) &&
      row[:category] == 'death' && selected_causes.include?(row[:dcode]) &&
      row[:sex] == selected_sex && row[:yearweek]
  end
  count_rows = fixture.select { |row| row[:rate].to_s.empty? }
  rate_rows = fixture.select { |row| row[:rate] == 'crude' }
else
  count_rate_filter = {
    'bool' => {
      'should' => [
        { 'term' => { 'rate' => '' } },
        { 'bool' => { 'must_not' => [{ 'exists' => { 'field' => 'rate' } }] } }
      ],
      'minimum_should_match' => 1
    }
  }
  count_rows = elastic_search(
    index: opts[:index], size: 1_000_000,
    filter: common_filters + [count_rate_filter],
    source: source_fields, debug: opts[:debug] ? 'SHOWONLY_QUERY' : nil
  )
  rate_rows = opts[:debug] ? [] : elastic_search(
    index: opts[:index], size: 1_000_000,
    filter: common_filters + [{ 'term' => { 'rate' => 'crude' } }],
    source: source_fields
  )
end

# 日本語: 週次表示では、死亡数に新型コロナ死亡、超過死亡の推移にワクチン全体接種を重ねる。
# English: In weekly views, overlay COVID-19 deaths on death counts and all vaccine doses on the excess trend.
overlay_source = %w[loc yearweek category dcode type date year week sex age_all]
covid_overlay_eligible = selected_period == 'weekly' && %w[deaths crude_rate].include?(selected_metric) &&
                           selected_ages == ['age_all'] && selected_sex == 'both'
overlay_rows = if selected_period != 'weekly'
                 []
               elsif opts[:fixture]
                 fixture_data.select do |row|
                   weekly_locations_for_query.include?(row[:loc].to_s.downcase) && row[:yearweek] &&
                     row[:sex] == 'both' &&
                     ((covid_overlay_eligible && row[:category] == 'death' &&
                       ((row[:loc].to_s.casecmp('jpn').zero? && row[:dcode] == '22200' && row[:type] == 'stmf') ||
                        (!row[:loc].to_s.casecmp('jpn').zero? && row[:dcode] == 'u07' && row[:type] == 'owid'))) ||
                      (row[:category] == 'vaxx' && row[:dcode] == 'doseall'))
                 end
               else
                 covid = if covid_overlay_eligible
                           japan = if weekly_locations_for_query.include?('jpn')
                                     elastic_search(
                                       index: opts[:index], size: 100_000,
                                       filter: [{ 'term' => { 'loc' => 'jpn' } },
                                                { 'term' => { 'category' => 'death' } },
                                                { 'term' => { 'dcode' => '22200' } },
                                                { 'term' => { 'type' => 'stmf' } },
                                                { 'term' => { 'sex' => 'both' } },
                                                { 'exists' => { 'field' => 'yearweek' } }],
                                       source: overlay_source
                                     )
                                   else
                                     []
                                   end
                           other_locations = weekly_locations_for_query - ['jpn']
                           international = if other_locations.empty?
                                             []
                                           else
                                             elastic_search(
                                               index: opts[:index], size: 100_000,
                                               filter: [{ 'terms' => { 'loc' => other_locations } },
                                                        { 'term' => { 'category' => 'death' } },
                                                        { 'term' => { 'dcode' => 'u07' } },
                                                        { 'term' => { 'type' => 'owid' } },
                                                        { 'term' => { 'sex' => 'both' } },
                                                        { 'exists' => { 'field' => 'yearweek' } }],
                                               source: overlay_source
                                             )
                                           end
                           japan + international
                         else
                           []
                         end
                 vaccinations = elastic_search(
                   index: opts[:index], size: 100_000,
                   filter: [{ 'terms' => { 'loc' => weekly_locations_for_query } },
                            { 'term' => { 'category' => 'vaxx' } }, { 'term' => { 'dcode' => 'doseall' } },
                            { 'term' => { 'sex' => 'both' } }, { 'exists' => { 'field' => 'yearweek' } }],
                   source: overlay_source
                 )
                 covid + vaccinations
               end
overlay_values = overlay_rows.filter_map do |row|
  next if row[:age_all].nil?

  { loc: row[:loc].to_s.downcase, date: row[:date], value: row[:age_all].to_f,
    overlay: row[:category] == 'vaxx' ? 'vaxx' : 'covid' }
end

weekly_required_ages = if selected_metric == 'asr' && selected_ages.include?('age_all')
                         STMF_ASR_AGES
                       else
                         selected_ages
                       end
count_rows = prefer_actual_weekly(count_rows, weekly_required_ages)
rate_rows = prefer_actual_weekly(rate_rows, weekly_required_ages)

# 日本語: 日本の全年齢実週次死亡数には率がないため、月次人口から週次粗死亡率を再計算する。
# English: Recalculate crude rates for Japan's actual all-age weekly counts from monthly populations.
if selected_metric == 'crude_rate' && selected_ages == ['age_all'] &&
   selected_sex == 'both' && weekly_locations_for_query.include?('jpn')
  population_rows = if opts[:fixture]
                      fixture_data.select do |row|
                        row[:loc].to_s.casecmp('jpn').zero? && row[:yearmonth] &&
                          row[:category] == 'pop' && row[:age_all]
                      end
                    else
                      elastic_search(
                        index: opts[:index], size: 100_000,
                        filter: [{ 'term' => { 'loc' => 'jpn' } },
                                 { 'term' => { 'category' => 'pop' } },
                                 { 'exists' => { 'field' => 'yearmonth' } },
                                 { 'exists' => { 'field' => 'age_all' } }],
                        source: %w[loc yearmonth category type age_all]
                      )
                    end
  rate_rows = replace_japan_weekly_crude_rates(count_rows, rate_rows, population_rows)
end

if selected_period == 'calendar'
  count_rows.each { |row| row[:loc] = 'gbr' if row[:loc].to_s.casecmp('eng').zero? }
  rate_rows.each { |row| row[:loc] = 'gbr' if row[:loc].to_s.casecmp('eng').zero? }
end

monthly_supplement_enabled = selected_metric == 'crude_rate' &&
                             selected_ages == ['age_all'] && selected_sex == 'both' &&
                             selected_causes == ['allcause']
sex_labels = {
  'male' => { ja: '男性', en: 'Male' },
  'female' => { ja: '女性', en: 'Female' }
}.freeze
incidence_metric_names = {
  'deaths' => { ja: '罹患数', en: 'Incidence count' },
  'crude_rate' => { ja: '粗罹患率', en: 'Crude incidence rate' },
  'asr' => { ja: '年齢調整罹患率', en: 'Age-standardized incidence rate' }
}.freeze
selected_metric_names = selected_dataset == 'cancer-incidence' && !mixed_japan_series ?
                          incidence_metric_names : METRICS
age_selection_label = if selected_period != 'calendar'
                        if selected_ages.include?('age_all')
                          $l == :ja ? '全年齢' : 'All ages'
                        else
                          selected_ages.map { |age| STMF_AGE_LABELS.fetch(age) }.join(', ')
                        end
                      elsif selected_ages.include?('age_all')
                        $l == :ja ? '全年齢' : 'All ages'
                      elsif selected_ages == ['age_0']
                        $l == :ja ? '0歳' : 'Age 0'
                      else
                        indexes = selected_ages.filter_map { |age| STANDARD_AGES.index(age) }.sort
                        if indexes.any? && indexes.each_cons(2).all? { |left, right| right == left + 1 }
                          lower = format('%02d', indexes.first * 5)
                          if indexes.last == STANDARD_AGES.length - 1
                            "#{lower}+"
                          else
                            "#{lower}-#{format('%02d', indexes.last * 5 + 4)}"
                          end
                        else
                          selected_ages.map { |age| AGES.fetch(age).fetch($l) }.join(', ')
                        end
                      end
jpn_2015_asr = selected_metric == 'asr' && selected_locations == ['JPN'] && selected_vital_causes.any?
vital_asr_standard_groups = selected_standard_groups(JPN_2015_STANDARD_GROUPS, selected_ages)
cancer_asr_standard_groups = selected_standard_groups(
  WHO_WORLD_STANDARD.map { |age, weight| [[age], weight] }, selected_ages
)
asr_stmf_weights = stmf_standard_weights(JPN_2015_STANDARD_GROUPS)
panel_label = lambda do |loc, cause, dataset|
  cause_name = if dataset == 'vital'
                 SPECIAL_CAUSES.fetch(cause, Death_codes.fetch(cause, { ja: cause, en: cause })).fetch($l)
               else
                 CANCER_SITES.fetch(cause, { ja: cause, en: cause }).fetch($l)
               end
  metric_names = dataset == 'cancer-incidence' ? incidence_metric_names : METRICS
  panel_metric_label = metric_names.fetch(selected_metric).fetch($l)
  parts = if selected_metric == 'birth_rate'
            [location_names(loc).fetch($l)]
          else
            [location_names(loc).fetch($l), panel_metric_label, age_selection_label]
          end
  parts << sex_labels.fetch(selected_sex).fetch($l) unless selected_sex == 'both'
  parts << cause_name
  unit = if selected_metric == 'birth_rate'
           if cause == 'infant'
             $l == :ja ? '（出生1,000人当たり）' : '(per 1,000 births)'
           elsif loc == 'JPN'
             $l == :ja ? '（出産1,000件当たり）' : '(per 1,000 deliveries)'
           else
             $l == :ja ? '（出生1,000人当たり）' : '(per 1,000 births)'
           end
         elsif selected_metric == 'asr' && dataset == 'vital' && selected_locations == ['JPN']
           $l == :ja ? '（人口10万人あたり、2015年人口モデル）' : '(per 100,000 pop, Japan 2015 population model)'
         elsif %w[crude_rate asr].include?(selected_metric)
           $l == :ja ? '（人口10万人当たり）' : '(per 100,000 pop)'
         elsif %w[deaths std_deaths].include?(selected_metric)
           if dataset == 'cancer-incidence'
             $l == :ja ? '（件）' : '(cases)'
           else
             $l == :ja ? '（人）' : '(persons)'
           end
         end
  label = [parts.join(' '), unit].compact.join($l == :ja ? '' : ' ')
  # 日本語: 男女表示で性特有癌を補完した率は、反対の性を含む母数であることを明示する。
  # English: State when a supplemented sex-specific cancer rate uses a denominator that includes the other sex.
  denominator_note = if selected_sex == 'both' && %w[crude_rate asr].include?(selected_metric)
                       if FEMALE_SPECIFIC_CANCER_SITES.include?(cause)
                         $l == :ja ? '※母数は男性人口を含む' : 'Note: denominator includes males'
                       elsif MALE_SPECIFIC_CANCER_SITES.include?(cause)
                         $l == :ja ? '※母数は女性人口を含む' : 'Note: denominator includes females'
                       end
                     end
  [label, denominator_note].compact.join(' ')
end

series_datasets = [['vital', selected_vital_causes], ['cancer-death', selected_cancer_causes]]
series_datasets = [['vital', selected_vital_causes]] if selected_period != 'calendar'
series_datasets << ['cancer-incidence', selected_cancer_causes] if include_incidence && selected_period == 'calendar'
series_specs = if mode == 'country'
                 selected_locations.map do |loc|
                   cause = selected_causes.first
                   dataset = CANCER_SITES.key?(cause) ? selected_dataset : 'vital'
                   [loc, selected_ages, cause, panel_label.call(loc, cause, dataset), dataset]
                 end
               else
                 series_datasets.flat_map do |dataset, causes|
                   causes.map do |cause|
                     key = "#{selected_locations.first}-#{selected_ages.join('+')}-#{dataset}-#{cause}"
                     [key, selected_ages, cause,
                      panel_label.call(selected_locations.first, cause, dataset), dataset]
                   end
                 end
               end

annual_by_dataset = series_datasets.to_h do |dataset, causes|
  definition = CANCER_DATASETS.fetch(dataset)
  annual = causes.flat_map do |cause|
    series_sex = dataset == 'vital' ? selected_sex : cancer_series_sex(selected_sex, cause)
    if selected_period != 'calendar' && selected_metric == 'asr'
      annualize_influenza_asr(count_rows, rate_rows,
                              selected_period == 'flu27' ? 27 : 36,
                              selected_ages, asr_stmf_weights)
    elsif selected_period != 'calendar'
      annualize_influenza_year(count_rows, rate_rows, selected_ages,
                               selected_period == 'flu27' ? 27 : 36,
                               selected_metric)
    elsif selected_metric == 'asr'
      stratified_asr_rows(annual_records_all, selected_locations, series_sex,
                          [cause],
                          standard_groups: dataset == 'vital' ? vital_asr_standard_groups : cancer_asr_standard_groups,
                          category: definition.fetch(:category), types: definition.fetch(:types),
                          population_sex: selected_sex)
    elsif selected_metric != 'std_deaths'
      annual_record_rows(annual_records_all, selected_locations, series_sex,
                         [cause], selected_metric, selected_ages,
                         category: definition.fetch(:category), types: definition.fetch(:types),
                         population_sex: selected_sex)
    elsif %w[deaths std_deaths].include?(selected_metric)
      annualize_weekly_counts(count_rows, selected_ages.first)
    else
      annualize_weekly(count_rows, rate_rows, selected_ages.first)
    end
  end
  [dataset, annual]
end

# 日本語: 年次の出生分母と乳児・周産期死亡分子を同じmstats indexから取得する。
# English: Read annual birth denominators and infant/perinatal numerators from the shared mstats index.
annual_source_fields = %w[id loc category rate dcode algo date year sex src_url age_all age_0]
annual_records = selected_metric == 'birth_rate' ? annual_records_all : []
special_rows = birth_rate_rows(annual_records)

chart_data = series_specs.flat_map do |series_key, age, cause, label, dataset|
  loc = mode == 'country' ? series_key : selected_locations.first
  rows = if SPECIAL_CAUSES.key?(cause)
           special_rows.select { |row| row[:loc] == loc && row[:dcode] == cause }
         else
           annual_by_dataset.fetch(dataset).select { |row| row[:loc] == loc && row[:dcode] == cause }
         end
  build_scenarios(rows, series_key, label,
                  use_cache: !opts[:fixture] || ENV['MORTYEAR_CACHE_FIXTURE'] == '1')
end

start_week = selected_period == 'flu27' ? 27 : 36
chart_data.each do |row|
  # 日本語: インフルエンザ年は冬が属する終了年の位置へ置く。
  # English: Plot an influenza season at its ending year, where its winter belongs.
  row[:season] ||= "#{row[:year]}/#{format('%02d', (row[:year] + 1) % 100)}" if selected_period != 'calendar'
  date = selected_period == 'calendar' ? Date.new(row[:year], 1, 1) : Date.new(row[:year] + 1, 1, 1)
  row[:plot_date] = date.iso8601
end
weekly_context = if selected_period == 'weekly' ||
                    (selected_period != 'calendar' && %w[crude_rate asr].include?(selected_metric)) ||
                    detailed_calendar_rate
                   weekly_display_rows(count_rows, rate_rows, selected_metric, selected_ages,
                                       asr_weights: asr_stmf_weights).map do |row|
                     series_key = mode == 'country' ? row[:loc] :
                       "#{selected_locations.first}-#{selected_ages.join('+')}-vital-#{row[:dcode]}"
                     row.merge(series: series_key)
                   end
                 else
                   []
                 end

# 日本語: 粗死亡率表示では、OWIDの週次コロナ死亡数を主系列と同じ年率換算へそろえる。
# English: For crude-rate views, convert weekly OWID COVID-19 deaths to the same annualized scale as the primary series.
if selected_period == 'weekly' && selected_metric == 'crude_rate'
  weekly_populations = weekly_context.each_with_object({}) do |row, result|
    population = Array(row[:model_strata]).sum { |stratum| stratum[:population].to_f }
    result[[row[:loc].to_s.downcase, row[:date].to_s]] ||= population if population.positive?
  end
  overlay_values = overlay_values.filter_map do |row|
    next row unless row[:overlay] == 'covid'

    population = weekly_populations[[row[:loc], row[:date].to_s]]
    next unless population&.positive?

    row.merge(value: row[:value] * DAYS_PER_YEAR * 100_000.0 / (7.0 * population))
  end
end
covid_overlay_available = overlay_values.any? { |row| row[:overlay] == 'covid' }
vaxx_overlay_available = overlay_values.any? { |row| row[:overlay] == 'vaxx' }

# 日本語: 全年齢・男女計・粗死亡率だけは、STMF開始前をUN月次crude rateで補完する。
# English: For all-age both-sex crude mortality only, supplement pre-STMF dates with UN monthly crude rate.
if monthly_supplement_enabled
  monthly_source = %w[loc yearmonth category rate dcode type date year month sex age_all]
  monthly_rows = if opts[:fixture]
                   fixture_data.select do |row|
                     locations_for_query.include?(row[:loc].to_s.downcase) &&
                       row[:yearmonth] && row[:category] == 'death' && row[:rate] == 'crude' &&
                       row[:type] == 'unmonth' && row[:dcode] == 'allcause' && row[:sex] == 'both'
                   end
                 else
                   elastic_search(
                     index: opts[:index], size: 100_000,
                     filter: [{ 'terms' => { 'loc' => locations_for_query } },
                              { 'term' => { 'category' => 'death' } },
                              { 'term' => { 'rate' => 'crude' } },
                              { 'term' => { 'type' => 'unmonth' } },
                              { 'term' => { 'dcode' => 'allcause' } },
                              { 'term' => { 'sex' => 'both' } },
                              { 'exists' => { 'field' => 'yearmonth' } }],
                     source: monthly_source
                   )
                 end
  weekly_context = prepend_monthly_crude(weekly_context, monthly_rows, mode,
                                         selected_locations, selected_ages)
else
  weekly_context = weekly_context.map do |row|
    row.merge(detail_period: $l == :ja ? '週' : 'Week')
  end
end
weekly_combinations = weekly_methods.product(weekly_baselines)
if selected_period == 'weekly'
  base_weekly_context = weekly_context
  weekly_context = weekly_combinations.flat_map do |method, baseline|
    analysis = weekly_baseline_analysis(base_weekly_context, method: method,
                                        baseline: baseline, metric: selected_metric)
    analysis_by_key = analysis.to_h { |row| [[row[:series], row[:date]], row] }
    base_weekly_context.map do |row|
      result = analysis_by_key[[row[:series], row[:date]]]
      combined_series = "#{row[:series]}--#{method}--#{baseline}"
      result ? row.merge(result.reject { |key, _value| %i[series date].include?(key) }, series: combined_series) :
        row.merge(series: combined_series)
    end
  end
end
# 日本語: 回帰用の年齢階級値はHTMLへ重複埋込みせず、計算後に除く。
# English: Remove duplicated model strata after calculation instead of embedding them in HTML.
weekly_context.each { |row| row.delete(:model_strata) }
weekly_context = insert_detail_gaps(weekly_context)
detail_series = weekly_context.filter_map { |row| row[:series] if row[:observed] }.uniq

# 日本語: start_year省略時は分析開始境界以後にある選択系列の最初の値から表示する。
# English: Without start_year, begin at the first selected value on or after the analysis boundary.
unless requested_start_year.between?(1950, 2020)
  first_value_year = chart_data.map { |row| row[:year] }.min
  default_start_year = [period_start_year, first_value_year || period_start_year].max
end

cutoffs = chart_data.map { |row| row[:train_to] }.uniq.sort
requested_cutoff = cgi['train_to'].to_i
preferred_cutoff = selected_period == 'calendar' ? 2019 : 2018
default_cutoff = if cutoffs.include?(requested_cutoff)
                   requested_cutoff
                 elsif cutoffs.include?(preferred_cutoff)
                   preferred_cutoff
                 else
                   cutoffs.last
                 end
cutoff_label = lambda do |year|
  year.to_s
end
available_specs = series_specs.select { |key, _age, _cause, _label| chart_data.any? { |row| row[:series] == key } }
if selected_period == 'weekly'
  method_labels = {
    'five_year' => ($l == :ja ? '5年平均' : 'Five-year average'),
    'farrington' => ($l == :ja ? 'Farrington型' : 'Farrington-style'),
    'euromomo' => ($l == :ja ? 'EuroMOMO型' : 'EuroMOMO-style')
  }
  baseline_labels = {
    'fixed_2015_2019' => ($l == :ja ? '基準期間2015–2019' : 'baseline 2015–2019'),
    'fixed_2016_2020' => ($l == :ja ? '基準期間2016–2020' : 'baseline 2016–2020'),
    'rolling' => ($l == :ja ? '直前5年移動基準' : 'previous-five-year rolling baseline')
  }
  available_specs = available_specs.flat_map do |key, ages, cause, label, dataset|
    weekly_combinations.map do |method, baseline|
      ["#{key}--#{method}--#{baseline}", ages, cause,
       "#{label} — #{method_labels.fetch(method)}・#{baseline_labels.fetch(baseline)}", dataset]
    end
  end
end

if opts[:summary]
  summary = available_specs.to_h do |key, _age, _cause, label|
    base_key = key.sub(/--(?:five_year|farrington|euromomo)--(?:fixed_2015_2019|fixed_2016_2020|rolling)\z/, '')
    values = chart_data.select { |row| row[:series] == base_key }
    last_cutoff = values.map { |row| row[:train_to] }.max
    requested_summary_cutoff = values.map { |row| row[:train_to] }.include?(default_cutoff) ? default_cutoff : last_cutoff
    selected_values = values.select { |row| interval_mode == 'analytic' ? row[:interval_method] == 'analytic' : row[:auto_selected] }
    poisson_latest = selected_values.select { |row| row[:model] == 'poisson' && row[:train_to] == requested_summary_cutoff }.
                     max_by { |row| row[:year] }
    latest = selected_values.select { |row| row[:model] == 'quasi_poisson' && row[:train_to] == last_cutoff }.
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

metric_label = selected_metric_names.fetch(selected_metric).fetch($l)
metric_label = $l == :ja ? '0歳人口当たり死亡率' : 'Mortality rate per age-0 population' if selected_metric == 'crude_rate' && selected_ages == ['age_0']
title = if selected_dataset == 'cancer-incidence'
          $l == :ja ? '日本のがん罹患数・罹患率と予測区間' : 'Cancer incidence and prediction intervals in Japan'
        elsif selected_dataset == 'cancer-death'
          $l == :ja ? '日本のがん死亡数・死亡率と予測区間' : 'Cancer mortality and prediction intervals in Japan'
        else
          $l == :ja ? '各国・各地域の死亡数・死亡率と予測区間' : 'Deaths, mortality rates, and prediction intervals by country and area'
        end
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
    #train-to-slider { width:50px; }
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
    <fieldset style="#{selected_dataset == 'vital' ? '' : 'display:none'}"><legend>#{ $l == :ja ? '比較方法' : 'Comparison mode' }</legend>
      <label><input class="comparison-mode" type="radio" name="mode" value="country" #{checked(mode == 'country')}>#{ $l == :ja ? '複数国・共通条件' : 'Countries, common condition' }</label>
      <label><input class="comparison-mode" type="radio" name="mode" value="series" #{checked(mode == 'series')}>#{ $l == :ja ? '一国・複数系列' : 'One country, multiple series' }</label>
    </fieldset>
    <fieldset style="#{selected_dataset == 'vital' ? '' : 'display:none'}"><legend>#{ $l == :ja ? '集計期間' : 'Period' }</legend>
      <label><input class="period-option" type="radio" name="period" value="calendar" #{checked(selected_period == 'calendar')}>#{ $l == :ja ? '暦年' : 'Calendar year' }</label>
      <span>#{ $l == :ja ? 'インフルエンザ年（開始:' : 'Influenza year (start:' }</span>
      <label><input class="period-option" type="radio" name="period" value="flu27" #{checked(selected_period == 'flu27')}>#{ $l == :ja ? '第27週' : 'W27' }</label>
      <label><input class="period-option" type="radio" name="period" value="flu36" #{checked(selected_period == 'flu36')}>#{ $l == :ja ? '第36週）' : 'W36)' }</label>
      <label><input class="period-option" type="radio" name="period" value="weekly" #{checked(selected_period == 'weekly')}>#{ $l == :ja ? '週次（超過・過少死亡）' : 'Weekly (excess/deficit mortality)' }</label>
    </fieldset>
    <fieldset id="weekly-method-fieldset" style="#{selected_period == 'weekly' ? '' : 'display:none'}"><legend>#{ $l == :ja ? '週次基準線' : 'Weekly baseline' }</legend>
      <label><input class="weekly-method-option" type="#{mode == 'series' ? 'checkbox' : 'radio'}" name="weekly_method" value="five_year" #{checked(weekly_methods.include?('five_year'))}>#{ $l == :ja ? '5年平均' : 'Five-year average' }</label>
      <label><input class="weekly-method-option" type="#{mode == 'series' ? 'checkbox' : 'radio'}" name="weekly_method" value="farrington" #{checked(weekly_methods.include?('farrington'))}>Farrington#{ $l == :ja ? '型' : '-style' }</label>
      <label><input class="weekly-method-option" type="#{mode == 'series' ? 'checkbox' : 'radio'}" name="weekly_method" value="euromomo" #{checked(weekly_methods.include?('euromomo'))}>EuroMOMO#{ $l == :ja ? '型' : '-style' }</label>
      &nbsp;
      <label><input class="weekly-baseline-option" type="#{mode == 'series' ? 'checkbox' : 'radio'}" name="weekly_baseline" value="fixed_2015_2019" #{checked(weekly_baselines.include?('fixed_2015_2019'))}>#{ $l == :ja ? '基準期間2015–2019' : 'Baseline period 2015–2019' }</label>
      <label><input class="weekly-baseline-option" type="#{mode == 'series' ? 'checkbox' : 'radio'}" name="weekly_baseline" value="fixed_2016_2020" #{checked(weekly_baselines.include?('fixed_2016_2020'))}>#{ $l == :ja ? '基準期間2016–2020' : 'Baseline period 2016–2020' }</label>
      <label><input class="weekly-baseline-option" type="#{mode == 'series' ? 'checkbox' : 'radio'}" name="weekly_baseline" value="rolling" #{checked(weekly_baselines.include?('rolling'))}>#{ $l == :ja ? '直前5年移動基準' : 'Previous-five-year rolling baseline' }</label>
    </fieldset><br>
    <fieldset><legend>#{ $l == :ja ? '指標' : 'Measure' }</legend>
HTML
METRICS.each do |metric, names|
  hidden = metric == 'std_deaths' || (selected_period != 'calendar' && !%w[deaths crude_rate asr].include?(metric)) ||
           (selected_dataset != 'vital' && !%w[deaths crude_rate asr].include?(metric))
  hidden_style = hidden ? ' style="display:none"' : ''
  label = if selected_dataset == 'cancer-incidence'
            { 'deaths' => { ja: '罹患数', en: 'Incidence count' },
              'crude_rate' => { ja: '粗罹患率', en: 'Crude incidence rate' },
              'asr' => { ja: '年齢調整罹患率', en: 'Age-standardized incidence rate' } }.
              fetch(metric, names).fetch($l)
          else
            names.fetch($l)
          end
  puts %(<label#{hidden_style}><input class="metric-option" type="radio" name="metric" value="#{metric}" #{checked(selected_metric == metric)}>#{CGI.escapeHTML(label)}</label>)
end
puts <<~HTML
    </fieldset><br>
    <fieldset id="location-fieldset"><legend>#{ $l == :ja ? '国・地域' : 'Country or area' }</legend>
HTML
location_groups = available_locations.group_by do |code|
  MORTYEAR_REGIONS.fetch(code, 'Other').then { |region| REGION_LABELS.key?(region) ? region : 'Other' }
end
REGION_LABELS.each do |region, region_names|
  codes = location_groups.fetch(region, []).sort_by { |code| location_sort_key(code, $l) }
  next if codes.empty?
  open = codes.any? { |code| selected_locations.include?(code) }
  selectable_count = codes.count do |code|
    if selected_metric == 'std_deaths'
      code == 'JPN'
    elsif selected_period == 'calendar'
      annual_metric_available?(code, annual_catalog.fetch(code), selected_metric)
    elsif selected_period == 'weekly'
      weekly_codes.include?(code) && %w[deaths crude_rate asr].include?(selected_metric)
    else
      period_metric_available?(annual_catalog.fetch(code), selected_metric, selected_period)
    end
  end
  toggle_label = $l == :ja ? 'この地域をすべて選択・解除' : 'Select or clear this region'
  puts %(<details class="location-region" #{open ? 'open' : ''}><summary><span class="location-region-name">#{CGI.escapeHTML(region_names.fetch($l))}</span>（<span class="location-region-count">#{selectable_count}</span>）<input class="location-region-toggle" type="checkbox" title="#{CGI.escapeHTML(toggle_label)}" aria-label="#{CGI.escapeHTML(toggle_label)}"></summary><div class="mortyear-options">)
  codes.each do |code|
    names = location_names(code)
    annual_metrics = METRICS.keys.select do |metric|
      metric == 'std_deaths' ? code == 'JPN' : annual_metric_available?(code, annual_catalog.fetch(code), metric)
    end
    detail_metrics = weekly_codes.include?(code) ? %w[deaths crude_rate asr] : []
    metrics = selected_period == 'calendar' ? annual_metrics : detail_metrics
    hidden = !metrics.include?(selected_metric)
    type = mode == 'country' ? 'checkbox' : 'radio'
    puts %(<label class="location-label" data-annual-metrics="#{annual_metrics.join(' ')}" data-weekly-metrics="#{detail_metrics.join(' ')}" style="#{hidden ? 'display:none' : ''}"><input class="location-option" type="#{type}" name="c" value="#{code}" #{checked(selected_locations.include?(code))} #{disabled(hidden)}>#{CGI.escapeHTML(names.fetch($l))}</label>)
  end
  puts %(</div></details>)
end
puts <<~HTML
    </fieldset><br>
    <fieldset id="sex-fieldset" style="#{selected_metric == 'birth_rate' ? 'display:none' : ''}"><legend>#{ $l == :ja ? '性別' : 'Sex' }</legend>
      <label><input class="sex-option" type="radio" name="sex" value="both" #{checked(selected_sex == 'both')}>#{ $l == :ja ? '男女計' : 'Both' }</label>
      <label><input class="sex-option" type="radio" name="sex" value="male" #{checked(selected_sex == 'male')}>#{ $l == :ja ? '男性' : 'Male' }</label>
      <label><input class="sex-option" type="radio" name="sex" value="female" #{checked(selected_sex == 'female')}>#{ $l == :ja ? '女性' : 'Female' }</label>
    </fieldset>
    <fieldset id="season-age-fieldset" style="#{selected_period == 'calendar' ? 'display:none' : ''}"><legend>#{ $l == :ja ? '年齢' : 'Age' }</legend>
HTML
STMF_AGES.each do |age|
  type = mode == 'country' ? 'radio' : 'checkbox'
  unavailable = selected_metric == 'asr' && age != 'age_all'
  puts %(<label><input class="age-season-option" type="#{type}" name="age" value="#{age}" #{checked(selected_ages.include?(age) && !unavailable)} #{disabled(unavailable)}>#{STMF_AGE_LABELS.fetch(age)}</label>)
end
puts <<~HTML
    </fieldset>
    <fieldset id="age-fieldset" style="#{selected_metric == 'birth_rate' || selected_period != 'calendar' ? 'display:none' : ''}"><legend>#{ $l == :ja ? '年齢' : 'Age' }</legend>
      <div class="age-scroll"><div id="age-scale">
        <div id="age-slider-row"><div id="age-range-slider"><input id="age-start" type="range" min="0" max="#{STANDARD_AGES.length - 1}" step="1"><input id="age-end" type="range" min="0" max="#{STANDARD_AGES.length - 1}" step="1"></div><output id="age-range-output"></output></div>
        <div id="age-options">
HTML
STANDARD_AGES.each_with_index do |age, index|
  active = selected_ages.include?('age_all') || selected_ages.include?(age)
  short_label = index == STANDARD_AGES.length - 1 ? '100+' : format('%02d', index * 5)
  terminal_class = index == STANDARD_AGES.length - 1 ? ' class="age-terminal"' : ''
  unavailable = !available_menu_ages.include?(age)
  puts %(<label#{terminal_class}><input class="age-option age-standard" type="checkbox" name="age" value="#{age}" #{checked(active && !unavailable)} #{disabled(unavailable || selected_period != 'calendar')}>#{short_label}</label>)
end
%w[age_0 age_all].each do |age|
  names = AGES.fetch(age)
  unavailable = !available_menu_ages.include?(age)
  puts %(<label class="age-special"><input class="age-option age-special-option" type="checkbox" name="age" value="#{age}" #{checked(selected_ages.include?(age) && !unavailable)} #{disabled(unavailable || selected_period != 'calendar')}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts <<~HTML
        </div>
      </div></div>
    </fieldset><br>
HTML
show_cause_fieldset = if selected_metric == 'birth_rate'
                        true
                      else
                        selected_locations == ['JPN']
                      end
puts <<~HTML
    <fieldset id="cause-fieldset" style="#{show_cause_fieldset ? '' : 'display:none'}"><legend>#{ $l == :ja ? '死因・症例' : 'Causes and conditions' }</legend>
HTML
puts %(<div class="cause-source-heading"><strong>#{CGI.escapeHTML($l == :ja ? '厚生労働省：人口動態統計' : 'Ministry of Health, Labour and Welfare: Vital Statistics')}</strong></div>)
japan_causes = if selected_period != 'calendar'
                 available_causes
               elsif vital_menu_catalog
                 catalog_available_causes(vital_menu_catalog, ['JPN'], selected_metric, selected_sex, selected_ages)
               else
                 annual_catalog.dig('JPN', :dcodes).to_a
               end.select { |cause| cause == 'allcause' || cause.match?(/\A\d{5}\z/) }
japan_causes.each do |cause|
  next unless cause == 'allcause'
  names = Death_codes.fetch(cause, { ja: cause, en: cause })
  type = mode == 'country' ? 'radio' : 'checkbox'
  puts %(<label><input class="cause-option" data-cause-scope="japan" data-dataset="vital" type="#{type}" name="dcodes" value="#{cause}" #{checked(selected_vital_causes.include?(cause))}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts %(<details open><summary>#{CGI.escapeHTML($l == :ja ? '出生関連指標' : 'Birth-related measures')}</summary><div class="mortyear-options">)
SPECIAL_CAUSES.each do |cause, names|
  type = mode == 'country' ? 'radio' : 'checkbox'
  locations = annual_catalog.select { |loc, catalog| birth_cause_available?(loc, catalog, cause) }.keys
  puts %(<label><input class="cause-option" data-cause-scope="birth" data-dataset="vital" data-locations="#{locations.join(' ')}" type="#{type}" name="dcodes" value="#{cause}" #{checked(selected_vital_causes.include?(cause))}>#{CGI.escapeHTML(names.fetch($l))}</label>)
end
puts %(</div></details>)
# 日本語: 上位分類recordがない場合も、同じ先頭2桁の死因を既知の分類名の下へ表示する。
# English: Show causes under their known two-digit group even when the parent record itself is absent.
numeric_cause_groups = japan_causes.grep(/\A\d{5}\z/).group_by { |cause| cause[0, 2] }
numeric_cause_groups.sort.each do |prefix, grouped_causes|
  parent = "#{prefix}000"
  parent_available = grouped_causes.include?(parent)
  children = grouped_causes.reject { |cause| cause == parent }
  names = Death_codes.fetch(parent, { ja: parent, en: parent })
  open = grouped_causes.any? { |cause| selected_causes.include?(cause) }
  puts %(<details #{open ? 'open' : ''}><summary>)
  type = mode == 'country' ? 'radio' : 'checkbox'
  if parent_available
    puts %(<label><input class="cause-option" data-cause-scope="japan" data-dataset="vital" type="#{type}" name="dcodes" value="#{parent}" #{checked(selected_vital_causes.include?(parent))}>#{parent}: #{CGI.escapeHTML(names.fetch($l))}</label></summary>)
  else
    puts %(#{prefix}: #{CGI.escapeHTML(names.fetch($l))}</summary>)
  end
  unless children.empty?
    puts %(<div class="mortyear-options">)
    children.each do |cause|
      child_names = Death_codes.fetch(cause, { ja: cause, en: cause })
      puts %(<label><input class="cause-option" data-cause-scope="japan" data-dataset="vital" type="#{type}" name="dcodes" value="#{cause}" #{checked(selected_vital_causes.include?(cause))}>#{cause}: #{CGI.escapeHTML(child_names.fetch($l))}</label>)
    end
    puts %(</div>)
  end
  puts %(</details>)
end
render_cancer_group = lambda do |dataset_key, heading|
  scope = dataset_key
  puts %(<details class="cancer-cause-group" open><summary>#{CGI.escapeHTML(heading)}</summary><div class="mortyear-options">)
  CANCER_SITES.each do |code, names|
    type = mode == 'country' ? 'radio' : 'checkbox'
    active = selected_cancer_causes.include?(code)
    puts %(<label><input class="cause-option cancer-site-option" data-cause-scope="#{scope}" data-dataset="#{dataset_key}" type="#{type}" name="dcodes" value="#{code}" #{checked(active)}>#{CGI.escapeHTML(names.fetch($l))}</label>)
  end
  puts %(</div></details>)
end
if selected_period == 'calendar'
  puts %(<div class="cause-source-heading"><strong>#{CGI.escapeHTML($l == :ja ? '国立がん研究センター：癌死亡' : 'National Cancer Center Japan: Cancer mortality')}</strong> <label><input id="include-incidence" type="checkbox" name="include_incidence" value="1" #{checked(include_incidence)}>#{CGI.escapeHTML($l == :ja ? '罹患も表示' : 'Also show incidence')}</label></div>)
  render_cancer_group.call('cancer-death', $l == :ja ? '癌部位' : 'Cancer sites')
end
puts <<~HTML
    </fieldset><br>
    <button type="submit">#{ $l == :ja ? '読込み' : 'Submit' }</button>
  </form>
  <script>
    (function () {
      function showLoading() {
        const vis = document.getElementById('mortyear-vis');
        if (vis) vis.innerHTML = '<div class="mortyear-loading">#{ $l == :ja ? '読み込み中……' : 'Loading…' }</div>';
      }
      function compactAges(values, period) {
        if (values.includes('age_all')) return 'all';
        if (period !== 'calendar') {
          const labels = #{JSON.generate(STMF_AGE_LABELS)};
          return values.map(value => labels[value] || value.replace(/^age_/, '')).join('~');
        }
        const order = #{JSON.generate(STANDARD_AGES)};
        const indexes = [...new Set(values.map(value => order.indexOf(value)).filter(index => index >= 0))].sort((a, b) => a - b);
        const compact = [];
        for (let i = 0; i < indexes.length; i += 1) {
          let j = i;
          while (j + 1 < indexes.length && indexes[j + 1] === indexes[j] + 1) j += 1;
          const first = order[indexes[i]].replace(/^age_/, '');
          const last = order[indexes[j]].replace(/^age_/, '');
          if (i === j) {
            compact.push(first);
          } else {
            const lower = first.slice(0, 2);
            const upper = last === '100plus' ? '100plus' : last.slice(3, 5);
            compact.push(`${lower}-${upper}`);
          }
          i = j;
        }
        if (values.includes('age_0')) compact.push('0');
        return compact.join('~');
      }
      document.querySelector('.mortyear-form').addEventListener('submit', event => {
        event.preventDefault();
        // 日本語: all選択時は個別年齢をGET parameterに重複して送らない。
        // English: When all ages is selected, omit redundant individual age parameters.
        const allAges = document.querySelector('.age-special-option[value="age_all"]');
        if (allAges.checked) standardInputs().forEach(input => { input.disabled = true; });
        // 日本語: 複数死因はcod.rbと同じく一つのdcodesへ~区切りで保存する。
        // English: Store multiple causes in one tilde-delimited dcodes parameter, as cod.rb does.
        const params = new URLSearchParams(new FormData(event.currentTarget));
        // 日本語: 非表示の別期間用checkboxを除き、現在の期間に対応する年齢だけをURLへ保存する。
        // English: Save only ages from the controls for the active period, excluding hidden controls for the other period.
        const period = params.get('period');
        const ageSelector = period === 'calendar' ? '.age-option:checked:not(:disabled)' : '.age-season-option:checked:not(:disabled)';
        const ages = Array.from(event.currentTarget.querySelectorAll(ageSelector)).map(input => input.value);
        params.delete('age');
        params.delete('ages');
        if (ages.length) params.set('ages', compactAges(ages, period));
        const causes = params.getAll('dcodes');
        params.delete('dcodes');
        if (causes.length) params.set('dcodes', causes.join('~'));
        ['weekly_method', 'weekly_baseline'].forEach(name => {
          const values = params.getAll(name);
          params.delete(name);
          if (values.length) params.set(name, values.join('~'));
        });
        // 日本語: 期間を切り替えたsubmitでは旧期間のlocation codeがformに残るため、
        // 暦年はGBR、インフルエンザ年はENGへcanonical化する。
        // English: On period changes the form still contains the previous period's location
        // code, so canonicalize it to GBR for calendar years and ENG for influenza years.
        const locations = params.getAll('c').map(value => {
          const upper = value.toUpperCase();
          if (period === 'calendar' && ['ENG', 'SCO'].includes(upper)) return 'gbr';
          if (period !== 'calendar' && upper === 'GBR') return 'eng';
          return value.toLowerCase();
        });
        params.delete('c');
        if (locations.length) params.set('c', locations.join('~'));
        // 日本語: 男女計は既定値なのでcanonical URLでは省略する。
        // English: Omit the default both-sex selection from canonical URLs.
        if (params.get('sex') === 'both') params.delete('sex');
        showLoading();
        window.location.assign(`${window.location.pathname}?${params.toString().replace(/%7E/gi, '~')}`);
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
        const seasonAges = Array.from(document.querySelectorAll('.age-season-option'));
        const weeklyMethods = Array.from(document.querySelectorAll('.weekly-method-option'));
        const weeklyBaselines = Array.from(document.querySelectorAll('.weekly-baseline-option'));
        if (selected === 'country') {
          setInputMode(locations, 'checkbox', 'c');
          setInputMode(causes, 'radio', 'dcodes');
          setInputMode(seasonAges, 'radio', 'age');
          setInputMode(weeklyMethods, 'radio', 'weekly_method');
          setInputMode(weeklyBaselines, 'radio', 'weekly_baseline');
        } else {
          setInputMode(locations, 'radio', 'c');
          setInputMode(causes, 'checkbox', 'dcodes');
          setInputMode(seasonAges, 'checkbox', 'age');
          setInputMode(weeklyMethods, 'checkbox', 'weekly_method');
          setInputMode(weeklyBaselines, 'checkbox', 'weekly_baseline');
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
      function updateLocationRegions() {
        document.querySelectorAll('.location-region').forEach(details => {
          const count = Array.from(details.querySelectorAll('.location-label')).filter(label => label.style.display !== 'none').length;
          details.querySelector('.location-region-count').textContent = count;
          details.style.display = count > 0 ? '' : 'none';
        });
        updateRegionToggles();
      }
      function locationMetrics(label) {
        const period = document.querySelector('.period-option:checked')?.value || 'calendar';
        const value = period === 'calendar' ? label.dataset.annualMetrics : label.dataset.weeklyMetrics;
        return (value || '').split(/\s+/).filter(Boolean);
      }
      function syncCauseVisibility(restrictLocations = false) {
        const fieldset = document.getElementById('cause-fieldset');
        const causes = Array.from(document.querySelectorAll('.cause-option'));
        let selectedLocations = Array.from(document.querySelectorAll('.location-option:checked:not(:disabled)')).map(input => input.value);
        const metric = document.querySelector('input[name="metric"]:checked').value;
        const calendarPeriod = document.querySelector('.period-option:checked').value === 'calendar';
        const birthLocations = selectedLocations.length > 0 && selectedLocations.every(location => {
          const input = document.querySelector(`.location-option[value="${location}"]`);
          return input && locationMetrics(input.closest('label')).includes('birth_rate');
        });
        const japanContext = calendarPeriod && selectedLocations.length === 1 && selectedLocations[0] === 'JPN' && metric !== 'birth_rate';
        const scope = japanContext ? 'japan' :
          metric === 'birth_rate' && (selectedLocations.length === 0 || birthLocations) ? 'birth' : null;
        const activeScopes = japanContext ? ['japan', 'cancer-death', 'cancer-incidence'] : (scope ? [scope] : []);
        const hidden = activeScopes.length === 0;
        fieldset.style.display = hidden ? 'none' : '';
        causes.forEach(input => {
          const supportedLocations = (input.dataset.locations || '').split(' ').filter(Boolean);
          const supported = input.dataset.causeScope !== 'birth' ||
            selectedLocations.every(location => supportedLocations.includes(location));
          const active = !hidden && activeScopes.includes(input.dataset.causeScope) && supported;
          input.disabled = !active;
          input.closest('label').style.display = active ? '' : 'none';
          if (!active) input.checked = false;
        });
        fieldset.querySelectorAll('details').forEach(details => {
          details.style.display = details.querySelector('.cause-option:not(:disabled)') ? '' : 'none';
        });
        const active = causes.filter(input => !input.disabled);
        if (active.length && !active.some(input => input.checked)) {
          if (scope === 'birth' && document.querySelector('.comparison-mode:checked').value === 'series') {
            active.forEach(input => { input.checked = true; });
          } else {
            const preferredDataset = 'vital';
            const preferred = active.find(input => input.dataset.dataset === preferredDataset &&
              input.value === (scope === 'birth' ? 'infant' : (preferredDataset === 'vital' ? 'allcause' : 'c53'))) || active[0];
            preferred.checked = true;
          }
        }
        if (restrictLocations && scope === 'birth') {
          const selectedCauses = causes.filter(input => input.dataset.causeScope === 'birth' && input.checked);
          document.querySelectorAll('.location-label').forEach(label => {
            const input = label.querySelector('.location-option');
            const metricAvailable = locationMetrics(label).includes('birth_rate');
            const causeAvailable = selectedCauses.every(cause =>
              cause.dataset.locations.split(/\s+/).includes(input.value)
            );
            const available = metricAvailable && causeAvailable;
            label.style.display = available ? '' : 'none';
            input.disabled = !available;
            if (!available) input.checked = false;
          });
          updateLocationRegions();
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
        const selectedPeriod = document.querySelector('.period-option:checked').value;
        const isCalendarPeriod = selectedPeriod === 'calendar';
        document.getElementById('weekly-method-fieldset').style.display = selectedPeriod === 'weekly' ? '' : 'none';
        const fixedAllAges = metric === 'birth_rate';
        const sexFieldset = document.getElementById('sex-fieldset');
        sexFieldset.style.display = metric === 'birth_rate' ? 'none' : '';
        document.querySelectorAll('.sex-option').forEach(input => {
          input.disabled = metric === 'birth_rate';
          if (metric === 'birth_rate') input.checked = input.value === 'both';
        });
        document.getElementById('age-fieldset').style.display = isCalendarPeriod && metric !== 'birth_rate' ? '' : 'none';
        document.getElementById('season-age-fieldset').style.display = !isCalendarPeriod ? '' : 'none';
        document.querySelectorAll('.age-season-option').forEach(input => {
          const asrUnavailable = metric === 'asr' && input.value !== 'age_all';
          input.disabled = isCalendarPeriod || asrUnavailable;
          if (!isCalendarPeriod && metric === 'asr') input.checked = input.value === 'age_all';
        });
        document.querySelectorAll('.age-option').forEach(input => {
          input.disabled = metric === 'birth_rate' || !isCalendarPeriod;
          if (fixedAllAges) input.checked = input.value === 'age_all';
        });
        if (!fixedAllAges && document.querySelector('.age-special-option[value="age_all"]').checked) {
          standardInputs().forEach(input => { input.checked = true; });
        }
        ageSlider.style.display = fixedAllAges ? 'none' : '';
        document.querySelectorAll('.location-label').forEach(label => {
          const available = locationMetrics(label).includes(metric);
          label.style.display = available ? "" : "none";
          label.querySelector('input').disabled = !available;
        });
        updateLocationRegions();
        const enabled = Array.from(document.querySelectorAll('.location-option:not(:disabled)'));
        if (metric !== 'birth_rate' && !enabled.some(input => input.checked) && enabled[0]) enabled[0].checked = true;
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
          form.requestSubmit();
        });
      });
      document.querySelectorAll('.location-option').forEach(input => input.addEventListener('change', () => {
        rememberLocations();
        updateRegionToggles();
        syncCauseVisibility();
      }));
      document.querySelectorAll('.cause-option').forEach(input => input.addEventListener('change', () => {
        if (input.checked && input.dataset.dataset) {
          const seriesMode = document.querySelector('.comparison-mode[value="series"]')?.checked;
          if (!seriesMode) {
            document.querySelectorAll('.cause-option').forEach(other => {
              if (other !== input && other.dataset.dataset !== input.dataset.dataset) other.checked = false;
            });
          }
        }
        if (input.classList.contains('cancer-site-option') && input.checked &&
            !document.querySelector('.comparison-mode[value="series"]')?.checked) {
          const hierarchy = #{JSON.generate(CANCER_SITE_CHILDREN)};
          Object.entries(hierarchy).forEach(([parent, children]) => {
            const parentInput = document.querySelector(`.cancer-site-option[data-dataset="${input.dataset.dataset}"][value="${parent}"]`);
            if (input.value === parent) {
              children.forEach(code => {
                const child = document.querySelector(`.cancer-site-option[data-dataset="${input.dataset.dataset}"][value="${code}"]`);
                if (child) child.checked = false;
              });
            } else if (children.includes(input.value) && parentInput) {
              parentInput.checked = false;
            }
          });
        }
        syncCauseVisibility(true);
        rememberLocations();
      }));
      document.querySelectorAll('.metric-option').forEach(input => input.addEventListener('change', () => {
        rememberLocations();
        syncMetric();
      }));
      document.querySelectorAll('.period-option').forEach(input => input.addEventListener('change', event => {
        const trainTo = document.getElementById('train-to-hidden');
        if (event.target.value === 'calendar' && trainTo.value === '2018') trainTo.value = '2019';
        if (event.target.value !== 'calendar' && trainTo.value === '2019') trainTo.value = '2018';
        // 日本語: 年次GBRと週次ENGを、再読込み前の選択欄でも対応付ける。
        // English: Map annual GBR and weekly ENG in the controls before reloading.
        const gbr = document.querySelector('.location-option[value="GBR"]');
        const eng = document.querySelector('.location-option[value="ENG"]');
        const sco = document.querySelector('.location-option[value="SCO"]');
        if (event.target.value === 'calendar' && ((eng && eng.checked) || (sco && sco.checked)) && gbr) {
          gbr.checked = true;
        } else if (event.target.value !== 'calendar' && gbr && gbr.checked && eng) {
          eng.checked = true;
        }
        syncMetric();
        syncCauseVisibility();
      }));
      restoreLocations();
      syncAgeSlider();
      syncMetric();
      if (document.querySelector('.metric-option:checked').value === 'birth_rate' &&
          document.querySelector('.cause-option[data-cause-scope="birth"]:checked')) {
        syncCauseVisibility(true);
      }
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
  oecd_reconructed = chart_data.any? do |row|
    urls = Array(row[:src_url])
    urls.any? { |url| url.to_s.include?('data-explorer.oecd.org') } &&
      urls.any? { |url| url.to_s.include?('population.un.org') }
  end
  approximation_note = if oecd_reconructed && (selected_locations - %w[JPN USA]).any?
                         $l == :ja ? ' OECD公表率とUN WPP 2024の出生数から死亡数を逆算した近似系列です。欠測年は補間していません。' : ' Approximate death counts are reconructed from OECD-published rates and UN WPP 2024 births. Missing years are not interpolated.'
                       elsif selected_locations.include?('USA') && selected_causes.include?('perm')
                         $l == :ja ? ' 米国の周産期死亡数は、丸められた公表率と出生数から逆算した近似値です。2006年と2010年は欠測のままです。' : ' U.S. perinatal death counts are approximate values reconructed from rounded published rates and births; 2006 and 2010 remain missing.'
                       else
                         ''
                       end
  unit_note = if $l == :ja
                '実死亡数と標準人口換算死亡数は人数、粗死亡率と年齢調整死亡率は人口10万人当たりです。出生関連死亡率は出生数または出産数1,000当たりです。0歳人口当たり死亡率は0歳人口10万人当たりで、出生関連死亡率とは分母が異なります。'
              else
                'Observed and standardized deaths are shown as counts. Crude and age-standardized mortality rates are shown per 100,000 population. Birth-related mortality rates are shown per 1,000 births or deliveries. The age-0 population rate is shown per 100,000 age-0 population and uses a different denominator from birth-related mortality rates.'
              end
  sources_by_location = if selected_period == 'weekly'
                          weekly_context.each_with_object({}) do |row, sources|
                            loc = row[:loc].to_s.upcase
                            next if loc.empty?
                            sources[loc] ||= []
                            sources[loc] |= Array(row[:src_url]).compact
                          end
                        else
                          available_specs.each_with_object({}) do |(key, _age, _cause, _label), sources|
                            loc = mode == 'country' ? key : selected_locations.first
                            urls = chart_data.select { |row| row[:series] == key }.flat_map { |row| row[:src_url] }.uniq
                            sources[loc] ||= []
                            sources[loc] |= urls
                          end
                        end
  source_entries = []
  if selected_dataset != 'vital'
    method = if selected_dataset == 'cancer-incidence'
               $l == :ja ? '国立がん研究センター公表のがん罹患数を使用しています。' :
                 'Uses cancer incidence counts published by the National Cancer Center Japan.'
             else
               $l == :ja ? '国立がん研究センター公表のがん死亡数を使用しています。' :
                 'Uses cancer mortality counts published by the National Cancer Center Japan.'
             end
    method += if selected_metric == 'asr'
                $l == :ja ? ' 年齢階級別人口とWHO世界標準人口を用いる直接法で年齢調整しています。' :
                  ' Rates are directly age-standardized using age-specific populations and the WHO world standard population.'
              elsif selected_metric == 'crude_rate'
                $l == :ja ? ' 人口を分母として粗率を計算しています。' :
                  ' Crude rates use population denominators.'
              else
                ''
              end
    raw_urls = sources_by_location.fetch('JPN', [])
    urls = raw_urls.select { |url| url.include?('ganjoho.jp') }
    if selected_metric != 'deaths'
      urls << ESTAT_POP_URL if raw_urls.any? { |url| url.include?('e-stat.go.jp') }
      urls << WPP_URL if raw_urls.any? { |url| url.include?('population.un.org') }
    end
    source_entries << { loc: 'JPN', method: method, urls: urls }
  elsif sources_by_location['JPN']&.any? { |url| url.include?('e-stat.go.jp') }
    method = if selected_period == 'weekly' && selected_metric == 'deaths' && selected_ages == ['age_all'] && $l == :ja
               '日本の超過死亡ダッシュボードが公表する補正済み週次死亡数を使用しています。'
             elsif selected_period == 'weekly' && selected_metric == 'deaths' && selected_ages == ['age_all']
               'Uses corrected weekly death counts published by the Japanese excess-mortality dashboard.'
             elsif selected_period == 'weekly' && selected_metric == 'crude_rate' && selected_ages == ['age_all'] && $l == :ja
               '日本の超過死亡ダッシュボードの補正済み週次死亡数と、e-Statの月次人口から粗死亡率を計算しています。'
             elsif selected_period == 'weekly' && selected_metric == 'crude_rate' && selected_ages == ['age_all']
               'Calculates crude mortality rates from corrected weekly deaths published by the Japanese excess-mortality dashboard and monthly e-Stat populations.'
             elsif jpn_2015_asr && selected_period == 'weekly' && $l == :ja
               'e-Statの月次死亡数・月次人口から作った週次推計値を、日本の2015年モデル人口で年齢調整しています。'
             elsif jpn_2015_asr && selected_period == 'weekly'
               'Uses weekly estimates derived from monthly e-Stat deaths and populations, standardized to the Japan 2015 model population.'
             elsif selected_period == 'weekly' && $l == :ja
               'e-Statの月次死亡数・月次人口から作った週次推計値を使用しています。'
             elsif selected_period == 'weekly'
               'Uses weekly estimates derived from monthly e-Stat deaths and populations.'
             elsif jpn_2015_asr && selected_period != 'calendar' && $l == :ja
               'e-Statの月次死亡数・月次人口から作った週次推計値をインフルエンザ年へ再集計し、日本の2015年モデル人口で年齢調整しています。'
             elsif jpn_2015_asr && selected_period != 'calendar'
               'Aggregates weekly estimates derived from monthly e-Stat deaths and populations into influenza years and standardizes them to the Japan 2015 model population.'
             elsif selected_period != 'calendar' && $l == :ja
               'e-Statの月次死亡数・月次人口から作った週次推計値を、インフルエンザ年へ再集計しています。UN WPPは使用していません。'
             elsif selected_period != 'calendar'
               'Aggregates weekly estimates derived from monthly e-Stat deaths and populations into influenza years. UN WPP is not used.'
             elsif selected_metric == 'birth_rate' &&
                selected_causes.include?('infant') && selected_causes.include?('perm') && $l == :ja
               'e-Statの確定数を使用。乳児死亡率の分母は出生数です。周産期死亡数は妊娠満22週以後の死産数と生後1週未満の早期新生児死亡数の合計で、分母は出産数（出生数＋妊娠満22週以後の死産数）です。'
             elsif selected_metric == 'birth_rate' &&
                   selected_causes.include?('infant') && selected_causes.include?('perm')
               'Uses final e-Stat counts. Infant mortality uses births as the denominator. Perinatal deaths combine fetal deaths at 22 completed weeks or later with early neonatal deaths under 7 days; the denominator is deliveries (births plus fetal deaths at 22 completed weeks or later).'
             elsif selected_metric == 'birth_rate' && selected_causes.include?('perm') && $l == :ja
               'e-Statの確定数を使用。周産期死亡数は妊娠満22週以後の死産数と生後1週未満の早期新生児死亡数の合計で、分母は出産数（出生数＋妊娠満22週以後の死産数）です。'
             elsif selected_metric == 'birth_rate' && selected_causes.include?('perm')
               'Uses final e-Stat counts. Perinatal deaths combine fetal deaths at 22 completed weeks or later with early neonatal deaths under 7 days; the denominator is deliveries (births plus fetal deaths at 22 completed weeks or later).'
             elsif selected_metric == 'birth_rate' && $l == :ja
               'e-Statの確定出生数と乳児死亡数を使用しています。'
             elsif selected_metric == 'birth_rate'
               'Uses final annual birth and infant death counts from e-Stat.'
             elsif jpn_2015_asr && $l == :ja
               'e-Statの年齢階級別死亡数・人口から、日本の2015年モデル人口を用いる直接法で年齢調整しています。'
             elsif jpn_2015_asr
               'Uses direct standardization of age-specific e-Stat deaths and populations to the Japan 2015 model population.'
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
    # 日本語: recordには年別fileの追跡URLを残すが、画面では安定した資料一覧へ集約する。
    # English: Retain per-year provenance in records, but show stable source listings on the page.
    other_urls = sources_by_location['JPN'].reject do |url|
      url.include?('e-stat.go.jp') || (mixed_japan_series && url.include?('ganjoho.jp'))
    end
    stable_urls = if selected_period == 'weekly' && selected_metric == 'deaths' && selected_ages == ['age_all']
                    []
                  elsif selected_period == 'weekly' && selected_metric == 'crude_rate' && selected_ages == ['age_all']
                    [ESTAT_POP_URL]
                  else
                    selected_period == 'calendar' ? [ESTAT_ANNUAL_DEATH_URL, ESTAT_DEATH_URL] : [ESTAT_DEATH_URL]
                  end
    stable_urls << ESTAT_POP_URL unless selected_metric == 'birth_rate' || stable_urls.include?(ESTAT_POP_URL) ||
                                           (selected_period == 'weekly' && selected_metric == 'deaths' && selected_ages == ['age_all'])
    source_entries << { loc: 'JPN', method: method, urls: (stable_urls + other_urls).uniq }
  end
  if mixed_japan_series && selected_cancer_causes.any?
    cancer_method = if include_incidence
                      $l == :ja ?
                        '国立がん研究センター公表の癌死亡数と癌罹患数を使用しています。癌系列の年齢調整にはWHO世界標準人口を使います。' :
                        'Uses cancer mortality and incidence counts published by the National Cancer Center Japan. Cancer series use the WHO world standard population.'
                    else
                      $l == :ja ?
                        '国立がん研究センター公表の癌死亡数を使用しています。癌系列の年齢調整にはWHO世界標準人口を使います。' :
                        'Uses cancer mortality counts published by the National Cancer Center Japan. Cancer series use the WHO world standard population.'
                    end
    cancer_urls = sources_by_location.fetch('JPN', []).select { |url| url.include?('ganjoho.jp') }
    source_entries << { loc: 'JPN', method: cancer_method, urls: cancer_urls }
  end
  sources_by_location.each do |loc, urls|
    next if selected_dataset != 'vital' && loc == 'JPN'
    next if loc == 'JPN' && urls.any? { |url| url.include?('e-stat.go.jp') }

    method = if selected_period == 'weekly' && urls.include?(HMD_URL) && $l == :ja
               'HMD STMFの週次死亡数・死亡率を使用しています。'
             elsif selected_period == 'weekly' && urls.include?(HMD_URL)
               'Uses weekly deaths and mortality rates from HMD STMF.'
             elsif selected_period != 'calendar' && urls.include?(HMD_URL) && $l == :ja
               'HMD STMFの週次死亡数・死亡率を、インフルエンザ年へ再集計しています。'
             elsif selected_period != 'calendar' && urls.include?(HMD_URL)
               'Aggregates HMD STMF weekly deaths and mortality rates into influenza years.'
             elsif loc == 'USA' && selected_metric == 'birth_rate' &&
                selected_causes.include?('infant') && selected_causes.include?('perm')
               if $l == :ja
                 '乳児死亡率には米国CDCの年次出生数・乳児死亡数を使用しています。周産期死亡率には米国の年次出生数と、OECD公表率から逆算した近似死亡数を使用しています。'
               else
                 'Infant mortality uses annual U.S. CDC birth and infant death counts. Perinatal mortality uses annual U.S. births and approximate death counts reconructed from OECD-published rates.'
               end
             elsif loc == 'USA' && selected_metric == 'birth_rate' && selected_causes.include?('perm')
               if $l == :ja
                 '米国の年次出生数と、OECD公表率から逆算した周産期死亡数を使用しています。死亡数は近似値です。'
               else
                 'Uses annual U.S. births and perinatal death counts reconructed from OECD-published rates. The death counts are approximate.'
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
                 'Uses approximate death counts reconructed from OECD-published rates and UN WPP 2024 births.'
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
    urls = entries.flat_map { |entry| entry[:urls] }.uniq - [HMD_URL, WPP_URL]
    links = urls.map { |url| %(<a href="#{CGI.escapeHTML(url)}" target="_blank">#{CGI.escapeHTML(url)}</a>) }.join('<br>')
    link_html = links.empty? ? '' : "<br>#{links}"
    "<li><strong>#{CGI.escapeHTML(location_label)}</strong>: #{CGI.escapeHTML(method)}#{link_html}</li>"
  end.join("\n")
  asr_note_ja = mixed_japan_series && selected_cancer_causes.any? ?
                  '人口動態統計には日本の2015年モデル人口、癌統計にはWHO世界標準人口を使います。' : selected_dataset == 'vital' ?
                  '日本単独表示では日本の2015年モデル人口、複数国比較とその他の国・地域ではWHO世界標準人口を使います。' :
                  'がん統計ではWHO世界標準人口を使います。'
  asr_note_en = mixed_japan_series && selected_cancer_causes.any? ?
                  'Vital Statistics use the Japan 2015 model population; cancer statistics use the WHO world standard population.' : selected_dataset == 'vital' ?
                  'Japan-only views use the Japan 2015 model population; multi-country comparisons and other locations use the WHO world standard population.' :
                  'Cancer statistics use the WHO world standard population.'
  method_notes = if $l == :ja
                   <<~HTML
                     <h3>用語と集計方法</h3>
                     <dl class="mortyear-note">
                       <dt><strong>HMD</strong></dt><dd>Human Mortality Database（国際死亡データベース）。各国の死亡・人口データを共通形式で提供しています。<br><a href="#{HMD_HOME_URL}" target="_blank">#{HMD_HOME_URL}</a></dd>
                       <dt><strong>STMF</strong></dt><dd>Short-Term Mortality Fluctuations。HMDが提供する週次死亡データです。この画面では年齢階級別の週次死亡数と死亡率を使用します。<br><a href="#{HMD_URL}" target="_blank">#{HMD_URL}</a></dd>
                       <dt><strong>UN WPP</strong></dt><dd>国連人口部のWorld Population Prospects（世界人口推計）。各国の年次人口などを補う場合に使用します。<br><a href="#{WPP_URL}" target="_blank">#{WPP_URL}</a></dd>
                       <dt><strong>ASR</strong></dt><dd>Age-standardized rate（年齢調整率）。#{asr_note_ja}選択年齢範囲内で標準人口weightを再正規化します。インフルエンザ年のASRはSTMF共通の粗い年齢階級による近似です。<br><a href="#{WHO_STANDARD_URL}" target="_blank">#{WHO_STANDARD_URL}</a></dd>
                       <dt><strong>インフルエンザ年の集計</strong></dt><dd>年境界をまたぐ週の死亡数は、各期間に含まれる日数に応じて配分します。週次死亡数と死亡率から得た人口を人口日として積算し、第27週または第36週から翌年の同じ開始週直前まで、全日がそろう期間だけを表示します。日本の週次値は実測週次値ではなく、e-Stat月次値から按分・平滑化した推計値です。</dd>
                     </dl>
                   HTML
                 else
                   <<~HTML
                     <h3>Terms and aggregation</h3>
                     <dl class="mortyear-note">
                       <dt><strong>HMD</strong></dt><dd>Human Mortality Database, which provides harmonized mortality and population data for participating countries.<br><a href="#{HMD_HOME_URL}" target="_blank">#{HMD_HOME_URL}</a></dd>
                       <dt><strong>STMF</strong></dt><dd>Short-Term Mortality Fluctuations, the weekly mortality dataset provided by HMD. This page uses its age-specific weekly deaths and mortality rates.<br><a href="#{HMD_URL}" target="_blank">#{HMD_URL}</a></dd>
                       <dt><strong>UN WPP</strong></dt><dd>United Nations World Population Prospects, published by the UN Population Division. It supplies annual population data where needed.<br><a href="#{WPP_URL}" target="_blank">#{WPP_URL}</a></dd>
                       <dt><strong>ASR</strong></dt><dd>Age-standardized rate. #{asr_note_en} Weights are renormalized within the selected age range. Influenza-year ASR is approximate because it uses broad common STMF age groups.<br><a href="#{WHO_STANDARD_URL}" target="_blank">#{WHO_STANDARD_URL}</a></dd>
                       <dt><strong>Influenza-year aggregation</strong></dt><dd>Deaths in a week crossing a year boundary are allocated in proportion to the number of days in each period. Population inferred from weekly deaths and rates is accumulated as population-days. Only complete periods from W27 or W36 to the day before the same starting week in the following year are shown. Japanese weekly values are estimates prorated and smoothed from monthly e-Stat data, not directly observed weekly counts.</dd>
                     </dl>
                   HTML
                 end
  coverage_items = if menu_catalog
                     available_count = lambda do |metric, cause: nil, age: nil|
                       menu_catalog.count do |_loc, entry|
                         entry.fetch(:series).any? do |item|
                           item[:metric] == metric && item[:displayable] &&
                             (!cause || item[:cause] == cause) && (!age || item[:age] == age)
                         end
                       end
                     end
                     general = [available_count.call('deaths'), available_count.call('crude_rate'),
                                available_count.call('deaths', age: 'age_0'),
                                available_count.call('crude_rate', age: 'age_0')].min
                     if selected_period == 'calendar'
                       [
                         [$l == :ja ? '全年齢・0歳・年齢区間別の死亡数と粗死亡率' : 'Death counts and crude mortality rates for all ages, age 0, and selected age ranges', general],
                         [$l == :ja ? '年齢調整死亡率' : 'Age-standardized mortality rates', available_count.call('asr')],
                         [$l == :ja ? '乳児死亡率' : 'Infant mortality rates', available_count.call('birth_rate', cause: 'infant')],
                         [$l == :ja ? '周産期死亡率' : 'Perinatal mortality rates', available_count.call('birth_rate', cause: 'perm')]
                       ]
                     elsif selected_period == 'weekly'
                       count = location_rates.count do |_code, rates|
                         rates.include?('') && rates.include?('crude')
                       end
                       [[$l == :ja ? '実死亡数・粗死亡率・年齢調整死亡率' :
                                      'Deaths, crude rates, and age-standardized rates', count]]
                     else
                       counts = %w[deaths crude_rate asr].map do |metric|
                         menu_catalog.count do |_loc, entry|
                           entry.fetch(:series).any? do |item|
                             item[:period] == selected_period && item[:metric] == metric &&
                               item[:age] == 'age_all' && item[:displayable]
                           end
                         end
                       end
                       [[$l == :ja ? '実死亡数・粗死亡率・年齢調整死亡率' :
                                      'Deaths, crude rates, and age-standardized rates', counts.min]]
                     end
                   end
  coverage_html = if coverage_items
                    coverage_items.map do |label, count|
                      separator = $l == :ja ? '：' : ': '
                      "<li>#{CGI.escapeHTML(label)}#{separator}#{count}#{CGI.escapeHTML($l == :ja ? 'か国・地域' : ' countries or areas')}</li>"
                    end.join
                  end
  standard_age_indexes = selected_ages.filter_map { |age| STANDARD_AGES.index(age) }.sort
  selected_80_plus = standard_age_indexes == (STANDARD_AGES.index('age_80_84')...STANDARD_AGES.length).to_a
  default_model = selected_chart_model
  dispersion_labels = available_specs.to_h do |key, _age, cause, _label|
    short_label = if mode == 'country'
                    location_names(key).fetch($l)
                  else
                    SPECIAL_CAUSES.fetch(cause, Death_codes.fetch(cause, { ja: cause, en: cause })).fetch($l)
                  end
    [key, short_label]
  end
  interval_note = if selected_period == 'weekly'
                    if $l == :ja
                      '週次基準線はSTMF由来の週次値だけで計算し、過去の月次補完値は使いません。5年平均の帯は同じ週の最小・最大、Farrington型は対象週の前後3週、EuroMOMO型は第16–25週・第37–44週を基準にします。'
                    else
                      'Weekly baselines use only STMF-derived weekly values, never the historical monthly supplement. The five-year average is accompanied by the same-week minimum-to-maximum band; Farrington-style uses ±3 weeks; EuroMOMO-style uses W16–25 and W37–44 as baseline weeks.'
                    end
                  elsif $l == :ja
                    '準ポアソンは、観測された過分散を反映した近似95%予測区間です。ポアソンでは、計算済みなら10,000回シミュレーションによる区間へ切り替えられます（青：準ポアソン、緑：ポアソン近似、黄：シミュレーション）。'
                  else
                    'Quasi-Poisson shows an approximate 95% prediction interval reflecting observed overdispersion. With Poisson, a 10,000-run simulated interval can be selected when available (blue: Quasi-Poisson; green: Poisson approximation; yellow: simulation).'
                  end
  weekly_excess_enabled = selected_period == 'weekly'
  weekly_cumulative_start = weekly_baselines.include?('fixed_2016_2020') ? 2021 : 2020
  weekly_excess_title = if $l == :ja
                          selected_metric == 'deaths' ? '超過死亡数' : '超過死亡率'
                        else
                          selected_metric == 'deaths' ? 'Excess deaths' : 'Excess mortality rate'
                        end
  weekly_excess_trend_title = $l == :ja ? "#{weekly_excess_title}の推移" : "#{weekly_excess_title} trend"
  weekly_excess_cumulative_title = if $l == :ja
                                     "#{weekly_cumulative_start}年からの累積#{weekly_excess_title}"
                                   else
                                     "Cumulative #{weekly_excess_title.downcase} from #{weekly_cumulative_start}"
                                   end
  weekly_deficit_title = if $l == :ja
                           selected_metric == 'deaths' ? '死亡数の増減' : '死亡率の増減'
                         else
                           selected_metric == 'deaths' ? 'Mortality difference' : 'Mortality rate difference'
                         end
  weekly_deficit_trend_title = $l == :ja ? "#{weekly_deficit_title}の推移" : "#{weekly_deficit_title} trend"
  weekly_deficit_cumulative_title = if $l == :ja
                                      "#{weekly_cumulative_start}年からの累積#{weekly_deficit_title}"
                                    else
                                      "Cumulative #{weekly_deficit_title.downcase} from #{weekly_cumulative_start}"
                                    end
  weekly_excess_lower_title = if weekly_methods == ['five_year']
                                $l == :ja ? '過去5年最大値超過' : 'Above five-year maximum'
                              elsif !weekly_methods.include?('five_year')
                                $l == :ja ? '予測上限超過' : 'Above prediction limit'
                              else
                                $l == :ja ? '保守的超過' : 'Conservative excess'
                              end
  weekly_excess_upper_title = $l == :ja ? '基準線超過' : 'Above baseline'
  covid_overlay_title = if selected_metric == 'crude_rate'
                          $l == :ja ? '新型コロナ粗死亡率' : 'COVID-19 crude mortality rate'
                        else
                          $l == :ja ? '新型コロナ死亡' : 'COVID-19 deaths'
                        end
  covid_overlay_format = selected_metric == 'deaths' ? ',.0f' : '.2f'
  if weekly_excess_enabled
    dark_red_note = if weekly_methods.include?('five_year') && weekly_methods.length > 1
                      $l == :ja ? '5年平均では過去5年最大値超過、Farrington型・EuroMOMO型では予測上限超過' :
                        'above the five-year maximum for the five-year average and above the prediction limit for Farrington-style and EuroMOMO-style'
                    else
                      weekly_excess_lower_title
                    end
    interval_note += if $l == :ja
                       " 下2段は超過死亡の推移と累積を同じ色で示し、薄赤は#{weekly_excess_upper_title}、濃赤は#{dark_red_note}です。「過少死亡も表示・累積」では負の差を青で示し、累積死亡増減から差し引きます。"
                     else
                       " The two lower panels show the excess trend and cumulative excess using the same colors: light red is #{weekly_excess_upper_title.downcase}; dark red is #{dark_red_note.downcase}. With mortality deficits enabled, negative differences are blue and reduce the cumulative mortality difference."
                     end
  end
  puts <<~HTML
    <p id="mortyear-controls" style="text-align:left">
      <label>#{ $l == :ja ? '表示開始年' : 'Display from' }
        <input id="start-year-slider" type="range" min="1950" max="2020" step="1" value="#{default_start_year}">
        <output id="start-year-output">#{cutoff_label.call(default_start_year)}</output>
      </label>
      &nbsp;
      <label style="#{selected_period == 'weekly' ? 'display:none' : ''}">#{ $l == :ja ? "学習期間 #{selected_period == 'calendar' ? '2000' : '1999'}–" : "Training period #{selected_period == 'calendar' ? '2000' : '1999'}–" }
        <input id="train-to-slider" type="range" min="#{cutoffs.min}" max="#{cutoffs.max}" step="1" value="#{default_cutoff}">
        <output id="train-to-output">#{cutoff_label.call(default_cutoff)}</output>
      </label>
      &nbsp;
      <label><input id="zero-base-checkbox" type="checkbox" #{checked(zero_base)}>
        #{ $l == :ja ? 'Y軸を0から表示' : 'Start Y-axis at zero' }
      </label>
      #{weekly_excess_enabled ? %(
      &nbsp;
      <label><input id="deficit-checkbox" type="checkbox" #{checked(include_deficit)}>
        #{ $l == :ja ? '過少死亡も表示・累積' : 'Show and accumulate mortality deficits' }
      </label>) : ''}
      #{covid_overlay_available ? %(
      &nbsp;
      <label><input id="covid-overlay-checkbox" type="checkbox" #{checked(covid_overlay)}>
        #{ $l == :ja ? '新型コロナ死亡を重ねる' : 'Overlay COVID-19 deaths' }
      </label>) : ''}
      #{vaxx_overlay_available ? %(
      &nbsp;
      <label><input id="vaxx-overlay-checkbox" type="checkbox" #{checked(vaxx_overlay)}>
        #{ $l == :ja ? 'ワクチン全体接種を重ねる' : 'Overlay all vaccine doses' }
      </label>) : ''}
      #{detail_series.any? && selected_period != 'weekly' ? %(
      &nbsp;
      <label><input id="weekly-view-checkbox" type="checkbox">
        #{ if monthly_supplement_enabled
             $l == :ja ? '週次・月次表示' : 'Weekly/monthly view'
           else
             $l == :ja ? '週次表示' : 'Weekly view'
           end }
      </label>) : ''}
      &nbsp;
      <span style="#{selected_period == 'weekly' ? 'display:none' : ''}">#{ $l == :ja ? 'モデル' : 'Model' }:</span>
      <label style="#{selected_period == 'weekly' ? 'display:none' : ''}"><input class="model-option" type="radio" name="chart_model" value="quasi_poisson" #{checked(default_model == 'quasi_poisson')}>
        #{ $l == :ja ? '準ポアソン' : 'Quasi-Poisson' }
      </label>
      <label style="#{selected_period == 'weekly' ? 'display:none' : ''}"><input class="model-option" type="radio" name="chart_model" value="poisson" #{checked(default_model == 'poisson')}>
        #{ $l == :ja ? 'ポアソン' : 'Poisson' }
      </label>
      <!-- 推定φの計算値はchart dataに残すが、画面には表示しない。
           Keep estimated dispersion in chart data, but do not display it. -->
      <!-- <output id="dispersion-output"></output> -->
      &nbsp;
      <label id="simulation-interval-control" style="display:none"><input id="simulation-interval-checkbox" type="checkbox" #{'checked' unless interval_mode == 'analytic'}>
        #{ $l == :ja ? 'シミュレーション区間を表示（未計算時は近似区間。1分以上待って再読込み）' : 'Show simulated interval (if unavailable, the approximate interval is shown; wait at least one minute and resubmit)' }
      </label>
    </p>
    <div id="mortyear-vis"></div>
    <script>
      const values = #{JSON.generate(chart_data)};
      const weeklyValues = #{JSON.generate(weekly_context)};
      const overlayValues = #{JSON.generate(overlay_values)};
      const detailSeries = #{JSON.generate(detail_series)};
      const displayStartDefault = #{default_start_year};
      const trainMin = #{cutoffs.min};
      const trainMax = #{cutoffs.max};
      const trainDefault = #{default_cutoff};
      const periodYearLabel = year => String(year);
      const modelDefault = #{JSON.generate(default_model)};
      const intervalModeDefault = #{JSON.generate(interval_mode)};
      const excessRateWeekFactor = #{selected_metric == 'deaths' ? '1' : (7.0 / DAYS_PER_YEAR).to_s};
      const excessCumulativeStart = #{weekly_cumulative_start};
      const panels = #{JSON.generate(available_specs.map { |key, _age, _cause, label| [key, label, mode == 'country' ? key.split('--').first.downcase : selected_locations.first.downcase] })};
      const dispersionLabels = #{JSON.generate(dispersion_labels)};
      const startWeek = #{start_week};
      const displayStartDate = year => #{%w[calendar weekly].include?(selected_period) ? '`${year}-01-01`' : '`${year + 1}-01-01`'};
      const annualTooltip = [
        #{selected_period == 'calendar' ?
          %({field:"year", type:"quantitative", title:#{JSON.generate($l == :ja ? '年' : 'Year')}}) :
          %({field:"season", type:"nominal", title:#{JSON.generate($l == :ja ? '期間' : 'Season')}})},
        {field:"observed", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '観測値' : 'Observed')}},
        {field:"expected", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '予測値' : 'Expected')}},
        {field:"pi_lower", type:"quantitative", format:".2f", title:"PI lower"},
        {field:"pi_upper", type:"quantitative", format:".2f", title:"PI upper"},
        {field:"population", type:"quantitative", format:",d", title:#{JSON.generate(denominator_title)}},
        {field:"dispersion", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '分散比' : 'Dispersion')}},
        {field:"interval_label", type:"nominal", title:#{JSON.generate($l == :ja ? '区間計算' : 'Interval method')}}
      ];
      const weeklyTooltip = [
        {field:"date", type:"temporal", title:#{JSON.generate($l == :ja ? '週末日' : 'Week ending')}},
        {field:"observed", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '観測値' : 'Observed')}},
        {field:"expected", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '基準値' : 'Baseline')}},
        {field:"lower", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '下限' : 'Lower')}},
        {field:"upper", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '上限' : 'Upper')}},
        {field:"excess_lower", type:"quantitative", format:".2f", title:#{JSON.generate(weekly_excess_lower_title)}},
        {field:"excess_upper", type:"quantitative", format:".2f", title:#{JSON.generate(weekly_excess_upper_title)}}
      ];
      const excessTooltip = [
        {field:"date", type:"temporal", title:#{JSON.generate($l == :ja ? '週末日' : 'Week ending')}},
        {field:"display_excess_lower", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '予測範囲外の差' : 'Difference outside prediction range')}},
        {field:"display_excess_upper", type:"quantitative", format:".2f", title:#{JSON.generate($l == :ja ? '基準線との差' : 'Difference from baseline')}}
      ];
      const annualTransforms = [
        {filter: "!primary_weekly"},
        {filter: "toDate(datum.plot_date) >= toDate(display_start_date) && toDate(datum.plot_date) <= now()"},
        {filter: "datum.train_to == train_to"},
        {filter: "datum.model == model"},
        {filter: "interval_mode == 'analytic' ? datum.interval_method == 'analytic' : datum.auto_selected"}
      ];
      const predictionTransforms = [...annualTransforms, {filter: "datum.year >= training_start"}];
      const panelSpecs = panels.map(([key, label, panelLoc]) => ({
        title: {text: label, anchor: "start"},
        width: "container", height: 260,
        transform: [
          {filter: `datum.series == '${key}'`}
        ],
        encoding: {
          x: {field: "plot_date", type: "temporal", scale: {domainMin: {expr: "toDate(display_start_date)"}, domainMax: {expr: "now()"}, nice: false}, axis: #{weekly_excess_enabled ? '{labels:false,ticks:false,domain:false,title:null}' : %({format:"%Y",tickCount:{interval:"year",step:1},labelOverlap:"greedy",labelSeparation:6})}, title: #{JSON.generate(if weekly_excess_enabled
            nil
          elsif %w[calendar weekly].include?(selected_period)
            $l == :ja ? '年' : 'Year'
          else
            start_week = selected_period == 'flu27' ? 27 : 36
            $l == :ja ? "インフルエンザ年（第#{start_week}週開始）" : "Influenza year (starts in W#{start_week})"
          end)}}
        },
        layer: [{layer: [
          {transform: predictionTransforms, mark: {type: "area", opacity: 0.55, clip: true}, encoding: {color: {field:"interval_style", type:"nominal", scale:{domain:["quasi_poisson","poisson","simulation"], range:["#c7dff0","#cde8cf","#eadfc2"]}, legend:null}, y: {field: "pi_lower", type: "quantitative", title: #{JSON.generate(y_axis_title)}, scale: {zero: {expr: "zero_base || show_covid_overlay"}}}, y2: {field: "pi_upper"}}},
          {transform: predictionTransforms, mark: {type: "line", strokeDash: [6,4], strokeWidth: 2, clip: true}, encoding: {color:{field:"interval_style", type:"nominal", scale:{domain:["quasi_poisson","poisson","simulation"], range:["#246a9e","#287a3d","#88733b"]}, legend:null}, y: {field: "expected", type: "quantitative"}}},
          {transform: [...annualTransforms, {filter:"view_mode == 'annual' || indexof(detail_series, datum.series) < 0"}], mark: {type: "line", color: "#c83e4d", strokeWidth: 2, point: true, clip: true}, encoding: {y: {field: "observed", type: "quantitative"}}},
          {data:{values:weeklyValues}, transform:[{filter:`datum.series == '${key}'`},{filter:"view_mode == 'weekly'"},{filter:"isValid(datum.expected)"},{filter:"toDate(datum.date) >= toDate(display_start_date) && toDate(datum.date) <= now()"}], mark:{type:"area", color:"#5b8db8", opacity:0.24, clip:true}, encoding:{x:{field:"date",type:"temporal"}, y:{field:"lower",type:"quantitative"}, y2:{field:"upper"}}},
          {data:{values:weeklyValues}, transform:[{filter:`datum.series == '${key}'`},{filter:"view_mode == 'weekly'"},{filter:"isValid(datum.expected)"},{filter:"toDate(datum.date) >= toDate(display_start_date) && toDate(datum.date) <= now()"}], mark:{type:"line", color:"#174a73", strokeDash:[7,4], strokeWidth:2, clip:true}, encoding:{x:{field:"date",type:"temporal"}, y:{field:"expected",type:"quantitative"}}},
          {data:{values:weeklyValues}, transform:[{filter:`datum.series == '${key}'`},{filter:"view_mode == 'weekly'"},{filter:"toDate(datum.date) >= toDate(display_start_date) && toDate(datum.date) <= now()"}], mark:{type:"line", color:"#c83e4d", strokeWidth:1.5, clip:true}, encoding:{x:{field:"date",type:"temporal"}, y:{field:"observed",type:"quantitative",title:#{JSON.generate(y_axis_title)}}}},
          {data:{values:weeklyValues}, transform:[{filter:`datum.series == '${key}'`},{filter:"view_mode == 'weekly'"},{filter:"isValid(datum.observed)"},{filter:"toDate(datum.date) >= toDate(display_start_date) && toDate(datum.date) <= now()"}], mark:{type:"point", opacity:0, size:260, clip:true}, encoding:{x:{field:"date",type:"temporal"}, y:{field:"observed",type:"quantitative"}, tooltip:weeklyTooltip}},
          {transform:[...predictionTransforms,{filter:"datum.outside_pi"},{filter:"view_mode == 'annual' || indexof(detail_series, datum.series) < 0"}], mark:{type:"point", color:"#111", filled:false, size:100, strokeWidth:2, clip:true}, encoding:{y:{field:"observed",type:"quantitative"}}},
          {transform:annualTransforms, mark:{type:"point", opacity:0, size:320, clip:true}, encoding:{y:{field:"observed",type:"quantitative"}, tooltip:annualTooltip}},
          {data:{values:[{plot_date:displayStartDate(#{$mortyear_training_start})}]}, transform:[{filter:"!primary_weekly"}], mark:{type:"rule", color:"#555", strokeDash:[3,3], clip:true}, encoding:{x:{field:"plot_date",type:"temporal"}}},
          {transform:[...annualTransforms,{filter:"datum.year == train_to"}], mark:{type:"rule", color:"#555", strokeDash:[3,3]}}
        ]},
          {data:{values:overlayValues},transform:[{filter:`datum.loc == '${panelLoc}' && datum.overlay == 'covid'`},{filter:"show_covid_overlay"},{filter:"toDate(datum.date) >= toDate(display_start_date) && toDate(datum.date) <= now()"}],mark:{type:"line",color:"#6f42c1",strokeWidth:2,clip:true},encoding:{x:{field:"date",type:"temporal"},y:{field:"value",type:"quantitative",axis:{orient:"right",title:#{JSON.generate(covid_overlay_title)},titleColor:"#6f42c1",labelColor:"#6f42c1",tickColor:"#6f42c1",domainColor:"#6f42c1"}},tooltip:[{field:"date",type:"temporal",title:#{JSON.generate($l == :ja ? '週末日' : 'Week ending')}},{field:"value",type:"quantitative",format:#{JSON.generate(covid_overlay_format)},title:#{JSON.generate(covid_overlay_title)}}]}}
        ],
        resolve:{scale:{y:"shared"},axis:{y:"independent"}}
      }));
      const excessPanelSpec = (key, cumulative) => ({
        title:{text:{expr:cumulative ? "include_deficit ? deficit_cumulative_title : excess_cumulative_title" : "include_deficit ? deficit_trend_title : excess_trend_title"},anchor:"start",fontSize:15},
        width:"container",height:115,
        data:{values:weeklyValues},
        transform:[
          {filter:`datum.series == '${key}'`},
          {filter:"isValid(datum.excess_upper)"},
          {calculate:"year(toDate(datum.date)) >= excess_cumulative_start ? (include_deficit ? datum.outside_deviation : datum.excess_lower) * excess_rate_week_factor : 0",as:"excess_lower_increment"},
          {calculate:"year(toDate(datum.date)) >= excess_cumulative_start ? (include_deficit ? datum.excess : datum.excess_upper) * excess_rate_week_factor : 0",as:"excess_upper_increment"},
          {window:[{op:"sum",field:"excess_lower_increment",as:"cumulative_excess_lower"},{op:"sum",field:"excess_upper_increment",as:"cumulative_excess_upper"}],sort:[{field:"date",order:"ascending"}],frame:[null,0]},
          {calculate:cumulative ? "year(toDate(datum.date)) >= excess_cumulative_start ? datum.cumulative_excess_lower : null" : "include_deficit ? datum.outside_deviation : datum.excess_lower",as:"display_excess_lower"},
          {calculate:cumulative ? "year(toDate(datum.date)) >= excess_cumulative_start ? datum.cumulative_excess_upper : null" : "include_deficit ? datum.excess : datum.excess_upper",as:"display_excess_upper"},
          {filter:"toDate(datum.date) >= toDate(display_start_date) && toDate(datum.date) <= now()"}
        ],
        encoding:{
          x:{field:"date",type:"temporal",scale:{domainMin:{expr:"toDate(display_start_date)"},domainMax:{expr:"now()"},nice:false},axis:{format:"%Y",tickCount:{interval:"year",step:1},labelOverlap:"greedy",labelSeparation:6},title:#{JSON.generate($l == :ja ? '年' : 'Year')}}
        },
        layer:[
          {layer:[
            {mark:{type:"bar",clip:true},encoding:{color:{condition:{test:"datum.display_excess_upper < 0",value:"#91b9dc"},value:"#e7a0a5",legend:null},y:{field:"display_excess_upper",type:"quantitative",scale:{zero:true},title:{expr:"include_deficit ? deficit_axis_title : excess_axis_title"}},y2:{datum:0}}},
            {mark:{type:"bar",clip:true},encoding:{color:{condition:{test:"datum.display_excess_lower < 0",value:"#326f9f"},value:"#b92f3a",legend:null},y:{field:"display_excess_lower",type:"quantitative",scale:{zero:true},title:{expr:"include_deficit ? deficit_axis_title : excess_axis_title"}},y2:{datum:0}}},
            {mark:{type:"point",opacity:0,size:220,clip:true},encoding:{y:{field:"display_excess_upper",type:"quantitative"},tooltip:excessTooltip}}
          ]},
          ...(cumulative ? [] : [{data:{values:overlayValues},transform:[{filter:`datum.loc == '${panels.find(panel => panel[0] == key)[2]}' && datum.overlay == 'vaxx'`},{filter:"show_vaxx_overlay"},{filter:"toDate(datum.date) >= toDate(display_start_date) && toDate(datum.date) <= now()"}],mark:{type:"line",color:"#16835b",strokeWidth:2,clip:true},encoding:{x:{field:"date",type:"temporal"},y:{field:"value",type:"quantitative",scale:{zero:true},title:#{JSON.generate($l == :ja ? 'ワクチン全体接種' : 'All vaccine doses')},axis:{orient:"right",titleColor:"#16835b",labelColor:"#16835b"}},tooltip:[{field:"date",type:"temporal",title:#{JSON.generate($l == :ja ? '週末日' : 'Week ending')}},{field:"value",type:"quantitative",format:",.0f",title:#{JSON.generate($l == :ja ? 'ワクチン全体接種' : 'All vaccine doses')}}]}}])
        ],
        resolve:{scale:{y:"independent"}}
      });
      const chartSpecs = [];
      panelSpecs.forEach((panel, index) => {
        chartSpecs.push(panel);
        if (#{weekly_excess_enabled ? 'true' : 'false'}) {
          const key = panels[index][0];
          chartSpecs.push(excessPanelSpec(key, false));
          chartSpecs.push(excessPanelSpec(key, true));
        }
      });
      const spec = {
        $schema: "https://vega.github.io/schema/vega-lite/v5.json",
        data: {values},
        params: [
          {name:"display_start", value:displayStartDefault},
          {name:"display_start_date", value:displayStartDate(displayStartDefault)},
          {name:"training_start", value:#{$mortyear_training_start}},
          {name:"train_to", value:trainDefault},
          {name:"model", value:modelDefault},
          {name:"interval_mode", value:intervalModeDefault},
          {name:"zero_base", value:#{zero_base ? 'true' : 'false'}},
          {name:"show_covid_overlay", value:#{covid_overlay ? 'true' : 'false'}},
          {name:"show_vaxx_overlay", value:#{vaxx_overlay ? 'true' : 'false'}},
          {name:"include_deficit", value:#{include_deficit ? 'true' : 'false'}},
          {name:"excess_axis_title", value:#{JSON.generate(weekly_excess_title)}},
          {name:"deficit_axis_title", value:#{JSON.generate(weekly_deficit_title)}},
          {name:"excess_trend_title", value:#{JSON.generate(weekly_excess_trend_title)}},
          {name:"deficit_trend_title", value:#{JSON.generate(weekly_deficit_trend_title)}},
          {name:"excess_cumulative_title", value:#{JSON.generate(weekly_excess_cumulative_title)}},
          {name:"deficit_cumulative_title", value:#{JSON.generate(weekly_deficit_cumulative_title)}},
          {name:"excess_rate_week_factor", value:excessRateWeekFactor},
          {name:"excess_cumulative_start", value:excessCumulativeStart},
          {name:"primary_weekly", value:#{selected_period == 'weekly' ? 'true' : 'false'}},
          {name:"view_mode", value:#{JSON.generate(selected_period == 'weekly' ? 'weekly' : 'annual')}},
          {name:"detail_series", value:detailSeries}
        ],
        vconcat: chartSpecs,
        autosize: {type:"fit-x", contains:"padding", resize:true},
        resolve: {scale: {y: "independent"}},
        config: {view:{stroke:null}, axis:{labelFontSize:15,titleFontSize:17}, axisY:{minExtent:84,maxExtent:84}, title:{fontSize:19}}
      };
      vegaEmbed("#mortyear-vis", spec, {mode:"vega-lite", actions:false}).then(result => {
        window.mortyearView = result.view;
        const slider = document.getElementById("train-to-slider");
        const startSlider = document.getElementById("start-year-slider");
        const startOutput = document.getElementById("start-year-output");
        const output = document.getElementById("train-to-output");
        const modelOptions = Array.from(document.querySelectorAll(".model-option"));
        const zeroBase = document.getElementById("zero-base-checkbox");
        const deficit = document.getElementById("deficit-checkbox");
        const covidOverlay = document.getElementById("covid-overlay-checkbox");
        const vaxxOverlay = document.getElementById("vaxx-overlay-checkbox");
        const simulationControl = document.getElementById("simulation-interval-control");
        const simulationInterval = document.getElementById("simulation-interval-checkbox");
        const weeklyView = document.getElementById("weekly-view-checkbox");
        // 日本語: browserのform復元値より、URLから決めた表示開始年と学習終了年を優先する。
        // English: Prefer the years derived from the URL over browser-restored form values.
        startSlider.value = String(displayStartDefault);
        startOutput.value = periodYearLabel(displayStartDefault);
        document.getElementById("start-year-hidden").value = String(displayStartDefault);
        slider.value = String(trainDefault);
        output.value = periodYearLabel(trainDefault);
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
          startOutput.value = periodYearLabel(value);
          document.getElementById("start-year-hidden").value = value;
          const url = new URL(window.location.href);
          url.searchParams.set("start_year", value);
          history.replaceState(null, "", url);
          result.view.signal("display_start", value).signal("display_start_date", displayStartDate(value)).runAsync();
        });
        slider.addEventListener("input", () => {
          const value = Number(slider.value);
          output.value = periodYearLabel(value);
          // updateDispersion(value); // 推定φは現在非表示。Estimated phi is currently hidden.
          result.view.signal("train_to", value).runAsync();
        });
        function syncModelControls(updateUrl = false) {
          const model = document.querySelector(".model-option:checked").value;
          result.view.signal("model", model).runAsync();
          if (updateUrl) {
            const url = new URL(window.location.href);
            url.searchParams.set("chart_model", model);
            history.replaceState(null, "", url);
          }
          simulationControl.style.display = model === "poisson" ? "" : "none";
        }
        modelOptions.forEach(input => input.addEventListener("change", () => syncModelControls(true)));
        syncModelControls();
        const syncZeroBase = () => {
          result.view.signal("zero_base", zeroBase.checked).runAsync();
          const url = new URL(window.location.href);
          if (zeroBase.checked) url.searchParams.set("zero_base", "1");
          else url.searchParams.delete("zero_base");
          history.replaceState(null, "", url);
        };
        zeroBase.addEventListener("change", syncZeroBase);
        window.addEventListener("pageshow", syncZeroBase);
        syncZeroBase();
        if (deficit) {
          const syncDeficit = () => {
            result.view.signal("include_deficit", deficit.checked).runAsync();
            const url = new URL(window.location.href);
            if (deficit.checked) url.searchParams.set("include_deficit", "1");
            else url.searchParams.delete("include_deficit");
            history.replaceState(null, "", url);
          };
          deficit.addEventListener("change", syncDeficit);
          window.addEventListener("pageshow", syncDeficit);
          syncDeficit();
        }
        if (covidOverlay) {
          const syncCovidOverlay = () => {
            result.view.signal("show_covid_overlay", covidOverlay.checked).runAsync();
            const url = new URL(window.location.href);
            if (covidOverlay.checked) url.searchParams.set("covid_overlay", "1");
            else url.searchParams.delete("covid_overlay");
            history.replaceState(null, "", url);
          };
          covidOverlay.addEventListener("change", syncCovidOverlay);
          window.addEventListener("pageshow", syncCovidOverlay);
          syncCovidOverlay();
        }
        if (vaxxOverlay) {
          const syncVaxxOverlay = () => {
            result.view.signal("show_vaxx_overlay", vaxxOverlay.checked).runAsync();
            const url = new URL(window.location.href);
            if (vaxxOverlay.checked) url.searchParams.set("vaxx_overlay", "1");
            else url.searchParams.delete("vaxx_overlay");
            history.replaceState(null, "", url);
          };
          vaxxOverlay.addEventListener("change", syncVaxxOverlay);
          window.addEventListener("pageshow", syncVaxxOverlay);
          syncVaxxOverlay();
        }
        simulationInterval.addEventListener("change", () => {
          const value = simulationInterval.checked ? "auto" : "analytic";
          result.view.signal("interval_mode", value).runAsync();
          const url = new URL(window.location.href);
          url.searchParams.set("interval", value);
          history.replaceState(null, "", url);
        });
        if (weeklyView) {
          const syncDetailView = () => {
            result.view.signal("view_mode", weeklyView.checked ? "weekly" : "annual").runAsync();
          };
          weeklyView.addEventListener("change", syncDetailView);
          window.addEventListener("pageshow", syncDetailView);
          // reload時にブラウザが復元したcheckboxの状態を初期描画にも反映する。
          // Apply the checkbox state restored by the browser to the initial chart as well.
          syncDetailView();
        }
        result.view.addSignalListener("train_to", (_name, value) => {
          const url = new URL(window.location.href);
          url.searchParams.set("train_to", value);
          history.replaceState(null, "", url);
          document.getElementById("train-to-hidden").value = value;
        });
      }).catch(console.warn);
    </script>
    <p class="mortyear-note">
      #{ interval_note + ' ' + unit_note + (selected_metric == 'std_deaths' ? ($l == :ja ? ' 日本の週次派生系列を完全な暦年へ集計し、年境界週の死亡数は日数按分しています。' : ' Japanese derived weekly series are aggregated into complete calendar years, and boundary weeks are prorated by days.') : '') + approximation_note }
    </p>
    #{coverage_html ? %(<section class="mortyear-coverage" style="text-align:left"><h2>#{CGI.escapeHTML($l == :ja ? '対応している国・地域数' : 'Countries and areas covered')}</h2><ul>#{coverage_html}</ul></section>) : ''}
    <section class="mortyear-sources" style="text-align:left">
      <h2>#{ $l == :ja ? 'グラフに使用したデータ' : 'Data used for the graphs' }</h2>
      <ul>#{source_items}</ul>
      #{method_notes}
    </section>
  HTML
end

puts <<~HTML
  </div>
  </div>
  </body>
  </html>
HTML
