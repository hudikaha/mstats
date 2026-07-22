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
<div style="position:relative;width:100%;height:280px">
<canvas id="chartAll" role="img"></canvas>
</div>
<div id="legendAll" style="display:flex;flex-wrap:wrap;gap:18px;margin:10px 0 6px"></div>

<div id="chartZoomHeading" style="font-size:16px;color:#52514e;margin:28px 0 2px;border-top:0.5px solid #e1e0d9;padding-top:20px"></div>
<div id="chartZoomSub" style="display:none"></div>
<div style="position:relative;width:100%;height:270px">
<canvas id="chartZoom" role="img"></canvas>
</div>
<div id="legendZoom" style="display:flex;flex-wrap:wrap;gap:18px;margin:10px 0 6px"></div>

<div class="note-list" data-language-content="ja" style="font-size:15px;color:#111;line-height:1.5;margin-top:18px">
<div class="note-item"><span class="mark">※</span><span class="text">起点は、PMDAで最初のHPVワクチン健康被害認定が確認できる2011年7月と、受診者系列開始の2022年3月から選択できる。2018年12月14日より前など年齢が分からない認定者は、すべて20歳未満として扱っている</span></div>
<div class="note-item"><span class="mark">※</span><span class="text">受診患者は厚労省のサーベイランス調査自体が2022年3月分から開始されており、それ以前のデータが存在しないため2022年3月起点からの累積となっている</span></div>
<div class="note-item"><span class="mark">※</span><span class="text">年齢切替は健康被害認定者、子宮頸癌罹患者・死亡者、自殺・全死因に適用され、年齢区分のない受診患者には適用されない。子宮頸癌は年次、自殺・全死因は月次データを累積している</span></div>
</div>

<div class="note-list" data-language-content="en" style="font-size:15px;color:#111;line-height:1.5;margin-top:18px">
<div class="note-item"><span class="mark">*</span><span class="text">The starting point can be selected as July 2011, when the first PMDA HPV vaccine injury certification is confirmed, or March 2022, when the visit series begins. Certification recipients whose age is unknown, including those before December 14, 2018, are treated as under 20.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">Symptom-visit patient data starts from the MHLW surveillance survey's own start date of March 2022, as no data exists before that.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">The age toggle applies to injury certifications, cervical cancer cases and deaths, suicide and all-cause deaths, but not to symptom-visit patients, which have no age breakdown. Cervical cancer uses annual data; suicide and all-cause deaths use monthly data.</span></div>
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

<p class="source-item">子宮頸癌罹患・死亡データ（2011～2015年罹患は全国がん罹患モニタリング集計、2016年以降罹患は全国がん登録、死亡は人口動態統計；国立がん研究センター「がん統計」）<br>
<a target="_blank" rel="noopener" href="https://ganjoho.jp/reg_stat/statistics/data/dl/index.html">https://ganjoho.jp/reg_stat/statistics/data/dl/index.html</a>
</p>
<p class="source-item">自殺・全死因（月次）: e-Stat「人口動態統計 月報（概数）」<br>
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
<p class="source-item">Cervical cancer incidence/mortality data (MCIJ for 2011–2015 incidence, National Cancer Registry from 2016, and Vital Statistics for mortality; Cancer Statistics, National Cancer Center Japan)<br>
<a target="_blank" rel="noopener" href="https://ganjoho.jp/reg_stat/statistics/data/dl/index.html">https://ganjoho.jp/reg_stat/statistics/data/dl/index.html</a>
</p>
<p class="source-item">Monthly suicide and all-cause deaths: e-Stat, Vital Statistics, Monthly Report (Preliminary)<br>
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
    srDesc: "HPVワクチン健康被害認定者、子宮頸癌罹患者・死亡者、接種後の体調不良を主訴とする協力医療機関の新規受診者について、選択した起点からの累積値を比較する。年齢区分は20歳未満から40歳未満まで切り替えられ、自殺・全死因の月次累積値も上段グラフへ追加できる。",
    ageGroupLabel: "年齢区分",
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
    legendSuicide: function(age){ return '自殺・'+age+'歳未満(月次・累積)'; },
    legendAllCause: function(age){ return '全死因・'+age+'歳未満(月次・累積)'; },
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
    srDesc: "Cumulative values from the selected starting point for HPV vaccine injury certifications, cervical cancer cases and deaths, and new symptom-related visits to designated medical institutions. Monthly cumulative suicide and all-cause deaths can also be added to the upper chart.",
    ageGroupLabel: "Age group",
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
    legendSuicide: function(age){ return 'Suicide, under '+age+' (monthly, cumulative)'; },
    legendAllCause: function(age){ return 'All-cause deaths, under '+age+' (monthly, cumulative)'; },
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

