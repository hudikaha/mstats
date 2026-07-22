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
<div class="note-item"><span class="mark">※</span><span class="text">年齢切替は健康被害認定者、子宮頸癌罹患者、死亡者に適用され、年齢区分のない受診患者には適用されない</span></div>
</div>

<div class="note-list" data-language-content="en" style="font-size:15px;color:#111;line-height:1.5;margin-top:18px">
<div class="note-item"><span class="mark">*</span><span class="text">The starting point can be selected as July 2011, when the first PMDA HPV vaccine injury certification is confirmed, or March 2022, when the visit series begins. Certification recipients whose age is unknown, including those before December 14, 2018, are treated as under 20.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">Symptom-visit patient data starts from the MHLW surveillance survey's own start date of March 2022, as no data exists before that.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">The age toggle applies to injury certifications, cervical cancer cases and deaths, but not to symptom-visit patients, which have no age breakdown.</span></div>
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
<p class="source-item">Number of patients visiting designated medical institutions with symptoms as primary complaint (Follow-up study on HPV vaccine safety, 110th Adverse Reaction Review Committee, Document 3-4, February 4, 2026)<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/11120000/001650654.pdf">https://www.mhlw.go.jp/content/11120000/001650654.pdf</a>
</p>
</section>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<script>
var I18N = {
  ja: {
    title: "HPVワクチン接種後の体調不良新規受診者数の推移と健康被害認定・子宮頸癌患者・死者との比較",
    h1: "HPVワクチン接種後の体調不良新規受診者数の推移と<br>健康被害認定・子宮頸癌患者・死者との比較",
    srDesc: "HPVワクチン健康被害認定者、子宮頸癌罹患者・死亡者、接種後の体調不良を主訴とする協力医療機関の新規受診者について、選択した起点からの累積推移を比較する。年齢区分は認定者、罹患者、死亡者について20歳未満から40歳未満まで切り替えられ、4系列は個別に表示・非表示を選択できる。",
    ageGroupLabel: "年齢区分",
    btn20: "20歳未満",
    btn25: "25歳未満",
    btn30: "30歳未満",
    btn35: "35歳未満",
    btn40: "40歳未満",
    startLabel: "累積の起点",
    startOptions: {2011:"2011年7月（最初の認定）",2022:"2022年3月（受診者系列の開始）"},
    seriesLabel: "表示項目",
    chartAllHeading: "HPVワクチン接種後の体調不良新規受診者数の推移",
    chartAllSub: "",
    chartAllAria: "選択した起点からの4系列の累積推移を同じ目盛りで比較する折れ線グラフ。",
    chartAllFallback: "全系列データ",
    chartZoomHeading: "HPVワクチン健康被害認定者数の推移",
    chartZoomSub: "",
    chartZoomAria: "健康被害認定者数をY軸上限として、認定者、罹患者、死亡者を比較する折れ線グラフ。",
    chartZoomFallback: "拡大図データ",
    legendShinryo: "体調不良を主訴として協力医療機関を受診した患者(新規・累積)",
    legendNintei: function(age){ return 'HPVワクチン健康被害認定者・'+age+'歳未満(累積)'; },
    legendRikan: function(age){ return '子宮頸癌罹患者・'+age+'歳未満(累積)'; },
    legendShibo: function(age){ return '子宮頸癌死亡者・'+age+'歳未満(累積)'; },
    dsNintei: 'HPVワクチン健康被害認定者',
    dsRikan: function(age){ return '子宮頸癌罹患者('+age+'歳未満)'; },
    dsShibo: function(age){ return '子宮頸癌死亡者('+age+'歳未満)'; },
    unit: '人',
    priorNote: '',
    tooltipTitle: function(year, month){ return year + '年' + month + '月頃の値(左側=直近確定値)'; }
  },
  en: {
    title: "Trends in Post-HPV-Vaccination Symptom New Hospital Visits Compared with Vaccine Injury Certifications and Cervical Cancer Cases/Deaths",
    h1: "Trends in Post-HPV-Vaccination Symptom New Hospital Visits<br>Compared with Vaccine Injury Certifications and Cervical Cancer Cases/Deaths",
    srDesc: "Cumulative trends from the selected starting point for HPV vaccine injury certifications, cervical cancer cases and deaths, and new symptom-related visits to designated medical institutions. Age groups can be selected from under 20 through under 40 for certifications, cancer cases and deaths, and each of the four series can be shown or hidden.",
    ageGroupLabel: "Age group",
    btn20: "Under 20",
    btn25: "Under 25",
    btn30: "Under 30",
    btn35: "Under 35",
    btn40: "Under 40",
    startLabel: "Cumulative starting point",
    startOptions: {2011:"July 2011 (first certification)",2022:"March 2022 (start of visit series)"},
    seriesLabel: "Visible series",
    chartAllHeading: "Trend in New Symptom-related Visits after HPV Vaccination",
    chartAllSub: "",
    chartAllAria: "Line chart comparing the four cumulative series from the selected starting point on one scale.",
    chartAllFallback: "All-series data",
    chartZoomHeading: "Trend in HPV Vaccine Injury Certification Recipients",
    chartZoomSub: "",
    chartZoomAria: "Line chart comparing certifications, cancer cases and deaths with the certification count as the Y-axis maximum.",
    chartZoomFallback: "Enlarged view data",
    legendShinryo: "Patients visiting with symptoms (new, cumulative)",
    legendNintei: function(age){ return 'HPV vaccine injury certification recipients, under '+age+' (cumulative)'; },
    legendRikan: function(age){ return 'Cervical cancer cases, under '+age+' (cumulative)'; },
    legendShibo: function(age){ return 'Cervical cancer deaths, under '+age+' (cumulative)'; },
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

function updateUrl(){
  var p = new URLSearchParams(window.location.search);
  p.set('l', CURRENT_LANG);
  p.set('age', CURRENT_AGE + '-');
  p.set('start', String(CURRENT_START));
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
    { label:'', data:shiboByAge[20], borderColor:'#444441', backgroundColor:'#444441', borderWidth:2.5, pointRadius:5, pointStyle:'rect', borderDash:[1,3] }
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
    item(3,legendItem('#444441', [1,3], 'rect', t.legendShibo(age)));
  document.getElementById('legendZoom').innerHTML =
    item(1,legendItem('#e34948', [], 'circle', t.legendNintei(age))) +
    item(2,legendItem('#eda100', [6,3], 'rectRot', t.legendRikan(age))) +
    item(3,legendItem('#444441', [1,3], 'rect', t.legendShibo(age))) +
    item(0,legendItem('#2a78d6', [], 'star', t.legendShinryo));
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
document.querySelectorAll('[data-series]').forEach(function(box){
  box.addEventListener('change',function(){setSeriesVisibility(parseInt(this.dataset.series,10),this.checked);});
});

setLang(CURRENT_LANG);
setStart(CURRENT_START);
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
html = html.sub('__MENU__', menu_html)

puts html
