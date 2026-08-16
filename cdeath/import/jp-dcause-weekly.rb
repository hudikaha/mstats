#!/usr/bin/ruby
# coding: utf-8

require 'csv'
require 'date'
require 'optparse'
require_relative 'mstats2026'

BASE_AGE_GROUPS = {
  age_all: %i[
    age_00_04 age_05_09 age_10_14 age_15_19 age_20_24 age_25_29
    age_30_34 age_35_39 age_40_44 age_45_49 age_50_54 age_55_59
    age_60_64 age_65_69 age_70_74 age_75_79 age_80_84 age_85_89
    age_90_94 age_95_99 age_100plus
  ],
  age_00_14: %i[age_00_04 age_05_09 age_10_14],
  age_15_64: %i[
    age_15_19 age_20_24 age_25_29 age_30_34 age_35_39
    age_40_44 age_45_49 age_50_54 age_55_59 age_60_64
  ],
  age_65_74: %i[age_65_69 age_70_74],
  age_75_84: %i[age_75_79 age_80_84],
  age_85plus: %i[age_85_89 age_90_94 age_95_99 age_100plus],
  age_05_14: %i[age_05_09 age_10_14],
  age_15_29: %i[age_15_19 age_20_24 age_25_29],
  age_30_49: %i[age_30_34 age_35_39 age_40_44 age_45_49],
  age_50_64: %i[age_50_54 age_55_59 age_60_64]
}.freeze

RATE_AGE_GROUPS = BASE_AGE_GROUPS.merge(
  BASE_AGE_GROUPS[:age_all].to_h { |age| [age, [age]] }
).freeze

OUTPUT_AGES = (Mstats2026::AGE_FIELDS + Mstats2026::AGGREGATE_AGE_FIELDS).
                map(&:to_sym).uniq.freeze

WEEK_SLICES = {}

# CSVの空欄を欠測のまま数値へ変換する。
# Convert CSV values to numbers while preserving empty fields as missing.
def number(value)
  return value if value.is_a?(Numeric)
  return nil if value.nil? || value.empty?
  # 日本語: 月次死亡CSVの「-」はjp-dcause.rbで0へ解決済みでなければならない。
  # English: jp-dcause.rb must resolve monthly death CSV dashes to zero before this stage.
  if %w[- ・].include?(value)
    raise ArgumentError, "unresolved source marker in canonical monthly CSV: #{value.inspect}"
  end

  value.include?('.') ? Float(value) : Integer(value)
end

# mstats2026 CSVをIDで検索できるレコードへ変換する。
# Read an mstats2026 CSV into records addressable by canonical ID.
def read_records(path)
  CSV.read(path, headers: true).to_h do |csv_row|
    row = csv_row.to_h.to_h do |key, value|
      converted = if key.start_with?('age_')
                    number(value)
                  elsif key == 'src_url' && value&.start_with?('[')
                    JSON.parse(value)
                  else
                    value
                  end
      [key.to_sym, converted]
    end
    row[:year] = row[:year].to_i
    row[:month] = row[:month].to_i if row[:month]
    # 日本語: 物理index移行時だけ旧CSVを読めるようにし、出力は常に新fieldへ統一する。
    # English: Accept old CSV fields only during physical-index migration and always emit the new schema.
    row[:loc] ||= row.delete(:loc_code)
    row[:area] ||= row.delete(:location)
    %i[rate algo type].each { |field| row[field] = row[field].to_s }
    [row.fetch(:id), row]
  end
end

# memory上の月次recordを週次計算用の数値recordへ変換する。
# Normalize in-memory monthly records into numeric records for weekly calculations.
def normalize_records(records)
  records.each_value do |row|
    row.each do |key, value|
      if key.to_s.start_with?('age_')
        row[key.to_sym] = number(value)
      elsif !key.is_a?(Symbol)
        row[key.to_sym] = value
        row.delete(key)
      end
    end
    row[:year] = row[:year].to_i
    row[:month] = row[:month].to_i if row[:month]
    %i[rate algo type].each { |field| row[field] = row[field].to_s }
  end
  records
