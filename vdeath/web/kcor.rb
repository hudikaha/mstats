#!/usr/bin/ruby
# coding: utf-8

require 'cgi'
require 'json'

mfacts = [
  File.expand_path('../../lib/mfacts.rb', __dir__),
  File.expand_path('lib/mfacts.rb', __dir__)
].find { |path| File.file?(path) }
abort 'lib/mfacts.rb not found' unless mfacts
require mfacts

cgi = CGI.new
requested_language = cgi['l']
if requested_language.match?(/^(en|english)/i) ||
   (requested_language.empty? && ENV['HTTP_ACCEPT_LANGUAGE'].to_s !~ /^ja/)
  $l = :en
else
  $l = :ja
end

iframe = %w[1 true].include?(cgi['i'])
page_name = File.basename($PROGRAM_NAME, '.rb')
title = {
  ja: 'Kirsch累積アウトカム比（KCOR）',
  en: 'Kirsch Cumulative Outcomes Ratio (KCOR)'
}.fetch($l)

text = {
  ja: {
    cutoff: '累積開始日（Cutoff）', area: '地域', age: '年齢', doses: '接種回数',
    cohort1: 'コホート1', cohort2: 'コホート2', slope: 'コホート1の傾き（dB）',
    date: '日付', cumulative_deaths: '累積死亡数', ratio: '比 = コホート2 / 調整後コホート1',
    loading: 'データを読み込んでいます…', load_error: 'データを読み込めませんでした。',
    no_area: '地域を1つ以上選択してください。'
  },
  en: {
    cutoff: 'Cutoff', area: 'Area', age: 'Age', doses: 'doses',
    cohort1: 'Cohort 1', cohort2: 'Cohort 2', slope: 'Cohort 1 Slope (dB)',
    date: 'Date', cumulative_deaths: 'Cumulative deaths', ratio: 'Ratio = Cohort 2 / Cohort 1 (scaled)',
    loading: 'Loading data…', load_error: 'Could not load data.',
    no_area: 'Select at least one area.'
  }
}.fetch($l)

config = {
  language: $l,
  manifest_url: "#{page_name}-data/manifest.json",
  text: text
}

print_header(title: title, iframe: iframe)
print <<~HTML
  <link rel="stylesheet" href="#{page_name}.css">
  <form action="#{page_name}.rb" method="get" class="language-selector">
    <label><input type="radio" name="l" value="ja" #{'checked' if $l == :ja} onchange="this.form.submit()">日本語</label>
    <label><input type="radio" name="l" value="en" #{'checked' if $l == :en} onchange="this.form.submit()">English</label>
    #{'<input type="hidden" name="i" value="true">' if iframe}
  </form>
  <hr>
  <div id="kcor-status" role="status">#{text[:loading]}</div>
  <div id="kcor-controls" hidden>
    <div class="kcor-row"><span class="kcor-label">#{text[:cutoff]}:</span><span id="cutoff"></span></div>
    <div class="kcor-row"><span class="kcor-label">#{text[:area]}:</span><span id="area"></span></div>
    <div class="kcor-row"><span class="kcor-label">#{text[:age]}:</span><span id="age"></span></div>
    <div class="kcor-row"><span class="kcor-label"><span class="cohort2">#{text[:cohort2]}</span> (#{text[:doses]}):</span><span id="c2"></span></div>
    <div class="kcor-row"><span class="kcor-label"><span class="cohort1">#{text[:cohort1]}</span> (#{text[:doses]}):</span><span id="c1"></span></div>
    <div class="kcor-row">
      <span class="kcor-label"><span class="cohort1">#{text[:slope]}</span>:</span>
      <span id="s2"></span>
      <span id="s2val" class="mono">×1.00 (dB=0.0)</span>
    </div>
  </div>
  <div id="view"></div>
  <hr>
  #{if $l == :ja
      <<~JA
        <ul>
          <li><a href="https://fujikawa.org/pub/kkcor/" target="_blank">各自治体の完全データから作成したKCOR用データセット</a></li>
          <li>CUMD-WK：cutoffごとに週単位で累積した死亡数。各行は1週に対応し、値は減少しません。</li>
          <li>IND-WKA：プライバシー保護のため、個人の日付をISO週の最終日（日曜日）に置換したデータ。</li>
          <li>DTH-WKA：死亡記録のある人だけを含むIND-WKA形式のデータ。</li>
          <li>PY：人年法用データ。<a href="vdeath.rb">人年法による解析</a>を参照。</li>
        </ul>
      JA
    else
      <<~EN
        <ul>
          <li><a href="https://fujikawa.org/pub/kkcor/" target="_blank">Datasets derived from complete municipal datasets (Kenji's data format for KCOR)</a></li>
          <li>CUMD-WK: Weekly cumulative deaths calculated separately for each cutoff; values do not decrease.</li>
          <li>IND-WKA: Individual records with dates replaced by the final day (Sunday) of each ISO week for privacy.</li>
          <li>DTH-WKA: IND-WKA records limited to people with a recorded death.</li>
          <li>PY: Person-year datasets. See <a href="vdeath.rb">person-year analysis</a>.</li>
        </ul>
      EN
    end}
  <script>window.KCOR_CONFIG = #{JSON.generate(config)};</script>
  <script src="#{page_name}.js"></script>
HTML

unless iframe
  print "</div></div>\n"
end
print "</body></html>\n"
