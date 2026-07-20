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
age  = cgi['age'] == '25-' ? '25' : '20'

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
<a class="site-title-qr" href="https://medicalfacts.info/hpvvhv.rb"><img src="qr/hpvvhv.rb.svg" alt="" title=""></a>
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
</div>
</div>

<div id="chartAllHeading" style="font-size:16px;color:#52514e;margin:6px 0 2px"></div>
<div id="chartAllSub" style="font-size:15px;color:#111;margin-bottom:8px"></div>
<div style="position:relative;width:100%;height:280px">
<canvas id="chartAll" role="img"></canvas>
</div>
<div id="legendAll" style="display:flex;flex-wrap:wrap;gap:18px;margin:10px 0 6px"></div>

<div id="chartZoomHeading" style="font-size:16px;color:#52514e;margin:28px 0 2px;border-top:0.5px solid #e1e0d9;padding-top:20px"></div>
<div id="chartZoomSub" style="font-size:15px;color:#111;margin-bottom:8px"></div>
<div style="position:relative;width:100%;height:270px">
<canvas id="chartZoom" role="img"></canvas>
</div>
<div id="legendZoom" style="display:flex;flex-wrap:wrap;gap:18px;margin:10px 0 6px"></div>

<div class="note-list" data-language-content="ja" style="font-size:15px;color:#111;line-height:1.5;margin-top:18px">
<div class="note-item"><span class="mark">※</span><span class="text">HPVワクチン健康被害認定者は個票データが2019年9月以降、近い間隔(ほぼ毎回の審議結果)で追えるため2019年9月起点とし(それ以前は概数「約340人」)、子宮頸癌患者と死者も比較のため同時期からの累積とした</span></div>
<div class="note-item"><span class="mark">※</span><span class="text">受診患者は厚労省のサーベイランス調査自体が2022年3月分から開始されており、それ以前のデータが存在しないため2022年3月起点からの累積となっている</span></div>
<div class="note-item"><span class="mark">※</span><span class="text">受診患者は20歳未満・25歳未満の区別ができないので切替え不可</span></div>
</div>

<div class="note-list" data-language-content="en" style="font-size:15px;color:#111;line-height:1.5;margin-top:18px">
<div class="note-item"><span class="mark">*</span><span class="text">HPV vaccine injury certification recipients can be tracked at close intervals (nearly every deliberation) from individual case records starting September 2019 (approx. 340 certified before this), so cervical cancer cases and deaths are also cumulated from the same starting point for comparison.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">Symptom-visit patient data starts from the MHLW surveillance survey's own start date of March 2022, as no data exists before that.</span></div>
<div class="note-item"><span class="mark">*</span><span class="text">Symptom-visit patients cannot be distinguished by under-20/under-25 age, so this series does not change with the age toggle.</span></div>
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

<p class="source-item">PMDA側 2021年3月末時点317人<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/000901929.pdf">https://www.mhlw.go.jp/content/000901929.pdf</a>
</p>

<p class="source-item">PMDA側 2025年3月末時点321人<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/10900000/001699794.pdf">https://www.mhlw.go.jp/content/10900000/001699794.pdf</a>
</p>