end

# 基礎年齢階級から表示用の集約年齢階級を作る。
# Build display age bands from the underlying five-year age groups.
def add_age_groups(row)
  BASE_AGE_GROUPS.each do |target, members|
    next unless row[target].nil?

    values = members.map { |age| row[age] }
    row[target] = values.sum if values.none?(&:nil?)
  end
  row
end

# 人口の年齢階級に合わせ、85歳以上一括または詳細階級を選ぶ。
# Select the aggregate or detailed 85-plus bands according to the population record.
def rate_age_groups(population)
  # 日本語: 年齢内訳のない旧年人口では、全年齢同士だけで粗死亡率を計算する。
  # English: For historical population records without age strata, calculate only the all-age crude rate.
  detailed_ages = BASE_AGE_GROUPS[:age_all]
  return { age_all: [:age_all] } if population[:age_all] && detailed_ages.all? { |age| population[age].nil? }

  groups = RATE_AGE_GROUPS.dup
  return groups if population[:age_85_89]

  under_85 = BASE_AGE_GROUPS[:age_all].take_while { |age| age != :age_85_89 }
  groups[:age_all] = under_85 + [:age_85plus]
  groups[:age_85plus] = [:age_85plus]
  groups
end

# 月次実数と人口から週次再構成用の粗死亡率・二種類のASRを作る。
# Derive crude rates and two ASRs used to reconstruct the weekly series.
def monthly_series(deaths, populations)
  populations.each_value { |row| add_age_groups(row) }
  populations_by_key = populations.values.to_h do |row|
    [[row[:loc], row[:yearmonth], row[:type], row[:sex]], row]
  end
  latest_population = populations.values.
                        select { |row| row[:type] == 'cfm' }.
                        group_by { |row| row[:sex] }.
                        transform_values { |rows| rows.max_by { |row| row[:yearmonth] } }

  deaths.each_with_object({}) do |(id, source), rows|
    raw = add_age_groups(source.dup)
    raw[:type] = 'stmfrecon'
    raw[:id] = Mstats2026.record_id_for(raw)
    rows[raw[:id]] = raw

    population = populations_by_key[[source[:loc], source[:yearmonth], 'cfm', source[:sex]]]
    population ||= populations_by_key[[source[:loc], source[:yearmonth], 'est', source[:sex]]]
    next unless population

    days_in_year = Date.leap?(source[:year]) ? 366 : 365
    days_in_month = Date.new(source[:year], source[:month], -1).day
    annual_rate = lambda do |members|
      count_values = members.map { |age| raw[age] }
      pop_values = members.map { |age| population[age] }
      next nil if count_values.any?(&:nil?) || pop_values.any? { |value| !value&.positive? }

      count_values.sum.to_f * 100_000 * days_in_year / (pop_values.sum * days_in_month)
    end

    crude_id = Mstats2026.record_id(loc: source[:loc], period: source[:yearmonth],
                                    category: 'death', rate: 'crude', death_code: source[:death_code],
                                    type: 'stmfrecon', sex: source[:sex])
    crude = raw.dup
    crude[:id] = crude_id
    crude[:rate] = 'crude'
    crude[:algo] = ''
    crude[:src_url] = (Array(raw[:src_url]) | Array(population[:src_url])).reject { |url| url.to_s.empty? }
    OUTPUT_AGES.each { |age| crude[age] = nil }
    rate_age_groups(population).each do |target, members|
      # 日本語: 公式全年齢値があれば、年齢内訳の形式差に左右されず直接使う。
      # English: Use official all-age totals directly, independent of age-band layout changes.
      rate_members = target == :age_all && raw[:age_all] && population[:age_all] ? [:age_all] : members
      value = annual_rate.call(rate_members)
      crude[target] = value.round(2) if value
    end
    rows[crude_id] = crude

    standards = {
      'whostd' => Mstats2026::WHO_WORLD_STANDARD.transform_keys(&:to_sym).
                    transform_values { |weight| weight.to_f },
      'jp2015std' => Mstats2026::JPN_2015_STANDARD.each_with_object({}) do |(age, weight), result|
        members = age == 'age_95plus' ? %i[age_95_99 age_100plus] : [age.to_sym]
        result[members] = weight.to_f
      end
    }
    standards['whostd'] = standards['whostd'].to_h { |age, weight| [[age], weight] }
    unless population[:age_85_89]
      standards.transform_values! do |groups|
        younger = groups.reject { |members, _weight| members.any? { |age| BASE_AGE_GROUPS[:age_85plus].include?(age) } }
        older_weight = groups.sum do |members, weight|
          members.any? { |age| BASE_AGE_GROUPS[:age_85plus].include?(age) } ? weight : 0.0
        end
        younger.merge([:age_85plus] => older_weight)
      end
    end
    standards.each do |algo, groups|
      weighted = groups.sum do |members, weight|
        value = annual_rate.call(members)
        break nil unless value
        value * weight
      end
      next unless weighted

      asr_id = Mstats2026.record_id(loc: source[:loc], period: source[:yearmonth],
                                    category: 'death', rate: 'asr', death_code: source[:death_code],
                                    algo: algo, type: 'stmfrecon', sex: source[:sex])
      asr = crude.slice(:loc, :area, :yearmonth, :category, :death_code, :death_cause,
                        :type, :src_url, :date, :year, :month, :sex).merge(
                          id: asr_id, rate: 'asr', algo: algo,
                          age_all: (weighted / groups.values.sum).round(2)
                        )
      rows[asr_id] = asr
    end
  end
