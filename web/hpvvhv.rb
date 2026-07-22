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
age  = %w[20- 25- 30- 35- 40-].include?(cgi['age']) ? cgi['age'].delete('-') : '20'
start = %w[2011 2022].include?(cgi['start']) ? cgi['start'] : '2011'
deaths = cgi['deaths'] == '1' ? 'true' : 'false'
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
#upperCharts { display:flex;gap:18px;align-items:stretch; }
#chartAllPanel { flex:1 1 100%;min-width:0; }
#comparePanel { flex:0 0 38%;min-width:310px;border:0.5px solid #e1e0d9;border-radius:8px;padding:12px;box-sizing:border-box; }
#compareSummary { font-size:13px;color:#52514e;line-height:1.35;margin-top:8px; }
#compareLegend { display:flex;flex-wrap:wrap;gap:4px 10px;font-size:12px;color:#52514e;margin-top:4px; }
.compare-year { padding:7px 0;border-top:0.5px solid #e1e0d9; }
.compare-year:first-child { border-top:none; }
.compare-row { display:flex;justify-content:space-between;gap:10px; }
.compare-row span:last-child { white-space:nowrap;font-variant-numeric:tabular-nums; }
@media (max-width:760px) {
  #upperCharts { flex-direction:column; }
  #comparePanel { flex-basis:auto;min-width:0;width:100%; }
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
<span id="ageGroupLabel" style="font-size:15px;color:#52514e"></span>
<div style="display:inline-flex;border:0.5px solid #c3c2b7;border-radius:8px;overflow:hidden">
<button id="btn20" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:#2a78d6;color:#fff"></button>
<button id="btn25" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn30" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn35" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
<button id="btn40" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
</div>
</div>

<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:10px">
<span id="startLabel" style="font-size:15px;color:#52514e"></span>
<div style="display:inline-flex;border:0.5px solid #c3c2b7;border-radius:8px;overflow:hidden">
<button id="btnStart2011" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:#2a78d6;color:#fff"></button>
<button id="btnStart2022" type="button" style="padding:6px 16px;font-size:15px;border:none;cursor:pointer;background:transparent;color:#52514e"></button>
</div>
<button id="btnDeaths" type="button" aria-pressed="false" style="padding:6px 16px;font-size:15px;border:0.5px solid #c3c2b7;border-radius:8px;cursor:pointer;background:transparent;color:#52514e"></button>
</div>
<fieldset style="border:0.5px solid #e1e0d9;border-radius:8px;padding:8px 12px;margin:0 0 14px">
<legend id="seriesLabel" style="font-size:15px;color:#52514e;padding:0 5px"></legend>
<div id="seriesChecks" style="display:flex;gap:10px 20px;flex-wrap:wrap;font-size:15px">
<label><input type="checkbox" data-series="0" checked> <span id="series0"></span></label>
<label><input type="checkbox" data-series="1" checked> <span id="series1"></span></label>
<label><input type="checkbox" data-series="2" checked> <span id="series2"></span></label>
<label><input type="checkbox" data-series="3" checked> <span id="series3"></span></label>
</div>
</fieldset>

<div id="chartAllHeading" style="font-size:16px;color:#52514e;margin:6px 0 2px"></div>
<div id="chartAllSub" style="display:none"></div>
<div id="upperCharts">
<div id="chartAllPanel">
<div style="position:relative;width:100%;height:280px">
<canvas id="chartAll" role="img"></canvas>
</div>
<div id="legendAll" style="display:flex;flex-wrap:wrap;gap:18px;margin:10px 0 6px"></div>
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

<div id="chartZoomHeading" style="font-size:16px;color:#52514e;margin:28px 0 2px;border-top:0.5px solid #e1e0d9;padding-top:20px"></div>
<div id="chartZoomSub" style="display:none"></div>
<div style="position:relative;width:100%;height:270px">
<canvas id="chartZoom" role="img"></canvas>
</div>
<div id="legendZoom" style="display:flex;flex-wrap:wrap;gap:18px;margin:10px 0 6px"></div>

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
var CURRENT_DEATHS = __DEATHS__;
var CURRENT_DENOMINATOR = '__DENOMINATOR__';

function updateUrl(){
  var p = new URLSearchParams(window.location.search);
  p.set('l', CURRENT_LANG);
  p.set('age', CURRENT_AGE + '-');
  p.set('start', String(CURRENT_START));
  if(CURRENT_DEATHS) p.set('deaths', '1'); else p.delete('deaths');
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
// 罹患は2016年以降をC53女性の15歳以上で再集計し、2011～2015年は従来のMCIJ値を維持する。
// Incidence uses female C53 ages 15+ from 2016; 2011–2015 retain the previous MCIJ values.
var rikan20Annual = [[2011,8],[2012,0],[2013,7],[2014,2],[2015,3],[2016,1],[2017,3],[2018,2],[2019,0],[2020,0],[2021,1],[2022,0],[2023,3]];
var rikan25Annual = [[2011,79],[2012,65],[2013,44],[2014,49],[2015,17],[2016,28],[2017,34],[2018,24],[2019,11],[2020,15],[2021,12],[2022,6],[2023,11]];
var rikan30Annual = [[2011,526],[2012,488],[2013,380],[2014,343],[2015,250],[2016,221],[2017,221],[2018,181],[2019,171],[2020,172],[2021,144],[2022,133],[2023,131]];
var rikan35Annual = [[2011,1501],[2012,1301],[2013,1140],[2014,1118],[2015,1030],[2016,935],[2017,881],[2018,798],[2019,705],[2020,663],[2021,620],[2022,610],[2023,589]];
var rikan40Annual = [[2011,2828],[2012,2607],[2013,2292],[2014,2399],[2015,2068],[2016,2048],[2017,1967],[2018,1799],[2019,1700],[2020,1577],[2021,1562],[2022,1448],[2023,1431]];
// 死亡は国立がん研究センターXLSのC53女性を15歳以上で直接再集計する。
// Mortality is directly recalculated for female C53 ages 15+ from the National Cancer Center XLS.
var shibo20Annual = [[2011,4],[2012,1],[2013,0],[2014,3],[2015,4],[2016,0],[2017,2],[2018,3],[2019,2],[2020,0],[2021,1],[2022,2],[2023,0],[2024,3]];
var shibo25Annual = [[2011,10],[2012,8],[2013,1],[2014,6],[2015,10],[2016,4],[2017,5],[2018,7],[2019,6],[2020,3],[2021,6],[2022,7],[2023,3],[2024,10]];
var shibo30Annual = [[2011,20],[2012,20],[2013,6],[2014,15],[2015,24],[2016,18],[2017,15],[2018,15],[2019,11],[2020,11],[2021,15],[2022,13],[2023,10],[2024,19]];
var shibo35Annual = [[2011,40],[2012,47],[2013,28],[2014,41],[2015,52],[2016,40],[2017,35],[2018,36],[2019,35],[2020,23],[2021,37],[2022,45],[2023,29],[2024,35]];
var shibo40Annual = [[2011,122],[2012,117],[2013,90],[2014,93],[2015,107],[2016,96],[2017,91],[2018,81],[2019,77],[2020,68],[2021,85],[2022,97],[2023,69],[2024,67]];

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

var monthlyDeathsRaw = [[2011,7,[0,0,2,10,47,48,46,68],[145,27,22,55,94,119,154,274]],[2011,8,[0,0,0,19,35,43,40,68],[149,40,28,66,99,110,165,274]],[2011,9,[0,0,4,17,40,51,44,67],[129,27,29,56,97,127,163,276]],[2011,10,[0,0,0,14,33,41,35,34],[114,16,15,40,70,84,109,190]],[2011,11,[0,0,2,16,38,38,36,38],[139,19,18,45,74,100,135,220]],[2011,12,[0,0,2,6,32,49,48,47],[160,17,13,38,77,91,132,238]],[2012,1,[0,0,0,9,21,38,48,37],[115,12,19,31,48,98,136,199]],[2012,2,[0,0,4,14,24,33,26,39],[133,21,16,36,53,74,110,200]],[2012,3,[0,0,2,8,35,48,37,45],[131,18,15,30,66,92,126,212]],[2012,4,[0,0,0,14,26,41,33,48],[146,15,14,34,54,86,118,177]],[2012,5,[0,0,2,19,38,44,35,62],[128,28,21,43,61,83,104,220]],[2012,6,[0,0,1,8,32,33,35,37],[114,10,12,32,63,88,107,175]],[2012,7,[0,0,1,15,27,31,42,64],[99,19,14,37,54,81,115,238]],[2012,8,[0,0,1,13,18,44,45,47],[122,8,17,40,54,85,99,204]],[2012,9,[0,0,0,16,29,38,48,41],[113,23,19,42,62,87,120,193]],[2012,10,[0,0,5,24,32,32,46,43],[120,15,22,55,66,72,115,203]],[2012,11,[0,0,2,13,25,33,45,29],[130,17,16,31,47,77,131,178]],[2012,12,[0,0,2,11,23,35,39,48],[143,19,21,37,68,100,137,197]],[2013,1,[0,0,1,12,35,36,35,44],[121,14,14,34,78,75,130,193]],[2013,2,[0,0,2,15,25,26,30,40],[80,15,14,35,56,61,99,172]],[2013,3,[0,0,2,4,26,30,41,47],[122,18,19,34,56,70,105,207]],[2013,4,[0,0,0,9,33,30,38,42],[99,15,9,34,60,61,121,160]],[2013,5,[0,0,4,12,29,29,47,58],[129,11,15,33,62,77,123,196]],[2013,6,[0,0,6,10,35,39,38,32],[111,22,16,26,68,83,115,171]],[2013,7,[0,0,2,16,24,33,41,53],[125,24,14,44,47,72,101,209]],[2013,8,[0,0,7,15,22,34,40,44],[92,17,19,38,47,78,128,195]],[2013,9,[0,0,5,13,24,31,37,51],[118,11,18,33,56,84,99,190]],[2013,10,[0,0,2,11,22,26,36,45],[101,7,13,25,56,62,125,197]],[2013,11,[0,0,2,7,27,36,39,41],[117,15,16,23,50,87,122,191]],[2013,12,[0,0,1,9,29,37,36,31],[125,15,16,33,60,74,108,194]],[2014,1,[0,0,3,13,17,30,34,39],[107,18,17,28,47,79,146,205]],[2014,2,[0,0,1,7,19,25,28,40],[111,11,15,26,54,70,108,172]],[2014,3,[0,1,4,13,27,36,52,53],[112,20,14,42,50,80,120,213]],[2014,4,[0,0,1,7,32,33,42,37],[108,7,8,33,57,72,122,181]],[2014,5,[0,0,1,16,32,31,28,42],[116,18,16,33,60,81,106,176]],[2014,6,[0,0,3,10,25,38,47,47],[124,25,18,25,55,83,120,174]],[2014,7,[0,0,4,9,25,26,38,34],[103,15,14,28,48,74,112,170]],[2014,8,[0,0,6,8,27,29,32,49],[111,9,15,28,45,73,88,191]],[2014,9,[0,0,6,11,32,29,23,53],[109,12,17,32,62,71,93,175]],[2014,10,[0,0,1,8,27,38,48,47],[81,16,16,26,64,81,132,158]],[2014,11,[0,0,2,9,23,37,29,44],[121,14,15,33,54,67,80,169]],[2014,12,[0,0,1,10,24,28,29,35],[138,19,18,31,59,80,95,178]],[2015,1,[0,0,2,10,21,31,38,46],[95,17,17,31,47,64,112,205]],[2015,2,[0,0,1,10,23,13,28,21],[109,16,20,24,52,54,90,123]],[2015,3,[0,0,1,16,32,30,42,29],[108,19,23,39,66,73,118,178]],[2015,4,[0,0,4,18,24,27,34,26],[98,12,22,43,44,71,107,157]],[2015,5,[0,0,0,13,19,28,22,30],[110,18,14,41,47,76,101,141]],[2015,6,[0,0,2,9,22,27,23,31],[96,8,11,24,39,65,91,147]],[2015,7,[0,0,0,6,34,25,33,25],[95,19,14,25,66,50,113,151]],[2015,8,[0,0,4,11,19,27,36,43],[113,20,27,34,51,84,110,150]],[2015,9,[0,0,5,9,21,35,32,36],[98,18,19,32,40,75,97,171]],[2015,10,[0,0,2,15,20,26,28,42],[99,15,9,36,45,65,106,170]],[2015,11,[0,0,4,12,18,28,21,42],[103,17,14,30,43,71,85,178]],[2015,12,[0,0,2,8,18,23,27,38],[95,20,13,25,46,82,94,176]],[2016,1,[0,0,2,11,28,24,19,35],[116,8,18,29,62,65,106,163]],[2016,2,[0,0,1,8,23,25,19,35],[127,15,22,23,45,67,88,183]],[2016,3,[0,0,0,9,33,34,31,32],[113,17,16,30,61,77,103,172]],[2016,4,[0,0,3,14,26,23,30,32],[111,16,13,30,59,64,84,172]],[2016,5,[0,0,3,7,16,29,24,40],[90,17,8,30,49,60,99,163]],[2016,6,[0,0,2,10,18,16,32,31],[89,12,13,29,37,44,99,153]],[2016,7,[0,0,2,8,26,16,24,33],[103,9,22,24,52,53,88,134]],[2016,8,[0,0,3,14,18,20,34,42],[91,13,16,27,46,55,102,147]],[2016,9,[0,0,2,12,15,26,24,36],[104,17,12,30,46,70,79,174]],[2016,10,[0,0,5,10,20,24,36,45],[111,12,16,31,60,64,104,164]],[2016,11,[0,0,2,14,16,17,22,25],[112,13,13,31,51,66,86,147]],[2016,12,[0,0,3,11,17,34,22,26],[100,13,17,36,44,81,90,139]],[2017,1,[0,0,6,12,23,21,25,32],[107,10,19,33,43,68,83,152]],[2017,2,[0,0,4,8,14,25,28,17],[115,14,12,26,33,62,90,127]],[2017,3,[0,0,1,7,37,25,33,38],[104,13,13,31,65,61,107,153]],[2017,4,[0,0,2,17,28,28,35,33],[99,6,13,34,49,53,99,144]],[2017,5,[0,0,5,8,20,22,27,38],[79,10,15,19,42,46,98,140]],[2017,6,[0,0,3,15,31,20,31,34],[95,11,9,31,56,49,93,151]],[2017,7,[0,0,5,9,22,25,28,25],[77,11,11,37,40,62,104,136]],[2017,8,[0,0,5,14,24,26,21,20],[87,10,14,29,46,55,91,132]],[2017,9,[0,0,3,7,28,28,36,30],[90,11,18,24,46,76,81,144]],[2017,10,[0,0,4,8,24,32,27,23],[110,16,13,34,55,77,93,136]],[2017,11,[0,0,1,7,19,24,23,19],[96,15,12,26,40,60,66,107]],[2017,12,[0,0,2,10,13,18,21,25],[98,15,12,27,41,60,95,153]],[2018,1,[0,0,2,10,16,20,23,18],[100,10,20,31,37,47,86,134]],[2018,2,[0,0,2,13,28,22,34,28],[87,16,13,38,51,60,90,138]],[2018,3,[0,0,2,19,26,25,24,27],[90,11,22,36,46,58,78,144]],[2018,4,[0,0,2,18,27,28,24,23],[88,18,17,35,54,66,95,138]],[2018,5,[0,0,2,19,31,18,31,31],[97,10,16,34,55,50,74,151]],[2018,6,[0,0,2,19,19,25,21,25],[104,9,10,32,38,58,77,120]],[2018,7,[0,0,4,20,38,25,29,29],[87,16,12,35,64,60,102,144]],[2018,8,[0,0,5,16,19,30,29,31],[86,17,18,27,50,63,85,123]],[2018,9,[0,0,3,16,34,22,31,22],[93,10,15,34,62,54,97,135]],[2018,10,[0,0,3,13,23,31,23,34],[87,13,14,27,48,59,100,151]],[2018,11,[0,0,3,12,23,26,27,26],[112,14,17,32,47,62,84,135]],[2018,12,[0,0,3,21,19,26,19,26],[96,13,23,35,48,61,81,141]],[2019,1,[0,0,6,20,23,23,27,25],[98,14,17,41,50,62,95,147]],[2019,2,[0,0,4,15,25,21,20,36],[96,14,9,31,55,51,78,131]],[2019,3,[0,0,3,19,24,26,24,32],[95,10,19,30,46,54,95,138]],[2019,4,[0,0,1,20,27,31,27,19],[78,15,17,42,58,60,79,116]],[2019,5,[0,0,4,16,27,23,22,25],[99,15,15,36,50,50,93,126]],[2019,6,[0,0,2,16,21,21,24,26],[93,8,14,34,41,49,76,136]],[2019,7,[0,0,5,13,21,33,23,28],[82,15,19,34,52,71,90,130]],[2019,8,[0,0,3,6,25,23,15,29],[81,16,17,31,48,61,65,155]],[2019,9,[0,0,8,21,16,25,21,26],[89,18,18,37,44,57,80,134]],[2019,10,[0,0,1,12,24,23,26,25],[85,16,8,28,51,49,92,120]],[2019,11,[0,0,4,14,29,25,30,24],[101,13,18,36,51,59,88,141]],[2019,12,[0,0,2,5,30,32,21,31],[93,16,19,26,66,60,85,152]],[2020,1,[0,0,7,14,25,28,14,25],[88,19,23,30,46,61,75,140]],[2020,2,[0,0,8,17,22,27,13,21],[75,16,22,37,55,60,67,120]],[2020,3,[0,0,2,18,28,27,27,24],[93,10,9,33,43,51,91,117]],[2020,4,[0,0,2,13,26,16,11,20],[70,11,16,26,47,44,53,129]],[2020,5,[0,0,2,12,25,22,26,25],[80,8,11,26,41,44,72,136]],[2020,6,[0,0,5,24,30,24,23,24],[67,11,9,41,64,55,75,111]],[2020,7,[0,0,2,20,38,33,38,42],[67,12,14,36,64,72,82,141]],[2020,8,[0,0,6,33,44,30,28,48],[80,14,21,55,66,59,76,154]],[2020,9,[0,0,7,27,39,38,35,35],[69,13,17,40,56,71,75,147]],[2020,10,[0,0,3,19,62,46,55,54],[65,13,6,35,87,83,106,154]],[2020,11,[0,0,7,27,27,43,33,34],[58,14,14,47,48,76,86,140]],[2020,12,[0,0,7,18,47,51,29,36],[92,14,18,40,78,82,82,143]],[2021,1,[0,0,4,17,41,36,35,26],[78,9,20,30,59,66,93,137]],[2021,2,[0,0,8,20,36,35,22,25],[62,16,17,38,58,63,72,111]],[2021,3,[0,0,6,19,52,38,31,35],[69,6,24,34,81,74,83,141]],[2021,4,[0,0,3,23,39,28,34,25],[64,15,11,41,65,65,98,149]],[2021,5,[0,0,7,28,37,41,25,37],[64,4,17,47,62,74,83,124]],[2021,6,[0,0,8,29,37,37,31,38],[66,7,13,36,63,63,91,126]],[2021,7,[0,1,6,22,28,33,31,32],[70,11,19,31,51,69,80,133]],[2021,8,[0,0,8,23,48,37,33,37],[73,15,23,41,66,71,77,142]],[2021,9,[0,1,8,13,46,35,28,24],[73,10,14,28,67,70,88,103]],[2021,10,[0,0,5,16,33,30,25,37],[95,12,11,35,50,56,70,132]],[2021,11,[0,0,3,21,32,20,26,22],[81,16,13,39,62,44,99,108]],[2021,12,[0,0,2,21,35,43,33,32],[70,15,15,48,59,80,91,115]],[2022,1,[0,0,5,18,33,28,22,30],[68,10,16,35,61,63,76,144]],[2022,2,[0,0,3,17,31,26,33,24],[65,15,11,32,54,75,84,133]],[2022,3,[0,0,4,24,41,40,27,21],[67,11,16,34,67,65,87,138]],[2022,4,[0,0,3,21,35,31,31,30],[71,13,10,38,61,73,96,132]],[2022,5,[0,0,5,27,35,40,37,45],[67,10,20,39,60,63,83,141]],[2022,6,[0,0,8,31,32,36,28,35],[76,9,16,50,55,65,74,119]],[2022,7,[0,0,1,28,39,26,26,46],[63,18,18,49,78,63,81,144]],[2022,8,[0,0,5,18,33,35,32,27],[71,17,16,37,59,74,106,147]],[2022,9,[0,0,9,28,33,26,32,39],[77,8,19,42,62,61,91,138]],[2022,10,[0,0,2,27,27,24,28,39],[73,11,11,44,62,73,77,150]],[2022,11,[0,0,7,21,37,26,25,24],[79,9,18,50,66,61,82,139]],[2022,12,[0,0,5,19,33,33,29,33],[80,13,18,38,60,70,85,135]],[2023,1,[0,0,6,21,39,33,31,29],[53,20,20,36,65,65,80,155]],[2023,2,[0,0,4,9,37,24,27,25],[72,15,17,23,59,46,78,136]],[2023,3,[0,0,4,18,34,40,32,35],[75,9,20,34,61,71,79,151]],[2023,4,[0,0,12,26,39,27,23,37],[68,12,17,45,70,61,84,117]],[2023,5,[0,0,3,24,42,31,34,31],[76,10,14,45,75,61,88,124]],[2023,6,[0,1,6,21,36,40,26,23],[97,10,17,36,58,70,71,133]],[2023,7,[0,0,5,36,32,30,22,31],[85,19,18,59,66,60,72,111]],[2023,8,[0,0,5,36,34,43,27,31],[74,10,17,57,70,74,84,115]],[2023,9,[0,0,3,42,37,38,21,34],[68,7,17,63,63,79,76,138]],[2023,10,[0,0,7,26,52,37,27,32],[67,15,23,40,82,77,75,127]],[2023,11,[0,0,4,20,39,26,26,25],[79,13,11,42,67,57,90,121]],[2023,12,[0,0,6,23,42,30,30,13],[73,12,20,55,65,63,84,118]],[2024,1,[0,0,11,22,38,31,21,23],[72,12,28,44,63,80,77,142]],[2024,2,[0,0,6,25,41,36,23,28],[68,11,29,43,71,81,84,120]],[2024,3,[0,0,5,20,51,44,38,22],[74,11,14,45,82,83,97,154]],[2024,4,[0,0,9,29,38,31,36,27],[72,16,21,42,66,71,82,111]],[2024,5,[0,0,10,29,40,38,30,38],[76,17,21,50,80,74,92,133]],[2024,6,[0,0,8,35,43,36,28,35],[85,14,26,53,66,71,82,121]],[2024,7,[0,0,8,27,43,31,25,36],[73,12,27,55,67,65,71,133]],[2024,8,[0,0,3,23,29,39,21,21],[67,21,14,44,46,75,66,123]],[2024,9,[0,0,7,31,45,36,17,19],[70,10,14,52,70,75,60,103]],[2024,10,[0,0,3,35,23,43,34,35],[63,10,8,55,51,73,65,149]],[2024,11,[0,1,3,33,36,35,32,28],[61,12,14,47,65,68,96,130]],[2024,12,[0,0,6,17,32,20,23,26],[100,12,22,40,66,61,85,121]],[2025,1,[0,0,4,31,31,31,36,33],[95,15,16,51,65,63,87,157]],[2025,2,[0,0,3,23,29,27,27,24],[56,15,15,40,55,59,78,115]],[2025,3,[0,0,3,24,36,19,33,23],[69,10,13,49,62,55,85,124]],[2025,4,[0,0,7,30,24,30,25,23],[55,11,13,53,53,54,81,111]],[2025,5,[0,0,10,29,35,24,22,40],[61,11,29,46,64,60,69,135]],[2025,6,[0,0,9,31,49,32,36,22],[73,14,22,44,71,64,74,109]],[2025,7,[0,0,0,35,36,31,24,29],[59,8,12,60,68,64,69,110]],[2025,8,[0,0,5,27,30,36,27,22],[63,12,19,44,70,68,87,122]],[2025,9,[0,0,10,33,51,31,25,32],[41,5,19,51,74,75,71,112]],[2025,10,[0,0,7,22,31,31,25,30],[71,10,25,52,53,66,80,121]],[2025,11,[0,0,10,21,39,21,20,14],[68,18,20,45,71,57,62,109]],[2025,12,[0,0,4,23,43,36,24,33],[83,18,24,46,71,83,83,132]],[2026,1,[0,0,6,36,35,38,22,17],[62,17,25,64,59,84,66,105]],[2026,2,[0,0,5,28,28,27,14,21],[75,13,22,51,56,63,65,105]]];

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
var annualDeathsByAge = {
  2011:{
    20:{allCause:606,suicide:167},25:{allCause:1583,suicide:616},30:{allCause:2874,suicide:1175},
    35:{allCause:4654,suicide:1727},40:{allCause:7641,suicide:2411}
  },
  2022:{
    20:{allCause:488,suicide:279},25:{allCause:1233,suicide:688},30:{allCause:2039,suicide:1059},
    35:{allCause:3061,suicide:1409},40:{allCause:4721,suicide:1802}
  }
};
// 人口は各年10月1日現在の確定女性人口を、15歳から選択上限未満まで合計した値。
// Population is confirmed female population on October 1, summed from age 15 to the selected upper bound.
var annualPopulationByAge = {
  2011:{20:2958000,25:6074000,30:9621000,35:13608000,40:18394000},
  2022:{20:2682000,25:5729000,30:8847000,35:11993000,40:15537000}
};
function cervicalAnnual(year,age){
  var source={20:shibo20Annual,25:shibo25Annual,30:shibo30Annual,35:shibo35Annual,40:shibo40Annual}[age];
  var row=source.find(function(r){return r[0]===year;});
  var total=row ? row[1] : 0;
  if(age===20) return total;
  var priorSource={25:shibo20Annual,30:shibo25Annual,35:shibo30Annual,40:shibo35Annual}[age];
  var priorRow=priorSource.find(function(r){return r[0]===year;});
  return total-(priorRow ? priorRow[1] : 0);
}

var ninteiByAge={}, rikanByAge={}, shiboByAge={};
function rebuildData(){
  ninteiByAge={20:rebaseEvents(detailedNinteiRaw(hpv20Raw)),25:rebaseEvents(detailedNinteiRaw(hpv25Raw)),30:rebaseEvents(detailedNinteiRaw(hpv30Raw)),35:rebaseEvents(detailedNinteiRaw(hpv35Raw)),40:rebaseEvents(detailedNinteiRaw(hpv40Raw))};
  rikanByAge={20:cumulativeAnnual(rikan20Annual),25:cumulativeAnnual(rikan25Annual),30:cumulativeAnnual(rikan30Annual),35:cumulativeAnnual(rikan35Annual),40:cumulativeAnnual(rikan40Annual)};
  shiboByAge={20:cumulativeAnnual(shibo20Annual),25:cumulativeAnnual(shibo25Annual),30:cumulativeAnnual(shibo30Annual),35:cumulativeAnnual(shibo35Annual),40:cumulativeAnnual(shibo40Annual)};
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
  var position = Chart.helpers.getRelativePosition(e, chart);
  var xScale = chart.scales.x;
  var hoveredX = xScale.getValueForPixel(position.x);
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
    plugins:{ legend:{display:false}, tooltip:{mode:'leftCarry', intersect:false, titleFont:{size:15}, bodyFont:{size:15}, usePointStyle:true, boxWidth:10, boxHeight:10, callbacks:{ title: titleFromFirst, label: ninteiTooltipCallback } } },
    interaction:{ mode:'leftCarry', intersect:false }
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
    plugins:{ legend:{display:false}, tooltip:{mode:'leftCarry', intersect:false, titleFont:{size:15}, bodyFont:{size:15}, usePointStyle:true, boxWidth:10, boxHeight:10, callbacks:{ title: titleFromFirst, label: ninteiTooltipCallback } } },
    interaction:{ mode:'leftCarry', intersect:false }
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
    values.map(function(v){return v.suicide;}),
    values.map(function(v){return Math.max(0,v.allCause-v.suicide-v.cervical);}),
    values.map(function(v){return CURRENT_DENOMINATOR==='population' ? Math.max(0,v.population-v.allCause) : 0;})
  ];
  var labels=[t.compareCervical,t.compareSuicide,t.compareOtherDeaths,t.compareOtherPopulation];
  chartCompare.data.datasets.forEach(function(ds,index){
    ds.label=labels[index];
    ds.counts=counts[index];
    ds.data=counts[index].map(function(value,i){return value/denominators[i]*100;});
  });
  chartCompare.data.datasets[3].hidden=CURRENT_DENOMINATOR!=='population';
  chartCompare.update();

  var rows=values.map(function(v,index){
    var denominator=denominators[index];
    var entries=CURRENT_DENOMINATOR==='population'
      ? [[t.denomPopulation,v.population],[t.compareAllCause,v.allCause],[t.compareSuicide,v.suicide],[t.compareCervical,v.cervical]]
      : [[t.compareAllCause,v.allCause],[t.compareSuicide,v.suicide],[t.compareCervical,v.cervical]];
    return '<div class="compare-year"><strong>'+years[index]+'</strong>'+
      entries.map(function(entry){
        var ratio=entry[1]/denominator*100;
        return '<div class="compare-row"><span>'+entry[0]+'</span><span>'+formatCount(entry[1])+' '+(CURRENT_LANG==='ja'?'人':'')+' / '+formatPercent(ratio)+'</span></div>';
      }).join('')+'</div>';
  }).join('');
  document.getElementById('compareSummary').innerHTML=rows;
  var legendItems=[['#444441',t.compareCervical],['#7a3db8',t.compareSuicide],['#9abdb4',t.compareOtherDeaths]];
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

function legendItem(color, dash, marker, label){
  var markerSvg = '';
  if(marker==='circle') markerSvg = '<circle cx="16" cy="8" r="4.5" fill="'+color+'"/>';
  else if(marker==='rectRot') markerSvg = '<rect x="11.5" y="3.5" width="9" height="9" fill="'+color+'" transform="rotate(45 16 8)"/>';
  else if(marker==='rect') markerSvg = '<rect x="11.5" y="3.5" width="9" height="9" fill="'+color+'"/>';
  else if(marker==='star') markerSvg = '<polygon points="16,2 17.7,7 23,7 18.7,10.2 20.3,15.2 16,12 11.7,15.2 13.3,10.2 9,7 14.3,7" fill="'+color+'"/>';
  var dashArr = dash.length ? dash.join(',') : '0';
  return '<span style="display:flex;align-items:center;gap:8px;font-size:16px;color:#52514e">'
    + '<svg width="32" height="16">'
    + '<line x1="2" y1="8" x2="30" y2="8" stroke="'+color+'" stroke-width="2.5" stroke-dasharray="'+dashArr+'"/>'
    + markerSvg + '</svg>' + label + '</span>';
}

function renderLegends(age){
  var t = I18N[CURRENT_LANG];
  function item(index,html){ var b=document.querySelector('[data-series="'+index+'"]'); return !b || b.checked ? html : ''; }
  document.getElementById('legendAll').innerHTML =
    item(0,legendItem('#2a78d6', [], 'star', t.legendShinryo)) +
    item(1,legendItem('#e34948', [], 'circle', t.legendNintei(age))) +
    item(2,legendItem('#eda100', [6,3], 'rectRot', t.legendRikan(age))) +
    item(3,legendItem('#444441', [1,3], 'rect', t.legendShibo(age))) +
    (CURRENT_DEATHS ? legendItem('#7a3db8', [8,3], '', t.legendSuicide(age)) : '') +
    (CURRENT_DEATHS ? legendItem('#16856b', [], 'circle', t.legendAllCause(age)) : '');
  document.getElementById('legendZoom').innerHTML =
    item(1,legendItem('#e34948', [], 'circle', t.legendNintei(age))) +
    item(2,legendItem('#eda100', [6,3], 'rectRot', t.legendRikan(age))) +
    item(3,legendItem('#444441', [1,3], 'rect', t.legendShibo(age))) +
    item(0,legendItem('#2a78d6', [], 'star', t.legendShinryo));
}

function updateDeathDatasets(age){
  var t=I18N[CURRENT_LANG];
  var suicide=CURRENT_DEATHS ? monthlyDeathCumulative(2,age) : [];
  var allCause=CURRENT_DEATHS ? monthlyDeathCumulative(3,age) : [];
  chartAll.data.datasets[4].data=suicide;
  chartAll.data.datasets[4].label=t.legendSuicide(age);
  chartAll.data.datasets[5].data=allCause;
  chartAll.data.datasets[5].label=t.legendAllCause(age);
  chartAll.setDatasetVisibility(4,CURRENT_DEATHS);
  chartAll.setDatasetVisibility(5,CURRENT_DEATHS);
  if(CURRENT_DEATHS && allCause.length){
    var maximum=Math.max.apply(null,allCause.map(function(point){return point.y;}));
    chartAll.options.scales.y.max=paddedAxisMax(maximum);
    chartAll.options.scales.y.ticks.stepSize=undefined;
  }else{
    chartAll.options.scales.y.max=800;
    chartAll.options.scales.y.ticks.stepSize=200;
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

  renderLegends(age);

  [20,25,30,35,40].forEach(function(a){
    var b=document.getElementById('btn'+a);
    b.style.background=age===a ? '#2a78d6' : 'transparent';
    b.style.color=age===a ? '#fff' : '#52514e';
  });
  document.getElementById('series1').textContent=t.legendNintei(age);
  document.getElementById('series2').textContent=t.legendRikan(age);
  document.getElementById('series3').textContent=t.legendShibo(age);
  chartAll.update(); chartZoom.update();
}

function setDeaths(visible){
  var button=document.getElementById('btnDeaths');
  var panel=document.getElementById('comparePanel');
  CURRENT_DEATHS=visible;
  panel.hidden=!CURRENT_DEATHS;
  button.setAttribute('aria-pressed',CURRENT_DEATHS ? 'true' : 'false');
  button.style.background=CURRENT_DEATHS ? '#2a78d6' : 'transparent';
  button.style.color=CURRENT_DEATHS ? '#fff' : '#52514e';
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
  chartAll.setDatasetVisibility(index,visible);
  chartZoom.setDatasetVisibility(index,visible);
  chartAll.update(); chartZoom.update();
  renderLegends(CURRENT_AGE);
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
  document.getElementById('startLabel').textContent = t.startLabel;
  document.getElementById('btnStart2011').textContent = t.startOptions[2011];
  document.getElementById('btnStart2022').textContent = t.startOptions[2022];
  document.getElementById('btnDeaths').textContent = t.deathsButton;
  document.getElementById('btnDenomAll').textContent = t.denomAll;
  document.getElementById('btnDenomPopulation').textContent = t.denomPopulation;
  document.getElementById('seriesLabel').textContent = t.seriesLabel;
  document.getElementById('series0').textContent=t.legendShinryo;
  document.getElementById('series1').textContent=t.legendNintei(CURRENT_AGE);
  document.getElementById('series2').textContent=t.legendRikan(CURRENT_AGE);
  document.getElementById('series3').textContent=t.legendShibo(CURRENT_AGE);
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
document.getElementById('btnStart2011').addEventListener('click', function(){ setStart(2011); updateUrl(); });
document.getElementById('btnStart2022').addEventListener('click', function(){ setStart(2022); updateUrl(); });
document.getElementById('btnDeaths').addEventListener('click', function(){ setDeaths(!CURRENT_DEATHS); updateUrl(); });
document.getElementById('btnDenomAll').addEventListener('click', function(){ setDenominator('allcause'); updateUrl(); });
document.getElementById('btnDenomPopulation').addEventListener('click', function(){ setDenominator('population'); updateUrl(); });
document.querySelectorAll('[data-series]').forEach(function(box){
  box.addEventListener('change',function(){setSeriesVisibility(parseInt(this.dataset.series,10),this.checked);});
});

setLang(CURRENT_LANG);
setStart(CURRENT_START);
setDeaths(CURRENT_DEATHS);
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
html = html.sub("var CURRENT_DEATHS = __DEATHS__;", "var CURRENT_DEATHS = #{deaths};")
html = html.sub("var CURRENT_DENOMINATOR = '__DENOMINATOR__';", "var CURRENT_DENOMINATOR = '#{denominator}';")
html = html.sub('__MENU__', menu_html)

puts html
