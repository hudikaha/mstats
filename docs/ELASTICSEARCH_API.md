# Using the Elasticsearch API

English | [日本語](ELASTICSEARCH_API_ja.md)

`medicalfacts.info` publishes mortality, population, KCOR, and post-vaccination
death analyses through a read-only Elasticsearch API. No client credentials are
required.

```text
https://medicalfacts.info/elastic/mstats/_search
https://medicalfacts.info/elastic/kcor/_search
https://medicalfacts.info/elastic/vdeath/_search
```

API responses are JSON. For example, retrieve the number of `mstats` records
as follows:

```sh
curl -sS 'https://medicalfacts.info/elastic/mstats/_count'
```

Response:

```json
{"count":1446906,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0}}
```

The counts and record contents below were retrieved on July 20, 2026, and will
change as the data is updated.

Instead of reading compact JSON directly, convert it to YAML with Ruby and
display it with `less`.

```sh
curl -sS 'https://medicalfacts.info/elastic/mstats/_count' \
  | ruby -ryaml -rjson -e 'puts YAML.dump(JSON.parse(STDIN.read))' \
  | less
```

This displays:

```yaml
---
count: 1446906
_shards:
  total: 1
  successful: 1
  skipped: 0
  failed: 0
```

Press `q` to exit `less`. This filter only makes the response easier to read;
the API response format remains JSON.

When the document ID is known, retrieve one record without a search query. No
method, header, or request body option is required.

```sh
curl -sS \
  'https://medicalfacts.info/elastic/mstats/_doc/jpn_2009w02_death__00000__both' \
  | ruby -ryaml -rjson -e 'puts YAML.dump(JSON.parse(STDIN.read))' \
  | less
```

The output begins as follows:

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

Additional fields follow under `_source`, which contains the actual record. A
nonexistent ID returns HTTP 404 with `found` set to `false`.

## Public datasets

| Index | Contents | Main fields |
|---|---|---|
| `mstats` | Mortality, causes of death, and population | `id`, `loc_code`, `date`, `year`, `category`, `death_code`, `sex`, `age_*` |
| `kcor` | KCOR results by cutoff | `id`, `areacode`, `date`, `cutoff`, `cweek`, `age`, `dose`, `deaths` |
| `vdeath` | Post-vaccination death analyses by age group and dose | `doc_id`, `areacode`, `period`, `age`, `dose`, `deaths`, `mortality` |
| `vdeath` | Age-adjusted vaccination/death analysis; backed by `vdeath2026` | Same as `vdeath` |
| `indiv` | Weekly-anonymized individual records (IND-WKA) | `id`, `vbirthday`, `date_doseN`, `date_death` |
| `covid19` | Legacy COVID-19 statistics | Dataset-specific |
| `enmort` | England mortality by vaccination status | Dataset-specific |

## Basics

Send Elasticsearch Query DSL as JSON. `POST` is recommended for nontrivial
searches.

### Retrieve the first 100 records

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

The result list is in `hits.hits`; each record is in `hits.hits[]._source`.

POST a query to `_count` for a filtered count.

```sh
curl -sS -H 'Content-Type: application/json' \
  -X POST 'https://medicalfacts.info/elastic/mstats/_count' \
  -d '{
    "query": { "match": { "loc_code": "jpn" } }
  }'
```

## mstats examples

### Country code and year range

This request retrieves 100 raw Japanese mortality records for 2020 through
2024, ordered by date.

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

`loc_code` normally uses lowercase ISO alpha-3 country codes; Japan is `jpn`.
Japanese municipalities use codes such as `jp132101`.

### Date, cause of death, and sex

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

The all-cause `death_code` is `00000`. Population records use `category=pop`;
their `type` is `conf`, `est`, or `jpns`.

## kcor example

Filter by area, cutoff, age, and dose.

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

## vdeath example

`vdeath` stores one record per age group. Unlike `mstats`, it has no `age_*`
fields; use `age` for the age group and `dose` for the dose count.

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

## Pagination

For large result sets, use `search_after` instead of increasing `from`. The
first request must define a unique sort order.

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

If the final record contains:

```json
"sort": ["2024-01-07", "jpn_2024w01_death__00000__both"]
```

pass that value unchanged to the next request:

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

CORS is enabled, so browsers can query the API directly.

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

## Inspecting the schema

```sh
curl -sS 'https://medicalfacts.info/elastic/mstats/_mapping'
curl -sS 'https://medicalfacts.info/elastic/mstats/_field_caps?fields=*'
```

## Public scope and limits

- The available public names are `mstats`, `kcor`, `vdeath`, `indiv`, `covid19`, and `enmort`.
- The endpoints are `_search`, `_count`, `_mapping`, `_field_caps`, and
  `_doc/{id}` for direct ID retrieval.
- Allowed methods are `GET`, `POST`, and CORS preflight `OPTIONS`. `_doc/{id}`
  is GET-only.
- Writes, deletes, bulk imports, and access to other indices are unavailable.
- Request bodies are limited to 1 MiB and the response timeout is 30 seconds.
- Select only required fields with `_source`, and avoid overly expensive or
  high-frequency queries.