function updateUrl(){
  var p = new URLSearchParams(window.location.search);
  p.set('l', CURRENT_LANG);
  p.set('age', CURRENT_AGE + '-');
  p.set('start', String(CURRENT_START));
  if(CURRENT_DEATHS) p.set('deaths', '1'); else p.delete('deaths');
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
var rikan20Annual = [[2011,8],[2012,0],[2013,7],[2014,2],[2015,3],[2016,1],[2017,3],[2018,2],[2019,0],[2020,1],[2021,1],[2022,1],[2023,3]];
var rikan25Annual = [[2011,79],[2012,65],[2013,44],[2014,49],[2015,17],[2016,28],[2017,34],[2018,24],[2019,11],[2020,16],[2021,12],[2022,7],[2023,11]];
var rikan30Annual = [[2011,526],[2012,488],[2013,380],[2014,343],[2015,250],[2016,221],[2017,221],[2018,181],[2019,171],[2020,173],[2021,144],[2022,134],[2023,131]];
var rikan35Annual = [[2011,1501],[2012,1301],[2013,1140],[2014,1118],[2015,1030],[2016,935],[2017,881],[2018,798],[2019,705],[2020,664],[2021,620],[2022,611],[2023,589]];
var rikan40Annual = [[2011,2828],[2012,2607],[2013,2292],[2014,2399],[2015,2068],[2016,2048],[2017,1967],[2018,1799],[2019,1700],[2020,1578],[2021,1562],[2022,1449],[2023,1431]];
var shibo20Annual = [[2011,0],[2012,0],[2013,1],[2014,0],[2015,0],[2016,0],[2017,0],[2018,0],[2019,2],[2020,0],[2021,0],[2022,0],[2023,1],[2024,1]];
var shibo25Annual = [[2011,0],[2012,3],[2013,3],[2014,2],[2015,1],[2016,2],[2017,1],[2018,1],[2019,2],[2020,0],[2021,0],[2022,1],[2023,1],[2024,1]];
var shibo30Annual = [[2011,19],[2012,14],[2013,15],[2014,23],[2015,16],[2016,17],[2017,11],[2018,6],[2019,13],[2020,8],[2021,7],[2022,9],[2023,7],[2024,7]];
var shibo35Annual = [[2011,87],[2012,65],[2013,68],[2014,82],[2015,72],[2016,65],[2017,61],[2018,49],[2019,70],[2020,44],[2021,33],[2022,40],[2023,42],[2024,29]];
var shibo40Annual = [[2011,205],[2012,191],[2013,189],[2014,190],[2015,193],[2016,171],[2017,148],[2018,137],[2019,168],[2020,135],[2021,106],[2022,130],[2023,117],[2024,98]];

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

var monthlyDeathsRaw = [[2011,7,[0,0,10,43,123,137,159,209],[293,64,73,166,270,330,427,733]],[2011,8,[0,0,2,48,116,147,155,205],[301,80,71,180,307,351,447,708]],[2011,9,[0,0,7,51,121,140,156,171],[266,58,53,160,272,317,428,661]],[2011,10,[0,0,4,37,115,134,127,196],[263,40,44,123,224,269,350,558]],[2011,11,[0,0,8,48,108,129,124,167],[286,37,44,131,217,279,369,582]],[2011,12,[0,0,6,32,104,148,145,179],[319,47,42,125,222,285,369,645]],[2012,1,[0,0,2,28,102,126,142,165],[264,34,46,96,192,272,363,619]],[2012,2,[0,0,9,38,103,112,104,178],[266,52,44,100,195,235,331,591]],[2012,3,[0,0,6,34,147,169,140,192],[290,47,38,97,259,293,366,611]],[2012,4,[0,0,2,43,107,155,150,173],[300,36,39,117,205,290,362,532]],[2012,5,[0,0,4,59,128,139,125,182],[264,52,41,127,220,269,328,578]],[2012,6,[0,0,6,36,106,118,146,141],[243,36,34,101,202,265,322,513]],[2012,7,[0,0,7,50,112,124,129,181],[239,43,33,146,206,254,326,572]],[2012,8,[0,0,11,46,86,140,127,154],[228,30,45,136,190,277,315,581]],[2012,9,[0,0,4,45,105,134,123,150],[251,48,43,127,205,270,318,515]],[2012,10,[0,0,8,55,106,122,138,171],[257,44,46,117,213,253,327,578]],[2012,11,[0,0,7,42,91,119,134,134],[264,39,43,102,168,241,338,528]],[2012,12,[0,0,9,33,84,129,128,172],[308,37,57,102,219,284,369,582]],[2013,1,[0,0,7,43,104,133,135,184],[261,37,46,94,225,247,363,617]],[2013,2,[0,0,7,28,92,102,107,161],[217,39,39,89,186,231,301,509]],[2013,3,[0,0,5,25,115,127,144,185],[258,34,42,100,212,258,328,581]],[2013,4,[0,0,4,52,119,134,150,160],[232,41,31,131,217,241,343,514]],[2013,5,[0,0,6,29,116,135,151,200],[267,29,35,100,218,262,337,540]],[2013,6,[0,0,13,42,103,114,114,162],[222,48,34,89,204,242,278,508]],[2013,7,[0,0,7,49,100,123,143,167],[266,55,53,138,172,246,328,551]],[2013,8,[0,0,13,40,83,124,125,168],[232,37,39,131,184,273,327,543]],[2013,9,[0,0,10,38,114,115,135,162],[256,34,40,114,218,228,308,497]],[2013,10,[0,0,7,43,103,98,144,153],[222,24,30,96,197,201,352,509]],[2013,11,[0,0,9,38,85,113,109,137],[261,32,47,99,178,245,296,521]],[2013,12,[0,1,3,27,116,105,141,138],[264,43,31,87,209,219,347,545]],[2014,1,[0,0,8,39,93,120,125,147],[238,44,45,94,199,257,370,576]],[2014,2,[0,1,3,29,101,114,113,114],[231,27,34,88,193,243,318,475]],[2014,3,[0,1,15,38,114,127,146,177],[235,45,47,109,203,265,359,538]],[2014,4,[0,0,7,38,117,120,127,131],[236,40,29,105,208,243,342,479]],[2014,5,[0,0,5,42,106,128,133,168],[240,34,41,99,194,253,343,498]],[2014,6,[0,0,6,35,116,116,140,134],[243,55,38,86,209,226,328,445]],[2014,7,[0,0,12,33,95,114,120,139],[229,45,41,98,185,234,326,470]],[2014,8,[0,0,13,42,81,122,120,153],[239,33,43,121,162,247,285,491]],[2014,9,[0,0,16,43,105,132,114,158],[224,37,43,113,211,249,303,495]],[2014,10,[0,0,6,32,84,126,142,166],[223,37,46,98,197,240,344,467]],[2014,11,[0,0,4,30,84,112,126,142],[245,26,45,92,182,209,294,449]],[2014,12,[0,0,5,32,81,91,112,132],[301,37,49,102,177,207,284,494]],[2015,1,[0,0,8,37,83,105,125,150],[218,34,40,99,153,211,343,517]],[2015,2,[0,0,6,42,74,79,105,114],[217,39,47,95,174,183,259,406]],[2015,3,[0,0,6,42,115,122,141,162],[229,43,46,106,218,236,320,520]],[2015,4,[0,0,13,47,100,89,136,139],[232,29,45,109,187,207,315,448]],[2015,5,[0,0,6,40,95,116,103,134],[242,48,38,102,187,243,296,469]],[2015,6,[0,0,7,40,87,116,106,111],[206,17,33,98,159,227,271,367]],[2015,7,[0,0,5,30,94,96,128,101],[213,42,39,90,189,195,325,421]],[2015,8,[0,0,14,36,85,98,129,125],[233,49,63,126,181,240,308,431]],[2015,9,[0,0,10,34,72,98,105,130],[206,31,34,104,157,200,278,452]],[2015,10,[0,1,3,34,82,108,116,138],[246,36,27,102,166,222,304,452]],[2015,11,[0,0,7,36,83,113,103,144],[223,36,32,98,162,217,258,455]],[2015,12,[0,0,3,28,81,90,101,124],[227,48,26,91,168,234,271,465]],[2016,1,[0,0,8,46,91,95,110,127],[240,25,37,104,197,207,301,454]],[2016,2,[0,0,5,21,73,94,89,121],[243,34,41,71,147,219,263,451]],[2016,3,[0,0,1,27,101,115,124,132],[236,40,40,90,199,228,307,474]],[2016,4,[0,0,7,44,99,102,98,125],[232,34,35,99,198,211,274,454]],[2016,5,[0,0,7,34,76,118,115,127],[215,32,39,96,168,203,303,442]],[2016,6,[0,0,2,33,90,89,120,109],[194,27,26,90,156,177,304,402]],[2016,7,[0,0,7,28,95,88,107,128],[216,26,44,101,179,197,257,409]],[2016,8,[0,0,11,39,82,82,98,121],[200,37,46,97,176,192,278,426]],[2016,9,[0,0,5,42,67,102,102,122],[209,38,32,95,148,217,264,430]],[2016,10,[0,0,7,42,84,96,111,120],[217,31,33,111,180,205,285,413]],[2016,11,[0,0,6,41,64,79,87,109],[207,28,31,100,156,200,249,404]],[2016,12,[0,0,4,32,79,104,88,99],[209,39,36,112,179,222,269,434]],[2017,1,[0,0,8,44,89,80,98,119],[228,28,49,100,167,202,265,428]],[2017,2,[0,0,11,35,77,92,105,86],[220,26,40,90,149,191,254,361]],[2017,3,[0,0,6,31,115,85,117,116],[219,31,39,98,210,186,307,401]],[2017,4,[0,0,7,48,110,95,109,118],[205,33,38,114,188,184,285,403]],[2017,5,[0,0,9,28,89,100,108,152],[194,28,33,67,164,190,292,430]],[2017,6,[0,0,6,45,86,84,109,126],[193,31,26,96,165,173,259,377]],[2017,7,[0,0,12,31,77,83,109,106],[192,34,35,93,153,189,274,382]],[2017,8,[0,0,12,42,78,95,100,125],[185,21,41,122,155,210,290,435]],[2017,9,[0,0,8,50,101,85,123,115],[177,29,39,106,186,201,261,394]],[2017,10,[0,0,7,34,81,105,106,107],[221,32,31,97,174,198,254,386]],[2017,11,[0,0,4,32,79,78,107,90],[201,30,27,91,155,177,252,333]],[2017,12,[0,0,9,38,75,66,87,112],[219,29,39,87,158,175,261,420]],[2018,1,[0,0,8,37,72,73,100,97],[216,28,41,92,142,154,285,399]],[2018,2,[0,0,5,35,82,76,108,124],[176,35,31,86,156,165,254,397]],[2018,3,[0,0,7,38,117,93,116,102],[195,23,48,81,188,198,262,386]],[2018,4,[0,0,6,49,81,79,106,109],[204,28,35,107,164,176,267,377]],[2018,5,[0,0,7,56,83,88,102,108],[194,30,39,104,158,185,262,396]],[2018,6,[0,0,6,56,89,98,86,111],[202,24,32,102,151,184,247,360]],[2018,7,[0,0,12,39,104,85,94,95],[189,33,42,100,196,198,262,371]],[2018,8,[0,0,14,39,83,92,101,108],[189,31,45,104,173,184,271,388]],[2018,9,[0,0,10,43,92,88,116,102],[190,27,34,90,176,186,265,348]],[2018,10,[0,0,7,30,93,104,114,113],[189,25,35,94,181,194,267,397]],[2018,11,[0,0,10,28,76,93,100,104],[239,36,39,79,153,191,228,387]],[2018,12,[0,0,7,53,73,90,93,113],[210,43,42,104,167,203,244,400]],[2019,1,[0,0,10,50,71,103,119,112],[227,39,36,103,166,200,291,416]],[2019,2,[0,0,6,56,98,64,87,102],[180,34,27,92,177,154,223,327]],[2019,3,[0,0,8,42,103,94,104,120],[203,23,38,88,177,179,281,377]],[2019,4,[0,0,10,58,95,96,104,89],[182,34,45,108,186,170,254,339]],[2019,5,[0,0,7,55,89,75,111,127],[191,30,31,103,174,169,267,388]],[2019,6,[0,0,6,46,89,74,85,105],[189,17,28,94,161,161,234,358]],[2019,7,[0,0,9,37,89,105,90,129],[198,31,38,87,179,196,249,391]],[2019,8,[0,0,8,38,91,77,81,104],[169,35,42,112,173,181,221,399]],[2019,9,[0,0,14,63,77,81,91,101],[185,41,43,115,158,169,236,366]],[2019,10,[0,0,1,50,80,60,83,85],[193,31,16,90,168,134,240,334]],[2019,11,[0,0,7,36,77,78,95,95],[198,29,40,102,140,167,219,371]],[2019,12,[0,0,4,31,79,82,95,118],[204,35,42,84,182,175,262,411]],[2020,1,[0,0,11,46,76,99,83,90],[192,39,52,87,150,196,257,376]],[2020,2,[0,0,12,42,76,92,67,95],[175,32,43,97,175,175,200,354]],[2020,3,[0,0,5,38,96,85,108,107],[184,20,28,79,161,177,266,362]],[2020,4,[0,0,7,44,92,73,61,76],[144,21,31,89,172,162,189,352]],[2020,5,[0,0,6,41,88,72,105,118],[166,20,21,90,158,164,242,381]],[2020,6,[0,0,15,56,87,76,88,95],[163,28,41,107,162,153,216,320]],[2020,7,[0,0,8,52,116,107,97,114],[156,24,29,106,185,193,238,352]],[2020,8,[0,0,15,73,132,106,102,127],[161,20,48,149,225,200,250,377]],[2020,9,[0,0,14,75,142,110,107,113],[147,23,39,126,220,204,237,363]],[2020,10,[0,0,8,65,134,116,137,152],[167,22,19,122,215,207,277,415]],[2020,11,[0,0,11,66,90,121,123,112],[129,28,30,117,155,212,255,355]],[2020,12,[0,0,10,41,113,115,112,121],[195,29,45,95,202,206,271,388]],[2021,1,[0,0,8,62,113,115,101,98],[172,27,38,102,178,212,245,359]],[2021,2,[0,0,11,48,113,109,92,105],[142,32,39,102,182,192,210,346]],[2021,3,[0,0,12,48,127,114,114,125],[149,20,37,88,202,220,248,384]],[2021,4,[0,0,9,60,122,100,113,122],[153,32,30,109,205,191,249,409]],[2021,5,[0,0,9,71,111,114,100,111],[153,23,35,119,189,211,260,358]],[2021,6,[0,0,12,57,107,90,106,122],[151,31,25,91,183,154,245,369]],[2021,7,[0,1,12,47,101,108,107,115],[159,29,41,93,175,198,237,370]],[2021,8,[0,0,16,48,109,99,91,127],[155,36,52,102,195,194,218,392]],[2021,9,[0,1,13,47,113,91,80,93],[144,18,39,94,182,177,225,322]],[2021,10,[0,0,10,37,97,110,91,105],[184,27,32,88,168,197,226,355]],[2021,11,[0,0,9,59,88,76,85,72],[155,28,35,108,157,153,249,284]],[2021,12,[0,0,7,48,83,115,99,102],[165,27,38,107,167,222,250,343]],[2022,1,[0,0,8,51,114,88,76,103],[142,26,33,100,184,178,215,380]],[2022,2,[0,0,4,42,106,95,92,100],[135,33,27,82,176,198,220,355]],[2022,3,[0,0,8,61,113,121,97,107],[145,26,29,108,191,209,234,388]],[2022,4,[0,0,9,54,92,90,84,116],[155,21,30,103,152,187,244,377]],[2022,5,[0,0,14,62,109,111,117,142],[150,23,38,106,186,195,247,368]],[2022,6,[0,0,18,72,110,103,113,109],[151,23,35,119,182,173,243,333]],[2022,7,[0,0,5,61,126,82,87,129],[149,31,42,123,215,183,225,364]],[2022,8,[0,1,10,49,89,95,85,93],[160,32,39,104,165,186,258,354]],[2022,9,[0,0,17,61,110,87,86,112],[162,23,44,104,199,167,229,358]],[2022,10,[0,0,7,57,81,102,96,110],[155,22,30,105,156,206,224,386]],[2022,11,[0,0,10,47,102,82,96,114],[174,23,30,111,168,178,235,366]],[2022,12,[0,0,9,45,90,97,85,114],[174,28,45,100,171,196,245,384]],[2023,1,[0,0,10,52,99,105,105,99],[139,31,44,98,186,204,246,392]],[2023,2,[0,0,10,30,93,84,96,94],[140,23,42,79,167,169,220,381]],[2023,3,[0,0,10,46,108,109,118,127],[168,30,40,89,187,197,266,391]],[2023,4,[0,0,14,62,111,111,88,139],[148,21,32,120,198,211,224,376]],[2023,5,[0,0,8,48,116,99,101,109],[158,24,38,104,199,198,219,361]],[2023,6,[0,1,12,49,86,101,97,105],[175,24,35,96,155,178,219,350]],[2023,7,[0,0,9,60,88,97,86,112],[194,42,34,119,189,192,221,372]],[2023,8,[0,0,12,68,106,111,100,134],[155,25,42,135,191,205,231,357]],[2023,9,[0,0,5,68,95,112,90,122],[141,18,30,120,170,215,230,361]],[2023,10,[0,0,14,63,98,98,118,104],[131,30,47,113,179,203,262,361]],[2023,11,[0,0,5,53,92,90,84,89],[156,33,42,104,176,184,236,353]],[2023,12,[0,0,11,54,102,91,100,85],[176,39,44,117,167,187,253,372]],[2024,1,[0,1,16,40,100,82,97,93],[165,28,51,90,168,194,234,375]],[2024,2,[0,0,9,44,93,82,83,109],[132,34,53,97,168,189,233,353]],[2024,3,[0,0,7,42,132,105,118,95],[152,29,41,93,216,211,266,387]],[2024,4,[0,0,14,60,113,92,87,115],[140,31,46,107,191,197,214,365]],[2024,5,[0,0,13,54,104,105,100,113],[159,33,35,112,195,188,247,362]],[2024,6,[0,0,12,75,104,86,87,93],[169,26,50,116,179,173,215,327]],[2024,7,[0,0,15,46,114,98,93,105],[152,26,54,111,182,195,220,353]],[2024,8,[0,0,9,53,91,99,77,95],[135,34,43,124,164,191,226,325]],[2024,9,[0,0,12,60,106,103,111,101],[137,20,35,113,185,204,243,321]],[2024,10,[0,0,7,62,95,104,112,110],[123,23,27,114,179,192,211,361]],[2024,11,[0,1,8,58,91,101,79,96],[129,36,32,116,176,180,222,340]],[2024,12,[0,0,10,33,76,67,76,84],[192,29,46,91,166,184,232,363]],[2025,1,[0,0,6,56,90,91,94,93],[196,39,37,112,182,190,259,393]],[2025,2,[0,0,8,39,95,84,81,88],[142,31,38,79,155,173,212,287]],[2025,3,[0,0,5,44,103,81,93,99],[149,30,30,104,175,175,235,369]],[2025,4,[0,0,10,56,87,106,90,99],[142,29,31,103,156,181,236,308]],[2025,5,[0,0,14,61,96,87,86,124],[154,29,43,110,177,182,238,342]],[2025,6,[0,0,20,57,107,88,97,94],[162,22,50,99,181,161,214,298]],[2025,7,[0,0,8,67,118,84,72,88],[124,19,38,123,202,172,191,300]],[2025,8,[0,0,8,62,81,103,89,94],[141,20,40,122,173,200,234,344]],[2025,9,[0,0,21,64,121,83,89,105],[113,19,40,110,194,180,212,320]],[2025,10,[0,0,9,63,88,95,91,95],[131,24,41,125,155,181,232,320]],[2025,11,[0,0,16,44,94,97,76,83],[149,31,46,102,173,194,187,321]],[2025,12,[0,0,6,51,110,90,71,103],[172,32,43,117,189,215,222,344]],[2026,1,[0,0,7,64,97,93,97,83],[141,34,45,140,170,215,221,318]],[2026,2,[0,0,8,49,97,81,72,79],[150,22,41,99,176,179,198,298]]];

function monthlyDeathCumulative(causeIndex, age){
  var cutoff=CURRENT_START===2011 ? 201107 : 202203;
  var fieldCount=age/5;
  var total=0, out=[{x:startX(),y:0}];
  monthlyDeathsRaw.forEach(function(row){
    if(row[0]*100+row[1]<cutoff) return;
    total+=row[causeIndex].slice(0,fieldCount).reduce(function(sum,value){return sum+value;},0);
    out.push({x:row[0]+(row[1]-1)/12,y:total});
  });
  return out;
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
  CURRENT_DEATHS=visible;
  button.setAttribute('aria-pressed',CURRENT_DEATHS ? 'true' : 'false');
  button.style.background=CURRENT_DEATHS ? '#2a78d6' : 'transparent';
  button.style.color=CURRENT_DEATHS ? '#fff' : '#52514e';
  setAge(CURRENT_AGE);
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
html = html.sub('__MENU__', menu_html)

puts html
