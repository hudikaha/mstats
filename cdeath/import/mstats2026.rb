# coding: utf-8

require 'csv'
require 'json'

# 死因と人口を共通のmstats2026 CSV形式へ出力する。
# Emit cause-of-death and population records in the shared mstats2026 CSV schema.
module Mstats2026
  WHO_WORLD_STANDARD = {
    'age_00_04' => 8.86, 'age_05_09' => 8.69, 'age_10_14' => 8.60,
    'age_15_19' => 8.47, 'age_20_24' => 8.22, 'age_25_29' => 7.93,
    'age_30_34' => 7.61, 'age_35_39' => 7.15, 'age_40_44' => 6.59,
    'age_45_49' => 6.04, 'age_50_54' => 5.37, 'age_55_59' => 4.55,
    'age_60_64' => 3.72, 'age_65_69' => 2.96, 'age_70_74' => 2.21,
    'age_75_79' => 1.52, 'age_80_84' => 0.91, 'age_85_89' => 0.44,
    'age_90_94' => 0.15, 'age_95_99' => 0.04, 'age_100over' => 0.005
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
    age_85over age_90_94 age_95_99 age_100over age_unknown
    age_elementary age_junior
  ].freeze

  AGGREGATE_AGE_FIELDS = %w[
    age_00_14 age_15_64 age_65_74 age_75_84
    age_05_14 age_15_29 age_30_49 age_50_64
  ].freeze

  FIELDS = (%w[
    id loc_code location yearmonth category rate death_code death_cause
    algo type src_url date year month sex
  ] + AGE_FIELDS).freeze

  WEEKLY_FIELDS = (%w[
    id loc_code location yearweek category rate death_code death_cause
    algo type src_url date year week sex
  ] + AGE_FIELDS + AGGREGATE_AGE_FIELDS).uniq.freeze

  YEARLY_FIELDS = (%w[
    id loc_code location category rate death_code death_cause
    algo type src_url date year sex
  ] + AGE_FIELDS + AGGREGATE_AGE_FIELDS).uniq.freeze

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
      csv << fields.map do |field|
        value = row[field.to_sym]
        value = JSON.generate(value) if value.is_a?(Array)
        %w[- ・].include?(value) ? nil : value
      end
    end
  end
end
