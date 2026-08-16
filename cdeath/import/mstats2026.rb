# coding: utf-8

require 'csv'
require 'json'

# 死因と人口を共通のmstats2026 CSV形式へ出力する。
# Emit cause-of-death and population records in the shared mstats2026 CSV schema.
module Mstats2026
  ID_FIELDS = %i[loc period category rate death_code algo type sex].freeze
  AREA_FILE = File.expand_path('../config/areas.json', __dir__)
  WHO_WORLD_STANDARD = {
    'age_00_04' => 8.86, 'age_05_09' => 8.69, 'age_10_14' => 8.60,
    'age_15_19' => 8.47, 'age_20_24' => 8.22, 'age_25_29' => 7.93,
    'age_30_34' => 7.61, 'age_35_39' => 7.15, 'age_40_44' => 6.59,
    'age_45_49' => 6.04, 'age_50_54' => 5.37, 'age_55_59' => 4.55,
    'age_60_64' => 3.72, 'age_65_69' => 2.96, 'age_70_74' => 2.21,
    'age_75_79' => 1.52, 'age_80_84' => 0.91, 'age_85_89' => 0.44,
    'age_90_94' => 0.15, 'age_95_99' => 0.04, 'age_100plus' => 0.005
  }.freeze
  JPN_2015_STANDARD = {
    'age_00_04' => 5_026_000, 'age_05_09' => 5_369_000, 'age_10_14' => 5_711_000,
    'age_15_19' => 6_053_000, 'age_20_24' => 6_396_000, 'age_25_29' => 6_738_000,
    'age_30_34' => 7_081_000, 'age_35_39' => 7_423_000, 'age_40_44' => 7_766_000,
    'age_45_49' => 8_108_000, 'age_50_54' => 8_451_000, 'age_55_59' => 8_793_000,
    'age_60_64' => 9_135_000, 'age_65_69' => 9_246_000, 'age_70_74' => 7_892_000,
    'age_75_79' => 6_306_000, 'age_80_84' => 4_720_000, 'age_85_89' => 3_134_000,
    'age_90_94' => 1_548_000, 'age_95plus' => 423_000
  }.freeze
  JPN_DEATH_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0'
  JPN_POP_URL = 'https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0'
  HMD_STMF_URL = 'https://www.mortality.org/Data/STMF'
  US_VITAL_STATS_URL = 'https://www.cdc.gov/nchs/data_access/vitalstatsonline.htm'
  OECD_DATA_EXPLORER_URL = 'https://data-explorer.oecd.org/'

  AGE_FIELDS = %w[
    age_all age_0 age_1 age_2 age_3 age_4
    age_00_04 age_05_09 age_10_14 age_15_19 age_20_24 age_25_29
    age_30_34 age_35_39 age_40_44 age_45_49 age_50_54 age_55_59
    age_60_64 age_65_69 age_70_74 age_75_79 age_80_84 age_85_89
    age_85plus age_90_94 age_95_99 age_100plus age_unknown
    age_elementary age_junior
  ].freeze

  AGGREGATE_AGE_FIELDS = %w[
    age_00_14 age_15_64 age_65_74 age_75_84
    age_05_14 age_15_29 age_30_49 age_50_64
  ].freeze

  FIELDS = (%w[
    id loc area areaj yearmonth category rate death_code death_cause
    algo type src_url date year month sex
  ] + AGE_FIELDS).freeze

  WEEKLY_FIELDS = (%w[
    id loc area areaj yearweek category rate death_code death_cause
    algo type src_url date year week sex
  ] + AGE_FIELDS + AGGREGATE_AGE_FIELDS).uniq.freeze

  YEARLY_FIELDS = (%w[
    id loc area areaj category rate death_code death_cause
    algo type src_url date year sex
  ] + AGE_FIELDS + AGGREGATE_AGE_FIELDS).uniq.freeze

  # 日本語: 文書IDを全category共通の8要素から生成し、要素内のunderscoreを拒否する。
  # English: Build document IDs from eight shared components and reject underscores inside components.
  def self.record_id(loc:, period:, category:, rate: '', death_code: '', algo: '', type: '', sex:)
    values = [loc, period, category, rate, death_code, algo, type, sex].map(&:to_s)
    invalid = ID_FIELDS.zip(values).select { |_field, value| value.include?('_') }
    unless invalid.empty?
      detail = invalid.map { |field, value| "#{field}=#{value.inspect}" }.join(', ')
      raise ArgumentError, "ID component contains underscore: #{detail}"
    end
    values.join('_')
  end

  # 日本語: CSV recordの期間fieldを選び、同じ8要素規則でIDを再生成する。
  # English: Select the CSV record's period field and rebuild its ID with the same eight-component rule.
  def self.record_id_for(row)
    fetch = ->(field) { row[field] || row[field.to_s] }
    period = fetch.call(:yearmonth) || fetch.call(:yearweek) || fetch.call(:year)
    record_id(loc: fetch.call(:loc), period: period, category: fetch.call(:category),
              rate: fetch.call(:rate), death_code: fetch.call(:death_code), algo: fetch.call(:algo),
              type: fetch.call(:type), sex: fetch.call(:sex))
  end

  # 日本語: 地域codeから日英名称を補い、全CSVで同じ表記を使う。
  # English: Fill bilingual names from the location code for consistent CSV output.
  def self.area_names(row)
    @areas ||= JSON.parse(File.read(AREA_FILE))
    loc = row[:loc] || row['loc']
    known = @areas.fetch(loc.to_s.downcase, {})
    [row[:area] || row['area'] || known['area'], row[:areaj] || row['areaj'] || known['areaj']]
  end

  # フィールド順を固定し、空値を保ったままCSVを出力する。
  # Write CSV with stable field ordering while preserving missing values.
  def self.output(rows, io = $stdout)
    output_fields(rows, FIELDS, io)
  end

  # 週次レコードを月次と同じ正規形のCSVとして出力する。
  # Write weekly records using the same canonical conventions as monthly records.
  def self.output_weekly(rows, io = $stdout)
    output_fields(rows, WEEKLY_FIELDS, io)
  end

  # 月・週fieldを持たない年次recordを共通形式で出力する。
  # Write annual records without monthly or weekly period fields.
  def self.output_yearly(rows, io = $stdout)
    output_fields(rows, YEARLY_FIELDS, io)
  end

  # 指定したフィールド順を固定し、欠測値を空欄として出力する。
  # Preserve the requested field order and emit missing values as empty fields.
  def self.output_fields(rows, fields, io)
    csv = CSV.new(io)
    csv << fields
    rows.keys.sort.each do |id|
      row = rows.fetch(id)
      area, areaj = area_names(row)
      csv << fields.map do |field|
        value = if field == 'area'
                  area
                elsif field == 'areaj'
                  areaj
                else
                  row[field.to_sym]
                end
        value = JSON.generate(value) if value.is_a?(Array)
        # 日本語: 原表の記号の意味は入力ごとに異なるため、共通層で欠測へ変換しない。
        # English: Source-marker meanings vary, so never silently convert them to missing here.
        if %w[- ・].include?(value)
          raise ArgumentError, "unresolved source marker: id=#{id} field=#{field} value=#{value.inspect}"
        end

        value
      end
    end
  end
end
