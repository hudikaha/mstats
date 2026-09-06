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
      <section class="record-cell doctor-cell"><h3>報告医所見・剖検</h3><b>関連あり／他要因なし</b><br>「患者は心筋炎で急死したと考えられる」<a href="https://www.mhlw.go.jp/content/10601000/001039711.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no15-medical.png" alt="報告医が関連あり、他要因なしと評価し、剖検で心筋炎所見を認めた原文"></a></section>
      <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>ブライトン分類1。「剖検上は心筋炎で矛盾しない」。</p><a href="https://www.mhlw.go.jp/content/10601000/001125548.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no15-eval.png" alt="症例No.22710の専門家評価γと剖検所見"></a></section>
    </div>
    <p class="source-note">報告医原文：PDF 1647ページ。専門家評価：別資料 PDF 38ページ。</p>
  </article>

  <article class="case">
    <h2>「血栓症による心室細動と考える」</h2>
    <p class="case-meta">73歳女性・2回目接種後に死亡（症例 No.1790）</p>
    <div class="record-grid">
      <section class="record-cell"><h3>基本情報・症状・転帰</h3>73歳女性／2回目<br>2021-08-06接種<br>2021-09-07死亡<br><b>症状：</b>心室細動、血栓症、血小板減少症、腎不全、多臓器不全等<br><b>転帰：</b>死亡</section>
      <section class="record-cell doctor-cell"><h3>報告医所見・剖検</h3><b>関連あり／他要因なし</b><br>「剖検の結果、微小梗塞が認められた。血栓症による心室細動と考える」<a href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no1790-row.png" alt="剖検で微小梗塞を認め、報告医が関連ありとした症例No.1790"></a></section>
      <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>微小血栓症を確認しブライトン分類1。DICを除く鑑別情報が不足し「否定も肯定もできません」。</p><a href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no1790-eval.png" alt="症例No.1790の専門家評価γ"></a></section>
    </div>
    <p class="source-note">厚生労働省資料 PDF 285ページの同じ行を、左右に分けて掲載。</p>
  </article>

  <article class="case">
    <h2>「ワクチン接種により下肢に血栓が発現」</h2>
    <p class="case-meta">40歳女性・2回目接種後に死亡（症例 No.1808／一覧 No.22258）</p>
    <div class="record-grid">
      <section class="record-cell"><h3>基本情報・症状・転帰</h3>40歳女性／2回目<br>2021-09-13接種<br>2022-02-27死亡<br><b>症状：</b>下肢腫脹・疼痛、肺動脈血栓塞栓症、突然死<br><b>転帰：</b>死亡</section>
      <section class="record-cell doctor-cell"><h3>報告医所見・剖検</h3><b>関連あり／他要因なし</b><br>「ワクチン接種により下肢に血栓が発現し、血栓が肺にとび、肺動脈につまり急死」<a href="https://www.mhlw.go.jp/content/10601000/001125524.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no1808-medical.png" alt="報告医がワクチンによる血栓と判断し、肺動脈に血栓所見を認めた原文"></a></section>
      <section class="record-cell expert-cell"><h3>専門家判定・理由</h3><span class="verdict">γ</span><p>肺動脈血栓は認めるが、接種から3か月以上経過し、臨床経過や血栓症リスクの情報が十分でない。</p><a href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no1808-eval.png" alt="症例No.1808の専門家評価γと判定理由"></a></section>
    </div>
    <p class="source-note">報告医原文：PDF 808ページ。専門家評価：別資料 PDF 289ページ。</p>
  </article>

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
      <a href="https://www.mhlw.go.jp/content/10601000/001161432.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/alpha-14.png" alt="14歳女性のα評価症例を掲載した厚生労働省資料"></a>
      <p class="source-note">厚生労働省資料 PDF 290ページ</p>
    </article>
    <article class="case">
      <h2>42歳女性・急性肺水腫等</h2>
      <p class="case-meta">接種直後に心肺停止・一覧 No.23198</p>
      <p><span class="verdict">α</span></p>
      <p>専門家は、画像所見等の範囲ではワクチン以外の原因として死因となる具体的異常所見が同定されず、接種と死亡との直接的因果関係は否定できないとした。</p>
      <a href="https://www.mhlw.go.jp/content/10601000/001197724.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/alpha-42.png" alt="42歳女性のα評価症例を掲載した厚生労働省資料"></a>
      <p class="source-note">厚生労働省資料 PDF 40ページ</p>
    </article>
  </div>

  <section class="sources">
    <h2>資料の読み方</h2>
    <ul>
      <li>画像は厚生労働省公表PDFの該当ページから切り出したものです。画像を押すと原資料を開きます。</li>
      <li>長い記載は要点を抜粋・要約しています。判断の検証にはリンク先の原資料を参照してください。</li>
      <li>「報告医評価」と「専門家評価」は評価主体が異なり、症状との因果関係と死亡との因果関係が分けて論じられる場合もあります。</li>
    </ul>
  </section>
</main>
</div>
</body>
</html>
HTMLDOC

puts html.sub('__MENU__', menu_out.string)
