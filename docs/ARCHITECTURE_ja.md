# 構成

[English](ARCHITECTURE.md) | 日本語

```text
repository外の原data
        -> Ruby変換scriptとMake target
        -> Git外の日付付きCSV
        -> 一回限りのLogstash投入
        -> Elasticsearch index
        -> Ruby CGI pageまたはJSON export
        -> medicalfacts.info
```

`lib/mfacts.rb` は保守対象CGI pageの共通Ruby layerです。`lib/menu.yml` を読み、共通page構造を
出力し、認証付きElasticsearch requestを提供します。各page固有ファイルはquery、変換、
Vega-Lite定義を担当します。

`cdeath` は日本の死因・人口処理、`vdeath` はワクチン接種・死亡分析とKCORを管理します。
その他の保守対象pageは `web` に置きます。大容量dataはrepository外に置き、symbolic linkで
dataをGitへコピーせずローカルの関係を表現します。
