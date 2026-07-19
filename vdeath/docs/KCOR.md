# KCOR

## 配置

`vdeath` は `cdeath` と同格の分野とし、KCORは `vdeath` 内で扱う。

```text
vdeath/
├── web/
│   ├── kcor.rb
│   ├── kcor.js
│   └── kcor.css
├── import/
│   └── export_kcor_json.rb
└── config/
    ├── elasticsearch/kcor2025-mapping.json
    └── logstash/kcor2025.conf
```

## Elasticsearch

- index名は `kcor2025`。
- `mstats2026` とは文書スキーマもindexも統合しない。
- 旧 `kkcor` indexは使用しない。
- 原資料は `~/fujikawa/pub/kkcor/*_CUMD-WK.csv.xz`。
- 原CSVの10フィールドをすべて保存する。

```text
id, areacode, area, areaj, cutoff, cweek, date, age, dose, deaths
```

`dose` は整数、`deaths` は整数、`cutoff` と `date` は日付、それ以外はkeywordとする。Elasticsearchの `_id` にはCSVの `id` を使用し、`id` フィールドも `_source` に残す。

2026-07-18の投入件数は1,075,651件。これは8本のCSVのヘッダーを除いた合計と一致する。

## 公開データ

Elasticsearchを正本とし、WebブラウザからElasticsearchを直接検索しない。`export_kcor_json.rb` がcutoff別JSONと `manifest.json` を生成し、nginxから静的配信する。

公開JSONへ出す元フィールドは次に限定する。

```text
areacode, area, areaj, date, age, dose, deaths
```

JSON内では地域、日付、年齢を辞書化し、各行は辞書indexと数値だけを持つ。ブラウザは選択中のcutoffだけを取得し、地域・年齢・接種回数の変更は通信せずに再集計する。一度取得したcutoffはページ内でキャッシュする。

既定cutoff `2021-09-05` は36,352行で、2026-07-18時点のHTTP gzip転送量は約117 KB。全36 cutoffの行数合計は1,075,651件で、旧 `BASE.js` の全行と完全一致することを確認した。

## Webアプリケーション

- `kcor.rb` は言語判定、タイトル、`lib/mfacts.rb` の共通メニュー、HTMLの骨組み、JS設定を出力する。
- `kcor.js` はJSON取得、選択UI、集計、Vega-Lite描画を担当する。
- `kcor.css` はKCOR固有の表示だけを担当し、共通レイアウトは `mfacts.css` を使用する。
- 日本語版は `?l=ja`、英語版は `?l=en`。
- 試験公開名は `kcor2025.rb`。この名前から `kcor2025.js`、`kcor2025.css`、`kcor2025-data/` を参照する。
