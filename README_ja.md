# mstats

[English](README.md) | 日本語

`mstats` は、医療に関わる統計情報（medical statistics）を扱うrepositoryです。
政府やその他の組織が公表する統計情報を取得・解析し、必要に応じて形式を統一するために
再加工したうえで、[medicalfacts.info](https://medicalfacts.info/) においてグラフなどの形で
提供します。また、ElasticsearchによるRESTful APIとしてdataを提供します。
Ruby CGI、共通表示処理、data変換、Elasticsearch mapping、Logstash template、
保守文書を収録します。

## 構成

```text
bin/       repository保守用utility
cdeath/    死因・人口処理とWeb application
lib/       共通menu、page layout、QR、Elasticsearch補助処理
vdeath/    ワクチン接種・死亡分析とKCOR
web/       その他の保守対象CGIと静的HTMLから変換した内容
docs/      repository全体の構成、data、security文書
```

各分野の詳細は [`cdeath/README.md`](cdeath/README.md)、[データ](docs/DATA_ja.md)、
[`vdeath/docs/KCOR_ja.md`](vdeath/docs/KCOR_ja.md) を参照してください。

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

公開データは目的に応じて次の形式に分かれます。

- `mstats`: 国・地域、月・週、死因、性別、年齢階級ごとの死亡数と人口
- `kcor`: cutoff時点の接種回数別cohortについて、その後の累積死亡数を週ごとに記録
- `vdeath`: 自治体、期間、年齢階級、接種回数ごとの人数、person-days、死亡数、死亡率
- `afterdose`: 接種からの経過週ごとのperson-timeと死亡数

`mstats`、`kcor`、`vdeath`は[公開Elasticsearch API](docs/ELASTICSEARCH_API_ja.md)から
検索できます。各recordとCSVのfield、年齢・期間・匿名化の定義は
[データ形式](docs/DATA_ja.md)を参照してください。

## セキュリティ

password、token、非公開取得元credential、`.env`、machine固有Logstash設定をcommitしては
いけません。codeはrepository外のファイルまたは環境変数から秘密を取得します。
詳細は[セキュリティ](docs/SECURITY_ja.md)を参照してください。

## License

このsoftwareは[MIT License](LICENSE)で公開します。

## 文書

- [文書索引](docs/README_ja.md)
- [構成](docs/ARCHITECTURE_ja.md)
- [データ形式](docs/DATA_ja.md)
- [セキュリティ](docs/SECURITY_ja.md)

## テキストとコメント

text fileはBOMなしUTF-8、LF改行、末尾改行ありに統一します。自明でない保守境界を説明する
Ruby commentは日本語を先、その次に英語を置きます。短いcommentは一行に両言語を併記して
構いません。
