#!/usr/bin/env ruby
# coding: utf-8
# csv2base_simple.rb
# Usage:
#   ruby csv2base_simple.rb [-o output.js] input1.csv [input2.csv ...]
#
# 例:
#   ruby csv2base_simple.rb data1.csv data2.csv -o BASE.js

require "csv"
require "json"

# JavaScript文字列として安全に引用する。 / Quote a value safely as a JavaScript string.
def q(s)
    JSON.dump(s.to_s)  # JS 文字列のエスケープ
end

# ==== 引数解析 ====
out_path = "BASE.js"
inputs = []

ARGV.each_with_index do |arg, i|
    if arg == "-o"
        out_path = ARGV[i+1] or abort "Error: -o の後に出力ファイル名を指定してください"
    elsif ARGV[i-1] != "-o"
        inputs << arg
    end
end

abort "Error: 入力CSVファイルを1つ以上指定してください" if inputs.empty?
inputs.each { |f| abort "Input CSV not found: #{f}" unless File.exist?(f) }

# ==== CSV 読み込み & 結合 ====
rows = []

inputs.each do |in_path|
    tbl = CSV.read(in_path, headers: true, encoding: "UTF-8")

    # 必須ヘッダの存在チェック
    need = %w[areacode area areaj cutoff date age dose deaths]
    have = tbl.headers.map { |h| h.to_s.strip.downcase }
    missing = need.reject { |k| have.include?(k) }
    abort "#{in_path}: Missing required columns: #{missing.join(", ")}" unless missing.empty?

    # 元の表のヘッダ → 正確なキー名で参照
    idx = {}
    need.each do |k|
        idx[k] = tbl.headers.index { |h| h.to_s.strip.downcase == k }
    end

    tbl.each do |r|
        areacode  = r[idx["areacode"]]
        area      = r[idx["area"]]
        areaj     = r[idx["areaj"]]
        cutoff    = r[idx["cutoff"]]
        date      = r[idx["date"]]
        age       = r[idx["age"]]
        dose_s    = r[idx["dose"]]
        deaths_s  = r[idx["deaths"]]

        # 数値化（整数化）。deaths==0 はスキップ
        dose   = ((Float(dose_s)   rescue dose_s.to_i)).to_i
        deaths = ((Float(deaths_s) rescue deaths_s.to_i)).to_i
        next if deaths == 0

        rows << %{  {areacode:#{q(areacode)}, area:#{q(area)}, areaj:#{q(areaj)}, cutoff:#{q(cutoff)}, date:#{q(date)}, age:#{q(age)}, dose:#{dose}, deaths:#{deaths}}}
    end
end

# ==== 出力 ====
File.open(out_path, "w", encoding: "UTF-8") do |f|
    f.puts "const BASE = ["
    f.puts rows.join(",\n")
    f.puts "];"
end
