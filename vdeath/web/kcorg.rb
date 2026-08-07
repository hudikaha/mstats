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
asset_version = File.mtime(File.join(__dir__, "#{page_name}.js")).to_i
title = {
  ja: 'Gamma-frailty補正Kirsch累積アウトカム比（KCOR-G）',
  en: 'Gamma-frailty-adjusted Kirsch Cumulative Outcomes Ratio (KCOR-G)'
}.fetch($l)

text = {
  ja: {
    cutoff: '累積開始日（Cutoff）', area: '地域', age: '年齢', doses: '接種回数',
    cohort1: 'コホート1', cohort2: 'コホート2',
    date: '日付', cumulative_hazard: '累積hazard',
    ratio: '累積hazard比 = コホート2 / コホート1',
    gamma_apply: 'Gamma補正を適用', gamma_remove: 'Gamma補正を解除',
    quiet_end: 'fit終了週', fitting: 'fit中…',
    gamma_factor: '自動整列：コホート1 × k₂/k₁ = ×%{factor}',
    observed: '観測', adjusted: 'Gamma補正', theta: 'θ', fit: 'fit',
    loading: 'データを読み込んでいます…', load_error: 'データを読み込めませんでした。',
    no_fit: '選択したcohortのgamma parameterがありません。',
    osaka_disabled: '大阪（死亡者のみの資料のため選択不可）'
  },
  en: {
    cutoff: 'Cutoff', area: 'Area', age: 'Age', doses: 'doses',
    cohort1: 'Cohort 1', cohort2: 'Cohort 2',
    date: 'Date', cumulative_hazard: 'Cumulative hazard',
    ratio: 'Cumulative hazard ratio = Cohort 2 / Cohort 1',
    gamma_apply: 'Apply gamma adjustment', gamma_remove: 'Remove gamma adjustment',
    quiet_end: 'Fit end week', fitting: 'Fitting…',
    gamma_factor: 'Automatic alignment: Cohort 1 × k₂/k₁ = ×%{factor}',
    observed: 'Observed', adjusted: 'Gamma-adjusted', theta: 'θ', fit: 'fit',
    loading: 'Loading data…', load_error: 'Could not load data.',
    no_fit: 'Gamma parameters are unavailable for the selected cohort.',
    osaka_disabled: 'Osaka (unavailable: death-only source data)'
  }
}.fetch($l)

config = {language: $l, elasticsearch_url: 'elastic/kcor/_search', text: text}

print_header(title: title, iframe: iframe)
print <<~HTML
  <link rel="stylesheet" href="#{page_name}.css?v=#{asset_version}">
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
    <div class="kcor-row"><label class="kcor-label cohort2" for="c2">#{text[:cohort2]} (#{text[:doses]}):</label><select id="c2"></select><span id="c2fit" class="mono"></span></div>
    <div class="kcor-row"><label class="kcor-label cohort1" for="c1">#{text[:cohort1]} (#{text[:doses]}):</label><select id="c1"></select><span id="c1fit" class="mono"></span></div>
    <div class="kcor-row"><button type="button" id="gamma-toggle">#{text[:gamma_apply]}</button><span id="gamma-factor" class="mono"></span></div>
  </div>
  <div id="quiet-row" hidden>
    <div><label class="kcor-label" for="quiet-end">#{text[:quiet_end]}:</label><span id="quiet-end-value" class="mono"></span></div>
    <input id="quiet-end" type="range" min="0" step="1" value="0">
  </div>
  <div id="view"></div>
  <hr>
  #{if $l == :ja
      <<~JA
        <section class="kcor-references">
          <h2>Gamma-frailty補正について</h2>
          <p>初期表示の実線は、固定cohortの週死亡数と週初risk人数から直接計算した観測累積hazardです。「Gamma補正を適用」を押すと、観測値を細線で残し、Gamma補正後の累積hazardを太線で追加します。</p>
          <p>fitはcutoffから常時表示されているスライダーで選んだ終了週までを使います。終了週の初期値はcutoffと同日で、この状態ではfitしません。Gamma補正後に終了週を12週以上先へ動かすとθと基準傾きkを推定し、k₂/k₁で青の補正線を赤の補正線へ自動的に重ねます。</p>
          <p>選択した地域・年齢の週初risk人数と週死亡数を合算してから、各接種回数cohortのθとkを推定します。大阪市は死亡者だけの資料でrisk setを作れないため選択できません。</p>
          <p>これはmethod検証用の実装です。<code>theta_zero</code>と<code>theta_upper_bound</code>は推定値が探索境界に達したことを表します。</p>
          <ul>
            <li><a href="kcor.rb">Gamma補正なしのKCOR</a></li>
            <li><a href="https://kirschsubstack.com/p/kcor-v6-enables-radical-transparency" target="_blank" rel="noopener noreferrer">KCOR v6 gamma-frailty method</a></li>
          </ul>
        </section>
      JA
    else
      <<~EN
        <section class="kcor-references">
          <h2>Gamma-frailty adjustment</h2>
          <p>The initial solid lines are observed cumulative hazards calculated directly from weekly deaths and the population at risk at the start of each week. Press “Apply gamma adjustment” to retain the observations as thin lines and add gamma-adjusted cumulative hazards as thick lines.</p>
          <p>The fit uses data from the cutoff through the end week selected by the always-visible slider. The end week initially equals the cutoff, so no fit is performed. After gamma adjustment is enabled, moving the end at least 12 weeks forward fits theta and the baseline slope k, then automatically aligns the blue adjusted line to the red one using k₂/k₁.</p>
          <p>Weekly risk populations and deaths are summed over the selected areas and ages before theta and k are fitted for each dose cohort. Osaka cannot be selected because its death-only source cannot provide a risk set.</p>
          <p>This is a method-validation implementation. <code>theta_zero</code> and <code>theta_upper_bound</code> identify fits at the search boundary.</p>
          <ul>
            <li><a href="kcor.rb">KCOR without gamma adjustment</a></li>
            <li><a href="https://kirschsubstack.com/p/kcor-v6-enables-radical-transparency" target="_blank" rel="noopener noreferrer">KCOR v6 gamma-frailty method</a></li>
          </ul>
        </section>
      EN
    end}
  <script>window.KCORG_CONFIG = #{JSON.generate(config)};</script>
  <script src="#{page_name}.js?v=#{asset_version}"></script>
HTML

unless iframe
  print "</div></div>\n"
end
print "</body></html>\n"
