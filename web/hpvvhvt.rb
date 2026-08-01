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
view = cgi['view'] == 'stack' ? 'stack' : 'overlay'
lag = [[cgi['lag'].to_i, -12].max, 12].min

menu_out = StringIO.new
$stdout = menu_out
print_site_menu(lang.to_sym)
$stdout = STDOUT

print "Content-Type: text/html; charset=UTF-8\r\n\r\n"

html = <<~'HTMLDOC'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title id="pageTitle"></title>
<style>
button { font-family:inherit; }
.controls { display:flex;align-items:center;gap:10px 18px;flex-wrap:wrap;margin:0 0 14px;font-size:18px; }
.control-group { display:flex;align-items:center;gap:7px; }
.segmented { display:inline-flex;border:0.5px solid #c3c2b7;border-radius:8px;overflow:hidden; }
.segmented button { padding:7px 15px;font-size:18px;border:0;cursor:pointer;background:transparent;color:#52514e; }
.segmented button.active { background:#2a78d6;color:#fff; }
#lagValue { min-width:7em;text-align:center;font-variant-numeric:tabular-nums; }
#correlation { margin:2px 0 12px;font-size:20px;color:#222;font-variant-numeric:tabular-nums; }
.chart-panel { position:relative;width:100%;height:500px; }
#stackCharts { display:none;grid-template-rows:1fr 1fr;gap:12px;height:620px; }
.stack-panel { position:relative;min-height:0; }
#sourceSection { margin-top:28px;border-top:0.5px solid #e1e0d9;padding-top:16px;font-size:17px; }
#sourceSection h2 { font-size:20px;font-weight:500;margin:0 0 8px; }
#sourceSection p { line-height:1.6; }
.source-page { display:block;width:95%;height:auto;margin:20px auto;border:0.5px solid #ddd; }
@media (max-width:760px) {
  .chart-panel { height:430px; }
  #stackCharts { height:600px; }
  .controls { gap:9px; }
  .control-group { flex-wrap:wrap; }
}
</style>
</head>
<body>
<link rel="stylesheet" href="covid19.css">
<div id="wrapper">
__MENU__
<div class="right-column">
<div class="site-title"><h1 id="heading" align="center"></h1></div>

<div class="controls">
  <div class="segmented">
    <button id="btnJa" type="button">日本語</button>
    <button id="btnEn" type="button">English</button>
  </div>
  <div class="control-group">
    <span id="viewLabel"></span>
    <div class="segmented">
      <button id="btnOverlay" type="button"></button>
      <button id="btnStack" type="button"></button>
    </div>
  </div>
  <div class="control-group">
    <span id="lagLabel"></span>
    <div class="segmented">
      <button id="btnLagMinus" type="button" aria-label="-1">−</button>
      <button id="btnLagReset" type="button">0</button>
      <button id="btnLagPlus" type="button" aria-label="+1">＋</button>
    </div>
    <span id="lagValue"></span>
  </div>
</div>

<div id="correlation" aria-live="polite"></div>
<div id="overlayChart" class="chart-panel"><canvas id="chartOverlay" role="img"></canvas></div>
<div id="stackCharts">
  <div class="stack-panel"><canvas id="chartVisits" role="img"></canvas></div>
  <div class="stack-panel"><canvas id="chartShipments" role="img"></canvas></div>
</div>

<section id="sourceSection">
  <h2 id="sourceHeading"></h2>
  <p><span id="sourceTitle"></span><br>
  <a target="_blank" rel="noopener" href="https://www.mhlw.go.jp/content/11120000/001650654.pdf">https://www.mhlw.go.jp/content/11120000/001650654.pdf</a></p>
  <div id="sourcePages">
    <img class="source-page" src="hpvvhvt-source/page-1.jpg" alt="">
    <img class="source-page" src="hpvvhvt-source/page-2.jpg" alt="">
    <img class="source-page" src="hpvvhvt-source/page-3.jpg" alt="">
    <img class="source-page" src="hpvvhvt-source/page-4.jpg" alt="">
    <img class="source-page" src="hpvvhvt-source/page-5.jpg" alt="">
    <img class="source-page" src="hpvvhvt-source/page-6.jpg" alt="">
    <img class="source-page" src="hpvvhvt-source/page-7.jpg" alt="">
    <img class="source-page" src="hpvvhvt-source/page-8.jpg" alt="">
  </div>
</section>
</div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<script>
var I18N = {
  ja: {
    title:'HPVワクチン接種後体調不良新規受診者数とHPVワクチン納入数の月次推移',
    heading:'HPVワクチン接種後体調不良新規受診者数と<br>HPVワクチン納入数の月次推移',
    viewLabel:'表示', overlay:'重ねる', stack:'上下に並べる', lagLabel:'納入数の表示位置',
    lagZero:'同じ月', lagBefore:function(n){return n+'か月前';}, lagAfter:function(n){return n+'か月後';},
    shipments:'HPVワクチン納入数', visits:'体調不良の新規受診患者数',
    shipmentsAxis:'納入数', visitsAxis:'新規受診者数', unit:'人',
    correlation:function(r){return '相関係数 r = '+r;},
    sourceHeading:'出典',
    sourceTitle:'厚生労働省「HPVワクチンの安全性に関するフォローアップ研究」（第110回副反応検討部会 資料3-4、2026年2月4日）',
    sourcePage:function(n){return '出典資料 '+n+'ページ';},
    month:function(key){return key.slice(0,4)+'年'+Number(key.slice(5))+'月';}
  },
  en: {
    title:'Monthly New Symptom-related Visits after HPV Vaccination and HPV Vaccine Shipments',
    heading:'Monthly New Symptom-related Visits after HPV Vaccination and<br>HPV Vaccine Shipments',
    viewLabel:'View', overlay:'Overlay', stack:'Stacked', lagLabel:'Shipment position',
    lagZero:'Same month', lagBefore:function(n){return n+' month'+(n===1?'':'s')+' earlier';}, lagAfter:function(n){return n+' month'+(n===1?'':'s')+' later';},
    shipments:'HPV vaccine shipments', visits:'New symptom-related visits',
    shipmentsAxis:'Shipments', visitsAxis:'New visits', unit:'',
    correlation:function(r){return 'Correlation r = '+r;},
    sourceHeading:'Source',
    sourceTitle:'MHLW, Follow-up Study on HPV Vaccine Safety (110th Adverse Reaction Review Committee, Document 3-4, February 4, 2026)',
    sourcePage:function(n){return 'Source document, page '+n;},
    month:function(key){return key;}
  }
};

var CURRENT_LANG='__LANG__';
var CURRENT_VIEW='__VIEW__';
var CURRENT_LAG=__LAG__;

// 同じ月次表の納入数と新規受診患者数を一つのrecordとして保持する。
// Keep shipments and new visits from the same monthly table in one record.
var monthlyRaw = [
  [2022,3,99003,5],[2022,4,65466,6],[2022,5,72324,6],[2022,6,121807,9],
  [2022,7,140073,13],[2022,8,193107,15],[2022,9,159885,15],[2022,10,155356,18],
  [2022,11,125470,16],[2022,12,113542,9],[2023,1,99641,14],[2023,2,109865,6],
  [2023,3,216905,10],[2023,4,197007,8],[2023,5,90551,5],[2023,6,143330,18],
  [2023,7,143566,10],[2023,8,210165,12],[2023,9,120944,21],[2023,10,124802,5],
  [2023,11,120015,18],[2023,12,108001,19],[2024,1,109953,9],[2024,2,114705,9],
  [2024,3,216544,9],[2024,4,175445,12],[2024,5,123566,12],[2024,6,176133,25],
  [2024,7,280804,21],[2024,8,571426,25],[2024,9,550013,43],[2024,10,552795,61],
  [2024,11,597151,56],[2024,12,550555,31],[2025,1,25010,25],[2025,2,15038,12],
  [2025,3,640306,14],[2025,4,70127,33],[2025,5,33482,23],[2025,6,37612,12],
  [2025,7,53460,13],[2025,8,104073,11],[2025,9,103787,15],[2025,10,126839,15],
  [2025,11,65652,6]
];

function monthIndex(year,month){ return year*12+month-1; }
function monthKey(index){
  var year=Math.floor(index/12), month=index%12+1;
  return year+'-'+String(month).padStart(2,'0');
}
function updateUrl(){
  var p=new URLSearchParams(window.location.search);
  p.set('l',CURRENT_LANG);
  if(CURRENT_VIEW==='stack') p.set('view','stack'); else p.delete('view');
  if(CURRENT_LAG) p.set('lag',String(CURRENT_LAG)); else p.delete('lag');
  window.history.replaceState(null,'',window.location.pathname+'?'+p.toString());
}
function visibleData(){
  var shipments=monthlyRaw.map(function(r){return {x:monthKey(monthIndex(r[0],r[1])+CURRENT_LAG),y:r[2]};});
  var visits=monthlyRaw.map(function(r){return {x:monthKey(monthIndex(r[0],r[1])),y:r[3]};});
  return {shipments:shipments,visits:visits};
}
function correlation(data){
  var byMonth={};
  data.shipments.forEach(function(p){byMonth[p.x]=p.y;});
  var pairs=data.visits.filter(function(p){return byMonth[p.x]!==undefined;}).map(function(p){return [byMonth[p.x],p.y];});
  var n=pairs.length;
  var meanX=pairs.reduce(function(s,p){return s+p[0];},0)/n;
  var meanY=pairs.reduce(function(s,p){return s+p[1];},0)/n;
  var xy=0,xx=0,yy=0;
  pairs.forEach(function(p){var x=p[0]-meanX,y=p[1]-meanY;xy+=x*y;xx+=x*x;yy+=y*y;});
  return {r:xy/Math.sqrt(xx*yy),n:n};
}
function labelsFor(data){
  return data.visits.map(function(p){return p.x;});
}
function chartData(data){
  var t=I18N[CURRENT_LANG],visibleMonths={};
  data.visits.forEach(function(p){visibleMonths[p.x]=true;});
  var visibleShipments=data.shipments.filter(function(p){return visibleMonths[p.x];});
  return [
    {type:'bar',label:t.visits,data:data.visits,borderColor:'#c44e52',backgroundColor:'rgba(196,78,82,0.72)',yAxisID:'yVisits',borderWidth:1,order:2},
    {type:'line',label:t.shipments,data:visibleShipments,borderColor:'#2a78d6',backgroundColor:'#2a78d6',pointBackgroundColor:'#2a78d6',pointBorderColor:'#2a78d6',pointBorderWidth:0,yAxisID:'yShipments',tension:0.15,pointRadius:5,pointHoverRadius:7,borderWidth:3,order:1}
  ];
}
function xScale(showTicks){
  return {type:'category',offset:false,ticks:{display:showTicks,maxRotation:0,autoSkip:true,maxTicksLimit:10,font:{size:16}},grid:{display:false}};
}
function tooltipOptions(){
  return {titleFont:{size:17},bodyFont:{size:17},callbacks:{title:function(items){return items.length?I18N[CURRENT_LANG].month(items[0].label):'';},label:function(ctx){return ctx.dataset.label+': '+ctx.parsed.y.toLocaleString()+(CURRENT_LANG==='ja'?'人':'');}}};
}
function legendOptions(){
  return {labels:{font:{size:18},sort:function(a,b){return a.datasetIndex-b.datasetIndex;}}};
}

Chart.defaults.font.size=16;
var overlayChart=new Chart(document.getElementById('chartOverlay'),{
  type:'bar',data:{datasets:[]},options:{animation:false,responsive:true,maintainAspectRatio:false,interaction:{mode:'nearest',intersect:true},plugins:{legend:legendOptions(),tooltip:tooltipOptions()},scales:{
    x:xScale(true),
    yShipments:{type:'linear',position:'left',beginAtZero:true,title:{display:true,text:'',font:{size:18}},ticks:{font:{size:16},callback:function(v){return Number(v).toLocaleString();}}},
    yVisits:{type:'linear',position:'right',beginAtZero:true,title:{display:true,text:'',font:{size:18}},ticks:{font:{size:16}},grid:{drawOnChartArea:false}}
  }}
});
var shipmentsChart=new Chart(document.getElementById('chartShipments'),{
  type:'line',data:{datasets:[]},options:{animation:false,responsive:true,maintainAspectRatio:false,interaction:{mode:'nearest',intersect:true},plugins:{legend:legendOptions(),tooltip:tooltipOptions()},scales:{x:xScale(true),y:{beginAtZero:true,title:{display:true,text:'',font:{size:18}},ticks:{font:{size:16},callback:function(v){return Number(v).toLocaleString();}}}}}
});
var visitsChart=new Chart(document.getElementById('chartVisits'),{
  type:'bar',data:{datasets:[]},options:{animation:false,responsive:true,maintainAspectRatio:false,interaction:{mode:'nearest',intersect:true},plugins:{legend:legendOptions(),tooltip:tooltipOptions()},scales:{x:xScale(false),y:{beginAtZero:true,title:{display:true,text:'',font:{size:18}},ticks:{font:{size:16}}}}}
});

function setActive(id,active){document.getElementById(id).classList.toggle('active',active);}
function render(){
  var t=I18N[CURRENT_LANG],data=visibleData(),labels=labelsFor(data),corr=correlation(data);
  document.documentElement.lang=CURRENT_LANG;
  document.getElementById('pageTitle').textContent=t.title;
  document.getElementById('heading').innerHTML=t.heading;
  document.getElementById('viewLabel').textContent=t.viewLabel;
  document.getElementById('btnOverlay').textContent=t.overlay;
  document.getElementById('btnStack').textContent=t.stack;
  document.getElementById('lagLabel').textContent=t.lagLabel;
  document.getElementById('lagValue').textContent=CURRENT_LAG===0?t.lagZero:(CURRENT_LAG<0?t.lagBefore(-CURRENT_LAG):t.lagAfter(CURRENT_LAG));
  document.getElementById('correlation').textContent=t.correlation(corr.r.toFixed(3));
  document.getElementById('sourceHeading').textContent=t.sourceHeading;
  document.getElementById('sourceTitle').textContent=t.sourceTitle;
  document.querySelectorAll('.source-page').forEach(function(img,index){img.alt=t.sourcePage(index+1);});
  setActive('btnJa',CURRENT_LANG==='ja');setActive('btnEn',CURRENT_LANG==='en');
  setActive('btnOverlay',CURRENT_VIEW==='overlay');setActive('btnStack',CURRENT_VIEW==='stack');
  document.getElementById('btnLagMinus').disabled=CURRENT_LAG<=-12;
  document.getElementById('btnLagPlus').disabled=CURRENT_LAG>=12;
  document.getElementById('overlayChart').style.display=CURRENT_VIEW==='overlay'?'block':'none';
  document.getElementById('stackCharts').style.display=CURRENT_VIEW==='stack'?'grid':'none';

  overlayChart.data.labels=labels;
  overlayChart.data.datasets=chartData(data);
  overlayChart.options.scales.yShipments.title.text=t.shipmentsAxis;
  overlayChart.options.scales.yVisits.title.text=t.visitsAxis;
  overlayChart.options.plugins.tooltip=tooltipOptions();
  overlayChart.update();

  shipmentsChart.data.labels=labels;
  shipmentsChart.data.datasets=[chartData(data)[1]];
  shipmentsChart.data.datasets[0].yAxisID='y';
  shipmentsChart.options.scales.y.title.text=t.shipmentsAxis;
  shipmentsChart.options.plugins.tooltip=tooltipOptions();
  shipmentsChart.update();
  visitsChart.data.labels=labels;
  visitsChart.data.datasets=[chartData(data)[0]];
  visitsChart.data.datasets[0].yAxisID='y';
  visitsChart.options.scales.y.title.text=t.visitsAxis;
  visitsChart.options.plugins.tooltip=tooltipOptions();
  visitsChart.update();
  updateUrl();
}

document.getElementById('btnJa').onclick=function(){CURRENT_LANG='ja';render();};
document.getElementById('btnEn').onclick=function(){CURRENT_LANG='en';render();};
document.getElementById('btnOverlay').onclick=function(){CURRENT_VIEW='overlay';render();};
document.getElementById('btnStack').onclick=function(){CURRENT_VIEW='stack';render();};
document.getElementById('btnLagMinus').onclick=function(){if(CURRENT_LAG>-12){CURRENT_LAG--;render();}};
document.getElementById('btnLagPlus').onclick=function(){if(CURRENT_LAG<12){CURRENT_LAG++;render();}};
document.getElementById('btnLagReset').onclick=function(){CURRENT_LAG=0;render();};
render();
</script>
</body>
</html>
HTMLDOC

html.sub!('__MENU__', menu_out.string)
html.sub!('__LANG__', lang)
html.sub!('__VIEW__', view)
html.sub!('__LAG__', lag.to_s)
print html
