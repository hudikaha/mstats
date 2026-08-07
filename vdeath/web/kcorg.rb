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
    date: '日付', cumulative_deaths: '累積死亡人数', cumulative_hazard: '累積hazard',
    ratio: '累積hazard比 = コホート2 / コホート1', death_ratio: '累積死亡人数比 = コホート2 / コホート1',
    gamma_apply: 'Gamma補正を適用', gamma_remove: 'Gamma補正を解除',
    quiet_start: 'quiet window開始週', quiet_end: 'quiet window終了週', fit_end: 'Fit終了週',
    fitting: 'fit中…',
    fit_wait: 'Gamma補正には4週以上のquiet windowが必要です。',
    baseline_factor: '選択週基準化：コホート1 ×%{factor}',
    gamma_factor: '選択週基準化：コホート1 ×%{factor}',
    observed: '観測', adjusted: 'Gamma補正', theta: 'θ', fit: 'fit',
    loading: 'データを読み込んでいます…', load_error: 'データを読み込めませんでした。',
    no_fit: '選択したcohortのgamma parameterがありません。',
    osaka_disabled: '大阪（Gamma補正時は選択不可）',
    gamma_active: 'Gamma補正を適用中', gamma_separator: '、',
    osaka_gamma_note: '大阪市は死亡者のみのデータのため選択できません'
  },
  en: {
    cutoff: 'Cutoff', area: 'Area', age: 'Age', doses: 'doses',
    cohort1: 'Cohort 1', cohort2: 'Cohort 2',
    date: 'Date', cumulative_deaths: 'Cumulative deaths', cumulative_hazard: 'Cumulative hazard',
    ratio: 'Cumulative hazard ratio = Cohort 2 / Cohort 1', death_ratio: 'Cumulative death-count ratio = Cohort 2 / Cohort 1',
    gamma_apply: 'Apply gamma adjustment', gamma_remove: 'Remove gamma adjustment',
    quiet_start: 'Quiet-window start week', quiet_end: 'Quiet-window end week', fit_end: 'Fit end week',
    fitting: 'Fitting…',
    fit_wait: 'Gamma adjustment requires a quiet window of at least four weeks.',
    baseline_factor: 'Selected-week normalization: Cohort 1 ×%{factor}',
    gamma_factor: 'Selected-week normalization: Cohort 1 ×%{factor}',
    observed: 'Observed', adjusted: 'Gamma-adjusted', theta: 'θ', fit: 'fit',
    loading: 'Loading data…', load_error: 'Could not load data.',
    no_fit: 'Gamma parameters are unavailable for the selected cohort.',
    osaka_disabled: 'Osaka (unavailable during gamma adjustment)',
    gamma_active: 'Gamma adjustment is active', gamma_separator: ': ',
    osaka_gamma_note: 'Osaka cannot be selected because its data include deaths only.'
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
    <div class="kcor-row"><span class="kcor-label cohort2">#{text[:cohort2]} (#{text[:doses]}):</span><span id="c2"></span></div>
    <div class="kcor-row"><span class="kcor-label cohort1">#{text[:cohort1]} (#{text[:doses]}):</span><span id="c1"></span></div>
    <div class="kcor-row"><button type="button" id="gamma-toggle">#{text[:gamma_apply]}</button><span id="osaka-gamma-note" hidden><span class="gamma-active-note">#{text[:gamma_active]}</span>#{text[:gamma_separator]}#{text[:osaka_gamma_note]}</span></div>
    <div id="fit-results">
      <div class="fit-result"><span id="gamma-factor" class="mono">&mdash;</span></div>
      <div class="fit-result gamma-fit-result"><span class="cohort2">#{text[:cohort2]} fit:</span><span id="c2fit" class="mono">&mdash;</span></div>
      <div class="fit-result gamma-fit-result"><span class="cohort1">#{text[:cohort1]} fit:</span><span id="c1fit" class="mono">&mdash;</span></div>
    </div>
  </div>
  <div id="quiet-row" hidden>
    <div id="gamma-window-controls" hidden>
      <div><span class="kcor-label">quiet window:</span><span id="quiet-start-value" class="mono"></span> – <span id="quiet-end-value" class="mono"></span></div>
      <div id="quiet-slider" class="chart-slider"><div class="slider-track"><span id="quiet-start-thumb" class="slider-thumb"></span><span id="quiet-end-thumb" class="slider-thumb"></span></div><input id="quiet-start" class="window-range" aria-label="#{text[:quiet_start]}" type="range" min="0" step="1" value="4"><input id="quiet-end" class="window-range" aria-label="#{text[:quiet_end]}" type="range" min="0" step="1" value="8"></div>
    </div>
    <div><label class="kcor-label" for="fit-end">#{text[:fit_end]}:</label><span id="fit-end-value" class="mono"></span></div>
    <div id="fit-slider" class="chart-slider"><div class="slider-track"><span id="fit-thumb" class="slider-thumb"></span></div><input id="fit-end" class="single-range" type="range" min="0" step="1" value="0"></div>
  </div>
  <div id="view"></div>
  <hr>
  #{if $l == :ja
      <<~JA
        <section class="kcor-references">
          <h2>Gamma-frailty補正について</h2>
          <p>初期表示は固定cohortの累積死亡人数です。Gamma補正またはFitで線が動くときは、変換前の元の線を同じ太さの破線、利用する最終値を実線で表示します。下段のRRは補正・Fitを反映した最終値を表示します。</p>
          <p>quiet windowは開始週と終了週を4週以上離して指定し、初期値は第4週〜第8週です。FitはGamma補正とは別の操作で、開始を第1週に固定し、選択した終了週におけるコホート2／コホート1の比で青線を尺度調整して、その週のKCORを1にします。Fit終了週が0ではFitせず、4週以上へ動かすと自動的に適用します。</p>
          <p>選択した地域・年齢・接種回数の週初risk人数と週死亡数を各cohort内で合算してからθとkを推定します。大阪市は通常の累積死亡人数では選択できますが、死亡者だけの資料でrisk setを作れないためGamma補正時は選択できません。</p>
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
          <p>The initial view shows cumulative death counts. When gamma adjustment or fitting moves a line, the original is retained as a dashed line of the same width and the final value is solid. The lower RR chart shows the final value reflecting adjustment and fit.</p>
          <p>The quiet-window start and end must remain at least four weeks apart and default to weeks 4–8. Fitting is separate from gamma adjustment: its start is fixed at week 1, and the blue line is scaled by the Cohort 2 / Cohort 1 ratio at the selected end week, making KCOR equal to 1 there. A fit end of week 0 does not fit; moving the end to week 4 or later applies it automatically.</p>
          <p>Weekly risk populations and deaths are summed over the selected areas, ages, and doses within each cohort before theta and k are fitted. Osaka is available for ordinary cumulative death counts, but unavailable during gamma adjustment because its death-only source cannot provide a risk set.</p>
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