<p class="source-item">子宮頸癌罹患・死亡データ(がん統計・国立がん研究センター)<br>
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
<p class="source-item">PMDA side, as of end of March 2021: 317<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/000901929.pdf">https://www.mhlw.go.jp/content/000901929.pdf</a>
</p>
<p class="source-item">PMDA side, as of end of March 2025: 321<br>
<a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/10900000/001699794.pdf">https://www.mhlw.go.jp/content/10900000/001699794.pdf</a>
</p>
<p class="source-item">Cervical cancer incidence/mortality data (Cancer statistics, National Cancer Center Japan)<br>
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
    srDesc: "HPVワクチン健康被害認定者、子宮頸癌罹患・死亡者、HPVワクチン接種後の体調不良を主訴として協力医療機関を受診した患者(新規)の累積推移。1つ目のグラフは4系列を同一目盛り(0〜800人)で重ねたもので、体調不良を主訴とする受診患者の累積は2025年11月までに750人に達するのに対し、HPVワクチン健康被害認定者・子宮頸癌罹患者・死亡者の3系列はこのスケールではほぼ横ばいに見える。2つ目のグラフはその3系列を目盛り最大値80に拡大したもので、HPVワクチン健康被害認定者が2026年3月までに約65〜75人まで積み上がる。体調不良を主訴として協力医療機関を受診した患者もこのグラフに含めているが、すぐにこのスケールを超えて見切れる。HPVワクチン健康被害認定者・子宮頸癌の罹患者・死亡者は、接種時または診断・死亡時の年齢が20歳未満か25歳未満かをトグルで切り替えられる。",
    ageGroupLabel: "年齢区分",
    btn20: "20歳未満",
    btn25: "25歳未満",
    chartAllHeading: "体調不良を主訴として協力医療機関を受診した患者",
    chartAllSub: "(Y軸80以下の詳細は下のグラフ参照)",
    chartAllAria: "折れ線グラフ。体調不良を主訴として協力医療機関を受診した患者の累積は750人まで増加するのに対し、HPVワクチン健康被害認定者・子宮頸癌罹患者・死亡者の3系列はこのスケールではほぼ横ばいに見える。",
    chartAllFallback: "全系列データ",
    chartZoomHeading: "HPVワクチン健康被害認定者・子宮頸癌罹患者・死者",
    chartZoomSub: "(上のグラフのY軸80以下を拡大)",
    chartZoomAria: "折れ線グラフ。最大値を80として拡大。HPVワクチン健康被害認定者は2026年3月までに約65〜75人まで積み上がる。子宮頸癌の罹患者・死亡者はごくわずかにとどまる。体調不良を主訴として協力医療機関を受診した患者はこのスケールをすぐに超え、画面上部で見切れる。",
    chartZoomFallback: "拡大図データ",
    legendShinryo: "体調不良を主訴として協力医療機関を受診した患者(新規・累積)",
    legendNintei: function(age){ return 'HPVワクチン健康被害認定者・'+age+'歳未満(累積)'; },
    legendRikan: function(age){ return '子宮頸癌罹患者・'+age+'歳未満(累積)'; },
    legendShibo: function(age){ return '子宮頸癌死亡者・'+age+'歳未満(累積)'; },
    dsNintei: 'HPVワクチン健康被害認定者',
    dsRikan: function(age){ return '子宮頸癌罹患者('+age+'歳未満)'; },
    dsShibo: function(age){ return '子宮頸癌死亡者('+age+'歳未満)'; },
    unit: '人',
    priorNote: '(これ以前に約340人認定)',
    tooltipTitle: function(year, month){ return year + '年' + month + '月頃の値(左側=直近確定値)'; }
  },
  en: {
    title: "Trends in Post-HPV-Vaccination Symptom New Hospital Visits Compared with Vaccine Injury Certifications and Cervical Cancer Cases/Deaths",
    h1: "Trends in Post-HPV-Vaccination Symptom New Hospital Visits<br>Compared with Vaccine Injury Certifications and Cervical Cancer Cases/Deaths",
    srDesc: "Cumulative trends of HPV vaccine injury certification recipients, cervical cancer cases and deaths, and new patients visiting designated medical institutions with symptoms after HPV vaccination. The first chart overlays all four series on the same scale (0-800), showing that cumulative symptom-visit patients reach 750 by November 2025, while the other three series appear nearly flat on this scale. The second chart enlarges the same three series to a maximum of 80, showing HPV vaccine injury certification recipients rising to about 65-75 by March 2026. Symptom-visit patients are also included in this chart but quickly exceed this scale and are cut off. HPV vaccine injury certification recipients and cervical cancer cases/deaths can be toggled between under-20 and under-25 age at vaccination, diagnosis, or death.",
    ageGroupLabel: "Age group",
    btn20: "Under 20",
    btn25: "Under 25",
    chartAllHeading: "Patients visiting a designated medical institution with symptoms as primary complaint",
    chartAllSub: "(For detail below Y=80, see the chart below)",
    chartAllAria: "Line chart. Cumulative symptom-visit patients rise to 750, while HPV vaccine injury certification recipients, cervical cancer cases, and deaths appear nearly flat on this scale.",
    chartAllFallback: "All-series data",
    chartZoomHeading: "HPV Vaccine Injury Certification Recipients, Cervical Cancer Cases and Deaths",
    chartZoomSub: "(Enlarged view of the chart above, Y ≤ 80)",
    chartZoomAria: "Line chart enlarged to a maximum of 80. HPV vaccine injury certification recipients rise to about 65-75 by March 2026. Cervical cancer cases and deaths remain very small. Symptom-visit patients quickly exceed this scale and are cut off at the top.",
    chartZoomFallback: "Enlarged view data",
    legendShinryo: "Patients visiting with symptoms (new, cumulative)",
    legendNintei: function(age){ return 'HPV vaccine injury certification recipients, under '+age+' (cumulative)'; },
    legendRikan: function(age){ return 'Cervical cancer cases, under '+age+' (cumulative)'; },
    legendShibo: function(age){ return 'Cervical cancer deaths, under '+age+' (cumulative)'; },
    dsNintei: 'HPV vaccine injury certification recipients',
    dsRikan: function(age){ return 'Cervical cancer cases (under '+age+')'; },
    dsShibo: function(age){ return 'Cervical cancer deaths (under '+age+')'; },
    unit: '',
    priorNote: ' (approx. 340 certified before this)',
    tooltipTitle: function(year, month){ return year + '-' + (month<10?'0':'') + month + ' (nearest confirmed value to the left)'; }
  }
};

