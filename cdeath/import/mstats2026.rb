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

  FIELDS = (%w[
    id loc_code location yearmonth category rate death_code death_cause
    algo type date year month sex
  ] + AGE_FIELDS).freeze

  # フィールド順を固定し、空値を保ったままCSVを出力する。
  # Write CSV with stable field ordering while preserving missing values.
  def self.output(rows, io = $stdout)
    csv = CSV.new(io)
    csv << FIELDS
    rows.sort.to_h.each_value do |row|
      csv << FIELDS.map do |field|
        value = row[field.to_sym]
        %w[- ・].include?(value) ? nil : value
      end
    end
  end
end