end

# 対象期間のISO週と月別日数を一度だけ計算し、全系列で共有する。
# Calculate ISO weeks and their days per month once, then share them across series.
def week_slices(first_date, last_date)
  WEEK_SLICES[[first_date, last_date]] ||= begin
    first_year = first_date.cwyear
    last_year = last_date.cwyear
    (first_year..last_year).flat_map do |year|
      (1..53).map do |week|
        sunday = Date.commercial(year, week, 7)
        monday = sunday - 6
        next if sunday < first_date || monday > last_date

        sources = (monday..sunday).
                    group_by { |date| [date.year, date.month] }.
                    map do |(calendar_year, month), days|
          period = format('%<year>04dm%<month>02d', year: calendar_year, month: month)
          [period, days.length, Date.new(calendar_year, month, -1).day]
        end
        [year, week, sunday, monday.month, sunday.month, sources]
      rescue ArgumentError
        nil
      end.compact
    end.freeze
  end
end

# 一つの月次系列をISO週へ日数按分する。
# Prorate one monthly series into ISO weeks according to days in each month.
def weekly_series(monthly)
  first = monthly.values.min_by { |row| row[:yearmonth] }
  last = monthly.values.max_by { |row| row[:yearmonth] }
  first_date = Date.new(first[:year], first[:month], 1)
  last_date = Date.new(last[:year], last[:month], -1)
  monthly_by_period = monthly.values.to_h { |row| [row[:yearmonth], row] }
  weeks = {}

  week_slices(first_date, last_date).each do |year, week, sunday, month1, month7, slices|
    sources = slices.map do |period, days, days_in_month|
      [monthly_by_period[period], days, days_in_month]
    end
    next unless sources.all? { |source, _days, _days_in_month| source }

    template = sources.first.first
    row = template.dup
    row.delete(:yearmonth)
    row.delete(:month)
    row[:yearweek] = format('%04dw%02d', year, week)
    row[:year] = year
    row[:week] = week
    row[:date] = sunday.to_s
    row[:id] = Mstats2026.record_id_for(row)
    row[:_month1] = month1
    row[:_month7] = month7

    OUTPUT_AGES.each do |age|
      total = 0.0
      missing = sources.any? do |source, days, days_in_month|
        value = source[age]
        next true if value.nil?

        divisor = %w[crude asr].include?(source[:rate]) ? 7 : days_in_month
        total += value.to_f * days / divisor
        false
      end
      row[age] = missing ? nil : total.round(2)
    end
    weeks[row[:id]] = row
  end
  smooth(weeks)
