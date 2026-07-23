#!/usr/bin/ruby
# coding: utf-8

require 'cgi'
require 'stringio'
begin
  require_relative '../lib/mfacts'
rescue LoadError
  require_relative 'lib/mfacts'
end

cgi = CGI.new
lang = cgi['l'] == 'en' ? 'en' : 'ja'
age  = %w[20- 25- 30- 35- 40- 45- 50- 55- 60- 65-].include?(cgi['age']) ? cgi['age'].delete('-') : '20'
start = %w[2011 2022].include?(cgi['start']) ? cgi['start'] : '2022'
legacy_deaths = cgi['deaths'] == '1'
suicide = legacy_deaths || cgi['suicide'] == '1' ? 'true' : 'false'
all_cause = legacy_deaths || cgi['allcause'] == '1' ? 'true' : 'false'
denominator = cgi['denominator'] == 'population' ? 'population' : 'allcause'

menu_out = StringIO.new
$stdout = menu_out
print_site_menu(lang.to_sym)
$stdout = STDOUT
menu_html = menu_out.string

print "Content-Type: text/html; charset=UTF-8\r\n\r\n"

html = <<~'HTMLDOC'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title id="pageTitleTag"></title>
<style>
.sr-only { position:absolute; width:1px; height:1px; overflow:hidden; clip:rect(0,0,0,0); }
button { font-family: inherit; }
.note-list { display:flex; flex-direction:column; gap:8px; }
.note-item { display:flex; align-items:flex-start; }
.note-item .mark { flex:0 0 1.2em; }
.note-item .text { flex:1 1 auto; }
[data-language-content] { display:none; }
body.lang-ja [data-language-content="ja"],
body.lang-en [data-language-content="en"] { display:block; }
body.lang-ja .note-list[data-language-content="ja"],
body.lang-en .note-list[data-language-content="en"] { display:flex; }
.source-item { margin-bottom:10px; }
#chartWorkspace { display:grid;grid-template-columns:minmax(0,62fr) minmax(310px,38fr);gap:18px;align-items:stretch; }
#trendCharts, #chartAllPanel { min-width:0; }
#comparePanel { min-width:0;border:0.5px solid #e1e0d9;border-radius:8px;padding:12px;box-sizing:border-box; }
#compareSummary { font-size:13px;color:#52514e;line-height:1.35;margin-top:8px; }
#compareLegend { display:flex;flex-wrap:wrap;gap:4px 10px;font-size:12px;color:#52514e;margin-top:4px; }
.compare-year { padding:7px 0;border-top:0.5px solid #e1e0d9; }
.compare-year:first-child { border-top:none; }
.compare-row { display:flex;justify-content:space-between;gap:10px; }
.compare-row span:last-child { white-space:nowrap;font-variant-numeric:tabular-nums; }
.age-control { display:flex;align-items:center;gap:8px;flex:1 1 620px;min-width:0; }
.age-control #ageGroupLabel { flex:0 0 auto;white-space:nowrap; }
.age-buttons { display:flex;flex-wrap:wrap;border:0.5px solid #c3c2b7;border-radius:8px;overflow:hidden; }
.age-buttons button { padding-left:8px !important;padding-right:8px !important; }
#seriesChecks .series-control { display:flex;align-items:center;gap:3px; }
#seriesChecks .series-key { display:flex;align-items:center; }
#seriesChecks label { display:flex;align-items:center;border:0.5px solid #c3c2b7;border-radius:8px;padding:5px 9px;cursor:pointer;transition:background-color .12s,color .12s; }
#seriesChecks input { position:absolute;opacity:0;pointer-events:none; }
#seriesChecks label:has(input:focus-visible) { outline:2px solid #2a78d6;outline-offset:2px; }
@media (max-width:760px) {
  #chartWorkspace { grid-template-columns:minmax(0,1fr); }
  #comparePanel { min-width:0;width:100%; }
  .age-control { flex-basis:100%;width:100%; }
  .age-buttons { display:grid;grid-template-columns:repeat(5,1fr);width:100%; }
  .age-buttons button { padding:6px 4px !important;font-size:13px !important; }
}
</style>
</head>
<body class="lang-__LANG__">
<link rel="stylesheet" href="covid19.css">
<div id="wrapper">
__MENU__
<div class="right-column">
<div class="site-title">
<h1 id="h1Title" align=center></h1>
</div>

<h2 id="srDesc" class="sr-only"></h2>

<div style="display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:10px">
<div style="display:inline-flex;border:0.5px solid #c3c2b7;border-radius:8px;overflow:hidden">
<button id="btnJa" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:#2a78d6;color:#fff">日本語</button>
<button id="btnEn" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e">English</button>
</div>
<div class="age-control">
<span id="ageGroupLabel" style="font-size:15px;color:#52514e"></span>
<div class="age-buttons">
<button id="btn20" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:#2a78d6;color:#fff"></button>
<button id="btn25" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn30" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn35" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn40" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn45" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn50" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn55" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn60" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn65" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
</div>
</div>
</div>

<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:10px">
<span id="startLabel" style="font-size:15px;color:#52514e"></span>
<div style="display:inline-flex;border:0.5px solid #c3c2b7;border-radius:8px;overflow:hidden">
<button id="btnStart2011" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:#2a78d6;color:#fff"></button>
<button id="btnStart2022" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
</div>
</div>
<fieldset style="border:0.5px solid #e1e0d9;border-radius:8px;padding:8px 12px;margin:0 0 14px">
<legend id="seriesLabel" style="font-size:15px;color:#52514e;padding:0 5px"></legend>
<div id="seriesChecks" style="display:flex;gap:10px 20px;flex-wrap:wrap;font-size:15px">
<div class="series-control"><span class="series-key" id="seriesKey0"></span><label><input type="checkbox" data-series="0" checked><span id="series0"></span></label></div>
<div class="series-control"><span class="series-key" id="seriesKey1"></span><label><input type="checkbox" data-series="1" checked><span id="series1"></span></label></div>
<div class="series-control"><span class="series-key" id="seriesKey2"></span><label><input type="checkbox" data-series="2" checked><span id="series2"></span></label></div>
<div class="series-control"><span class="series-key" id="seriesKey3"></span><label><input type="checkbox" data-series="3" checked><span id="series3"></span></label></div>
<div class="series-control"><span class="series-key" id="seriesKey4"></span><label><input type="checkbox" data-series="4"><span id="series4"></span></label></div>
<div class="series-control"><span class="series-key" id="seriesKey5"></span><label><input type="checkbox" data-series="5"><span id="series5"></span></label></div>
</div>
</fieldset>

<div id="chartWorkspace">
<div id="trendCharts">
<div id="chartAllHeading" style="font-size:16px;color:#52514e;margin:6px 0 2px"></div>
<div id="chartAllSub" style="display:none"></div>
<div id="chartAllPanel">
<div style="position:relative;width:100%;height:280px">
<canvas id="chartAll" role="img"></canvas>
</div>
</div>

<div id="chartZoomHeading" style="font-size:16px;color:#52514e;margin:28px 0 2px;border-top:0.5px solid #e1e0d9;padding-top:20px"></div>
<div id="chartZoomSub" style="display:none"></div>
<div style="position:relative;width:100%;height:270px">
<canvas id="chartZoom" role="img"></canvas>
</div>
</div>
<aside id="comparePanel" hidden>
<div id="compareHeading" style="font-size:15px;color:#52514e;margin-bottom:8px"></div>
<div style="display:flex;justify-content:center;margin-bottom:8px">
<div style="display:inline-flex;border:0.5px solid #c3c2b7;border-radius:8px;overflow:hidden">
<button id="btnDenomAll" type="button" style="padding:5px 13px;font-size:14px;border:none;cursor:pointer;background:#2a78d6;color:#fff"></button>
<button id="btnDenomPopulation" type="button" style="padding:5px 13px;font-size:14px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
</div>
</div>
<div style="position:relative;width:100%;height:150px">
<canvas id="chartCompare" role="img"></canvas>
</div>
<div id="compareLegend"></div>
<div id="compareSummary"></div>
</aside>
</div>

<div class="note-list" data-language-content="ja" style="font-size:15px;color:#111;line-height:1.5;margin-top:18px">
<div class="note-item"><span class="mark">※</span><span class="text">起点は、PMDAで最初のHPVワクチン健康被害認定が確認できる2011年7月と、受診者系列開始の2022年3月から選択できる。2018年12月14日より前など年齢が分からない認定者は、15歳以上20歳未満として扱っている</span></div>
<div class="note-item"><span class="mark">※</span><span class="text">受診患者は厚労省のサーベイランス調査自体が2022年3月分から開始されており、それ以前のデータが存在しないため2022年3月起点からの累積となっている</span></div>
<div class="note-item"><span class="mark">※</span><span class="text">年齢切替は健康被害認定者、子宮頸癌罹患者・死亡者、女性の自殺・全死因に適用され、年齢区分のない受診患者には適用されない。子宮頸癌は年次、自殺・全死因は月次データを累積している</span></div>
<div class="note-item"><span class="mark">※</span><span class="text">右側の割合グラフは累積ではなく、選択上限直下の5歳階級について2011年と2022年それぞれの年間人数を比較する。人口は各年10月1日現在の確定人口</span></div>
</div>

<div class="note-list" data-language-content="en" style="font-size:15px;color:#111;line-height:1.5;margin-top:18px">
<div class="note-item"><span class="mark">*</span><span class="text">The starting point can be selected as July 2011, when the first PMDA HPV vaccine injury certification is confirmed, or March 2022, when the visit series begins. Certification recipients whose age is unknown, including those before December 14, 2018, are treated as ages 15–19.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">Symptom-visit patient data starts from the MHLW surveillance survey's own start date of March 2022, as no data exists before that.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">The age toggle applies to injury certifications, cervical cancer cases and deaths, and female suicide and all-cause deaths, but not to symptom-visit patients, which have no age breakdown. Cervical cancer uses annual data; suicide and all-cause deaths use monthly data.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">The share chart on the right is not cumulative; it compares annual counts for 2011 and 2022 in the five-year age band immediately below the selected limit. Population is the confirmed population as of October 1 in each year.</span></div>
</div>

<section data-language-content="ja" style="font-size:15px;color:#111;margin-top:18px;line-height:1.9;border-top:0.5px solid #e1e0d9;padding-top:14px">
<h2 style="font-size:15px;font-weight:500;margin-bottom:6px">出典</h2>
<p class="source-item">HPVワクチン健康被害認定者（定期接種）: 厚生労働省「疾病・障害認定審査会 感染症・予防接種審査分科会 審議結果一覧」<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/stf/shingi/shingi-shippei_127696_00006.html">https://www.mhlw.go.jp/stf/shingi/shingi-shippei_127696_00006.html</a>
</p>

<p class="source-item">HPVワクチン健康被害認定者（旧任意接種・PMDA）：厚生労働省「HPVワクチン副反応被害判定調査会」<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/stf/shingi-yakuji_39216.html">https://www.mhlw.go.jp/stf/shingi-yakuji_39216.html</a><br>
<a target="_blank" rel="noopener" href="https://warp.ndl.go.jp/web/20250702154652/https://www.mhlw.go.jp/stf/shingi/shingi-yakuji_366199.html">https://warp.ndl.go.jp/web/20250702154652/https://www.mhlw.go.jp/stf/shingi/shingi-yakuji_366199.html</a><br>
</p>

<p class="source-item">最初の認定（2011年7月）: PMDA「副作用救済給付の決定に関する情報」2011年度7月分、2017年9月時点295人: 厚生労働省パンフレット<br>
<a target="_blank" rel="noopener" href="https://www.pmda.go.jp/files/000157220.pdf">https://www.pmda.go.jp/files/000157220.pdf</a><br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/10601000/000590796.pdf">https://www.mhlw.go.jp/content/10601000/000590796.pdf</a>
</p>

<p class="source-item">PMDA側 2021年3月末時点317人<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/000901929.pdf">https://www.mhlw.go.jp/content/000901929.pdf</a>
</p>

<p class="source-item">PMDA側 2025年3月末時点321人<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/10900000/001699794.pdf">https://www.mhlw.go.jp/content/10900000/001699794.pdf</a>
</p>

<p class="source-item">子宮頸癌罹患・死亡データ（女性・子宮頸部C53・15歳以上）：2011～2015年の罹患は全国がん罹患モニタリング集計による公式推計、2016年以降の罹患は全国がん登録、死亡は人口動態統計。国立がん研究センター「がん統計」<br>
<a target="_blank" rel="noopener" href="https://ganjoho.jp/reg_stat/statistics/data/dl/index.html">https://ganjoho.jp/reg_stat/statistics/data/dl/index.html</a>
</p>
<p class="source-item">女性人口：e-Stat「人口推計 各月1日現在人口 月次」（各年10月1日現在の確定人口）<br>
<a target="_blank" rel="noopener" href="https://www.e-stat.go.jp/stat-search/files?page=1&amp;layout=datalist&amp;toukei=00200524&amp;tstat=000000090001&amp;cycle=1&amp;tclass1=000001011678&amp;cycle_facet=tclass1&amp;tclass2val=0">https://www.e-stat.go.jp/stat-search/files?page=1&amp;layout=datalist&amp;toukei=00200524&amp;tstat=000000090001&amp;cycle=1&amp;tclass1=000001011678&amp;cycle_facet=tclass1&amp;tclass2val=0</a>
</p>
<p class="source-item">女性の自殺・全死因（月次）: e-Stat「人口動態統計 月報（概数）」<br>
<a target="_blank" rel="noopener" href="https://www.e-stat.go.jp/stat-search/files?page=1&amp;layout=datalist&amp;toukei=00450011&amp;tstat=000001028897&amp;cycle=1&amp;tclass1=000001053058&amp;tclass2=000001053060&amp;tclass3val=0">https://www.e-stat.go.jp/stat-search/files?page=1&amp;layout=datalist&amp;toukei=00450011&amp;tstat=000001028897&amp;cycle=1&amp;tclass1=000001053058&amp;tclass2=000001053060&amp;tclass3val=0</a>
</p>
<p class="source-item">体調不良を主訴として協力医療機関を受診した患者数(HPVワクチンの安全性に関するフォローアップ研究、第110回副反応検討部会資料3-4、2026年2月4日)<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/11120000/001650654.pdf">https://www.mhlw.go.jp/content/11120000/001650654.pdf</a>
</p>
</section>

<section data-language-content="en" style="font-size:15px;color:#111;margin-top:18px;line-height:1.9;border-top:0.5px solid #e1e0d9;padding-top:14px">
<h2 style="font-size:15px;font-weight:500;margin-bottom:6px">Sources</h2>
<p class="source-item">HPV vaccine injury certification recipients (routine vaccination): MHLW, Review Results of the Infectious Diseases and Immunization Subcommittee<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/stf/shingi/shingi-shippei_127696_00006.html">https://www.mhlw.go.jp/stf/shingi/shingi-shippei_127696_00006.html</a>
</p>
<p class="source-item">HPV vaccine injury certification recipients (former voluntary vaccination / PMDA): MHLW's HPV Vaccine Adverse Reaction Damage Assessment Committee<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/stf/shingi-yakuji_39216.html">https://www.mhlw.go.jp/stf/shingi-yakuji_39216.html</a><br>
<a target="_blank" rel="noopener" href="https://warp.ndl.go.jp/web/20250702154652/https://www.mhlw.go.jp/stf/shingi/shingi-yakuji_366199.html">https://warp.ndl.go.jp/web/20250702154652/https://www.mhlw.go.jp/stf/shingi/shingi-yakuji_366199.html</a><br>
</p>
<p class="source-item">First certification (July 2011): PMDA benefit decision list; 295 recipients as of September 2017: MHLW pamphlet<br>
<a target="_blank" rel="noopener" href="https://www.pmda.go.jp/files/000157220.pdf">https://www.pmda.go.jp/files/000157220.pdf</a><br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/10601000/000590796.pdf">https://www.mhlw.go.jp/content/10601000/000590796.pdf</a>
</p>
<p class="source-item">PMDA side, as of end of March 2021: 317<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/000901929.pdf">https://www.mhlw.go.jp/content/000901929.pdf</a>
</p>
<p class="source-item">PMDA side, as of end of March 2025: 321<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/10900000/001699794.pdf">https://www.mhlw.go.jp/content/10900000/001699794.pdf</a>
</p>
<p class="source-item">Cervical cancer incidence/mortality data (female, cervix uteri C53, ages 15 and over): 2011–2015 incidence is an official MCIJ estimate; incidence from 2016 is from the National Cancer Registry; mortality is from Vital Statistics. Cancer Statistics, National Cancer Center Japan<br>
<a target="_blank" rel="noopener" href="https://ganjoho.jp/reg_stat/statistics/data/dl/index.html">https://ganjoho.jp/reg_stat/statistics/data/dl/index.html</a>
</p>
<p class="source-item">Female population: e-Stat, Population Estimates, monthly population as of the first day of each month (confirmed population as of October 1 in each year)<br>
<a target="_blank" rel="noopener" href="https://www.e-stat.go.jp/stat-search/files?page=1&amp;layout=datalist&amp;toukei=00200524&amp;tstat=000000090001&amp;cycle=1&amp;tclass1=000001011678&amp;cycle_facet=tclass1&amp;tclass2val=0">https://www.e-stat.go.jp/stat-search/files?page=1&amp;layout=datalist&amp;toukei=00200524&amp;tstat=000000090001&amp;cycle=1&amp;tclass1=000001011678&amp;cycle_facet=tclass1&amp;tclass2val=0</a>
</p>
<p class="source-item">Monthly female suicide and all-cause deaths: e-Stat, Vital Statistics, Monthly Report (Preliminary)<br>
<a target="_blank" rel="noopener" href="https://www.e-stat.go.jp/stat-search/files?page=1&amp;layout=datalist&amp;toukei=00450011&amp;tstat=000001028897&amp;cycle=1&amp;tclass1=000001053058&amp;tclass2=000001053060&amp;tclass3val=0">https://www.e-stat.go.jp/stat-search/files?page=1&amp;layout=datalist&amp;toukei=00450011&amp;tstat=000001028897&amp;cycle=1&amp;tclass1=000001053058&amp;tclass2=000001053060&amp;tclass3val=0</a>
</p>
<p class="source-item">Number of patients visiting designated medical institutions with symptoms as primary complaint (Follow-up study on HPV vaccine safety, 110th Adverse Reaction Review Committee, Document 3-4, February 4, 2026)<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/11120000/001650654.pdf">https://www.mhlw.go.jp/content/11120000/001650654.pdf</a>
</p>
</section>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<script>
var I18N = {
  ja: {
    title: "HPVワクチン接種後の体調不良新規受診者数の累積と健康被害認定・子宮頸癌患者・死者との比較",
    h1: "HPVワクチン接種後の体調不良新規受診者数の累積と<br>健康被害認定・子宮頸癌患者・死者との比較",
    srDesc: "HPVワクチン健康被害認定者、子宮頸癌罹患者・死亡者、接種後の体調不良を主訴とする協力医療機関の新規受診者について、選択した起点からの累積値を比較する。年齢区分は15歳以上20歳未満から40歳未満まで切り替えられ、自殺・全死因の月次累積値も上段グラフへ追加できる。",
    ageGroupLabel: "15歳以上",
    btn20: "20歳未満",
    btn25: "25歳未満",
    btn30: "30歳未満",
    btn35: "35歳未満",
    btn40: "40歳未満",
    btn45: "45歳未満",
    btn50: "50歳未満",
    btn55: "55歳未満",
    btn60: "60歳未満",
    btn65: "65歳未満",
    startLabel: "累積の起点",
    startOptions: {2011:"2011年7月（最初の認定）",2022:"2022年3月（受診者系列の開始）"},
    deathsButton: "自殺・全死因",
    seriesLabel: "表示項目",
    chartAllHeading: "HPVワクチン接種後の体調不良新規受診者数の累積",
    chartAllSub: "",
    chartAllAria: "選択した起点からの累積値を同じ目盛りで比較し、自殺・全死因も追加できる折れ線グラフ。",
    chartAllFallback: "全系列データ",
    chartZoomHeading: "HPVワクチン健康被害認定者数の累積",
    chartZoomSub: "",
    chartZoomAria: "健康被害認定者数をY軸上限として、認定者、罹患者、死亡者を比較する折れ線グラフ。",
    chartZoomFallback: "拡大図データ",
    legendShinryo: "体調不良を主訴として協力医療機関を受診した患者(新規・累積)",
    legendNintei: function(age){ return 'HPVワクチン健康被害認定者・'+age+'歳未満(累積)'; },
    legendRikan: function(age){ return '子宮頸癌罹患者・'+age+'歳未満(累積)'; },
    legendShibo: function(age){ return '子宮頸癌死亡者・'+age+'歳未満(累積)'; },
    legendSuicide: function(age){ return '女性の自殺・'+age+'歳未満(月次・累積)'; },
    legendAllCause: function(age){ return '女性の全死因・'+age+'歳未満(月次・累積)'; },
    compareHeading: function(age){ return '女性・'+(age-5)+'歳以上'+age+'歳未満の年間人数と割合'; },
    denomAll: '全死因',
    denomPopulation: '人口',
    compareAllCause: '全死因死亡',
    compareSuicide: '自殺死亡',
    compareCervical: '子宮頸癌死亡',
    compareOtherDeaths: 'その他の死亡',
    compareOtherPopulation: '死亡以外の人口',
    compareAria: '2011年と2022年について、女性の全死因死亡、自殺死亡、子宮頸癌死亡の年間人数と割合を比較する棒グラフ。',
    dsNintei: 'HPVワクチン健康被害認定者',
    dsRikan: function(age){ return '子宮頸癌罹患者('+age+'歳未満)'; },
    dsShibo: function(age){ return '子宮頸癌死亡者('+age+'歳未満)'; },
    unit: '人',
    priorNote: '',
    tooltipTitle: function(year, month){ return year + '年' + month + '月頃の値(左側=直近確定値)'; }
  },
  en: {
    title: "Cumulative Post-HPV-Vaccination Symptom New Hospital Visits Compared with Vaccine Injury Certifications and Cervical Cancer Cases/Deaths",
    h1: "Cumulative Post-HPV-Vaccination Symptom New Hospital Visits<br>Compared with Vaccine Injury Certifications and Cervical Cancer Cases/Deaths",
    srDesc: "Cumulative values from the selected starting point for HPV vaccine injury certifications, cervical cancer cases and deaths, and new symptom-related visits to designated medical institutions. Age ranges start at 15, and monthly cumulative suicide and all-cause deaths can also be added to the upper chart.",
    ageGroupLabel: "Age 15 and over",
    btn20: "Under 20",
    btn25: "Under 25",
    btn30: "Under 30",
    btn35: "Under 35",
    btn40: "Under 40",
    btn45: "Under 45",
    btn50: "Under 50",
    btn55: "Under 55",
    btn60: "Under 60",
    btn65: "Under 65",
    startLabel: "Cumulative starting point",
    startOptions: {2011:"July 2011 (first certification)",2022:"March 2022 (start of visit series)"},
    deathsButton: "Suicide / All Causes",
    seriesLabel: "Visible series",
    chartAllHeading: "Cumulative New Symptom-Related Visits after HPV Vaccination",
    chartAllSub: "",
    chartAllAria: "Line chart comparing cumulative series from the selected starting point, with optional suicide and all-cause deaths.",
    chartAllFallback: "All-series data",
    chartZoomHeading: "Cumulative HPV Vaccine Injury Certification Recipients",
    chartZoomSub: "",
    chartZoomAria: "Line chart comparing certifications, cancer cases and deaths with the certification count as the Y-axis maximum.",
    chartZoomFallback: "Enlarged view data",
    legendShinryo: "Patients visiting with symptoms (new, cumulative)",
    legendNintei: function(age){ return 'HPV vaccine injury certification recipients, under '+age+' (cumulative)'; },
    legendRikan: function(age){ return 'Cervical cancer cases, under '+age+' (cumulative)'; },
    legendShibo: function(age){ return 'Cervical cancer deaths, under '+age+' (cumulative)'; },
    legendSuicide: function(age){ return 'Female suicide, under '+age+' (monthly, cumulative)'; },
    legendAllCause: function(age){ return 'Female all-cause deaths, under '+age+' (monthly, cumulative)'; },
    compareHeading: function(age){ return 'Annual count and share: females ages '+(age-5)+' to under '+age; },
    denomAll: 'All causes',
    denomPopulation: 'Population',
    compareAllCause: 'All-cause deaths',
    compareSuicide: 'Suicide deaths',
    compareCervical: 'Cervical cancer deaths',
    compareOtherDeaths: 'Other deaths',
    compareOtherPopulation: 'Population excluding deaths',
    compareAria: 'Bar chart comparing annual counts and shares of female all-cause, suicide, and cervical cancer deaths in 2011 and 2022.',
    dsNintei: 'HPV vaccine injury certification recipients',
    dsRikan: function(age){ return 'Cervical cancer cases (under '+age+')'; },
    dsShibo: function(age){ return 'Cervical cancer deaths (under '+age+')'; },
    unit: '',
    priorNote: '',
    tooltipTitle: function(year, month){ return year + '-' + (month<10?'0':'') + month + ' (nearest confirmed value to the left)'; }
  }
};

var CURRENT_LANG = '__LANG__';
var CURRENT_AGE = __AGE__;
var CURRENT_START = __START__;
var CURRENT_SUICIDE = __SUICIDE__;
var CURRENT_ALL_CAUSE = __ALL_CAUSE__;
var CURRENT_DENOMINATOR = '__DENOMINATOR__';

function updateUrl(){
  var p = new URLSearchParams(window.location.search);
  p.set('l', CURRENT_LANG);
  p.set('age', CURRENT_AGE + '-');
  p.set('start', String(CURRENT_START));
  p.delete('deaths');
  if(CURRENT_SUICIDE) p.set('suicide','1'); else p.delete('suicide');
  if(CURRENT_ALL_CAUSE) p.set('allcause','1'); else p.delete('allcause');
  if(CURRENT_DENOMINATOR==='population') p.set('denominator','population'); else p.delete('denominator');
  window.history.replaceState(null, '', window.location.pathname + '?' + p.toString());
}

function yfrac(dstr){
  var d = new Date(dstr+'T00:00:00Z');
  var y = d.getUTCFullYear();
  var start = Date.UTC(y,0,1);
  var end = Date.UTC(y+1,0,1);
  return y + (d.getTime()-start)/(end-start);
}
function decPos(y){ return y + 11/12; }

var hpv20Raw = [
['2016-01-01',0],['2018-12-14',1],['2019-09-01',1],['2019-09-27',2],['2019-12-06',5],['2020-06-19',6],['2020-08-20',7],
['2021-03-31',10],['2022-02-10',12],['2022-06-16',14],['2022-12-12',15],['2023-03-14',16],
['2023-05-26',17],['2023-09-15',18],['2023-11-17',19],['2023-12-18',21],['2024-01-19',22],
['2024-02-19',26],['2024-05-02',27],['2024-05-31',30],['2024-06-28',31],['2024-09-26',34],
['2024-10-31',35],['2024-11-29',37],['2024-12-20',37],['2025-01-31',38],['2025-02-21',38],
['2025-03-21',38],['2025-03-31',42],['2025-04-21',46],['2025-05-30',47],['2025-06-18',49],
['2025-07-29',53],['2025-08-25',56],['2025-09-30',57],['2025-10-31',59],['2025-12-23',60],
['2026-01-26',62],['2026-02-24',65],['2026-03-26',66]
];
var hpv25Raw = [
['2016-01-01',0],['2018-12-14',1],['2019-09-01',1],['2019-09-27',2],['2019-12-06',5],['2020-06-19',6],['2020-08-20',7],
['2021-03-31',10],['2022-02-10',12],['2022-06-16',14],['2022-12-12',15],['2023-03-14',16],
['2023-05-26',17],['2023-09-15',18],['2023-11-17',19],['2023-12-18',21],['2024-01-19',22],
['2024-02-19',26],['2024-05-02',28],['2024-05-31',31],['2024-06-28',32],['2024-09-26',35],
['2024-10-31',36],['2024-11-29',39],['2024-12-20',40],['2025-01-31',41],['2025-02-21',42],
['2025-03-21',43],['2025-03-31',47],['2025-04-21',51],['2025-05-30',52],['2025-06-18',54],
['2025-07-29',58],['2025-08-25',61],['2025-09-30',63],['2025-10-31',65],['2025-12-23',66],
['2026-01-26',68],['2026-02-24',73],['2026-03-26',75]
];
var hpv30Raw = hpv25Raw.map(function(r){ return [r[0], r[1] + (r[0]>='2026-02-24' ? 1 : 0)]; });
var hpv35Raw = hpv30Raw.map(function(r){return r.slice();});
var hpv40Raw = hpv30Raw.map(function(r){return r.slice();});
var hpv45Raw = hpv30Raw.map(function(r){return r.slice();});
var hpv50Raw = hpv30Raw.map(function(r){return r.slice();});
var hpv55Raw = hpv30Raw.map(function(r){return r.slice();});
var hpv60Raw = hpv30Raw.map(function(r){return r.slice();});
var hpv65Raw = hpv30Raw.map(function(r){return r.slice();});
// Ages are unavailable for the historical aggregate, so all of it is included
// in every "under N" series. From September 2019 onward, retain each dated
// age-specific routine-vaccination decision and add confirmed PMDA increases.
var ninteiHistory = [['2011-07-01',0],['2017-09-01',295],['2019-08-31',342]];
function detailedNinteiRaw(ageRaw){
  var anchor='2019-08-31', base=0;
  ageRaw.forEach(function(r){ if(r[0]<=anchor) base=r[1]; });
  var out=[ninteiHistory[0].slice(),ninteiHistory[1].slice()];
  ageRaw.forEach(function(r){
    if(r[0]>'2017-09-01' && r[0]<=anchor) out.push([r[0],295+r[1]]);
  });
  out.push(ninteiHistory[2].slice());
  ageRaw.forEach(function(r){
    if(r[0]<=anchor) return;
    var pmdaExtra = r[0]>='2025-03-31' ? 7 : (r[0]>='2021-03-31' ? 3 : 0);
    out.push([r[0],342+(r[1]-base)+pmdaExtra]);
  });
  return out;
}
// 罹患は2011～2015年のMCIJ公式推計と2016年以降の全国がん登録から、C53女性の15歳以上を再集計する。
// Incidence uses female C53 ages 15+ from official MCIJ estimates for 2011–2015 and the National Cancer Registry from 2016.
var rikan20Annual = [[2011,0],[2012,0],[2013,3],[2014,2],[2015,2],[2016,1],[2017,3],[2018,2],[2019,0],[2020,0],[2021,1],[2022,0],[2023,3]];
var rikan25Annual = [[2011,71],[2012,65],[2013,40],[2014,49],[2015,16],[2016,28],[2017,34],[2018,24],[2019,11],[2020,15],[2021,12],[2022,6],[2023,11]];
var rikan30Annual = [[2011,518],[2012,488],[2013,376],[2014,343],[2015,249],[2016,221],[2017,221],[2018,181],[2019,171],[2020,172],[2021,144],[2022,133],[2023,131]];
var rikan35Annual = [[2011,1493],[2012,1301],[2013,1136],[2014,1118],[2015,1029],[2016,935],[2017,881],[2018,798],[2019,705],[2020,663],[2021,620],[2022,610],[2023,589]];
var rikan40Annual = [[2011,2820],[2012,2607],[2013,2288],[2014,2399],[2015,2067],[2016,2048],[2017,1967],[2018,1799],[2019,1700],[2020,1577],[2021,1562],[2022,1448],[2023,1431]];
var rikan45Annual = [[2011,4457],[2012,4146],[2013,3731],[2014,3885],[2015,3448],[2016,3382],[2017,3232],[2018,3045],[2019,2895],[2020,2687],[2021,2702],[2022,2536],[2023,2510]];
var rikan50Annual = [[2011,5542],[2012,5270],[2013,4862],[2014,5004],[2015,4716],[2016,4724],[2017,4567],[2018,4442],[2019,4242],[2020,4004],[2021,4037],[2022,3778],[2023,3730]];
var rikan55Annual = [[2011,6331],[2012,6146],[2013,5732],[2014,5965],[2015,5720],[2016,5744],[2017,5550],[2018,5541],[2019,5350],[2020,5059],[2021,5210],[2022,4980],[2023,4869]];
var rikan60Annual = [[2011,7194],[2012,6964],[2013,6413],[2014,6819],[2015,6504],[2016,6631],[2017,6475],[2018,6440],[2019,6276],[2020,5953],[2021,6184],[2022,5940],[2023,5845]];
var rikan65Annual = [[2011,8379],[2012,7940],[2013,7332],[2014,7799],[2015,7381],[2016,7555],[2017,7311],[2018,7210],[2019,7073],[2020,6684],[2021,6996],[2022,6764],[2023,6691]];
// 死亡は国立がん研究センターXLSのC53女性を15歳以上で直接再集計する。
// Mortality is directly recalculated for female C53 ages 15+ from the National Cancer Center XLS.
var shibo20Annual = [[2011,0],[2012,0],[2013,1],[2014,0],[2015,0],[2016,0],[2017,0],[2018,0],[2019,2],[2020,0],[2021,0],[2022,0],[2023,1],[2024,1]];
var shibo25Annual = [[2011,0],[2012,3],[2013,3],[2014,2],[2015,1],[2016,2],[2017,1],[2018,1],[2019,2],[2020,0],[2021,0],[2022,1],[2023,1],[2024,1]];
var shibo30Annual = [[2011,19],[2012,14],[2013,15],[2014,23],[2015,16],[2016,17],[2017,11],[2018,6],[2019,13],[2020,8],[2021,7],[2022,9],[2023,7],[2024,7]];
var shibo35Annual = [[2011,87],[2012,65],[2013,68],[2014,82],[2015,72],[2016,65],[2017,61],[2018,49],[2019,70],[2020,44],[2021,33],[2022,40],[2023,42],[2024,29]];
var shibo40Annual = [[2011,205],[2012,191],[2013,189],[2014,190],[2015,193],[2016,171],[2017,148],[2018,137],[2019,168],[2020,135],[2021,106],[2022,130],[2023,117],[2024,98]];
var shibo45Annual = [[2011,407],[2012,381],[2013,345],[2014,392],[2015,366],[2016,356],[2017,294],[2018,302],[2019,325],[2020,283],[2021,267],[2022,286],[2023,249],[2024,195]];
var shibo50Annual = [[2011,626],[2012,598],[2013,555],[2014,656],[2015,583],[2016,593],[2017,534],[2018,555],[2019,573],[2020,537],[2021,503],[2022,525],[2023,477],[2024,361]];
var shibo55Annual = [[2011,847],[2012,812],[2013,799],[2014,910],[2015,839],[2016,846],[2017,780],[2018,826],[2019,831],[2020,819],[2021,769],[2022,800],[2023,775],[2024,609]];
var shibo60Annual = [[2011,1075],[2012,1021],[2013,1013],[2014,1137],[2015,1065],[2016,1047],[2017,1001],[2018,1032],[2019,1092],[2020,1067],[2021,1030],[2022,1058],[2023,1013],[2024,853]];
var shibo65Annual = [[2011,1379],[2012,1347],[2013,1306],[2014,1395],[2015,1303],[2016,1247],[2017,1238],[2018,1246],[2019,1337],[2020,1286],[2021,1244],[2022,1280],[2023,1256],[2024,1073]];

var shinryoRaw = [
[2022,3,5],[2022,4,11],[2022,5,17],[2022,6,26],[2022,7,39],[2022,8,54],[2022,9,69],[2022,10,87],[2022,11,103],[2022,12,112],
[2023,1,126],[2023,2,132],[2023,3,142],[2023,4,150],[2023,5,155],[2023,6,173],[2023,7,183],[2023,8,195],[2023,9,216],[2023,10,221],[2023,11,239],[2023,12,258],
[2024,1,267],[2024,2,276],[2024,3,285],[2024,4,297],[2024,5,309],[2024,6,334],[2024,7,355],[2024,8,380],[2024,9,423],[2024,10,484],[2024,11,540],[2024,12,571],
[2025,1,596],[2025,2,608],[2025,3,622],[2025,4,655],[2025,5,678],[2025,6,690],[2025,7,703],[2025,8,714],[2025,9,729],[2025,10,744],[2025,11,750]
];
var shinryoData = shinryoRaw.map(function(r){return {x:r[0]+(r[1]-1)/12, y:r[2]};});

function startX(){ return CURRENT_START===2011 ? 2011+6/12 : 2022+2/12; }
function rebaseEvents(raw){
  var sx=startX(), cutoff=CURRENT_START===2022 ? yfrac('2022-03-31') : sx, base=0;
  raw.forEach(function(r){ if(yfrac(r[0])<=cutoff) base=r[1]; });
  var out=[{x:sx,y:0}];
  raw.forEach(function(r){ var x=yfrac(r[0]); if(x>cutoff) out.push({x:x,y:r[1]-base}); });
  return out;
}
function cumulativeAnnual(raw){
  var total=0, out=[{x:startX(),y:0}];
  raw.forEach(function(r){ if(decPos(r[0])>=startX()){ total+=r[1]; out.push({x:decPos(r[0]),y:total}); } });
  return out;
}
function visitData(){ return shinryoData.filter(function(p){return p.x>=startX();}); }


// 外部data directoryのmstats2026 CSVから確認した女性月次値。公開mstats APIとも全recordを照合済み。
// Monthly female values verified against the external mstats2026 CSV; every record also matches the public mstats API.
var monthlyDeathsRaw = [[2011,1,[0,0,1,13,29,38,42,52,55,43,47,52,68],[160,18,9,41,67,100,140,228,360,476,663,1049,1954]],[2011,2,[0,0,1,12,31,22,42,49,37,38,44,45,56],[119,18,9,41,61,62,150,212,243,405,558,920,1667]],[2011,3,[0,0,2,9,19,43,40,44,58,52,48,56,72],[157,46,31,44,61,103,149,254,347,480,628,1156,1948]],[2011,4,[0,0,0,13,43,43,53,49,45,50,57,64,55],[157,20,16,50,84,113,159,255,318,461,636,993,1852]],[2011,5,[0,0,4,17,54,74,70,95,76,67,61,70,90],[171,61,61,76,107,154,174,315,377,482,702,1053,1957]],[2011,6,[0,0,4,21,48,69,56,73,67,65,55,46,80],[148,37,34,54,86,128,150,251,357,447,632,1006,1743]],[2011,7,[0,0,2,10,47,48,46,68,59,55,66,62,80],[145,27,22,55,94,119,154,274,352,487,661,1017,1816]],[2011,8,[0,0,0,19,35,43,40,68,72,60,55,61,70],[149,40,28,66,99,110,165,274,388,484,675,1080,1952]],[2011,9,[0,0,4,17,40,51,44,67,48,42,53,47,63],[129,27,29,56,97,127,163,276,361,439,626,1040,1859]],[2011,10,[0,0,0,14,33,41,35,34,47,47,53,45,68],[114,16,15,40,70,84,109,190,311,441,640,1007,1825]],[2011,11,[0,0,2,16,38,38,36,38,60,43,52,32,65],[139,19,18,45,74,100,135,220,353,412,559,901,1735]],[2011,12,[0,0,2,6,32,49,48,47,41,43,50,56,65],[160,17,13,38,77,91,132,238,317,488,669,1032,1992]],[2012,1,[0,0,0,9,21,38,48,37,36,44,51,36,62],[115,12,19,31,48,98,136,199,325,439,657,971,1875]],[2012,2,[0,0,4,14,24,33,26,39,37,38,39,48,72],[133,21,16,36,53,74,110,200,290,383,597,935,1809]],[2012,3,[0,0,2,8,35,48,37,45,49,54,56,50,70],[131,18,15,30,66,92,126,212,305,407,638,926,1836]],[2012,4,[0,0,0,14,26,41,33,48,47,40,54,43,52],[146,15,14,34,54,86,118,177,324,385,539,830,1646]],[2012,5,[0,0,2,19,38,44,35,62,51,53,49,43,65],[128,28,21,43,61,83,104,220,310,407,588,884,1628]],[2012,6,[0,0,1,8,32,33,35,37,41,43,48,56,57],[114,10,12,32,63,88,107,175,274,379,587,817,1568]],[2012,7,[0,0,1,15,27,31,42,64,51,51,63,48,64],[99,19,14,37,54,81,115,238,313,385,591,891,1630]],[2012,8,[0,0,1,13,18,44,45,47,56,37,57,31,49],[122,8,17,40,54,85,99,204,289,385,590,865,1696]],[2012,9,[0,0,0,16,29,38,48,41,47,41,55,36,59],[113,23,19,42,62,87,120,193,281,390,580,825,1545]],[2012,10,[0,0,5,24,32,32,46,43,42,51,47,50,64],[120,15,22,55,66,72,115,203,339,404,589,859,1627]],[2012,11,[0,0,2,13,25,33,45,29,54,42,41,49,61],[130,17,16,31,47,77,131,178,302,400,558,873,1621]],[2012,12,[0,0,2,11,23,35,39,48,44,43,45,42,57],[143,19,21,37,68,100,137,197,328,454,626,921,1747]],[2013,1,[0,0,1,12,35,36,35,44,46,50,51,53,65],[121,14,14,34,78,75,130,193,361,444,624,974,1872]],[2013,2,[0,0,2,15,25,26,30,40,51,44,44,37,57],[80,15,14,35,56,61,99,172,260,383,563,852,1653]],[2013,3,[0,0,2,4,26,30,41,47,46,47,48,58,58],[122,18,19,34,56,70,105,207,288,423,569,931,1683]],[2013,4,[0,0,0,9,33,30,38,42,29,52,38,46,65],[99,15,9,34,60,61,121,160,265,407,600,794,1596]],[2013,5,[0,0,4,12,29,29,47,58,55,53,52,49,65],[129,11,15,33,62,77,123,196,331,420,592,836,1516]],[2013,6,[0,0,6,10,35,39,38,32,50,49,48,48,56],[111,22,16,26,68,83,115,171,267,380,542,789,1470]],[2013,7,[0,0,2,16,24,33,41,53,48,49,55,34,55],[125,24,14,44,47,72,101,209,288,403,569,791,1588]],[2013,8,[0,0,7,15,22,34,40,44,46,56,41,35,49],[92,17,19,38,47,78,128,195,322,446,610,806,1647]],[2013,9,[0,0,5,13,24,31,37,51,46,35,43,51,52],[118,11,18,33,56,84,99,190,289,364,577,780,1455]],[2013,10,[0,0,2,11,22,26,36,45,56,48,39,40,47],[101,7,13,25,56,62,125,197,318,407,617,824,1542]],[2013,11,[0,0,2,7,27,36,39,41,47,57,40,39,49],[117,15,16,23,50,87,122,191,280,457,570,857,1625]],[2013,12,[0,0,1,9,29,37,36,31,53,44,56,36,52],[125,15,16,33,60,74,108,194,341,475,639,886,1659]],[2014,1,[0,0,3,13,17,30,34,39,34,42,31,41,41],[107,18,17,28,47,79,146,205,292,446,587,937,1741]],[2014,2,[0,0,1,7,19,25,28,40,37,38,41,31,39],[111,11,15,26,54,70,108,172,301,415,583,850,1490]],[2014,3,[0,1,4,13,27,36,52,53,41,68,44,43,44],[112,20,14,42,50,80,120,213,302,428,624,824,1625]],[2014,4,[0,0,1,7,32,33,42,37,54,43,42,45,51],[108,7,8,33,57,72,122,181,300,392,576,830,1544]],[2014,5,[0,0,1,16,32,31,28,42,47,50,44,50,50],[116,18,16,33,60,81,106,176,307,433,543,797,1400]],[2014,6,[0,0,3,10,25,38,47,47,52,46,38,42,51],[124,25,18,25,55,83,120,174,279,374,500,783,1377]],[2014,7,[0,0,4,9,25,26,38,34,44,44,34,39,45],[103,15,14,28,48,74,112,170,313,401,528,826,1393]],[2014,8,[0,0,6,8,27,29,32,49,48,59,48,56,57],[111,9,15,28,45,73,88,191,303,408,537,797,1447]],[2014,9,[0,0,6,11,32,29,23,53,47,37,42,44,48],[109,12,17,32,62,71,93,175,306,382,549,803,1305]],[2014,10,[0,0,1,8,27,38,48,47,41,60,59,46,59],[81,16,16,26,64,81,132,158,281,438,604,819,1469]],[2014,11,[0,0,2,9,23,37,29,44,47,45,42,49,45],[121,14,15,33,54,67,80,169,330,419,594,816,1406]],[2014,12,[0,0,1,10,24,28,29,35,41,49,54,43,43],[138,19,18,31,59,80,95,178,302,441,662,954,1542]],[2015,1,[0,0,2,10,21,31,38,46,48,40,42,42,43],[95,17,17,31,47,64,112,205,343,453,653,862,1577]],[2015,2,[0,0,1,10,23,13,28,21,39,33,44,44,42],[109,16,20,24,52,54,90,123,268,408,553,786,1319]],[2015,3,[0,0,1,16,32,30,42,29,61,41,44,46,44],[108,19,23,39,66,73,118,178,314,429,557,794,1357]],[2015,4,[0,0,4,18,24,27,34,26,38,63,35,43,45],[98,12,22,43,44,71,107,157,267,410,497,742,1365]],[2015,5,[0,0,0,13,19,28,22,30,42,58,54,40,44],[110,18,14,41,47,76,101,141,309,369,557,743,1329]],[2015,6,[0,0,2,9,22,27,23,31,49,38,40,37,43],[96,8,11,24,39,65,91,147,282,386,546,662,1235]],[2015,7,[0,0,0,6,34,25,33,25,52,52,56,50,42],[95,19,14,25,66,50,113,151,327,396,586,749,1285]],[2015,8,[0,0,4,11,19,27,36,43,42,40,37,36,46],[113,20,27,34,51,84,110,150,287,385,551,754,1345]],[2015,9,[0,0,5,9,21,35,32,36,34,56,54,26,41],[98,18,19,32,40,75,97,171,271,391,573,725,1242]],[2015,10,[0,0,2,15,20,26,28,42,41,41,42,39,45],[99,15,9,36,45,65,106,170,282,408,581,820,1334]],[2015,11,[0,0,4,12,18,28,21,42,46,40,46,38,40],[103,17,14,30,43,71,85,178,296,386,617,807,1281]],[2015,12,[0,0,2,8,18,23,27,38,30,52,39,42,37],[95,20,13,25,46,82,94,176,310,462,609,830,1407]],[2016,1,[0,0,2,11,28,24,19,35,38,34,35,51,46],[116,8,18,29,62,65,106,163,298,398,584,902,1394]],[2016,2,[0,0,1,8,23,25,19,35,33,45,46,34,39],[127,15,22,23,45,67,88,183,311,412,600,845,1322]],[2016,3,[0,0,0,9,33,34,31,32,39,51,49,40,40],[113,17,16,30,61,77,103,172,303,462,605,798,1278]],[2016,4,[0,0,3,14,26,23,30,32,41,35,52,37,32],[111,16,13,30,59,64,84,172,276,407,565,716,1249]],[2016,5,[0,0,3,7,16,29,24,40,41,38,56,40,39],[90,17,8,30,49,60,99,163,280,422,599,745,1243]],[2016,6,[0,0,2,10,18,16,32,31,34,43,48,38,31],[89,12,13,29,37,44,99,153,276,416,576,706,1126]],[2016,7,[0,0,2,8,26,16,24,33,42,46,30,33,47],[103,9,22,24,52,53,88,134,296,388,577,705,1198]],[2016,8,[0,0,3,14,18,20,34,42,30,38,28,28,44],[91,13,16,27,46,55,102,147,278,441,557,726,1156]],[2016,9,[0,0,2,12,15,26,24,36,36,40,39,40,28],[104,17,12,30,46,70,79,174,266,402,549,755,1156]],[2016,10,[0,0,5,10,20,24,36,45,43,43,28,39,40],[111,12,16,31,60,64,104,164,283,417,541,801,1177]],[2016,11,[0,0,2,14,16,17,22,25,25,38,49,46,35],[112,13,13,31,51,66,86,147,270,419,569,757,1197]],[2016,12,[0,0,3,11,17,34,22,26,30,35,37,38,35],[100,13,17,36,44,81,90,139,289,451,631,805,1263]],[2017,1,[0,0,6,12,23,21,25,32,23,49,26,29,39],[107,10,19,33,43,68,83,152,295,477,547,826,1332]],[2017,2,[0,0,4,8,14,25,28,17,37,36,41,33,33],[115,14,12,26,33,62,90,127,256,397,555,743,1114]],[2017,3,[0,0,1,7,37,25,33,38,38,35,52,33,33],[104,13,13,31,65,61,107,153,317,415,564,703,1203]],[2017,4,[0,0,2,17,28,28,35,33,47,38,34,49,37],[99,6,13,34,49,53,99,144,297,422,509,778,1145]],[2017,5,[0,0,5,8,20,22,27,38,35,44,54,40,40],[79,10,15,19,42,46,98,140,269,377,583,744,1159]],[2017,6,[0,0,3,15,31,20,31,34,39,42,47,30,28],[95,11,9,31,56,49,93,151,259,430,545,681,1051]],[2017,7,[0,0,5,9,22,25,28,25,37,42,37,49,36],[77,11,11,37,40,62,104,136,270,416,547,774,1136]],[2017,8,[0,0,5,14,24,26,21,20,44,49,53,36,36],[87,10,14,29,46,55,91,132,291,432,623,762,1099]],[2017,9,[0,0,3,7,28,28,36,30,33,49,35,34,35],[90,11,18,24,46,76,81,144,256,412,534,694,1062]],[2017,10,[0,0,4,8,24,32,27,23,29,36,51,28,37],[110,16,13,34,55,77,93,136,268,426,521,759,1165]],[2017,11,[0,0,1,7,19,24,23,19,41,35,44,37,31],[96,15,12,26,40,60,66,107,280,405,590,720,1137]],[2017,12,[0,0,2,10,13,18,21,25,21,37,39,40,21],[98,15,12,27,41,60,95,153,256,467,596,836,1198]],[2018,1,[0,0,2,10,16,20,23,18,33,48,48,32,22],[100,10,20,31,37,47,86,134,278,504,640,832,1256]],[2018,2,[0,0,2,13,28,22,34,28,42,33,45,29,29],[87,16,13,38,51,60,90,138,244,427,546,768,1146]],[2018,3,[0,0,2,19,26,25,24,27,43,42,45,35,36],[90,11,22,36,46,58,78,144,264,465,591,735,1177]],[2018,4,[0,0,2,18,27,28,24,23,28,44,41,47,43],[88,18,17,35,54,66,95,138,262,402,554,737,1141]],[2018,5,[0,0,2,19,31,18,31,31,40,46,50,40,37],[97,10,16,34,55,50,74,151,291,398,555,754,1075]],[2018,6,[0,0,2,19,19,25,21,25,45,47,37,32,26],[104,9,10,32,38,58,77,120,259,422,524,684,944]],[2018,7,[0,0,4,20,38,25,29,29,36,37,47,19,35],[87,16,12,35,64,60,102,144,254,420,610,775,1111]],[2018,8,[0,0,5,16,19,30,29,31,34,55,55,31,33],[86,17,18,27,50,63,85,123,229,440,578,707,1067]],[2018,9,[0,0,3,16,34,22,31,22,33,43,40,29,24],[93,10,15,34,62,54,97,135,266,383,528,733,1006]],[2018,10,[0,0,3,13,23,31,23,34,40,42,34,42,33],[87,13,14,27,48,59,100,151,232,464,545,777,1082]],[2018,11,[0,0,3,12,23,26,27,26,36,36,47,41,24],[112,14,17,32,47,62,84,135,227,453,613,777,1109]],[2018,12,[0,0,3,21,19,26,19,26,32,48,45,43,31],[96,13,23,35,48,61,81,141,288,462,621,794,1227]],[2019,1,[0,0,6,20,23,23,27,25,18,47,33,28,27],[98,14,17,41,50,62,95,147,242,529,623,833,1214]],[2019,2,[0,0,4,15,25,21,20,36,29,43,37,33,29],[96,14,9,31,55,51,78,131,237,412,587,783,1101]],[2019,3,[0,0,3,19,24,26,24,32,28,39,46,31,36],[95,10,19,30,46,54,95,138,264,411,567,723,1071]],[2019,4,[0,0,1,20,27,31,27,19,31,39,42,30,32],[78,15,17,42,58,60,79,116,223,387,555,723,1083]],[2019,5,[0,0,4,16,27,23,22,25,35,40,52,32,35],[99,15,15,36,50,50,93,126,275,445,567,718,1014]],[2019,6,[0,0,2,16,21,21,24,26,41,45,35,32,32],[93,8,14,34,41,49,76,136,247,402,535,731,991]],[2019,7,[0,0,5,13,21,33,23,28,25,40,43,39,38],[82,15,19,34,52,71,90,130,241,406,570,753,1055]],[2019,8,[0,0,3,6,25,23,15,29,33,41,35,36,27],[81,16,17,31,48,61,65,155,232,441,605,824,1113]],[2019,9,[0,0,8,21,16,25,21,26,30,51,28,31,16],[89,18,18,37,44,57,80,134,205,449,512,720,968]],[2019,10,[0,0,1,12,24,23,26,25,29,30,42,32,27],[85,16,8,28,51,49,92,120,244,429,545,798,1057]],[2019,11,[0,0,4,14,29,25,30,24,38,51,43,35,25],[101,13,18,36,51,59,88,141,241,408,578,693,1102]],[2019,12,[0,0,2,5,30,32,21,31,33,40,48,40,25],[93,16,19,26,66,60,85,152,272,502,656,815,1163]],[2020,1,[0,0,7,14,25,28,14,25,28,47,38,30,25],[88,19,23,30,46,61,75,140,269,458,681,830,1162]],[2020,2,[0,0,8,17,22,27,13,21,13,41,28,29,19],[75,16,22,37,55,60,67,120,210,411,549,720,1053]],[2020,3,[0,0,2,18,28,27,27,24,28,47,33,35,31],[93,10,9,33,43,51,91,117,258,468,558,734,1088]],[2020,4,[0,0,2,13,26,16,11,20,31,28,36,25,32],[70,11,16,26,47,44,53,129,197,419,588,740,1024]],[2020,5,[0,0,2,12,25,22,26,25,19,42,32,36,35],[80,8,11,26,41,44,72,136,204,439,561,696,989]],[2020,6,[0,0,5,24,30,24,23,24,34,42,35,29,33],[67,11,9,41,64,55,75,111,208,435,545,695,902]],[2020,7,[0,0,2,20,38,33,38,42,35,36,62,44,44],[67,12,14,36,64,72,82,141,197,390,598,729,1035]],[2020,8,[0,0,6,33,44,30,28,48,46,57,51,47,39],[80,14,21,55,66,59,76,154,257,430,635,806,1012]],[2020,9,[0,0,7,27,39,38,35,35,51,48,47,40,37],[69,13,17,40,56,71,75,147,243,400,539,705,968]],[2020,10,[0,0,3,19,62,46,55,54,76,77,81,58,52],[65,13,6,35,87,83,106,154,281,456,642,765,1090]],[2020,11,[0,0,7,27,27,43,33,34,51,62,56,43,43],[58,14,14,47,48,76,86,140,258,438,610,781,1008]],[2020,12,[0,0,7,18,47,51,29,36,35,54,46,53,39],[92,14,18,40,78,82,82,143,276,471,617,823,1135]],[2021,1,[0,0,4,17,41,36,35,26,46,65,43,36,38],[78,9,20,30,59,66,93,137,265,453,609,787,1087]],[2021,2,[0,0,8,20,36,35,22,25,36,53,57,42,37],[62,16,17,38,58,63,72,111,203,393,581,771,1019]],[2021,3,[0,0,6,19,52,38,31,35,47,58,55,31,41],[69,6,24,34,81,74,83,141,237,451,613,738,1059]],[2021,4,[0,0,3,23,39,28,34,25,37,60,57,42,35],[64,15,11,41,65,65,98,149,186,411,601,773,1012]],[2021,5,[0,0,7,28,37,41,25,37,38,38,36,56,24],[64,4,17,47,62,74,83,124,216,433,618,729,1054]],[2021,6,[0,0,8,29,37,37,31,38,38,40,49,59,34],[66,7,13,36,63,63,91,126,245,394,564,765,953]],[2021,7,[0,1,6,22,28,33,31,32,28,46,46,48,29],[70,11,19,31,51,69,80,133,237,416,635,744,967]],[2021,8,[0,0,8,23,48,37,33,37,47,44,50,37,35],[73,15,23,41,66,71,77,142,236,427,642,794,1063]],[2021,9,[0,1,8,13,46,35,28,24,32,44,36,41,17],[73,10,14,28,67,70,88,103,206,414,620,710,976]],[2021,10,[0,0,5,16,33,30,25,37,41,40,43,32,43],[95,12,11,35,50,56,70,132,235,392,639,719,1025]],[2021,11,[0,0,3,21,32,20,26,22,37,35,49,40,43],[81,16,13,39,62,44,99,108,210,373,645,734,1036]],[2021,12,[0,0,2,21,35,43,33,32,24,48,54,41,46],[70,15,15,48,59,80,91,115,235,407,681,865,1120]],[2022,1,[0,0,5,18,33,28,22,30,40,49,64,45,42],[68,10,16,35,61,63,76,144,230,434,681,758,1127]],[2022,2,[0,0,3,17,31,26,33,24,35,37,46,30,25],[65,15,11,32,54,75,84,133,211,385,595,776,1075]],[2022,3,[0,0,4,24,41,40,27,21,39,47,45,54,50],[67,11,16,34,67,65,87,138,230,455,652,815,1086]],[2022,4,[0,0,3,21,35,31,31,30,38,43,54,41,38],[71,13,10,38,61,73,96,132,232,375,631,787,1030]],[2022,5,[0,0,5,27,35,40,37,45,49,63,63,64,58],[67,10,20,39,60,63,83,141,240,453,657,777,1040]],[2022,6,[0,0,8,31,32,36,28,35,38,54,50,48,33],[76,9,16,50,55,65,74,119,197,419,579,724,980]],[2022,7,[0,0,1,28,39,26,26,46,29,50,61,43,29],[63,18,18,49,78,63,81,144,232,432,625,767,1070]],[2022,8,[0,0,5,18,33,35,32,27,46,50,33,36,35],[71,17,16,37,59,74,106,147,242,474,677,768,1177]],[2022,9,[0,0,9,28,33,26,32,39,41,49,72,41,40],[77,8,19,42,62,61,91,138,234,416,625,789,1071]],[2022,10,[0,0,2,27,27,24,28,39,31,37,45,51,30],[73,11,11,44,62,73,77,150,223,433,665,841,1065]],[2022,11,[0,0,7,21,37,26,25,24,30,46,52,54,33],[79,9,18,50,66,61,82,139,210,419,632,805,1129]],[2022,12,[0,0,5,19,33,33,29,33,29,47,59,41,35],[80,13,18,38,60,70,85,135,240,475,711,879,1251]],[2023,1,[0,0,6,21,39,33,31,29,45,51,63,51,36],[53,20,20,36,65,65,80,155,241,442,712,948,1195]],[2023,2,[0,0,4,9,37,24,27,25,17,40,56,44,33],[72,15,17,23,59,46,78,136,203,369,625,757,1079]],[2023,3,[0,0,4,18,34,40,32,35,31,35,53,46,40],[75,9,20,34,61,71,79,151,192,437,651,826,1042]],[2023,4,[0,0,12,26,39,27,23,37,29,48,51,46,44],[68,12,17,45,70,61,84,117,201,402,659,733,993]],[2023,5,[0,0,3,24,42,31,34,31,30,49,59,36,35],[76,10,14,45,75,61,88,124,211,362,663,818,1039]],[2023,6,[0,1,6,21,36,40,26,23,41,38,52,39,30],[97,10,17,36,58,70,71,133,199,369,636,727,969]],[2023,7,[0,0,5,36,32,30,22,31,44,38,70,47,33],[85,19,18,59,66,60,72,111,233,418,739,762,1079]],[2023,8,[0,0,5,36,34,43,27,31,44,41,50,45,31],[74,10,17,57,70,74,84,115,240,401,676,822,1124]],[2023,9,[0,0,3,42,37,38,21,34,40,40,55,40,41],[68,7,17,63,63,79,76,138,235,380,664,825,1038]],[2023,10,[0,0,7,26,52,37,27,32,31,43,52,48,38],[67,15,23,40,82,77,75,127,213,410,715,815,1121]],[2023,11,[0,0,4,20,39,26,26,25,25,35,50,55,36],[79,13,11,42,67,57,90,121,202,363,648,759,1113]],[2023,12,[0,0,6,23,42,30,30,13,37,39,55,42,39],[73,12,20,55,65,63,84,118,241,425,691,859,1205]],[2024,1,[0,0,11,22,38,31,21,23,26,49,62,36,32],[72,12,28,44,63,80,77,142,216,378,735,894,1143]],[2024,2,[0,0,6,25,41,36,23,28,31,37,37,39,28],[68,11,29,43,71,81,84,120,209,339,642,802,1045]],[2024,3,[0,0,5,20,51,44,38,22,34,57,46,42,31],[74,11,14,45,82,83,97,154,231,433,618,802,1142]],[2024,4,[0,0,9,29,38,31,36,27,25,43,47,42,37],[72,16,21,42,66,71,82,111,202,400,638,767,1041]],[2024,5,[0,0,10,29,40,38,30,38,31,38,52,38,32],[76,17,21,50,80,74,92,133,208,366,632,815,1058]],[2024,6,[0,0,8,35,43,36,28,35,29,39,53,35,36],[85,14,26,53,66,71,82,121,199,367,629,760,974]],[2024,7,[0,0,8,27,43,31,25,36,38,39,51,36,35],[73,12,27,55,67,65,71,133,205,382,681,827,1046]],[2024,8,[0,0,3,23,29,39,21,21,26,30,44,58,32],[67,21,14,44,46,75,66,123,187,391,697,864,1111]],[2024,9,[0,0,7,31,45,36,17,19,27,36,45,43,31],[70,10,14,52,70,75,60,103,156,359,619,794,1022]],[2024,10,[0,0,3,35,23,43,34,35,28,32,43,47,31],[63,10,8,55,51,73,65,149,204,377,660,819,1038]],[2024,11,[0,1,3,33,36,35,32,28,32,26,56,47,34],[61,12,14,47,65,68,96,130,215,330,664,802,1110]],[2024,12,[0,0,6,17,32,20,23,26,31,38,50,31,36],[100,12,22,40,66,61,85,121,216,432,737,936,1266]],[2025,1,[0,0,4,31,31,31,36,33,26,35,48,32,39],[95,15,16,51,65,63,87,157,230,434,787,897,1320]],[2025,2,[0,0,3,23,29,27,27,24,17,28,36,30,25],[56,15,15,40,55,59,78,115,177,342,600,803,1044]],[2025,3,[0,0,3,24,36,19,33,23,37,35,46,41,27],[69,10,13,49,62,55,85,124,217,377,678,807,1102]],[2025,4,[0,0,7,30,24,30,25,23,29,37,44,29,35],[55,11,13,53,53,54,81,111,187,334,613,785,1015]],[2025,5,[0,0,10,29,35,24,22,40,22,36,42,48,37],[61,11,29,46,64,60,69,135,208,357,591,830,1023]],[2025,6,[0,0,9,31,49,32,36,22,27,36,47,41,28],[73,14,22,44,71,64,74,109,175,298,633,796,1015]],[2025,7,[0,0,0,35,36,31,24,29,30,39,54,44,27],[59,8,12,60,68,64,69,110,197,327,630,830,1017]],[2025,8,[0,0,5,27,30,36,27,22,20,45,44,41,28],[63,12,19,44,70,68,87,122,195,377,611,797,1102]],[2025,9,[0,0,10,33,51,31,25,32,27,34,52,48,23],[41,5,19,51,74,75,71,112,185,316,606,771,999]],[2025,10,[0,0,7,22,31,31,25,30,33,38,51,46,32],[71,10,25,52,53,66,80,121,187,337,608,804,1011]],[2025,11,[0,0,10,21,39,21,20,14,24,27,42,33,28],[68,18,20,45,71,57,62,109,182,312,657,771,1105]],[2025,12,[0,0,4,23,43,36,24,33,26,34,46,34,38],[83,18,24,46,71,83,83,132,199,365,706,854,1207]],[2026,1,[0,0,6,36,35,38,22,17,24,38,48,31,29],[62,17,25,64,59,84,66,105,179,342,658,853,1218]],[2026,2,[0,0,5,28,28,27,14,21,30,36,38,26,24],[75,13,22,51,56,63,65,105,161,312,582,750,1002]]];

function monthlyDeathCumulative(causeIndex, age){
  var cutoff=CURRENT_START===2011 ? 201107 : 202203;
  var fieldCount=age/5;
  var total=0, out=[{x:startX(),y:0}];
  monthlyDeathsRaw.forEach(function(row){
    if(row[0]*100+row[1]<cutoff) return;
    total+=row[causeIndex].slice(3,fieldCount).reduce(function(sum,value){return sum+value;},0);
    out.push({x:row[0]+(row[1]-1)/12,y:total});
  });
  return out;
}

// 右側の比較は時系列・累積ではなく、2011年と2022年の年次実数から選択上限直下の5歳階級を求める。
// The right-hand comparison derives the five-year age band below the selected limit from annual counts for 2011 and 2022.
var annualDeathsByAge={};
[2011,2022].forEach(function(year){
  annualDeathsByAge[year]={};
  [20,25,30,35,40,45,50,55,60,65].forEach(function(age){
    var fieldCount=age/5, suicide=0, allCause=0;
    monthlyDeathsRaw.forEach(function(row){
      if(row[0]!==year) return;
      suicide+=row[2].slice(3,fieldCount).reduce(function(sum,value){return sum+value;},0);
      allCause+=row[3].slice(3,fieldCount).reduce(function(sum,value){return sum+value;},0);
    });
    annualDeathsByAge[year][age]={allCause:allCause,suicide:suicide};
  });
});
// 人口は外部data directoryのCSVにある各年10月1日現在の確定女性人口を、15歳から選択上限未満まで合計した値。
// Population is confirmed female population from the external CSV on October 1, summed from age 15 to the selected upper bound.
var annualPopulationByAge = {
  2011:{20:2958000,25:6074000,30:9621000,35:13608000,40:18394000,45:23004000,50:26966000,55:30787000,60:34979000,65:40393000},
  2022:{20:2682000,25:5729000,30:8847000,35:11993000,40:15537000,45:19455000,50:24126000,55:28806000,60:32844000,65:36605000}
};
function cervicalAnnual(year,age){
  var sources={20:shibo20Annual,25:shibo25Annual,30:shibo30Annual,35:shibo35Annual,40:shibo40Annual,45:shibo45Annual,50:shibo50Annual,55:shibo55Annual,60:shibo60Annual,65:shibo65Annual};
  var source=sources[age];
  var row=source.find(function(r){return r[0]===year;});
  var total=row ? row[1] : 0;
  if(age===20) return total;
  var priorSource=sources[age-5];
  var priorRow=priorSource.find(function(r){return r[0]===year;});
  return total-(priorRow ? priorRow[1] : 0);
}

var ninteiByAge={}, rikanByAge={}, shiboByAge={};
function rebuildData(){
  ninteiByAge={20:rebaseEvents(detailedNinteiRaw(hpv20Raw)),25:rebaseEvents(detailedNinteiRaw(hpv25Raw)),30:rebaseEvents(detailedNinteiRaw(hpv30Raw)),35:rebaseEvents(detailedNinteiRaw(hpv35Raw)),40:rebaseEvents(detailedNinteiRaw(hpv40Raw)),45:rebaseEvents(detailedNinteiRaw(hpv45Raw)),50:rebaseEvents(detailedNinteiRaw(hpv50Raw)),55:rebaseEvents(detailedNinteiRaw(hpv55Raw)),60:rebaseEvents(detailedNinteiRaw(hpv60Raw)),65:rebaseEvents(detailedNinteiRaw(hpv65Raw))};
  rikanByAge={20:cumulativeAnnual(rikan20Annual),25:cumulativeAnnual(rikan25Annual),30:cumulativeAnnual(rikan30Annual),35:cumulativeAnnual(rikan35Annual),40:cumulativeAnnual(rikan40Annual),45:cumulativeAnnual(rikan45Annual),50:cumulativeAnnual(rikan50Annual),55:cumulativeAnnual(rikan55Annual),60:cumulativeAnnual(rikan60Annual),65:cumulativeAnnual(rikan65Annual)};
  shiboByAge={20:cumulativeAnnual(shibo20Annual),25:cumulativeAnnual(shibo25Annual),30:cumulativeAnnual(shibo30Annual),35:cumulativeAnnual(shibo35Annual),40:cumulativeAnnual(shibo40Annual),45:cumulativeAnnual(shibo45Annual),50:cumulativeAnnual(shibo50Annual),55:cumulativeAnnual(shibo55Annual),60:cumulativeAnnual(shibo60Annual),65:cumulativeAnnual(shibo65Annual)};
}
rebuildData();

function makeXScale(){
  var ticks=[];
  for(var y=Math.floor(startX());y<=2026;y++) ticks.push(y);
  return {
    type:'linear', min:startX(), max:2026.4,
    afterBuildTicks: function(axis){ axis.ticks = ticks.map(function(v){return {value:v};}); },
    grid:{color:'#e1e0d9', drawTicks:false},
    border:{color:'#c3c2b7'},
    ticks:{ display:true, color:'#898781', font:{size:16}, callback:function(v){return Math.round(v);} }
  };
}
function fixWidth(axis){ axis.width = 60; }
function paddedAxisMax(value){
  return Math.max(100,Math.ceil(value*1.1/100)*100);
}

var vertLinePlugin = {
  id:'vertLine2022',
  afterDraw: function(chart){
    var xs = chart.scales.x, ys = chart.scales.y;
    var xPix = xs.getPixelForValue(2022 + 2/12);
    var ctx = chart.ctx;
    ctx.save();
    ctx.strokeStyle = '#c3c2b7';
    ctx.setLineDash([3,3]);
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(xPix, ys.top);
    ctx.lineTo(xPix, ys.bottom);
    ctx.stroke();
    ctx.restore();
  }
};

function ninteiTooltipCallback(context){
  var t = I18N[CURRENT_LANG];
  var v = context.parsed.y;
  var text = context.dataset.label + ': ' + v + t.unit;
  return text;
}

Chart.Interaction.modes.leftCarry = function(chart, e, options, useFinalPosition){
  // 実データ点に重なった場合だけ、そのX位置以前の各系列の直近確定値を集める。
  // Only an actual data point triggers the tooltip; other series carry their latest confirmed value to that X position.
  var triggerItems=Chart.Interaction.modes.point(chart,e,{intersect:true},useFinalPosition);
  if(!triggerItems.length) return [];
  var trigger=triggerItems[0];
  var hoveredX=chart.data.datasets[trigger.datasetIndex].data[trigger.index].x;
  var items = [];
  chart.data.datasets.forEach(function(dataset, datasetIndex){
    var meta = chart.getDatasetMeta(datasetIndex);
    if (!meta.visible) return;
    var data = dataset.data;
    var idx = -1;
    for (var i = 0; i < data.length; i++){
      if (data[i].x <= hoveredX) { idx = i; } else { break; }
    }
    if (idx === -1) return;
    var element = meta.data[idx];
    if (element) items.push({ element: element, datasetIndex: datasetIndex, index: idx });
  });
  return items;
};

function titleFromFirst(items){
  if(!items.length) return '';
  var t = I18N[CURRENT_LANG];
  var x = items[0].parsed.x;
  var year = Math.floor(x);
  var month = Math.round((x - year) * 12) + 1;
  if(month > 12){ month = 12; year += 1; }
  return t.tooltipTitle(year, month);
}

var chartAll = new Chart(document.getElementById('chartAll'), {
  type:'line',
  data:{ datasets:[
    { label:'', data:visitData(), borderColor:'#2a78d6', backgroundColor:'#2a78d6', borderWidth:3, pointRadius:4, pointStyle:'star', borderDash:[] },
    { label:'', data:ninteiByAge[20], borderColor:'#e34948', backgroundColor:'#e34948', borderWidth:2.5, pointRadius:5, pointStyle:'circle', borderDash:[] },
    { label:'', data:rikanByAge[20], borderColor:'#eda100', backgroundColor:'#eda100', borderWidth:2.5, pointRadius:6, pointStyle:'rectRot', borderDash:[6,3] },
    { label:'', data:shiboByAge[20], borderColor:'#444441', backgroundColor:'#444441', borderWidth:2.5, pointRadius:5, pointStyle:'rect', borderDash:[1,3] },
    { label:'', data:[], borderColor:'#7a3db8', backgroundColor:'#7a3db8', borderWidth:2.5, pointRadius:0, pointStyle:'triangle', borderDash:[8,3], hidden:true },
    { label:'', data:[], borderColor:'#16856b', backgroundColor:'#16856b', borderWidth:2.5, pointRadius:0, pointStyle:'circle', borderDash:[], hidden:true }
  ]},
  plugins:[vertLinePlugin],
  options:{
    responsive:true, maintainAspectRatio:false,
    scales:{
      x: makeXScale(),
      y:{ min:0, max:800, afterFit:fixWidth, grid:{color:'#e1e0d9'}, border:{color:'#c3c2b7'}, ticks:{color:'#898781', font:{size:16}, stepSize:200} }
    },
    plugins:{ legend:{display:false}, tooltip:{mode:'leftCarry', intersect:true, titleFont:{size:15}, bodyFont:{size:15}, usePointStyle:true, boxWidth:10, boxHeight:10, callbacks:{ title: titleFromFirst, label: ninteiTooltipCallback } } },
    interaction:{ mode:'leftCarry', intersect:true }
  }
});

var chartZoom = new Chart(document.getElementById('chartZoom'), {
  type:'line',
  data:{ datasets:[
    { label:'', data:visitData(), borderColor:'#2a78d6', backgroundColor:'#2a78d6', borderWidth:3, pointRadius:4, pointStyle:'star', borderDash:[] },
    { label:'', data:ninteiByAge[20], borderColor:'#e34948', backgroundColor:'#e34948', borderWidth:2.5, pointRadius:5, pointStyle:'circle', borderDash:[] },
    { label:'', data:rikanByAge[20], borderColor:'#eda100', backgroundColor:'#eda100', borderWidth:2.5, pointRadius:6, pointStyle:'rectRot', borderDash:[6,3] },
    { label:'', data:shiboByAge[20], borderColor:'#444441', backgroundColor:'#444441', borderWidth:2.5, pointRadius:5, pointStyle:'rect', borderDash:[1,3] }
  ]},
  plugins:[vertLinePlugin],
  options:{
    responsive:true, maintainAspectRatio:false,
    scales:{
      x: makeXScale(),
      y:{ min:0, max:80, afterFit:fixWidth, grid:{color:'#e1e0d9'}, border:{color:'#c3c2b7'}, ticks:{color:'#898781', font:{size:16}, precision:0} }
    },
    plugins:{ legend:{display:false}, tooltip:{mode:'leftCarry', intersect:true, titleFont:{size:15}, bodyFont:{size:15}, usePointStyle:true, boxWidth:10, boxHeight:10, callbacks:{ title: titleFromFirst, label: ninteiTooltipCallback } } },
    interaction:{ mode:'leftCarry', intersect:true }
  }
});

var chartCompare = new Chart(document.getElementById('chartCompare'), {
  type:'bar',
  data:{
    labels:['2011','2022'],
    datasets:[
      {label:'',data:[0,0],backgroundColor:'#444441',borderWidth:0},
      {label:'',data:[0,0],backgroundColor:'#7a3db8',borderWidth:0},
      {label:'',data:[0,0],backgroundColor:'#9abdb4',borderWidth:0},
      {label:'',data:[0,0],backgroundColor:'#e1e0d9',borderWidth:0}
    ]
  },
  options:{
    indexAxis:'y',responsive:true,maintainAspectRatio:false,
    scales:{
      x:{stacked:true,min:0,max:100,grid:{color:'#e1e0d9'},border:{color:'#c3c2b7'},ticks:{color:'#898781',callback:function(v){return v+'%';}}},
      y:{stacked:true,grid:{display:false},border:{display:false},ticks:{color:'#52514e',font:{size:15}}}
    },
    plugins:{
      legend:{display:false},
      tooltip:{callbacks:{label:function(context){
        var count=context.dataset.counts[context.dataIndex];
        return context.dataset.label+': '+formatCount(count)+' ('+formatPercent(context.raw)+')';
      }}}
    }
  }
});

function formatCount(value){ return Math.round(value).toLocaleString(CURRENT_LANG==='ja' ? 'ja-JP' : 'en-US'); }
function formatPercent(value){
  var digits=value>=10 ? 1 : (value>=1 ? 2 : (value>=0.01 ? 3 : 5));
  return value.toFixed(digits)+'%';
}
function compareValues(year,age){
  var deaths=annualDeathsByAge[year][age];
  var priorDeaths=age===20 ? {allCause:0,suicide:0} : annualDeathsByAge[year][age-5];
  var population=annualPopulationByAge[year][age]-(age===20 ? 0 : annualPopulationByAge[year][age-5]);
  var cervical=cervicalAnnual(year,age);
  return {
    population:population,
    allCause:deaths.allCause-priorDeaths.allCause,
    suicide:deaths.suicide-priorDeaths.suicide,
    cervical:cervical
  };
}
function updateCompareChart(age){
  var t=I18N[CURRENT_LANG], years=[2011,2022];
  var values=years.map(function(year){return compareValues(year,age);});
  var denominators=values.map(function(v){return CURRENT_DENOMINATOR==='population' ? v.population : v.allCause;});
  var counts=[
    values.map(function(v){return v.cervical;}),
    values.map(function(v){return CURRENT_SUICIDE ? v.suicide : 0;}),
    values.map(function(v){return Math.max(0,v.allCause-(CURRENT_SUICIDE ? v.suicide : 0)-v.cervical);}),
    values.map(function(v){return CURRENT_DENOMINATOR==='population' ? Math.max(0,v.population-v.allCause) : 0;})
  ];
  var labels=[t.compareCervical,t.compareSuicide,t.compareOtherDeaths,t.compareOtherPopulation];
  chartCompare.data.datasets.forEach(function(ds,index){
    ds.label=labels[index];
    ds.counts=counts[index];
    ds.data=counts[index].map(function(value,i){return value/denominators[i]*100;});
  });
  chartCompare.data.datasets[1].hidden=!CURRENT_SUICIDE;
  chartCompare.data.datasets[3].hidden=CURRENT_DENOMINATOR!=='population';
  chartCompare.update();

  var rows=values.map(function(v,index){
    var denominator=denominators[index];
    var entries=[];
    if(CURRENT_DENOMINATOR==='population') entries.push([t.denomPopulation,v.population]);
    entries.push([t.compareAllCause,v.allCause]);
    if(CURRENT_SUICIDE) entries.push([t.compareSuicide,v.suicide]);
    entries.push([t.compareCervical,v.cervical]);
    return '<div class="compare-year"><strong>'+years[index]+'</strong>'+
      entries.map(function(entry){
        var ratio=entry[1]/denominator*100;
        return '<div class="compare-row"><span>'+entry[0]+'</span><span>'+formatCount(entry[1])+' '+(CURRENT_LANG==='ja'?'人':'')+' / '+formatPercent(ratio)+'</span></div>';
      }).join('')+'</div>';
  }).join('');
  document.getElementById('compareSummary').innerHTML=rows;
  var legendItems=[['#444441',t.compareCervical]];
  if(CURRENT_SUICIDE) legendItems.push(['#7a3db8',t.compareSuicide]);
  legendItems.push(['#9abdb4',t.compareOtherDeaths]);
  if(CURRENT_DENOMINATOR==='population') legendItems.push(['#e1e0d9',t.compareOtherPopulation]);
  document.getElementById('compareLegend').innerHTML=legendItems.map(function(item){
    return '<span><span style="display:inline-block;width:9px;height:9px;margin-right:4px;background:'+item[0]+'"></span>'+item[1]+'</span>';
  }).join('');
  document.getElementById('compareHeading').textContent=t.compareHeading(age);
  document.getElementById('chartCompare').setAttribute('aria-label',t.compareAria);
  ['All','Population'].forEach(function(name){
    var mode=name==='Population' ? 'population' : 'allcause';
    var button=document.getElementById('btnDenom'+name);
    button.style.background=CURRENT_DENOMINATOR===mode ? '#2a78d6' : 'transparent';
    button.style.color=CURRENT_DENOMINATOR===mode ? '#fff' : '#52514e';
  });
}

function legendKey(color,dash,marker){
  var markerSvg='';
  if(marker==='circle') markerSvg='<circle cx="16" cy="8" r="4.5" fill="'+color+'"/>';
  else if(marker==='rectRot') markerSvg='<rect x="11.5" y="3.5" width="9" height="9" fill="'+color+'" transform="rotate(45 16 8)"/>';
  else if(marker==='rect') markerSvg='<rect x="11.5" y="3.5" width="9" height="9" fill="'+color+'"/>';
  else if(marker==='star') markerSvg='<polygon points="16,2 17.7,7 23,7 18.7,10.2 20.3,15.2 16,12 11.7,15.2 13.3,10.2 9,7 14.3,7" fill="'+color+'"/>';
  return '<svg width="32" height="16" aria-hidden="true"><line x1="2" y1="8" x2="30" y2="8" stroke="'+color+'" stroke-width="2.5" stroke-dasharray="'+(dash.length ? dash.join(',') : '0')+'"/>'+markerSvg+'</svg>';
}

function renderSeriesLegends(age){
  var t = I18N[CURRENT_LANG];
  var items=[
    ['#2a78d6',[],'star',t.legendShinryo],
    ['#e34948',[],'circle',t.legendNintei(age)],
    ['#eda100',[6,3],'rectRot',t.legendRikan(age)],
    ['#444441',[1,3],'rect',t.legendShibo(age)],
    ['#7a3db8',[8,3],'',t.legendSuicide(age)],
    ['#16856b',[],'circle',t.legendAllCause(age)]
  ];
  items.forEach(function(item,index){
    var checkbox=document.querySelector('[data-series="'+index+'"]');
    var selected=checkbox.checked, label=checkbox.closest('label'), text=document.getElementById('series'+index);
    label.style.background=selected ? item[0] : 'transparent';
    label.style.borderColor=item[0];
    text.style.color=selected ? '#fff' : '#52514e';
    text.textContent=item[3];
    document.getElementById('seriesKey'+index).innerHTML=legendKey(item[0],item[1],item[2]);
  });
}

function updateDeathDatasets(age){
  var t=I18N[CURRENT_LANG];
  var suicide=CURRENT_SUICIDE ? monthlyDeathCumulative(2,age) : [];
  var allCause=CURRENT_ALL_CAUSE ? monthlyDeathCumulative(3,age) : [];
  chartAll.data.datasets[4].data=suicide;
  chartAll.data.datasets[4].label=t.legendSuicide(age);
  chartAll.data.datasets[5].data=allCause;
  chartAll.data.datasets[5].label=t.legendAllCause(age);
  chartAll.setDatasetVisibility(4,CURRENT_SUICIDE);
  chartAll.setDatasetVisibility(5,CURRENT_ALL_CAUSE);
  if(CURRENT_ALL_CAUSE && allCause.length){
    var maximum=Math.max.apply(null,allCause.map(function(point){return point.y;}));
    chartAll.options.scales.y.max=paddedAxisMax(maximum);
    chartAll.options.scales.y.ticks.stepSize=undefined;
  }else{
    var visibleMain=chartAll.data.datasets.slice(0,CURRENT_SUICIDE ? 5 : 4);
    var mainMaximum=Math.max.apply(null,visibleMain.flatMap(function(dataset){return dataset.data.map(function(point){return point.y;});}));
    chartAll.options.scales.y.max=paddedAxisMax(mainMaximum);
    chartAll.options.scales.y.ticks.stepSize=undefined;
  }
}

function setAge(age){
  CURRENT_AGE = age;
  var t = I18N[CURRENT_LANG];
  var ninteiData = ninteiByAge[age];
  var rikanData = rikanByAge[age];
  var shiboData = shiboByAge[age];
  var ninteiMax = Math.max.apply(null, ninteiData.map(function(p){return p.y;}));

  chartAll.data.datasets[0].data = visitData();
  chartAll.data.datasets[0].label = t.legendShinryo;
  chartAll.data.datasets[1].data = ninteiData;
  chartAll.data.datasets[1].label = t.dsNintei;
  chartAll.data.datasets[2].data = rikanData;
  chartAll.data.datasets[2].label = t.dsRikan(age);
  chartAll.data.datasets[3].data = shiboData;
  chartAll.data.datasets[3].label = t.dsShibo(age);
  updateDeathDatasets(age);
  chartAll.update();

  chartZoom.data.datasets[0].data = visitData();
  chartZoom.data.datasets[0].label = t.legendShinryo;
  chartZoom.data.datasets[1].data = ninteiData;
  chartZoom.data.datasets[1].label = t.dsNintei;
  chartZoom.data.datasets[2].data = rikanData;
  chartZoom.data.datasets[2].label = t.dsRikan(age);
  chartZoom.data.datasets[3].data = shiboData;
  chartZoom.data.datasets[3].label = t.dsShibo(age);
  chartZoom.options.scales.y.max = paddedAxisMax(ninteiMax);
  chartZoom.update();

  updateCompareChart(age);

  renderSeriesLegends(age);

  [20,25,30,35,40,45,50,55,60,65].forEach(function(a){
    var b=document.getElementById('btn'+a);
    b.style.background=age===a ? '#2a78d6' : 'transparent';
    b.style.color=age===a ? '#fff' : '#52514e';
  });
  chartAll.update(); chartZoom.update();
}

function setDeathSeries(index,visible){
  var panel=document.getElementById('comparePanel');
  if(index===4) CURRENT_SUICIDE=visible;
  if(index===5) CURRENT_ALL_CAUSE=visible;
  document.querySelector('[data-series="'+index+'"]').checked=visible;
  panel.hidden=!CURRENT_ALL_CAUSE;
  setAge(CURRENT_AGE);
  window.requestAnimationFrame(function(){ chartAll.resize(); chartCompare.resize(); });
}

function setDenominator(value){
  CURRENT_DENOMINATOR=value;
  updateCompareChart(CURRENT_AGE);
}

function setStart(value){
  CURRENT_START=parseInt(value,10);
  rebuildData();
  chartAll.options.scales.x=makeXScale();
  chartZoom.options.scales.x=makeXScale();
  setAge(CURRENT_AGE);
  [2011,2022].forEach(function(y){
    var b=document.getElementById('btnStart'+y);
    b.style.background=CURRENT_START===y ? '#2a78d6' : 'transparent';
    b.style.color=CURRENT_START===y ? '#fff' : '#52514e';
  });
}

function setSeriesVisibility(index, visible){
  if(index>=4){setDeathSeries(index,visible);return;}
  chartAll.setDatasetVisibility(index,visible);
  chartZoom.setDatasetVisibility(index,visible);
  chartAll.update(); chartZoom.update();
  renderSeriesLegends(CURRENT_AGE);
}

function setLang(lang){
  CURRENT_LANG = lang;
  if (window.updateSiteMenu) window.updateSiteMenu(lang);
  var t = I18N[lang];
  document.body.classList.remove('lang-ja', 'lang-en');
  document.body.classList.add('lang-' + lang);
  document.title = t.title;
  document.getElementById('pageTitleTag').textContent = t.title;
  document.getElementById('h1Title').innerHTML = t.h1;
  document.getElementById('srDesc').textContent = t.srDesc;
  document.getElementById('ageGroupLabel').textContent = t.ageGroupLabel;
  document.getElementById('btn20').textContent = t.btn20;
  document.getElementById('btn25').textContent = t.btn25;
  document.getElementById('btn30').textContent = t.btn30;
  document.getElementById('btn35').textContent = t.btn35;
  document.getElementById('btn40').textContent = t.btn40;
  document.getElementById('btn45').textContent = t.btn45;
  document.getElementById('btn50').textContent = t.btn50;
  document.getElementById('btn55').textContent = t.btn55;
  document.getElementById('btn60').textContent = t.btn60;
  document.getElementById('btn65').textContent = t.btn65;
  document.getElementById('startLabel').textContent = t.startLabel;
  document.getElementById('btnStart2011').textContent = t.startOptions[2011];
  document.getElementById('btnStart2022').textContent = t.startOptions[2022];
  document.getElementById('btnDenomAll').textContent = t.denomAll;
  document.getElementById('btnDenomPopulation').textContent = t.denomPopulation;
  document.getElementById('seriesLabel').textContent = t.seriesLabel;
  document.getElementById('chartAllHeading').textContent = t.chartAllHeading;
  document.getElementById('chartAllSub').textContent = t.chartAllSub;
  document.getElementById('chartAll').setAttribute('aria-label', t.chartAllAria);
  document.getElementById('chartAll').textContent = t.chartAllFallback;
  document.getElementById('chartZoomHeading').textContent = t.chartZoomHeading;
  document.getElementById('chartZoomSub').textContent = t.chartZoomSub;
  document.getElementById('chartZoom').setAttribute('aria-label', t.chartZoomAria);
  document.getElementById('chartZoom').textContent = t.chartZoomFallback;

  var bJa = document.getElementById('btnJa');
  var bEn = document.getElementById('btnEn');
  bJa.style.background = lang==='ja' ? '#2a78d6' : 'transparent';
  bJa.style.color = lang==='ja' ? '#fff' : '#52514e';
  bEn.style.background = lang==='en' ? '#2a78d6' : 'transparent';
  bEn.style.color = lang==='en' ? '#fff' : '#52514e';

  setAge(CURRENT_AGE);
}

document.getElementById('btnJa').addEventListener('click', function(){ setLang('ja'); updateUrl(); });
document.getElementById('btnEn').addEventListener('click', function(){ setLang('en'); updateUrl(); });
document.getElementById('btn20').addEventListener('click', function(){ setAge(20); updateUrl(); });
document.getElementById('btn25').addEventListener('click', function(){ setAge(25); updateUrl(); });
document.getElementById('btn30').addEventListener('click', function(){ setAge(30); updateUrl(); });
document.getElementById('btn35').addEventListener('click', function(){ setAge(35); updateUrl(); });
document.getElementById('btn40').addEventListener('click', function(){ setAge(40); updateUrl(); });
document.getElementById('btn45').addEventListener('click', function(){ setAge(45); updateUrl(); });
document.getElementById('btn50').addEventListener('click', function(){ setAge(50); updateUrl(); });
document.getElementById('btn55').addEventListener('click', function(){ setAge(55); updateUrl(); });
document.getElementById('btn60').addEventListener('click', function(){ setAge(60); updateUrl(); });
document.getElementById('btn65').addEventListener('click', function(){ setAge(65); updateUrl(); });
document.getElementById('btnStart2011').addEventListener('click', function(){ setStart(2011); updateUrl(); });
document.getElementById('btnStart2022').addEventListener('click', function(){ setStart(2022); updateUrl(); });
document.getElementById('btnDenomAll').addEventListener('click', function(){ setDenominator('allcause'); updateUrl(); });
document.getElementById('btnDenomPopulation').addEventListener('click', function(){ setDenominator('population'); updateUrl(); });
document.querySelectorAll('[data-series]').forEach(function(box){
  box.addEventListener('change',function(){setSeriesVisibility(parseInt(this.dataset.series,10),this.checked);updateUrl();});
});

setLang(CURRENT_LANG);
setStart(CURRENT_START);
setDeathSeries(4,CURRENT_SUICIDE);
setDeathSeries(5,CURRENT_ALL_CAUSE);
updateUrl();
</script>

</div>
</div>
</body>
</html>
HTMLDOC

html = html.sub('lang-__LANG__', "lang-#{lang}")
html = html.sub("var CURRENT_LANG = '__LANG__';", "var CURRENT_LANG = '#{lang}';")
html = html.sub("var CURRENT_AGE = __AGE__;", "var CURRENT_AGE = #{age};")
html = html.sub("var CURRENT_START = __START__;", "var CURRENT_START = #{start};")
html = html.sub("var CURRENT_SUICIDE = __SUICIDE__;", "var CURRENT_SUICIDE = #{suicide};")
html = html.sub("var CURRENT_ALL_CAUSE = __ALL_CAUSE__;", "var CURRENT_ALL_CAUSE = #{all_cause};")
html = html.sub("var CURRENT_DENOMINATOR = '__DENOMINATOR__';", "var CURRENT_DENOMINATOR = '#{denominator}';")
html = html.sub('__MENU__', menu_html)

puts html
