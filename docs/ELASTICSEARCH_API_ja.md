# Elasticsearch APIの利用方法

[English](ELASTICSEARCH_API.md) | 日本語

`medicalfacts.info` は、死亡・人口統計、KCOR、接種後死亡分析を読取専用の
Elasticsearch APIで公開しています。認証情報は不要です。

```text
https://medicalfacts.info/elastic/mstats/_search
https://medicalfacts.info/elastic/kcor/_search
https://medicalfacts.info/elastic/vdeath/_search
```

APIの応答はJSONです。例えば、`mstats`のrecord数は次のように取得できます。

```sh
curl -sS 'https://medicalfacts.info/elastic/mstats/_count'
```

応答:

```json
{"count":1446906,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0}}
```

以下の件数とrecord内容は2026年7月20日の取得例で、data更新により変わります。

JSONをそのまま読む代わりに、RubyでYAMLへ変換して`less`で表示することもできます。

```sh
curl -sS 'https://medicalfacts.info/elastic/mstats/_count' \
  | ruby -ryaml -rjson -e 'puts YAML.dump(JSON.parse(STDIN.read))' \
  | less
```

この場合は次のように表示されます。

```yaml
---
count: 1446906
_shards:
  total: 1
  successful: 1
  skipped: 0
  failed: 0
```

`q`で`less`を終了します。このfilterは表示を読みやすくするだけなので、APIから
返されるデータ形式はJSONのままです。

文書IDが分かっている場合は、検索条件を指定せずに1件取得できます。method、header、
request bodyの指定は不要です。

```sh
curl -sS \
  'https://medicalfacts.info/elastic/mstats/_doc/jpn_2009w02_death__00000__both' \
  | ruby -ryaml -rjson -e 'puts YAML.dump(JSON.parse(STDIN.read))' \
  | less
```

表示は次のように始まります。

```yaml
---
_index: mstats20260719
_type: _doc
_id: jpn_2009w02_death__00000__both
_version: 2
_seq_no: 1446906
_primary_term: 1
found: true
_source:
  year: 2009
  age_1: 10.16
  date: '2009-01-11'
  age_2: 3.16
  age_85_89: 4307.71
  age_00_14: 89.42
  age_65_69: 1730.58
  type:
  age_all: 25573.03
```

この後にも`_source`内のfieldが続きます。`_source`が実際のrecordです。存在しないIDを
指定するとHTTP 404となり、`found: false`が返ります。

## 公開dataset

| index | 内容 | 主なfield |
|---|---|---|
| `mstats` | 国別・日本の死亡数、死因別死亡数、人口 | `id`, `loc_code`, `date`, `year`, `category`, `death_code`, `sex`, `age_*` |
| `kcor` | cutoff別KCOR集計 | `id`, `areacode`, `date`, `cutoff`, `cweek`, `age`, `dose`, `deaths` |
| `vdeath` | 年齢区分・接種回数ごとの年齢補正済み接種後死亡分析 | `areacode`, `period`, `age`, `dose`, `deaths`, `mortality` |
| `indiv` | 週単位匿名化個票（IND-WKA） | `id`, `vbirthday`, `date_doseN`, `date_death` |
| `indivdth` | 死亡者のみの週単位匿名化個票（DTH-WKA） | `id`, `vbirthday`, `date_death` |

## 基本

検索条件はElasticsearch Query DSLのJSONで送ります。複雑な検索では`POST`を推奨します。

### 先頭から100件

```sh
curl -sS -H 'Content-Type: application/json' \
  -X POST 'https://medicalfacts.info/elastic/mstats/_search' \
  -d '{
    "size": 100,
    "_source": ["id", "date", "yearweek", "death_code", "sex", "age_all"],
    "query": {
      "bool": {
        "filter": [
          { "match": { "loc_code": "jpn" } },
          { "match": { "category": "death" } },
          { "match": { "death_code": "00000" } },
          { "match": { "sex": "both" } }
        ]
      }
    }
  }'
```

結果本体は`hits.hits`、各recordは`hits.hits[]._source`に入ります。

条件付き件数は`_count`へqueryをPOSTします。

```sh
curl -sS -H 'Content-Type: application/json' \
  -X POST 'https://medicalfacts.info/elastic/mstats/_count' \
  -d '{
    "query": { "match": { "loc_code": "jpn" } }
  }'
```

## mstatsの検索例

### 国コードと年の範囲

日本の2020～2024年の元の死亡数を、日付順で100件取得します。