end

# 旧処理と同じ境界補正を週次系列へ適用する。
# Apply the legacy month-boundary smoothing to a weekly series.
def smooth(rows)
  previous = []
  rows.sort.to_h.each_value do |row|
    month1 = row[:_month1]
    month7 = row[:_month7]

    if previous[1] && previous[0] && previous[1][1] != previous[0][1] &&
       previous[0][2] == month7
      smooth_triplet(previous[1][0], previous[0][0], row, :left)
    end
    if previous[1] && previous[0] && month7 != previous[0][2] &&
       previous[0][1] == previous[1][1]
      smooth_triplet(previous[1][0], previous[0][0], row, :right)
    end
    previous.unshift([row, month1, month7])
  end
  rows
end

# 月境界で同値となった二週へ差分の一部を戻す。
# Redistribute part of a month-boundary step across adjacent weeks.
def smooth_triplet(older, middle, newer, direction)
  OUTPUT_AGES.each do |age|
    values = [older[age], middle[age], newer[age]]
    next unless values.all? { |value| value.is_a?(Numeric) }

    edge, repeated = direction == :left ? [older[age], middle[age]] : [newer[age], middle[age]]
    next unless middle[age] == (direction == :left ? newer[age] : older[age])

    difference = edge - repeated
    next if difference.zero?

    one_day = middle[age] / 7.0
    shift = difference.abs * 0.33 < one_day ? difference * 0.33 : (difference.positive? ? one_day : -one_day)
    if direction == :left
      older[age] = (older[age] - shift).round(2)
      middle[age] = (middle[age] + shift).round(2)
    else
      newer[age] = (newer[age] - shift).round(2)
      middle[age] = (middle[age] + shift).round(2)
    end
  end
end

# 月次死因recordと人口recordから週次raw・crude・asr系列を生成する。
# Generate weekly raw, crude, and ASR series from monthly deaths and populations.
def build_weekly(deaths, populations)
  monthly = monthly_series(deaths, populations)
  monthly.values.group_by do |row|
    [row[:loc], row[:rate], row[:death_code], row[:algo], row[:type], row[:sex]]
  end.each_with_object({}) do |(_key, series), rows|
    rows.merge!(weekly_series(series.to_h { |row| [row[:id], row] }))
  end
end

# 日本語: 確定月次を優先し、その最終月より後だけ概数・速報月次で補う。
# English: Prefer confirmed monthly records and append provisional records only after their last month.
def merge_preferred_monthly(current, preferred_path)
  return current unless preferred_path

  preferred = read_records(preferred_path)
  last_period = preferred.values.map { |row| row[:yearmonth] }.max
  current_after = current.select { |_id, row| row[:yearmonth] > last_period }
  preferred.merge(current_after)
end

if $PROGRAM_NAME == __FILE__
  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: jp-dcause-weekly.rb --population POP.csv DEATH.csv'
    opts.on('--population FILE', 'mstats2026 population CSV') do |file|
      options[:population] = file
    end
    opts.on('--preferred-monthly FILE', 'confirmed monthly death CSV used before current data') do |file|
      options[:preferred_monthly] = file
    end
  end.parse!

  abort 'population CSV is required: --population FILE' unless options[:population]
  abort 'one monthly death CSV is required' unless ARGV.length == 1

  deaths = read_records(ARGV.first)
  populations = read_records(options[:population])
  deaths = merge_preferred_monthly(deaths, options[:preferred_monthly])
  Mstats2026.output_weekly(build_weekly(deaths, populations))
end