var CURRENT_LANG = '__LANG__';
var CURRENT_AGE = __AGE__;

function updateUrl(){
  var p = new URLSearchParams(window.location.search);
  p.set('l', CURRENT_LANG);
  p.set('age', CURRENT_AGE===25 ? '25-' : '20-');
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
['2019-09-01',0],['2019-09-27',1],['2019-12-06',4],['2020-06-19',5],['2020-08-20',6],
['2021-03-31',9],['2022-02-10',11],['2022-06-16',13],['2022-12-12',14],['2023-03-14',15],
['2023-05-26',16],['2023-09-15',17],['2023-11-17',18],['2023-12-18',20],['2024-01-19',21],
['2024-02-19',25],['2024-05-02',26],['2024-05-31',29],['2024-06-28',30],['2024-09-26',33],
['2024-10-31',34],['2024-11-29',36],['2024-12-20',36],['2025-01-31',37],['2025-02-21',37],
['2025-03-21',37],['2025-03-31',41],['2025-04-21',45],['2025-05-30',46],['2025-06-18',48],
['2025-07-29',52],['2025-08-25',55],['2025-09-30',56],['2025-10-31',58],['2025-12-23',59],
['2026-01-26',61],['2026-02-24',64],['2026-03-26',65]
];
var hpv25Raw = [
['2019-09-01',0],['2019-09-27',1],['2019-12-06',4],['2020-06-19',5],['2020-08-20',6],
['2021-03-31',9],['2022-02-10',11],['2022-06-16',13],['2022-12-12',14],['2023-03-14',15],
['2023-05-26',16],['2023-09-15',17],['2023-11-17',18],['2023-12-18',20],['2024-01-19',21],
['2024-02-19',25],['2024-05-02',27],['2024-05-31',30],['2024-06-28',31],['2024-09-26',34],
['2024-10-31',35],['2024-11-29',38],['2024-12-20',39],['2025-01-31',40],['2025-02-21',41],
['2025-03-21',42],['2025-03-31',46],['2025-04-21',50],['2025-05-30',51],['2025-06-18',53],
['2025-07-29',57],['2025-08-25',60],['2025-09-30',62],['2025-10-31',64],['2025-12-23',65],
['2026-01-26',67],['2026-02-24',72],['2026-03-26',74]
];
var ninteiData20 = hpv20Raw.map(function(r){return {x:yfrac(r[0]), y:r[1]};});
var ninteiData25 = hpv25Raw.map(function(r){return {x:yfrac(r[0]), y:r[1]};});

