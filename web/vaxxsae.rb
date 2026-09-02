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
#chartWrap canvas { width:100% !important;height:100% !important; }
.legend { display:flex;justify-content:center;gap:16px 28px;flex-wrap:wrap;margin:4px 0 12px;font-size:18px; }
.legend-item { display:flex;align-items:center;gap:8px; }
.swatch { width:22px;height:15px;box-sizing:border-box; }
.manufacturer { background:#2a78d6; }
.medical { background:#e07b39; }
.notes { margin:14px 0 24px;font-size:16px;line-height:1.65;color:#4d4d4d; }
.notes p { margin:.35em 0; }
.source { margin-top:20px;padding-top:14px;border-top:1px solid #ddd;font-size:17px;line-height:1.6; }
@media (max-width:750px) {
  #chartWrap { height:1120px; }
  .segmented button { font-size:16px; }
  .legend { font-size:16px; }
}
</style>
</head>
<body>
<div id="wrapper">
__MENU__
<main class="right-column">
  <div class="site-title">
    <h1 id="heading" align="center"></h1>
    <a class="site-title-qr" href="https://medicalfacts.info/vaxxsae.rb"><img id="pageQr" src="qr/vaxxsae.rb.svg" alt=""></a>
  </div>
  <div class="controls">
    <label><input id="showHpv2" type="checkbox"><span id="showHpv2Label"></span></label>
    <div class="segmented">
      <button id="btnJa" type="button">日本語</button>
      <button id="btnEn" type="button">English</button>
    </div>
  </div>
  <div class="legend" aria-label="凡例">
    <span class="legend-item"><span class="swatch manufacturer"></span><span id="legendManufacturer"></span></span>
    <span class="legend-item"><span class="swatch medical"></span><span id="legendMedical"></span></span>
  </div>
  <div id="chartWrap"><canvas id="chart" role="img"></canvas></div>
  <div class="notes">
    <p id="periodNote"></p>
    <p id="denominatorNote"></p>
    <p id="duplicateNote"></p>
    <p id="unavailableNote"></p>
  </div>
  <section class="source">
    <strong id="sourceHeading"></strong><br>
    <span id="sourceTitle"></span><br>
    <a href="https://www.mhlw.go.jp/content/11120000/001666661.pdf" target="_blank" rel="noopener">https://www.mhlw.go.jp/content/11120000/001666661.pdf</a>
  </section>
</main>
</div>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<script>
const rows = [
  {ja:'乾燥組換え帯状疱疹ワクチン',en:'Recombinant zoster',d:2178394,m:118,h:22},
  {ja:'23価肺炎球菌莢膜ポリサッカライドワクチン',en:'Pneumococcal polysaccharide (23-valent)',d:326272,m:8,h:3},
  {ja:'組換え沈降9価HPVワクチン',en:'HPV (9-valent)',d:382371,m:76,h:28},
  {ja:'組換え沈降4価HPVワクチン',en:'HPV (4-valent)',d:16720,m:17,h:2},
  {ja:'組換え沈降2価HPVワクチン',en:'HPV (2-valent)',d:398,m:3,h:0},
  {ja:'乾燥弱毒生麻しん風しん混合ワクチン',en:'Measles-rubella (MR)',d:1027205,m:7,h:8},
  {ja:'乾燥弱毒生風しんワクチン',en:'Rubella',d:46720,m:0,h:0},
  {ja:'乾燥弱毒生おたふくかぜワクチン',en:'Mumps',d:696133,m:6,h:7},
  {ja:'乾燥弱毒生水痘ワクチン',en:'Varicella',d:1169412,m:9,h:10},
  {ja:'沈降精製百日せきジフテリア破傷風混合ワクチン',en:'Diphtheria-tetanus-pertussis (DPT)',d:94312,m:1,h:0},
  {ja:'沈降ジフテリア破傷風混合トキソイド',en:'Diphtheria-tetanus (DT)',d:436689,m:0,h:3},
  {ja:'沈降破傷風トキソイド',en:'Tetanus toxoid',d:266893,m:3,h:0},
  {ja:'不活化ポリオワクチン',en:'Inactivated polio',d:30678,m:0,h:0},
  {ja:'沈降精製百日せきジフテリア破傷風不活化ポリオ混合ワクチン',en:'DPT-IPV',d:298378,m:1,h:3},
  {ja:'沈降精製百日せきジフテリア破傷風不活化ポリオHib混合ワクチン',en:'DPT-IPV-Hib',d:1293879,m:28,h:19},
  {ja:'乾燥ヘモフィルスb型ワクチン',en:'Hib',d:32474,m:3,h:1},
  {ja:'沈降20価肺炎球菌結合型ワクチン',en:'Pneumococcal conjugate (20-valent)',d:1139876,m:31,h:19},
  {ja:'沈降15価肺炎球菌結合型ワクチン',en:'Pneumococcal conjugate (15-valent)',d:205122,m:8,h:1},
  {ja:'経皮接種用BCGワクチン',en:'BCG',d:334215,m:16,h:8},
  {ja:'乾燥細胞培養日本脳炎ワクチン',en:'Japanese encephalitis',d:1672722,m:0,h:3},
  {ja:'組換え沈降B型肝炎ワクチン',en:'Hepatitis B',d:1979969,m:29,h:15},
  {ja:'RSウイルスワクチン（アレックスビー）',en:'RSV (Arexvy)',d:6835,m:2,h:0},
  {ja:'RSウイルスワクチン（アブリスボ）',en:'RSV (Abrysvo)',d:63457,m:32,h:0},
  {ja:'経口弱毒生ヒトロタウイルスワクチン',en:'Rotavirus (monovalent)',d:421407,m:29,h:14},
  {ja:'5価経口弱毒生ロタウイルスワクチン',en:'Rotavirus (5-valent)',d:338888,m:21,h:11},
  {ja:'乾燥弱毒生麻しんワクチン',en:'Measles',d:null,m:0,h:0},
  {ja:'ジフテリアトキソイド',en:'Diphtheria toxoid',d:null,m:0,h:0},
  {ja:'沈降13価肺炎球菌結合型ワクチン',en:'Pneumococcal conjugate (13-valent)',d:null,m:8,h:0}
];

const I18N = {
  ja: {
    title:'ワクチン別 重篤な副反応疑い報告数（10万接種可能延べ人数当たり）',
    manufacturer:'製造販売業者からの報告（全件重篤）', medical:'医療機関からの報告（うち重篤）', showHpv2:'2価HPVワクチンを表示',
    axis:'10万接種可能延べ人数当たり報告数', unavailable:'算出不可', cases:'件', people:'接種可能延べ人数',
    period:'※ 2025-04-01〜2025-09-30の報告を合算しています。',
    denominator:'※ 分母は納入数量から推定された「接種可能延べ人数」で、実際の接種者数ではありません。',
    duplicate:'※ 製造販売業者報告は全件が重篤です。同一症例が両方から報告された場合は、医療機関報告として計上されています。',
    unavailableNote:'※ 接種可能延べ人数を得られない3ワクチンは、末尾に「算出不可」と表示しています。',
    sourceHeading:'出典', sourceTitle:'厚生労働省「各ワクチンの報告状況」（9〜12ページ）',
    qr:'このページのQRコード'
  },
  en: {
    title:'Serious suspected adverse-event reports by vaccine (per 100,000 possible vaccinations)',
    manufacturer:'Reports from manufacturers (all serious)', medical:'Reports from medical institutions (serious)', showHpv2:'Show 2-valent HPV vaccine',
    axis:'Reports per 100,000 possible vaccinations', unavailable:'Not calculable', cases:'reports', people:'Possible vaccinations',
    period:'* Reports from 2025-04-01 through 2025-09-30 are combined.',
    denominator:'* The denominator is possible vaccinations estimated from shipments, not the actual number vaccinated.',
    duplicate:'* All manufacturer reports are serious. Cases reported by both sources are counted under medical-institution reports.',
    unavailableNote:'* Three vaccines without an available denominator are shown as not calculable at the bottom.',
    sourceHeading:'Source', sourceTitle:'Ministry of Health, Labour and Welfare, “Reports by vaccine” (pp. 9–12)',
    qr:'QR code for this page'
  }
};

rows.forEach(r => { r.mRate = r.d ? r.m / r.d * 100000 : null; r.hRate = r.d ? r.h / r.d * 100000 : null; });
rows.sort((a,b) => {
  if (a.d === null) return b.d === null ? 0 : 1;
  if (b.d === null) return -1;
  return (b.mRate + b.hRate) - (a.mRate + a.hRate);
});
let displayedRows = rows.filter(r => r.en !== 'HPV (2-valent)');

let lang = new URLSearchParams(location.search).get('l') === 'en' ? 'en' : '__LANG__';
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
      if (r.d === null) { ctx.fillStyle='#777'; ctx.textAlign='left'; ctx.fillText(t.unavailable,x.left+5,yy); return; }
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
      y:{stacked:true,ticks:{autoSkip:false,font:{size:14}}}
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
  document.getElementById('showHpv2Label').textContent=t.showHpv2;
  document.getElementById('periodNote').textContent=t.period;
  document.getElementById('denominatorNote').textContent=t.denominator;
  document.getElementById('duplicateNote').textContent=t.duplicate;
  document.getElementById('unavailableNote').textContent=t.unavailableNote;
  document.getElementById('sourceHeading').textContent=t.sourceHeading;
  document.getElementById('sourceTitle').textContent=t.sourceTitle;
  document.getElementById('pageQr').alt=t.qr;
  document.getElementById('btnJa').classList.toggle('active',lang==='ja');
  document.getElementById('btnEn').classList.toggle('active',lang==='en');
  if (window.updateSiteMenu) window.updateSiteMenu(lang);
  displayedRows=rows.filter(r=>document.getElementById('showHpv2').checked || r.en !== 'HPV (2-valent)');
  chart.data.labels=displayedRows.map(r=>r[lang]);
  chart.data.datasets[0].label=t.manufacturer;
  chart.data.datasets[0].data=displayedRows.map(r=>r.mRate);
  chart.data.datasets[1].label=t.medical;
  chart.data.datasets[1].data=displayedRows.map(r=>r.hRate);
  chart.options.scales.x.title.text=t.axis;
  chart.update();
  const u=new URL(location.href); u.searchParams.set('l',lang); history.replaceState(null,'',u);
}
document.getElementById('btnJa').addEventListener('click',()=>{lang='ja';render();});
document.getElementById('btnEn').addEventListener('click',()=>{lang='en';render();});
document.getElementById('showHpv2').addEventListener('change',render);
render();
</script>
</body>
</html>
HTMLDOC

html.sub!('__MENU__', menu_out.string)
html.gsub!('__LANG__', lang)
print html
