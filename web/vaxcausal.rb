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
  .definition,.comparison,.compact-cases { grid-template-columns:1fr; }
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

  <p class="lead">新型コロナワクチン接種後の死亡報告では、報告した医師の因果関係評価と、国の審議会に示される専門家評価は同じではありません。厚生労働省の原資料で、医師の記載と最終的なα・γ判定を見比べます。</p>

  <div class="definition" aria-label="因果関係評価の区分">
    <div><b>α</b>ワクチンと死亡との因果関係が否定できないもの</div>
    <div><b>β</b>ワクチンと死亡との因果関係が認められないもの</div>
    <div><b>γ</b>情報不足等により、因果関係が評価できないもの</div>
  </div>

  <article class="case">
    <h2>「臨床的には因果関係があるとしか思えない」</h2>
    <p class="case-meta">73歳女性・1回目接種当日に死亡（資料上の症例 No.170／一覧 No.4252）</p>
    <div class="comparison">
      <section class="opinion doctor">
        <h3>報告医の意見</h3>
        「ワクチンが心肺機能に何らかの影響を及ぼしたのではないか」「最後のトリガーになった可能性がある」「臨床的には因果関係があるとしか思えない」
      </section>
      <section class="opinion expert">
        <h3>専門家評価</h3>
        <span class="verdict">γ</span>
        <p>「これまで全く健康」との記載に対し、糖尿病・高血圧症の既往や内服薬を示唆する記載もあるとして、患者背景は不詳、接種と死亡の因果関係は評価できないとされた。</p>
      </section>
    </div>
    <a href="https://www.mhlw.go.jp/content/10601000/000823365.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no170-report.png" alt="厚生労働省資料に掲載された症例No.170の報告医意見"></a>
    <p class="source-note">上：厚生労働省資料（PDF 580ページ）の抜粋。</p>
    <a href="https://www.mhlw.go.jp/content/10601000/001010964.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no170-eval.png" alt="厚生労働省資料に掲載された症例一覧No.4252の専門家評価"></a>
    <p class="source-note">上：専門家評価を掲載した別資料（PDF 60ページ）の抜粋。</p>
  </article>

  <div class="compact-cases">
    <article class="case">
      <h2>急性間質性肺炎</h2>
      <p class="case-meta">85歳男性・症例 No.203</p>
      <section class="opinion doctor"><h3>報告医評価</h3><b>関連あり</b><br>他要因：無</section>
      <section class="opinion expert"><h3>専門家評価</h3><span class="verdict">γ</span><p>接種との因果関係は不明で、その他の原因による急性間質性肺炎も否定できないとされた。</p></section>
    </article>
    <article class="case">
      <h2>脳静脈洞血栓症・血小板減少</h2>
      <p class="case-meta">72歳男性・症例 No.204</p>
      <section class="opinion doctor"><h3>報告医評価</h3><b>関連あり</b><br>他要因：無</section>
      <section class="opinion expert"><h3>専門家評価</h3><span class="verdict">γ</span><p>脳静脈血栓症が致死的だったか判別できず、接種との因果関係は不明とされた。</p></section>
    </article>
  </div>
  <a href="https://www.mhlw.go.jp/content/10601000/000846547.pdf" target="_blank" rel="noopener"><img class="source-image" src="src/vaxcausal/no203-204.png" alt="厚生労働省資料に掲載された症例No.203とNo.204"></a>
  <p class="source-note">厚生労働省資料（PDF 30ページ）の抜粋。横長の原表を掲載。</p>

  <div class="takeaway">
    <h2>γは「医師が関連なしと判断した症例」ではない</h2>
    報告医が「関連あり」と評価しても、専門家が死亡との因果関係を確定できなければγになります。したがって、γの件数だけから因果関係の有無を結論づけることはできません。一方で、報告医の所見だけで因果関係が確定するわけでもありません。
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