var rikan25Data = [[2019,11],[2020,27],[2021,39],[2022,46],[2023,57]].map(function(r){return {x:decPos(r[0]),y:r[1]};});
var rikan20Data = [[2019,0],[2020,1],[2021,2],[2022,3],[2023,6]].map(function(r){return {x:decPos(r[0]),y:r[1]};});
var shibo25Data = [[2019,2],[2020,2],[2021,2],[2022,3],[2023,4],[2024,5]].map(function(r){return {x:decPos(r[0]),y:r[1]};});
var shibo20Data = [[2019,2],[2020,2],[2021,2],[2022,2],[2023,3],[2024,4]].map(function(r){return {x:decPos(r[0]),y:r[1]};});

var shinryoRaw = [
[2022,3,5],[2022,4,11],[2022,5,17],[2022,6,26],[2022,7,39],[2022,8,54],[2022,9,69],[2022,10,87],[2022,11,103],[2022,12,112],
[2023,1,126],[2023,2,132],[2023,3,142],[2023,4,150],[2023,5,155],[2023,6,173],[2023,7,183],[2023,8,195],[2023,9,216],[2023,10,221],[2023,11,239],[2023,12,258],
[2024,1,267],[2024,2,276],[2024,3,285],[2024,4,297],[2024,5,309],[2024,6,334],[2024,7,355],[2024,8,380],[2024,9,423],[2024,10,484],[2024,11,540],[2024,12,571],
[2025,1,596],[2025,2,608],[2025,3,622],[2025,4,655],[2025,5,678],[2025,6,690],[2025,7,703],[2025,8,714],[2025,9,729],[2025,10,744],[2025,11,750]
];
var shinryoData = shinryoRaw.map(function(r){return {x:r[0]+(r[1]-1)/12, y:r[2]};});

