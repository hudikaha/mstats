#!/usr/bin/ruby
# coding: utf-8

require 'csv'
require 'date'
require 'optparse'
require_relative 'mstats2026'

ALL_CAUSE_SOURCE_URL = 'https://exdeaths-japan.org/data/Observed.csv'.freeze
CAUSE_SOURCE_URL = 'https://exdeaths-japan.org/data/Observed.csv.zip'.freeze

# dashboardの都道府県番号を日英名称へ対応させる。locは別途jp01〜jp47へ変換する。
# Map dashboard prefecture numbers to bilingual names; loc is converted separately to jp01-jp47.
PREFECTURES = [
  %w[Hokkaido 北海道], %w[Aomori 青森県], %w[Iwate 岩手県],
  %w[Miyagi 宮城県], %w[Akita 秋田県], %w[Yamagata 山形県],
  %w[Fukushima 福島県], %w[Ibaraki 茨城県], %w[Tochigi 栃木県],
  %w[Gunma 群馬県], %w[Saitama 埼玉県], %w[Chiba 千葉県],
  %w[Tokyo 東京都], %w[Kanagawa 神奈川県], %w[Niigata 新潟県],
  %w[Toyama 富山県], %w[Ishikawa 石川県], %w[Fukui 福井県],
  %w[Yamanashi 山梨県], %w[Nagano 長野県], %w[Gifu 岐阜県],
  %w[Shizuoka 静岡県], %w[Aichi 愛知県], %w[Mie 三重県],
  %w[Shiga 滋賀県], %w[Kyoto 京都府], %w[Osaka 大阪府],
  %w[Hyogo 兵庫県], %w[Nara 奈良県], %w[Wakayama 和歌山県],
  %w[Tottori 鳥取県], %w[Shimane 島根県], %w[Okayama 岡山県],
  %w[Hiroshima 広島県], %w[Yamaguchi 山口県], %w[Tokushima 徳島県],
  %w[Kagawa 香川県], %w[Ehime 愛媛県], %w[Kochi 高知県],
  %w[Fukuoka 福岡県], %w[Saga 佐賀県], %w[Nagasaki 長崎県],
  %w[Kumamoto 熊本県], %w[Oita 大分県], %w[Miyazaki 宮崎県],
  %w[Kagoshima 鹿児島県], %w[Okinawa 沖縄県]
].each_with_index.to_h { |values, index| [(index + 1).to_s, values] }.
  merge('48' => %w[Japan 日本]).freeze

CAUSES = {
  'allcause' => ['allcause', 'All causes'],
  'respiratory' => ['10000', 'Diseases of the respiratory system'],
  'circulatory' => ['09000', 'Diseases of the circulatory system'],
  'cancer' => ['02100', 'Malignant neoplasms'],
  'senility' => ['18100', 'Senility'],
  'suicide' => ['20200', 'Suicide'],
  'covid19' => ['22200', 'COVID-19']
}.freeze

options = { prefecture_ids: nil, through: nil }
OptionParser.new do |parser|
  parser.on('--prefecture-ids IDS', 'Comma-separated dashboard IDs') do |value|
    options[:prefecture_ids] = value.split(',')
  end
  parser.on('--through DATE', 'Include weeks ending on or before DATE') do |value|
    options[:through] = Date.iso8601(value)
  end
end.parse!(ARGV)
abort 'Usage: exdeaths-weekly.rb [--prefecture-ids 48] ALL.csv CAUSE_DIR' unless ARGV.length == 2

all_path, cause_dir = ARGV
paths = {
  'allcause' => all_path,
  'non_covid' => File.join(cause_dir, 'Observed_non-COVID-19.csv'),
  'respiratory' => File.join(cause_dir, 'Observed_Respiratory.csv'),
  'circulatory' => File.join(cause_dir, 'Observed_Circulatory.csv'),
  'cancer' => File.join(cause_dir, 'Observed_Cancer.csv'),
  'senility' => File.join(cause_dir, 'Observed_Senility.csv'),
  'suicide' => File.join(cause_dir, 'Observed_Suicide.csv')
}
paths.each_value { |path| abort "Missing source CSV: #{path}" unless File.file?(path) }

# 補正済み観測値だけを読み、地域・週を共通keyにする。
# Read only corrected observations and key them consistently by area and week.
def read_weighted(path, selected_ids, through)
  CSV.foreach(path, headers: true).each_with_object({}) do |source, rows|
    id = source['prefecture_id']
    next if selected_ids && !selected_ids.include?(id)
    value = source['Observed_weighted']
    raise "Missing Observed_weighted: #{path}: #{source.inspect}" if value.nil? || value.empty?

    date = Date.strptime(source['week_ending_date'], '%d%b%Y')
    next if through && date > through
    rows[[id, date]] = Float(value)
  end
end

source_values = paths.transform_values do |path|
  read_weighted(path, options[:prefecture_ids], options[:through])
end
cause_keys = source_values.fetch('respiratory').keys.sort
%w[circulatory cancer senility suicide non_covid].each do |name|
  values = source_values.fetch(name)
  missing = cause_keys - values.keys
  extra = values.keys - cause_keys
  raise "Cause source keys differ for #{name}: missing=#{missing.length} extra=#{extra.length}" unless missing.empty? && extra.empty?
end

rows = {}
CAUSES.each_key do |name|
  values = if name == 'covid19'
             source_values.fetch('non_covid').select { |(_id, date), _value| date >= Date.new(2020, 1, 1) }.to_h do |key, non_covid|
               [key, source_values.fetch('allcause').fetch(key) - non_covid]
             end
           else
             source_values.fetch(name)
           end
  values.sort_by { |(prefecture_id, date), _value| [prefecture_id.to_i, date] }.each do |(prefecture_id, date), value|
    area, _areaj = PREFECTURES.fetch(prefecture_id)
    loc = prefecture_id == '48' ? 'jpn' : format('jp%02d', prefecture_id.to_i)
    period = format('%04dw%02d', date.cwyear, date.cweek)
    if value.negative?
      warn "Omit negative derived COVID-19 value: #{loc} #{period} #{value}"
      next
    end
    dcode, death_cause = CAUSES.fetch(name)
    id = Mstats2026.record_id(loc: loc, period: period, category: 'death',
                              dcode: dcode, type: 'stmf', sex: 'both')
    rows[id] = {
      id: id, loc: loc, area: area,
      yearweek: period, category: 'death', rate: '', dcode: dcode,
      death_cause: death_cause, algo: '', type: 'stmf',
      src_url: name == 'allcause' ? [ALL_CAUSE_SOURCE_URL] :
        (name == 'covid19' ? [ALL_CAUSE_SOURCE_URL, CAUSE_SOURCE_URL] : [CAUSE_SOURCE_URL]),
      date: date.iso8601, year: date.cwyear, week: date.cweek, sex: 'both', age_all: value.round(2)
    }
  end
end

Mstats2026.output_weekly(rows)
