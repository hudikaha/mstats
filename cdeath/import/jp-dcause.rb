#!/usr/bin/ruby
# coding: utf-8

require 'pp'
require 'csv'
require 'date'
require 'json'
require_relative 'mstats2026'

module JpDcause
  # e-Stat月次死因CSVを一度だけ読み、mstats2026月次recordへ変換する。
  # Read e-Stat monthly cause CSVs once and convert them into mstats2026 records.
  def self.read(files, verbose: true)
    health = {}

files.each do |file|
    csvtext = ''
    year = month = 0
    date = nil
    header_flag = false
    count = 0
    year2 = month2 = 0
    file.sub(/(\d+)-(\d+).csv/) do
        year2 = $1.to_i
        month2 = $2.to_i
    end
    File.foreach(file) do |line|
        count = 0
        line = line.tr('０-９', '0-9').gsub(/ |　/,'')
        [
            /（(20\d+)）年(\d+)月/,
            /平成(元)年(\d+)月/,
            /平成(\d+)年(\d+)月/,
            /令和(元)年(\d+)月/,
            /令和(\d+)年(\d+)月/,
        ].each do |regexp|
            if line =~ regexp
                line.gsub(regexp) do
                    #pp line, $1, $2
                    year = $1.to_i
                    month = $2.to_i
                    year = 1 if line =~ /元/
                    year += 1988 if year < 100 && line =~ /平成/
                    year += 2018 if year < 100 && line =~ /令和/
                    #pp year, month
                    date = Date.parse("#{year}-#{month}-01")
                end
                next
            end
        end
        next if line =~ /人口動態|保管|,,（人）|死因簡単分類/
        if ! header_flag
            if line =~ /^,,,総数/
                line = line.gsub(/^,,,総数/, '未使用,種別,性別,総数') # 2022-01 まで
                header_flag = true
            elsif line =~ /^,,総数/
                line = line.gsub(/^,,総数/, '種別,性別,総数') # 2022-02 以降
                header_flag = true
            end
        end
        next if line =~ /^,,,|^,,\"\"/
        csvtext += line
    end
    #puts "#{year} #{month}"
    #print csvtext
    prev_code = prev_cause = ''
    prev_id = nil
    CSV.parse(csvtext, headers: true).each do |row0|
        row = row0.to_h
        #pp row['種別']
        code = prev_code
        cause = prev_cause
        if row['種別'] =~ /総数/
            code = 'all'
            cause = '全死因'
        elsif row['種別'] && row['種別'] =~ /^(\d+)(.*)$/
            row['種別'].sub(/^(\d*)(.*)$/) do
                code = $1
                cause = $2
            end
        elsif row['種別']
            cause += row['種別']
            health[prev_id][:death_cause] += row['種別'] if prev_id
        end
        #$codes[code] = cause
        #pp row['種別'], $CODES
        sex = 'both'
        sex = 'male' if row['性別'] =~ /男/
        sex = 'female' if row['性別'] =~ /女/
        code = '00000' if code == 'all'
        id = "jpn_#{year}m#{sprintf('%02d', month)}_death__#{code}__#{sex}"
        health[id] = {
            id: id,
            category: 'death',
            loc_code: 'jpn',
            location: 'Japan',
            date: "#{year}-#{sprintf('%02d', month)}-01",
            yearmonth: "#{year}m#{sprintf('%02d', month)}",
            year: year,
            month: month,
            sex: sex,
            rate: '',
            death_code: code,
            death_cause: cause,
            algo: '',
            age_all: '', age_0: '', age_1: '', age_2: '', age_3: '', age_4: '', age_00_04: '', age_05_09: '', age_10_14: '', age_15_19: '', age_20_24: '', age_25_29: '', age_30_34: '', age_35_39: '', age_40_44: '', age_45_49: '', age_50_54: '', age_55_59: '', age_60_64: '', age_65_69: '', age_70_74: '', age_75_79: '', age_80_84: '', age_85_89: '', age_90_94: '', age_95_99: '', age_100over: '', age_unknown: '', age_elementary: '', age_junior: '',
        }
        prev_id = id
        prev_code = health[id][:death_code]
        prev_cause = health[id][:death_cause]
        row.each do |k, v|
            next if k =~ /種別|性別|未使用/
            if k =~ /総数/
                k = 'all'
            elsif k =~ /歳/
                k = k.sub(/歳/, '').sub(/-/, '_').sub(/以上/, 'over')
            elsif k =~ /不詳/
                k = 'unknown'
            elsif k =~ /小学生/
                k = 'elementary'
            elsif k =~ /中学生/
                k = 'junior'
            end
            #print "#{k} #{v}"
            #puts
            if ! health[id]["age_#{k}".to_sym]
                raise "No health[#{id}][age_#{k}]"
            end
            health[id]["age_#{k}".to_sym] = v
            #STDERR.puts "age_#{k}: #{v}" if k == 'all' && id == 'jpn_2020_m06_death_all_both'
            count += 1
        end
    end
    match = ''
    match = 'NO MATCH' if year != year2 || month != month2
    STDERR.puts "#{date}: #{count} #{match}" if verbose
end

    health
  end
end

if $PROGRAM_NAME == __FILE__
  Mstats2026.output(JpDcause.read(ARGV))
end