function makeXScale(){
  return {
    type:'linear', min:2019.5, max:2026.4,
    afterBuildTicks: function(axis){ axis.ticks = [2020,2021,2022,2023,2024,2025,2026].map(function(v){return {value:v};}); },
    grid:{color:'#e1e0d9', drawTicks:false},
    border:{color:'#c3c2b7'},
    ticks:{ display:true, color:'#898781', font:{size:16}, callback:function(v){return Math.round(v);} }
  };
}
function fixWidth(axis){ axis.width = 60; }

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
  if(context.dataset.label === t.dsNintei){ text += t.priorNote; }
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
    { label:'', data:shinryoData, borderColor:'#2a78d6', backgroundColor:'#2a78d6', borderWidth:3, pointRadius:4, pointStyle:'star', borderDash:[] },
    { label:'', data:ninteiData20, borderColor:'#e34948', backgroundColor:'#e34948', borderWidth:2.5, pointRadius:5, pointStyle:'circle', borderDash:[] },
    { label:'', data:rikan20Data, borderColor:'#eda100', backgroundColor:'#eda100', borderWidth:2.5, pointRadius:6, pointStyle:'rectRot', borderDash:[6,3] },
    { label:'', data:shibo20Data, borderColor:'#444441', backgroundColor:'#444441', borderWidth:2.5, pointRadius:5, pointStyle:'rect', borderDash:[1,3] }
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
    { label:'', data:shinryoData, borderColor:'#2a78d6', backgroundColor:'#2a78d6', borderWidth:3, pointRadius:4, pointStyle:'star', borderDash:[] },
    { label:'', data:ninteiData20, borderColor:'#e34948', backgroundColor:'#e34948', borderWidth:2.5, pointRadius:5, pointStyle:'circle', borderDash:[] },
    { label:'', data:rikan20Data, borderColor:'#eda100', backgroundColor:'#eda100', borderWidth:2.5, pointRadius:6, pointStyle:'rectRot', borderDash:[6,3] },
    { label:'', data:shibo20Data, borderColor:'#444441', backgroundColor:'#444441', borderWidth:2.5, pointRadius:5, pointStyle:'rect', borderDash:[1,3] }
  ]},
  plugins:[vertLinePlugin],
  options:{
    responsive:true, maintainAspectRatio:false,
    scales:{
      x: makeXScale(),
      y:{ min:0, max:80, afterFit:fixWidth, grid:{color:'#e1e0d9'}, border:{color:'#c3c2b7'}, ticks:{color:'#898781', font:{size:16}, stepSize:20} }
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
  document.getElementById('legendAll').innerHTML =
    legendItem('#2a78d6', [], 'star', t.legendShinryo) +
    legendItem('#e34948', [], 'circle', t.legendNintei(age)) +
    legendItem('#eda100', [6,3], 'rectRot', t.legendRikan(age)) +
    legendItem('#444441', [1,3], 'rect', t.legendShibo(age));
  document.getElementById('legendZoom').innerHTML =
    legendItem('#e34948', [], 'circle', t.legendNintei(age)) +
    legendItem('#eda100', [6,3], 'rectRot', t.legendRikan(age)) +
    legendItem('#444441', [1,3], 'rect', t.legendShibo(age)) +
    legendItem('#2a78d6', [], 'star', t.legendShinryo);
}

function setAge(age){
  CURRENT_AGE = age;
  var t = I18N[CURRENT_LANG];
  var ninteiData = age===20 ? ninteiData20 : ninteiData25;
  var rikanData = age===20 ? rikan20Data : rikan25Data;
  var shiboData = age===20 ? shibo20Data : shibo25Data;

  chartAll.data.datasets[0].label = t.legendShinryo;
  chartAll.data.datasets[1].data = ninteiData;
  chartAll.data.datasets[1].label = t.dsNintei;
  chartAll.data.datasets[2].data = rikanData;
  chartAll.data.datasets[2].label = t.dsRikan(age);
  chartAll.data.datasets[3].data = shiboData;
  chartAll.data.datasets[3].label = t.dsShibo(age);
  chartAll.update();

  chartZoom.data.datasets[0].label = t.legendShinryo;
  chartZoom.data.datasets[1].data = ninteiData;
  chartZoom.data.datasets[1].label = t.dsNintei;
  chartZoom.data.datasets[2].data = rikanData;
  chartZoom.data.datasets[2].label = t.dsRikan(age);
  chartZoom.data.datasets[3].data = shiboData;
  chartZoom.data.datasets[3].label = t.dsShibo(age);
  chartZoom.update();

  renderLegends(age);

  var b20 = document.getElementById('btn20');
  var b25 = document.getElementById('btn25');
  b20.style.background = age===20 ? '#2a78d6' : 'transparent';
  b20.style.color = age===20 ? '#fff' : '#52514e';
  b25.style.background = age===25 ? '#2a78d6' : 'transparent';
  b25.style.color = age===25 ? '#fff' : '#52514e';
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
  var qrImage = document.querySelector('.site-title-qr img');
  var qrLabel = lang === 'en' ? 'QR code for this page' : 'このページのQRコード';
  qrImage.alt = qrLabel;
  qrImage.title = qrLabel;
  document.getElementById('srDesc').textContent = t.srDesc;
  document.getElementById('ageGroupLabel').textContent = t.ageGroupLabel;
  document.getElementById('btn20').textContent = t.btn20;
  document.getElementById('btn25').textContent = t.btn25;
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

setLang(CURRENT_LANG);
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
html = html.sub('__MENU__', menu_html)

puts html
