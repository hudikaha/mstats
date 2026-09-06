#!/usr/bin/ruby
# coding: utf-8

require 'cgi'
require 'stringio'
begin
  require_relative '../lib/mfacts'
rescue LoadError
  require_relative 'lib/mfacts'
end

menu_out = StringIO.new
$stdout = menu_out
print_site_menu(:ja)
$stdout = STDOUT

print "Content-Type: text/html; charset=UTF-8\r\n\r\n"

html = <<~'HTMLDOC'
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>医師が「関連あり」と報告しても、専門家評価はγ――新型コロナワクチン死亡報告の実例</title>
<link rel="stylesheet" href="covid19.css">
<style>
.right-column { color:#202020; }
.lead { margin:0 auto 28px;max-width:920px;font-size:20px;line-height:1.75; }
.definition { display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:20px 0 30px; }
.definition div { padding:15px 18px;border-radius:8px;background:#f3f3f1;font-size:18px;line-height:1.55; }
.definition b { display:block;font-size:27px; }
.case { margin:28px 0;padding:22px;border:1px solid #cacaca;border-radius:10px;background:#fff; }
.case h2 { margin:0 0 8px;font-size:27px;line-height:1.45; }
.case-meta { margin:0 0 18px;color:#555;font-size:17px; }
.comparison { display:grid;grid-template-columns:1fr 1fr;gap:18px; }
.opinion { padding:20px;border-radius:8px;font-size:19px;line-height:1.75; }
.doctor { background:#eef5ff;border-left:7px solid #2878c8; }
.expert { background:#fff1f0;border-left:7px solid #c94444; }
.opinion h3 { margin:0 0 10px;font-size:21px; }
.verdict { display:inline-block;padding:2px 12px;border-radius:999px;background:#c94444;color:#fff;font-size:23px;font-weight:bold; }
.alpha .verdict { background:#2878c8; }
.source-image { display:block;width:100%;height:auto;margin-top:18px;border:1px solid #bbb;box-sizing:border-box; }
.source-image.narrow { width:min(100%,820px);margin-left:auto;margin-right:auto; }
.evidence-grid { display:grid;grid-template-columns:1.45fr 1fr;gap:14px;align-items:start;margin-top:18px; }
.record-grid { display:grid;grid-template-columns:minmax(190px,.7fr) minmax(360px,1.45fr) minmax(330px,1fr);gap:14px;align-items:start; }
.record-cell { min-width:0;padding:16px;border-radius:8px;background:#f6f6f4;font-size:17px;line-height:1.65; }
.record-cell h3 { margin:0 0 8px;font-size:20px; }
.record-cell.doctor-cell { background:#eef5ff;border-top:6px solid #2878c8; }
.record-cell.expert-cell { background:#fff1f0;border-top:6px solid #c94444; }
.record-cell .source-image { margin-top:12px;background:#fff; }
.source-note { margin:7px 0 0;color:#555;font-size:15px;line-height:1.55; }
.source-note a { overflow-wrap:anywhere; }
.evidence-link { display:block;cursor:zoom-in; }
.source-link { font-weight:bold; }
.page-viewer { position:fixed;inset:0;z-index:10000;display:none;background:rgba(0,0,0,.86);padding:24px;overflow:auto; }
.page-viewer.open { display:block; }
.page-viewer-inner { position:relative;width:max-content;max-width:96vw;margin:auto;background:#fff; }
.page-viewer img { display:block;max-width:94vw;height:auto; }
.crop-box { position:absolute;border:6px solid #e00000;box-shadow:0 0 0 2px #fff;pointer-events:none; }
.page-viewer-close { position:fixed;right:18px;top:12px;z-index:10001;width:52px;height:52px;border:2px solid #fff;border-radius:50%;background:#111;color:#fff;font-size:34px;line-height:42px;cursor:pointer; }
.compact-cases { display:grid;grid-template-columns:1fr 1fr;gap:18px; }
.compact-cases .case { margin:0; }
.takeaway { margin:32px 0;padding:22px 26px;background:#fff8d9;border-left:8px solid #d49a00;font-size:20px;line-height:1.75; }
.takeaway h2 { margin:0 0 8px;font-size:27px; }
.sources { margin-top:34px;padding-top:18px;border-top:1px solid #ccc;font-size:16px;line-height:1.7; }
.sources li { margin:.6em 0; }
@media (max-width:760px) {
  html,body { max-width:100%;overflow-x:hidden; }
  #wrapper { width:100%;max-width:100%; }
  .right-column { flex:0 0 100%;width:100%;max-width:100%;min-width:0;padding:0 8px;overflow:hidden; }
  .right-column * { box-sizing:border-box; }
  .site-title h1 { font-size:30px;overflow-wrap:anywhere; }
  .lead { font-size:18px; }
  .definition,.comparison,.compact-cases,.evidence-grid,.record-grid { grid-template-columns:1fr; }
  .case { padding:16px; }
  .case h2,.takeaway h2 { font-size:23px; }
  .opinion { font-size:17px; }
  .page-viewer { padding:62px 4px 12px; }
  .page-viewer img { max-width:98vw; }
  .crop-box { border-width:4px; }
}
</style>
</head>
<body>
<div id="wrapper">
__MENU__
<main class="right-column">
  <div class="site-title">
    <h1 align="center">医師が「関連あり」と報告しても<br>専門家評価はγ</h1>
  </div>

  <p class="lead">剖検所見を踏まえて報告医がワクチンとの因果関係を「関連あり」と評価しても、国の審議会に示される専門家評価がγとなった死亡報告があります。厚生労働省の原文を、報告医の判断と専門家評価が読める大きさで切り出しました。</p>

  <div class="definition" aria-label="因果関係評価の区分">
    <div><b>α</b>ワクチンと死亡との因果関係が否定できないもの</div>
    <div><b>β</b>ワクチンと死亡との因果関係が認められないもの</div>
    <div><b>γ</b>情報不足等により、因果関係が評価できないもの</div>
  </div>

  <article class="case">
    <h2>「患者は心筋炎で急死したと考えられる」</h2>
    <p class="case-meta">55歳女性・4回目接種2日後に死亡（一覧 No.22710）</p>
    <div class="record-grid">
      <section class="record-cell"><h3>基本情報・症状・転帰</h3>55歳女性／4回目<br>2022-11-20接種<br>2022-11-22死亡<br><b>症状：</b>突然死、心肺停止、心筋炎、腹痛、嘔吐、倦怠感<br><b>転帰：</b>死亡</section>
      <section class="record-cell doctor-cell"><h3>報告医所見・剖検</h3><b>関連あり／他要因なし</b><br>「患者は心筋炎で急死したと考えられる」<a class="evidence-link" href="src/vaxcausal/pages/001039711-p1647.png" data-full="src/vaxcausal/pages/001039711-p1647.png" data-box="45,34,49,49" data-page-label="元PDF 1647ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no15-medical.png" alt="報告医が関連あり、他要因なしと評価し、剖検で心筋炎所見を認めた原文"></a></section>
      <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>ブライトン分類1。「剖検上は心筋炎で矛盾しない」。</p><a class="evidence-link" href="src/vaxcausal/pages/001125548-p38.png" data-full="src/vaxcausal/pages/001125548-p38.png" data-box="7,6,86,6" data-page-label="元PDF 38ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no15-eval.png" alt="症例No.22710の専門家評価理由"></a></section>
    </div>
    <p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001039711.pdf" target="_blank" rel="noopener">元PDF（1647/1844ページ）</a>・<a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001125548.pdf" target="_blank" rel="noopener">専門家評価の元PDF（38/43ページ）</a></p>
  </article>

  <article class="case">
    <h2>「血栓症による心室細動と考える」</h2>
    <p class="case-meta">73歳女性・2回目接種後に死亡（症例 No.1790）</p>
    <div class="record-grid">
      <section class="record-cell"><h3>基本情報・症状・転帰</h3>73歳女性／2回目<br>2021-08-06接種<br>2021-09-07死亡<br><b>症状：</b>心室細動、血栓症、血小板減少症、腎不全、多臓器不全等<br><b>転帰：</b>死亡</section>
      <section class="record-cell doctor-cell"><h3>報告医所見・剖検</h3><b>関連あり／他要因なし</b><br>「剖検の結果、微小梗塞が認められた。血栓症による心室細動と考える」<a class="evidence-link" href="src/vaxcausal/pages/001161432-p285.png" data-full="src/vaxcausal/pages/001161432-p285.png" data-box="2.5,45,95,15.5" data-page-label="元PDF 285ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1790-row.png" alt="剖検で微小梗塞を認め、報告医が関連ありとした症例No.1790"></a></section>
      <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>微小血栓症を確認しブライトン分類1。DICを除く鑑別情報が不足し「否定も肯定もできません」。</p><a class="evidence-link" href="src/vaxcausal/pages/001161432-p285.png" data-full="src/vaxcausal/pages/001161432-p285.png" data-box="2.5,45,95,15.5" data-page-label="元PDF 285ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1790-eval.png" alt="症例No.1790の専門家評価理由"></a></section>
    </div>
    <p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（285/456ページ）</a>の同じ行を、左右に分けて掲載。</p>
  </article>

  <article class="case">
    <h2>「ワクチン接種により下肢に血栓が発現」</h2>
    <p class="case-meta">40歳女性・2回目接種後に死亡（症例 No.1808／一覧 No.22258）</p>
    <div class="record-grid">
      <section class="record-cell"><h3>基本情報・症状・転帰</h3>40歳女性／2回目<br>2021-09-13接種<br>2022-02-27死亡<br><b>症状：</b>下肢腫脹・疼痛、肺動脈血栓塞栓症、突然死<br><b>転帰：</b>死亡</section>
      <section class="record-cell doctor-cell"><h3>報告医所見・剖検</h3><b>関連あり／他要因なし</b><br>「ワクチン接種により下肢に血栓が発現し、血栓が肺にとび、肺動脈につまり急死」<a class="evidence-link" href="src/vaxcausal/pages/001125524-p808.png" data-full="src/vaxcausal/pages/001125524-p808.png" data-box="34,25,62,73" data-page-label="元PDF 808ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1808-medical.png" alt="報告医がワクチンによる血栓と判断し、肺動脈に血栓所見を認めた原文"></a></section>
      <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>肺動脈血栓は認めるが、接種から3か月以上経過し、臨床経過や血栓症リスクの情報が十分でない。</p><a class="evidence-link" href="src/vaxcausal/pages/001161432-p289.png" data-full="src/vaxcausal/pages/001161432-p289.png" data-box="2.5,73.5,95,17" data-page-label="元PDF 289ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1808-eval.png" alt="症例No.1808の専門家評価理由"></a></section>
    </div>
    <p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001125524.pdf" target="_blank" rel="noopener">元PDF（808/2363ページ）</a>・<a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">専門家評価の元PDF（289/456ページ）</a></p>
  </article>

  <article class="case"><h2>「右冠動脈内に新しい血栓」</h2><p class="case-meta">80歳女性・症例 No.185</p><div class="record-grid">
    <section class="record-cell"><h3>基本情報・症状・転帰</h3>80歳女性／1回目<br>2021-06-01接種<br>2021-06-03死亡<br><b>症状：</b>右冠動脈の心筋梗塞、完全閉塞<br><b>転帰：</b>死亡</section>
    <section class="record-cell doctor-cell"><h3>報告医所見・解剖</h3><b>関連あり／他要因なし</b><br>解剖で右冠動脈内に新しい血栓を確認。<a class="evidence-link" href="src/vaxcausal/pages/001161432-p31.png" data-full="src/vaxcausal/pages/001161432-p31.png" data-box="2.5,52.8,95,15.7" data-page-label="元PDF 31ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no185-medical.png" alt="症例No.185の報告内容"></a></section>
    <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>因果関係は否定できないが不明。心筋梗塞のリスク因子にも留意が必要。</p><a class="evidence-link" href="src/vaxcausal/pages/001161432-p31.png" data-full="src/vaxcausal/pages/001161432-p31.png" data-box="2.5,52.8,95,15.7" data-page-label="元PDF 31ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no185-eval.png" alt="症例No.185の専門家判定理由"></a></section>
  </div><p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（31/456ページ）</a></p></article>

  <article class="case"><h2>「薬剤性肺障害の可能性」</h2><p class="case-meta">80歳男性・症例 No.862</p><div class="record-grid">
    <section class="record-cell"><h3>基本情報・症状・転帰</h3>80歳男性／1回目<br>2021-07-09接種<br>2021-07-23死亡<br><b>症状：</b>間質性肺疾患<br><b>転帰：</b>死亡</section>
    <section class="record-cell doctor-cell"><h3>報告医所見・病理解剖</h3><b>関連あり／他要因なし</b><br>死因は「薬剤性肺障害の可能性」。<a class="evidence-link" href="src/vaxcausal/pages/001161432-p114.png" data-full="src/vaxcausal/pages/001161432-p114.png" data-box="2.5,55.5,95,9.7" data-page-label="元PDF 114ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no862-medical.png" alt="症例No.862の報告内容"></a></section>
    <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>間質性肺炎の可能性は十分あるが詳細と接種との因果関係は不明。剖検所見も必要。</p><a class="evidence-link" href="src/vaxcausal/pages/001161432-p114.png" data-full="src/vaxcausal/pages/001161432-p114.png" data-box="2.5,55.5,95,9.7" data-page-label="元PDF 114ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no862-eval.png" alt="症例No.862の専門家判定理由"></a></section>
  </div><p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（114/456ページ）</a></p></article>

  <article class="case"><h2>「急性心筋炎」</h2><p class="case-meta">43歳男性・症例 No.1260</p><div class="record-grid">
    <section class="record-cell"><h3>基本情報・症状・転帰</h3>43歳男性／2回目<br>2021-08-30接種<br>2021-09-08死亡<br><b>症状：</b>急性心筋炎、心停止、心嚢水<br><b>転帰：</b>死亡</section>
    <section class="record-cell doctor-cell"><h3>報告医所見・解剖</h3><b>関連あり／他要因なし</b><br>解剖で心嚢水を多量に認めた。<a class="evidence-link" href="src/vaxcausal/pages/001161432-p172.png" data-full="src/vaxcausal/pages/001161432-p172.png" data-box="2.5,14,95,15" data-page-label="元PDF 172ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1260-medical.png" alt="症例No.1260の報告内容"></a></section>
    <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>心膜炎から心タンポナーデの可能性はあるが、接種との因果関係は情報不足。</p><a class="evidence-link" href="src/vaxcausal/pages/001161432-p172.png" data-full="src/vaxcausal/pages/001161432-p172.png" data-box="2.5,14,95,15" data-page-label="元PDF 172ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1260-eval.png" alt="症例No.1260の専門家判定理由"></a></section>
  </div><p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（172/456ページ）</a></p></article>

  <article class="case"><h2>「剖検にて心筋炎と診断」</h2><p class="case-meta">36歳男性・症例 No.1332</p><div class="record-grid">
    <section class="record-cell"><h3>基本情報・症状・転帰</h3>36歳男性／2回目<br>2021-08-28接種<br>2021-08-31死亡<br><b>症状：</b>急性心筋炎、突然死<br><b>転帰：</b>死亡</section>
    <section class="record-cell doctor-cell"><h3>報告医所見・解剖</h3><b>関連あり／他要因なし</b><br>解剖により急性心筋炎と報告。<a class="evidence-link" href="src/vaxcausal/pages/001161432-p183.png" data-full="src/vaxcausal/pages/001161432-p183.png" data-box="2.5,53,95,10" data-page-label="元PDF 183ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1332-medical.png" alt="症例No.1332の報告内容"></a></section>
    <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>心筋炎の診断は妥当だが、死亡を示す客観所見や原因の情報が不足。</p><a class="evidence-link" href="src/vaxcausal/pages/001161432-p183.png" data-full="src/vaxcausal/pages/001161432-p183.png" data-box="2.5,53,95,10" data-page-label="元PDF 183ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1332-eval.png" alt="症例No.1332の専門家判定理由"></a></section>
  </div><p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（183/456ページ）</a></p></article>

  <article class="case"><h2>「多発性肺内動脈血栓性塞栓による呼吸不全」</h2><p class="case-meta">64歳女性・症例 No.1737</p><div class="record-grid">
    <section class="record-cell"><h3>基本情報・症状・転帰</h3>64歳女性／1回目<br>2021-06-29接種<br>2021-07-02死亡<br><b>症状：</b>肺・腎動脈血栓症、呼吸不全<br><b>転帰：</b>死亡</section>
    <section class="record-cell doctor-cell"><h3>報告医所見・病理解剖</h3><b>関連あり</b><br>病理解剖で全身の血栓を確認。多発性肺内動脈血栓性塞栓による呼吸不全が死因と診断。<a class="evidence-link" href="src/vaxcausal/pages/001161432-p275.png" data-full="src/vaxcausal/pages/001161432-p275.png" data-box="2.5,14,95,18.5" data-page-label="元PDF 275ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1737-medical.png" alt="症例No.1737の報告内容"></a></section>
    <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>急性肺動脈内血小板血栓の多発による呼吸不全と考えるが、発現が早く増悪因子も否定できない。</p><a class="evidence-link" href="src/vaxcausal/pages/001161432-p275.png" data-full="src/vaxcausal/pages/001161432-p275.png" data-box="2.5,14,95,18.5" data-page-label="元PDF 275ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1737-eval.png" alt="症例No.1737の専門家判定理由"></a></section>
  </div><p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（275/456ページ）</a></p></article>

  <article class="case"><h2>「行政解剖の結果、心筋炎を伴う急性循環不全」</h2><p class="case-meta">19歳男性・症例 No.1762</p><div class="record-grid">
    <section class="record-cell"><h3>基本情報・症状・転帰</h3>19歳男性／3回目<br>2022-07-29接種<br>2022-08-01死亡<br><b>症状：</b>心筋炎、急性循環不全<br><b>転帰：</b>死亡</section>
    <section class="record-cell doctor-cell"><h3>報告医所見・行政解剖</h3><b>関連あり／他要因なし</b><br>行政解剖で心筋炎を伴う急性循環不全と判断。<a class="evidence-link" href="src/vaxcausal/pages/001161432-p280.png" data-full="src/vaxcausal/pages/001161432-p280.png" data-box="2.5,26,95,14" data-page-label="元PDF 280ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1762-medical.png" alt="症例No.1762の報告内容"></a></section>
    <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>パルボウイルスB19を検出。心筋の情報は不明。</p><a class="evidence-link" href="src/vaxcausal/pages/001161432-p280.png" data-full="src/vaxcausal/pages/001161432-p280.png" data-box="0,0,0,0" data-page-label="元PDF 280ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no1762-eval.png" alt="症例No.1762の専門家判定理由"></a></section>
  </div><p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（280/456ページ）</a></p></article>

  <article class="case"><h2>「時間経過よりコミナティが死亡原因」</h2><p class="case-meta">70歳男性・2価ワクチン症例 No.101</p><div class="record-grid">
    <section class="record-cell"><h3>基本情報・症状・転帰</h3>70歳男性／6回目<br>2023-05-27接種<br>2023-05-28死亡<br><b>症状：</b>心筋梗塞、心タンポナーデ、塞栓症<br><b>転帰：</b>死亡</section>
    <section class="record-cell doctor-cell"><h3>報告医所見・剖検</h3><b>関連あり／他要因なし</b><br>「時間経過よりコミナティが死亡原因になったものと考える」。<a class="evidence-link" href="src/vaxcausal/pages/001161432-p329.png" data-full="src/vaxcausal/pages/001161432-p329.png" data-box="2.5,47,95,9" data-page-label="元PDF 329ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/no101-medical.png" alt="2価ワクチン症例No.101の報告内容"></a></section>
    <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>コメントなし。</p></section>
  </div><p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（329/456ページ）</a></p></article>

  <div class="takeaway">
    <h2>γは「医師が関連なしと判断した症例」ではない</h2>
    剖検が行われ、報告医が「関連あり」と評価した症例もγに含まれます。γは「剖検なし」「医師も原因とは考えていない」症例だけを意味しません。一方、報告医の判断や剖検所見だけで、ワクチンとの因果関係が確定するわけでもありません。
  </div>

  <h2>では、αになった死亡報告は何か</h2>
  <div class="compact-cases alpha">
    <article class="case">
      <h2>14歳女性・心筋炎等</h2>
      <p class="case-meta">3回目接種45時間後に死亡・症例 No.1809</p>
      <p><span class="verdict">α</span></p>
      <p>剖検で心筋・心膜の炎症所見があり、他のウイルス検査は陰性。専門家は、心筋炎から不整脈を生じ死亡に至ったとの判断は、得られた情報と矛盾しないとした。</p>
      <a class="evidence-link" href="src/vaxcausal/pages/001161432-p290.png" data-full="src/vaxcausal/pages/001161432-p290.png" data-box="2.5,14,95,31" data-page-label="元PDF 290ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/alpha-14.png" alt="14歳女性のα評価症例を掲載した厚生労働省資料"></a>
      <p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener">元PDF（290/456ページ）</a></p>
    </article>
    <article class="case">
      <h2>42歳女性・急性肺水腫等</h2>
      <p class="case-meta">接種直後に心肺停止・一覧 No.23198</p>
      <p><span class="verdict">α</span></p>
      <p>専門家は、画像所見等の範囲ではワクチン以外の原因として死因となる具体的異常所見が同定されず、接種と死亡との直接的因果関係は否定できないとした。</p>
      <a class="evidence-link" href="src/vaxcausal/pages/001197724-p40.png" data-full="src/vaxcausal/pages/001197724-p40.png" data-box="4,10,92,42" data-page-label="元PDF 40ページと切抜き範囲"><img class="source-image" src="src/vaxcausal/alpha-42.png" alt="42歳女性のα評価症例を掲載した厚生労働省資料"></a>
      <p class="source-note"><a class="source-link" href="https://www.mhlw.go.jp/content/10601000/001197724.pdf" target="_blank" rel="noopener">元PDF（40/52ページ）</a></p>
    </article>
  </div>

  <section class="sources">
    <h2>資料の読み方</h2>
    <ul>
      <li>画像は厚生労働省公表PDFの該当ページから切り出したものです。画像を押すと、元の1ページ全体と切抜き範囲（赤枠）を表示します。</li>
      <li>長い記載は要点を抜粋・要約しています。判断の検証にはリンク先の原資料を参照してください。</li>
      <li>「報告医評価」と「専門家評価」は評価主体が異なり、症状との因果関係と死亡との因果関係が分けて論じられる場合もあります。</li>
    </ul>
  </section>
</main>
</div>
<div class="page-viewer" id="page-viewer" role="dialog" aria-modal="true" aria-label="元PDFページと切抜き範囲">
  <button class="page-viewer-close" type="button" aria-label="閉じる">×</button>
  <div class="page-viewer-inner"><img alt="元PDFの該当ページ"><span class="crop-box"></span></div>
</div>
<script>
(() => {
  const viewer = document.getElementById('page-viewer');
  const pageImage = viewer.querySelector('img');
  const box = viewer.querySelector('.crop-box');
  // 切抜き画像と赤枠は同じPDF座標から作る。 / Derive displayed crops and red boxes from the same PDF coordinates.
  const cropBoxes = {
    'no15-medical.png': '49.1,31.2,44.7,60.6',
    'no15-eval.png': '75.0,7.0,8.9,2.3',
    'no1808-medical.png': '39.0,24.0,54.8,69.5',
    'no185-medical.png': '21.9,52.8,18.5,15.7', 'no185-eval.png': '78.7,52.8,12.3,15.7',
    'no862-medical.png': '21.9,55.5,18.5,9.7', 'no862-eval.png': '78.7,55.5,12.3,9.7',
    'no1260-medical.png': '21.9,15.5,18.5,13.4', 'no1260-eval.png': '78.7,15.5,12.3,13.4',
    'no1332-medical.png': '21.9,53.0,18.5,9.9', 'no1332-eval.png': '78.7,53.0,12.3,9.9',
    'no1737-medical.png': '21.9,15.5,18.5,16.9', 'no1737-eval.png': '78.7,15.5,12.3,16.9',
    'no1762-medical.png': '21.9,26.3,18.5,13.8', 'no1762-eval.png': '78.7,26.3,12.3,13.8',
    'no1790-row.png': '21.9,45.1,18.5,15.3', 'no1790-eval.png': '78.7,45.1,12.3,15.3',
    'no1808-eval.png': '62.5,73.6,12.3,15.3',
    'no101-medical.png': '21.9,47.4,18.5,9.0',
    'alpha-14.png': '78.7,59.0,12.3,13.1',
    'alpha-42.png': '83.0,20.1,14.7,36.2'
  };
  const close = () => { viewer.classList.remove('open'); document.body.style.overflow = ''; };
  document.querySelectorAll('.evidence-link').forEach(link => {
    link.addEventListener('click', event => {
      event.preventDefault();
      const imageName = link.querySelector('img').src.split('/').pop();
      const values = cropBoxes[imageName].split(',');
      pageImage.src = link.dataset.full;
      pageImage.alt = link.dataset.pageLabel;
      [box.style.left, box.style.top, box.style.width, box.style.height] = values.map(value => `${value}%`);
      viewer.classList.add('open');
      document.body.style.overflow = 'hidden';
    });
  });
  viewer.querySelector('.page-viewer-close').addEventListener('click', close);
  viewer.addEventListener('click', event => { if (event.target === viewer) close(); });
  document.addEventListener('keydown', event => { if (event.key === 'Escape') close(); });
})();
</script>
</body>
</html>
HTMLDOC

puts html.sub('__MENU__', menu_out.string)