```sh
curl -sS -H 'Content-Type: application/json' \
  -X POST 'https://medicalfacts.info/elastic/mstats/_search' \
  -d '{
    "size": 100,
    "_source": [
      "id", "loc_code", "location", "date", "year",
      "yearmonth", "yearweek", "category", "death_code", "sex", "age_all"
    ],
    "query": {
      "bool": {
        "filter": [
          { "match": { "loc_code": "jpn" } },
          { "match": { "category": "death" } },
          { "term":  { "rate": "" } },
          { "term":  { "algo": "" } },
          { "range": { "year": { "gte": 2020, "lte": 2024 } } }
        ]
      }
    },
    "sort": [
      { "date": "asc" },
      { "id": "asc" }
    ]
  }'
```

`loc_code`は小文字の3文字国コードを基本とします。日本は`jpn`です。日本の自治体は
`jp132101`のようなコードを使用します。

### 日付、死因、性別を指定

```json
{
  "size": 100,
  "_source": [
    "id", "date", "yearmonth", "death_code", "death_cause", "sex", "age_all"
  ],
  "query": {
    "bool": {
      "filter": [
        { "match": { "loc_code": "jpn" } },
        { "match": { "category": "death" } },
        { "match": { "death_code": "02100" } },
        { "match": { "sex": "both" } },
        { "range": { "date": { "gte": "2020-01-01", "lt": "2025-01-01" } } }
      ]
    }
  },
  "sort": [
    { "date": "asc" },
    { "id": "asc" }
  ]
}
```

全死因の`death_code`は`00000`です。人口recordは`category=pop`で、`type`は
`conf`、`est`、`jpns`のいずれかです。

## kcorの検索例

地域、cutoff、年齢、接種回数を指定します。

```sh
curl -sS -H 'Content-Type: application/json' \
  -X POST 'https://medicalfacts.info/elastic/kcor/_search' \
  -d '{
    "size": 100,
    "query": {
      "bool": {
        "filter": [
          { "term": { "areacode": "jp132101" } },
          { "term": { "cutoff": "2021-06-06" } },
          { "term": { "age": "00-09" } },
          { "term": { "dose": 0 } }
        ]
      }
    },
    "sort": [
      { "date": "asc" },
      { "id": "asc" }
    ]
  }'
```

## vdeathの検索例

`vdeath`は年齢区分ごとに1つのrecordを持ちます。`mstats`のような`age_*` fieldはなく、
年齢区分を`age`、接種回数を`dose`で指定します。

```sh
curl -sS -H 'Content-Type: application/json' \
  -X POST 'https://medicalfacts.info/elastic/vdeath/_search' \
  -d '{
    "size": 100,
    "query": {
      "bool": {
        "filter": [
          { "match": { "areacode": "jp132101" } },
          { "match": { "age": "80+" } },
          { "match": { "dose": "0" } }
        ]
      }
    }
  }'
```

## 続きの取得

大量取得では`from`を増やさず、`search_after`を使用してください。最初のrequestでは
一意に並ぶsortを指定します。

```json
{
  "size": 1000,
  "query": { "term": { "loc_code": "jpn" } },
  "sort": [
    { "date": "asc" },
    { "id": "asc" }
  ]
}
```

最後のrecordの`sort`が次の場合、

```json
"sort": ["2024-01-07", "jpn_2024w01_death__00000__both"]
```

次のrequestへそのまま渡します。

```json
{
  "size": 1000,
  "query": { "term": { "loc_code": "jpn" } },
  "search_after": ["2024-01-07", "jpn_2024w01_death__00000__both"],
  "sort": [
    { "date": "asc" },
    { "id": "asc" }
  ]
}
```

## Browser JavaScript

CORSを許可しているため、browserから直接取得できます。

```js
const response = await fetch(
  "https://medicalfacts.info/elastic/mstats/_search",
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      size: 100,
      query: { term: { loc_code: "jpn" } }
    })
  }
);

if (!response.ok) throw new Error(`HTTP ${response.status}`);
const json = await response.json();
const records = json.hits.hits.map(hit => hit._source);
```

## schemaの確認

```sh
curl -sS 'https://medicalfacts.info/elastic/mstats/_mapping'
curl -sS 'https://medicalfacts.info/elastic/mstats/_field_caps?fields=*'
```

## 公開範囲と注意

- 使用できる公開名は`mstats`、`kcor`、`vdeath`、`indiv`、`indivdth`です。
- endpointは`_search`、`_count`、`_mapping`、`_field_caps`、ID指定の`_doc/{id}`です。
- methodは`GET`、`POST`、CORS preflightの`OPTIONS`だけです。`_doc/{id}`はGET限定です。
- 書込み、削除、bulk投入、他のindexへのアクセスはできません。
- request bodyは1 MiB以下、応答待ちは30秒以内です。
- 必要なfieldだけを`_source`で指定し、過度に大きなqueryや連続requestを避けてください。
