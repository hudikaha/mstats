# KCOR

[English](KCOR.md) | 日本語

## 配置

`vdeath`は`cdeath`と同格の分野とし、KCORは`vdeath`内で扱います。

```text
vdeath/
├── web/
│   ├── kcor.rb
│   ├── kcor.js
│   └── kcor.css
├── import/
│   └── vdeathp.rb
└── config/
    ├── elasticsearch/kcor2025-mapping.json
    └── logstash/kcor2025.conf
```

## Elasticsearch

- 実体index名は`kcor2025`、公開・検索用aliasは`kcor`です。
- `kcor.js`は公開API `/elastic/kcor/_search`からcutoff一覧と選択cutoffのrecordを取得します。
- `index.max_result_window`とbrowserの1回のrequest上限は100万件です。
- `mstats2026`とはdocument schemaもindexも統合しません。
- 旧`kkcor` indexは使用しません。
- `CUMD-WK` CSVの10 fieldをすべて保存します。

```text
id, areacode, area, areaj, cutoff, cweek, date, age, dose, deaths
```

`dose`と`deaths`は整数、`cutoff`と`date`は日付、それ以外はkeywordです。
Elasticsearchの`_id`にはCSVの`id`を使用し、`id` fieldも`_source`に残します。

## 公開データ

Elasticsearchを正本とし、`kcor.js`は公開API `/elastic/kcor/_search`を直接検索します。
最初にcutoff一覧と既定値に必要なmetadataを取得し、選択したcutoffについて次のfieldを取得します。

```text
areacode, area, areaj, date, age, dose, deaths
```

browserは選択中のcutoffだけを取得し、地域・年齢・接種回数の変更は通信せずに再集計します。
一度取得したcutoffはpage内でcacheします。

## Web application

- `kcor.rb`は言語判定、title、`lib/mfacts.rb`の共通menu、HTMLの骨組み、JS設定を出力します。
- `kcor.js`はElasticsearch APIからの取得、選択UI、集計、Vega-Lite描画を担当します。
- `kcor.css`はKCOR固有の表示だけを担当し、共通layoutは`mfacts.css`を使用します。
- 日本語版は`?l=ja`、英語版は`?l=en`です。
