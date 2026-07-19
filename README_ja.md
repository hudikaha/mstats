# mstats

[English](README.md) | 日本語

`mstats` は、[medicalfacts.info](https://medicalfacts.info/) で公開する死亡、
死因、人口、ワクチン接種および関連統計グラフのソースrepositoryです。Ruby CGI、
共通表示処理、data変換、Elasticsearch mapping、Logstash template、保守文書を収録します。

原data、生成した累積CSV、認証情報、ローカル固有のLogstash設定は収録しません。
これらはGitの外に置き、ローカルpath、環境変数、symbolic linkで接続します。

## 構成

```text
bin/       repository保守用utility
cdeath/    死因・人口処理とWeb application
lib/       共通menu、page layout、QR、Elasticsearch補助処理
vdeath/    ワクチン接種・死亡分析とKCOR
web/       その他の保守対象CGIと静的HTMLから変換した内容
docs/      repository全体の構成、data、security文書
data       外部data directoryへのローカルsymbolic link
```

各分野の詳細は [`cdeath/README.md`](cdeath/README.md)、[データ](docs/DATA_ja.md)、
[`vdeath/docs/KCOR.md`](vdeath/docs/KCOR.md) を参照してください。

## Web application

共通menuは [`lib/menu.yml`](lib/menu.yml) で定義します。
[`lib/mfacts.rb`](lib/mfacts.rb) が共通menu、title、QR code、Elasticsearch補助処理を
出力します。各Ruby pageが固有のquery、変換、Vega-Lite定義を担当します。

ファイル配備例:

```sh
scp lib/mfacts.rb fujikawa.org:fujikawa/covid19/lib/mfacts.rb
scp web/example.rb fujikawa.org:fujikawa/covid19/example.rb
```

## データ

大容量dataはcommitしません。ローカルの `data` は `~/work/mstats/data` を指し、他の
source directoryも内容をGitへコピーせず接続します。`cdeath/Makefile` が取得、検証、
変換、upload、一回限りのLogstash投入targetを提供します。

死因と人口の共通形式を **mstats2026** と呼びます。KCORはdocument構造と検索modelが
異なるため、別の `kcor2025` indexを使用します。

## セキュリティ

password、token、非公開取得元credential、`.env`、machine固有Logstash設定をcommitしては
いけません。codeはrepository外のファイルまたは環境変数から秘密を取得します。
詳細は[セキュリティ](docs/SECURITY_ja.md)を参照してください。

## 文書

- [文書索引](docs/README_ja.md)
- [構成](docs/ARCHITECTURE_ja.md)
- [データ](docs/DATA_ja.md)
- [セキュリティ](docs/SECURITY_ja.md)

## テキストとコメント

text fileはBOMなしUTF-8、LF改行、末尾改行ありに統一します。自明でない保守境界を説明する
Ruby commentは日本語を先、その次に英語を置きます。短いcommentは一行に両言語を併記して
構いません。

## repositoryの由来

このrepositoryは非公開の旧 `mstats2025` repositoryから履歴を引き継がず、新しく開始
しました。旧Git履歴と旧 `old/` directoryは意図的に移行していません。
