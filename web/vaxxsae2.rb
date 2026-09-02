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

menu_out = StringIO.new
$stdout = menu_out
print_site_menu(lang.to_sym)
$stdout = STDOUT

print "Content-Type: text/html; charset=UTF-8\r\n\r\n"

html = <<~'HTMLDOC'
<!DOCTYPE html>
<html lang="__LANG__">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title id="pageTitle"></title>
<link rel="stylesheet" href="covid19.css">
<style>
.controls { display:flex;align-items:center;justify-content:space-between;gap:10px 18px;flex-wrap:wrap;margin:0 0 12px;font-size:18px; }
.controls label { display:flex;align-items:center;gap:7px;cursor:pointer; }
.controls input { width:19px;height:19px; }
.segmented { display:inline-flex;border:1px solid #c3c2b7;border-radius:8px;overflow:hidden; }
.segmented button { padding:7px 15px;border:0;background:transparent;color:#52514e;font:18px inherit;cursor:pointer; }
.segmented button.active { background:#2a78d6;color:#fff; }
#chartWrap { position:relative;width:100%;height:1050px; }
#barCharts { display:grid;grid-template-columns:minmax(0,1fr);gap:14px;width:100%;height:100%; }
#barCharts.with-aluminum { grid-template-columns:minmax(0,2fr) minmax(260px,1fr); }
.chart-panel { position:relative;min-width:0;height:100%; }
#aluminumPanel { display:none; }
#barCharts.with-aluminum #aluminumPanel { display:block; }
#scatterPanel { display:none;position:relative;width:100%;height:100%; }
#chartWrap.scatter-mode #barCharts { display:none; }
#chartWrap.scatter-mode #scatterPanel { display:block; }
#chartWrap canvas { width:100% !important;height:100% !important; }
.legend { display:flex;justify-content:center;gap:16px 28px;flex-wrap:wrap;margin:4px 0 12px;font-size:18px; }
.period-summary { margin:2px 0 12px;text-align:center;font-size:19px;font-weight:600;color:#222; }
.legend-item { display:flex;align-items:center;gap:8px; }
.swatch { width:22px;height:15px;box-sizing:border-box; }
.manufacturer { background:#2a78d6; }
.medical { background:#e07b39; }
.aluminum { background:#6b8e23; }
.notes { margin:14px 0 24px;font-size:16px;line-height:1.65;color:#4d4d4d; }
.notes p { margin:.35em 0; }
.source { margin-top:20px;padding-top:14px;border-top:1px solid #ddd;font-size:17px;line-height:1.6; }
#sourcePages { display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px;margin-top:20px; }
.source-page { display:block;width:100%;height:auto;border:1px solid #ddd;box-sizing:border-box; }
@media (max-width:750px) {
  #chartWrap { height:1120px; }
  #barCharts.with-aluminum { grid-template-columns:minmax(0,1.7fr) minmax(150px,1fr);gap:6px; }
  .segmented button { font-size:16px; }
  .legend { font-size:16px; }
  #sourcePages { grid-template-columns:1fr;gap:16px; }
}
</style>
</head>
<body>
<div id="wrapper">
__MENU__
<main class="right-column">
  <div class="site-title">
    <h1 id="heading" align="center"></h1>
    <a class="site-title-qr" href="https://medicalfacts.info/vaxxsae2.rb"><img id="pageQr" src="qr/vaxxsae2.rb.svg" alt=""></a>
  </div>
  <div class="controls">
    <label><input id="showExcluded" type="checkbox"><span id="showExcludedLabel"></span></label>
    <div class="segmented">
      <button id="btnJa" type="button">日本語</button>
      <button id="btnEn" type="button">English</button>
    </div>
  </div>
  <p id="periodNote" class="period-summary"></p>
  <div class="controls">
    <span id="viewLabel"></span>
    <div class="segmented">
      <button id="btnSerious" type="button"></button>
      <button id="btnAluminum" type="button"></button>
      <button id="btnScatter" type="button"></button>
    </div>
  </div>
  <div class="legend" aria-label="凡例">
    <span class="legend-item"><span class="swatch manufacturer"></span><span id="legendManufacturer"></span></span>
    <span class="legend-item"><span class="swatch medical"></span><span id="legendMedical"></span></span>
    <span id="legendAluminumItem" class="legend-item"><span class="swatch aluminum"></span><span id="legendAluminum"></span></span>
  </div>
  <div id="chartWrap">
    <div id="barCharts">
      <div class="chart-panel"><canvas id="chart" role="img"></canvas></div>
      <div id="aluminumPanel" class="chart-panel"><canvas id="aluminumChart" role="img"></canvas></div>
    </div>
    <div id="scatterPanel"><canvas id="scatterChart" role="img"></canvas></div>
  </div>
  <div class="notes">
    <p id="denominatorNote"></p>
    <p id="duplicateNote"></p>
    <p id="unavailableNote"></p>
    <p id="aluminumNote"></p>
  </div>
  <section class="source">
    <strong id="sourceHeading"></strong><br>
    <span id="sourceTitle"></span><br>
    <a href="https://www.mhlw.go.jp/content/11120000/001666661.pdf" target="_blank" rel="noopener">https://www.mhlw.go.jp/content/11120000/001666661.pdf</a>
    <div id="sourcePages">
      <img class="source-page" src="vaxxsae-src/page-01.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-02.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-03.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-04.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-05.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-06.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-07.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-08.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-09.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-10.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-11.jpg" alt="">
      <img class="source-page" src="vaxxsae-src/page-12.jpg" alt="">
    </div>
  </section>
</main>
</div>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<script>
const rows = [
  {ja:'帯状疱疹（組換え）',en:'Zoster (recombinant)',d:2178394,m:118,h:22,al:0},
  {ja:'23価肺炎球菌',en:'Pneumococcal (23-valent)',d:326272,m:8,h:3,al:0},
  {ja:'9価HPV',en:'HPV (9-valent)',d:382371,m:76,h:28,al:0.5},
  {ja:'4価HPV',en:'HPV (4-valent)',d:16720,m:17,h:2,al:0.225},
  {ja:'2価HPV',en:'HPV (2-valent)',d:398,m:3,h:0,al:0.5},
  {ja:'MR（麻しん・風しん）',en:'MR (measles-rubella)',d:1027205,m:7,h:8,al:0},
  {ja:'風しん',en:'Rubella',d:46720,m:0,h:0,al:0},
  {ja:'おたふくかぜ',en:'Mumps',d:696133,m:6,h:7,al:0},
  {ja:'水痘',en:'Varicella',d:1169412,m:9,h:10,al:0},
  {ja:'DPT',en:'DPT',d:94312,m:1,h:0,al:0.1},
  {ja:'DT（ジフテリア・破傷風）',en:'DT',d:436689,m:0,h:3,al:0.1},
  {ja:'破傷風トキソイド',en:'Tetanus toxoid',d:266893,m:3,h:0,al:0.1},
  {ja:'不活化ポリオ',en:'Inactivated polio',d:30678,m:0,h:0,al:0},
  {ja:'DPT-IPV',en:'DPT-IPV',d:298378,m:1,h:3,al:0.1},
  {ja:'DPT-IPV-Hib',en:'DPT-IPV-Hib',d:1293879,m:28,h:19,al:0.1},
  {ja:'Hib',en:'Hib',d:32474,m:3,h:1,al:0},
  {ja:'20価肺炎球菌',en:'Pneumococcal (20-valent)',d:1139876,m:31,h:19,al:0.125},
  {ja:'15価肺炎球菌',en:'Pneumococcal (15-valent)',d:205122,m:8,h:1,al:0.125},
  {ja:'BCG',en:'BCG',d:334215,m:16,h:8,al:0},
  {ja:'日本脳炎',en:'Japanese encephalitis',d:1672722,m:0,h:3,al:0},
  {ja:'B型肝炎',en:'Hepatitis B',d:1979969,m:29,h:15,al:0.5},
  {ja:'RSV（アレックスビー）',en:'RSV (Arexvy)',d:6835,m:2,h:0,al:0},
  {ja:'RSV（アブリスボ）',en:'RSV (Abrysvo)',d:63457,m:32,h:0,al:0},
  {ja:'1価ロタ',en:'Rotavirus (monovalent)',d:421407,m:29,h:14,al:0},
  {ja:'5価ロタ',en:'Rotavirus (5-valent)',d:338888,m:21,h:11,al:0},
  {ja:'麻しん',en:'Measles',d:null,m:0,h:0,al:0},
  {ja:'ジフテリアトキソイド',en:'Diphtheria toxoid',d:0,m:0,h:0,al:0.1},
  {ja:'13価肺炎球菌',en:'Pneumococcal (13-valent)',d:null,m:8,h:0,al:0.125}
];

const I18N = {
  ja: {
    title:'ワクチン別 重篤な副反応疑い報告頻度とアルミニウムアジュバント量（試作）',
    manufacturer:'製造販売業者からの報告（「重篤」として報告）', medical:'医療機関からの報告（うち重篤）', aluminum:'アルミニウム', showExcluded:'1万以下または算出不可も表示',
    viewLabel:'表示', serious:'重篤報告', withAluminum:'重篤報告＋アルミ', scatter:'散布図',
    axis:'接種可能のべ人数10万当たりの報告頻度', unavailable:'算出不可', cases:'件', people:'接種可能のべ人数',
    period:'集計期間：2025-04-01〜2025-09-30',
    denominator:'※ 分母は納入数量から推定された「接種可能のべ人数」で、実際の接種者数ではありません。',
    duplicate:'※ 製造販売業者報告は全件が重篤です。同一症例が両方から報告された場合は、医療機関報告として計上されています。',
    unavailableNote:'※ 接種可能のべ人数が1万以下または算出不可のワクチンは、初期表示から除外しています。',
    aluminumAxis:'元素Al換算量（mg／1回接種）', aluminumNote:'※ アルミニウム量は、国内製品の1回接種当たり元素Al換算量の最大値です。製品・接種量によって異なる場合があります。',
    sourceHeading:'出典', sourceTitle:'厚生労働省「各ワクチンの報告状況」（9〜12ページ）',
    qr:'このページのQRコード', sourcePage:n=>'出典資料 '+n+'ページ'
  },
  en: {
    title:'Serious suspected adverse-event report frequency and aluminum adjuvant amount by vaccine (draft)',
    manufacturer:'Manufacturer reports (reported as serious)', medical:'Medical-institution reports (serious)', aluminum:'Aluminum', showExcluded:'Also show ≤10,000 or not calculable',
    viewLabel:'View', serious:'Serious reports', withAluminum:'Reports + aluminum', scatter:'Scatter plot',
    axis:'Reports per 100,000 possible vaccinations', unavailable:'Not calculable', cases:'reports', people:'Possible vaccinations',
    period:'Period: 2025-04-01–2025-09-30',
    denominator:'* The denominator is possible vaccinations estimated from shipments, not the actual number vaccinated.',
    duplicate:'* All manufacturer reports are serious. Cases reported by both sources are counted under medical-institution reports.',
    unavailableNote:'* Vaccines with 10,000 or fewer possible vaccinations, or without a calculable denominator, are hidden initially.',
    aluminumAxis:'Elemental Al equivalent (mg/dose)', aluminumNote:'* Aluminum is the maximum elemental-Al-equivalent amount per dose among Japanese products; it may vary by product and dose.',
    sourceHeading:'Source', sourceTitle:'Ministry of Health, Labour and Welfare, “Reports by vaccine” (pp. 9–12)',
    qr:'QR code for this page', sourcePage:n=>'Source page '+n
  }
};

rows.forEach(r => { r.mRate = r.d ? r.m / r.d * 100000 : null; r.hRate = r.d ? r.h / r.d * 100000 : null; });
rows.sort((a,b) => {
  if (!a.d) return !b.d ? 0 : 1;
  if (!b.d) return -1;
  return (b.mRate + b.hRate) - (a.mRate + a.hRate);
});
let displayedRows = rows.filter(r => r.d !== null && r.d > 10000);

let lang = new URLSearchParams(location.search).get('l') === 'en' ? 'en' : '__LANG__';
let view = ['aluminum','scatter'].includes(new URLSearchParams(location.search).get('view')) ? new URLSearchParams(location.search).get('view') : 'serious';
Chart.defaults.font.family = getComputedStyle(document.body).fontFamily;
Chart.defaults.font.size = 15;

// 棒の末尾へ合計率を、分母不明の行へ算出不可を描く。
// Draw total rates at bar ends and mark rows with unavailable denominators.
const endLabels = {
  id:'endLabels',
  afterDatasetsDraw(chart) {
    const ctx=chart.ctx, x=chart.scales.x, y=chart.scales.y, t=I18N[lang];
    ctx.save(); ctx.font='bold 14px '+Chart.defaults.font.family; ctx.textBaseline='middle';
    displayedRows.forEach((r,i) => {
      const yy=y.getPixelForValue(i);
      if (!r.d) { ctx.fillStyle='#777'; ctx.textAlign='left'; ctx.fillText(t.unavailable,x.left+5,yy); return; }
      const total=r.mRate+r.hRate;
      const xx=x.getPixelForValue(total);
      ctx.fillStyle='#333'; ctx.textAlign=xx > x.right-62 ? 'right' : 'left';
      ctx.fillText(total.toFixed(total >= 100 ? 1 : 2), xx + (xx > x.right-62 ? -5 : 5), yy);
    });
    ctx.restore();
  }
};

const chart = new Chart(document.getElementById('chart'), {
  type:'bar',
  plugins:[endLabels],
  data:{labels:[],datasets:[
    {label:'',data:[],backgroundColor:'#2a78d6',borderWidth:0},
    {label:'',data:[],backgroundColor:'#e07b39',borderWidth:0}
  ]},
  options:{
    indexAxis:'y',responsive:true,maintainAspectRatio:false,animation:{duration:500},
    layout:{padding:{right:48}},
    plugins:{legend:{display:false},tooltip:{callbacks:{
      label(c) { const r=displayedRows[c.dataIndex], t=I18N[lang], n=c.datasetIndex===0?r.m:r.h; return c.dataset.label+': '+n.toLocaleString()+' '+t.cases+' ('+(c.raw||0).toFixed(2)+')'; },
      afterBody(items) { const r=displayedRows[items[0].dataIndex],t=I18N[lang]; return r.d ? t.people+': '+r.d.toLocaleString() : t.unavailable; }
    }}},
    scales:{
      x:{stacked:true,beginAtZero:true,title:{display:true,text:'',font:{size:18}},ticks:{font:{size:14}}},
      y:{stacked:true,ticks:{autoSkip:false,color:'#111',font:{size:17,weight:'600'}}}
    }
  }
});

const aluminumChart = new Chart(document.getElementById('aluminumChart'), {
  type:'bar',
  data:{labels:[],datasets:[{label:'',data:[],backgroundColor:'#6b8e23',borderWidth:0}]},
  options:{
    indexAxis:'y',responsive:true,maintainAspectRatio:false,animation:{duration:500},
    layout:{padding:{right:28}},
    plugins:{legend:{display:false},tooltip:{callbacks:{
      label(c){return c.dataset.label+': '+Number(c.raw).toFixed(3)+' mg';}
    }}},
    scales:{
      x:{beginAtZero:true,title:{display:true,text:'',font:{size:18}},ticks:{font:{size:14}}},
      y:{ticks:{display:false,autoSkip:false},grid:{display:false},border:{display:false}}
    }
  }
});

const scatterChart = new Chart(document.getElementById('scatterChart'), {
  type:'scatter',
  data:{datasets:[{label:'',data:[],backgroundColor:'#6b8e23',pointRadius:7,pointHoverRadius:9}]},
  options:{
    responsive:true,maintainAspectRatio:false,animation:{duration:500},
    plugins:{legend:{display:false},tooltip:{callbacks:{
      title(items){return items[0].raw.label;},
      label(c){const t=I18N[lang];return [t.aluminumAxis+': '+c.raw.x.toFixed(3),t.axis+': '+c.raw.y.toFixed(2)];}
    }}},
    scales:{
      x:{beginAtZero:true,title:{display:true,text:'',font:{size:18}},ticks:{font:{size:14}}},
      y:{beginAtZero:true,title:{display:true,text:'',font:{size:18}},ticks:{font:{size:14}}}
    }
  }
});

function render() {
  const t=I18N[lang];
  document.documentElement.lang=lang;
  document.getElementById('pageTitle').textContent=t.title;
  document.getElementById('heading').textContent=t.title;
  document.getElementById('legendManufacturer').textContent=t.manufacturer;
  document.getElementById('legendMedical').textContent=t.medical;
  document.getElementById('legendAluminum').textContent=t.aluminum;
  document.getElementById('showExcludedLabel').textContent=t.showExcluded;
  document.getElementById('viewLabel').textContent=t.viewLabel;
  document.getElementById('btnSerious').textContent=t.serious;
  document.getElementById('btnAluminum').textContent=t.withAluminum;
  document.getElementById('btnScatter').textContent=t.scatter;
  document.getElementById('periodNote').textContent=t.period;
  document.getElementById('denominatorNote').textContent=t.denominator;
  document.getElementById('duplicateNote').textContent=t.duplicate;
  document.getElementById('unavailableNote').textContent=t.unavailableNote;
  document.getElementById('aluminumNote').textContent=t.aluminumNote;
  document.getElementById('sourceHeading').textContent=t.sourceHeading;
  document.getElementById('sourceTitle').textContent=t.sourceTitle;
  document.getElementById('pageQr').alt=t.qr;
  document.getElementById('btnJa').classList.toggle('active',lang==='ja');
  document.getElementById('btnEn').classList.toggle('active',lang==='en');
  document.getElementById('btnSerious').classList.toggle('active',view==='serious');
  document.getElementById('btnAluminum').classList.toggle('active',view==='aluminum');
  document.getElementById('btnScatter').classList.toggle('active',view==='scatter');
  document.getElementById('barCharts').classList.toggle('with-aluminum',view==='aluminum');
  document.getElementById('chartWrap').classList.toggle('scatter-mode',view==='scatter');
  document.getElementById('legendAluminumItem').style.display=view==='serious'?'none':'flex';
  if (window.updateSiteMenu) window.updateSiteMenu(lang);
  displayedRows=rows.filter(r=>document.getElementById('showExcluded').checked || (r.d !== null && r.d > 10000));
  chart.data.labels=displayedRows.map(r=>r[lang]+' ('+(r.m+r.h).toLocaleString()+'/'+(r.d===null?t.unavailable:r.d.toLocaleString())+')');
  chart.data.datasets[0].label=t.manufacturer;
  chart.data.datasets[0].data=displayedRows.map(r=>r.mRate);
  chart.data.datasets[1].label=t.medical;
  chart.data.datasets[1].data=displayedRows.map(r=>r.hRate);
  chart.options.scales.x.title.text=t.axis;
  chart.update();
  aluminumChart.data.labels=displayedRows.map(r=>r[lang]);
  aluminumChart.data.datasets[0].label=t.aluminum;
  aluminumChart.data.datasets[0].data=displayedRows.map(r=>r.al);
  aluminumChart.options.scales.x.title.text=t.aluminumAxis;
  aluminumChart.update();
  scatterChart.data.datasets[0].label=t.aluminum;
  scatterChart.data.datasets[0].data=displayedRows.filter(r=>r.d).map(r=>({x:r.al,y:r.mRate+r.hRate,label:r[lang]+' ('+(r.m+r.h).toLocaleString()+'/'+r.d.toLocaleString()+')'}));
  scatterChart.options.scales.x.title.text=t.aluminumAxis;
  scatterChart.options.scales.y.title.text=t.axis;
  scatterChart.update();
  document.querySelectorAll('.source-page').forEach((img,i)=>{img.alt=t.sourcePage(i+1);});
  const u=new URL(location.href); u.searchParams.set('l',lang); u.searchParams.set('view',view); history.replaceState(null,'',u);
}
document.getElementById('btnJa').addEventListener('click',()=>{lang='ja';render();});
document.getElementById('btnEn').addEventListener('click',()=>{lang='en';render();});
document.getElementById('showExcluded').addEventListener('change',render);
document.getElementById('btnSerious').addEventListener('click',()=>{view='serious';render();});
document.getElementById('btnAluminum').addEventListener('click',()=>{view='aluminum';render();});
document.getElementById('btnScatter').addEventListener('click',()=>{view='scatter';render();});
render();
</script>
</body>
</html>
HTMLDOC

html.sub!('__MENU__', menu_out.string)
html.gsub!('__LANG__', lang)
print html
