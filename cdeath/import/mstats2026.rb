# coding: utf-8

require 'csv'

# 死因と人口を共通のmstats2026 CSV形式へ出力する。
# Emit cause-of-death and population records in the shared mstats2026 CSV schema.
module Mstats2026
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
    algo type date year month sex
  ] + AGE_FIELDS).freeze

  WEEKLY_FIELDS = (%w[
    id loc_code location yearweek category rate death_code death_cause
    algo type date year week sex
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

  # 指定したフィールド順を固定し、欠測値を空欄として出力する。
  # Preserve the requested field order and emit missing values as empty fields.
  def self.output_fields(rows, fields, io)
    csv = CSV.new(io)
    csv << fields
    rows.keys.sort.each do |id|
      row = rows.fetch(id)
      csv << fields.map do |field|
        value = row[field.to_sym]
        %w[- ・].include?(value) ? nil : value
      end
    end
  end
end
