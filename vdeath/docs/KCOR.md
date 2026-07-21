# KCOR

English | [日本語](KCOR_ja.md)

## Layout

KCOR belongs to `vdeath`, which is a top-level domain alongside `cdeath`.

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

- The physical index is `kcor2025`; the public search alias is `kcor`.
- `kcor.js` retrieves cutoff metadata and records for the selected cutoff from `/elastic/kcor/_search`.
- Both `index.max_result_window` and the browser request limit are 1,000,000 records.
- The document schema and index remain separate from `mstats2026`.
- The old `kkcor` index is not used.
- All ten fields from the `CUMD-WK` CSV are stored.

```text
id, areacode, area, areaj, cutoff, cweek, date, age, dose, deaths
```

`dose` and `deaths` are integers; `cutoff` and `date` are dates; all other
fields are keywords. The CSV `id` is used as the Elasticsearch `_id` and is
also retained in `_source`.

## Published data

Elasticsearch is the authoritative store, and `kcor.js` queries the public
`/elastic/kcor/_search` API directly. It first retrieves cutoff metadata, then
requests these fields for the selected cutoff:

```text
areacode, area, areaj, date, age, dose, deaths
```

The browser retrieves only the selected cutoff. Changes to location, age, and
dose selections are recomputed without another request. Retrieved cutoffs are
cached within the page.

## Web application

- `kcor.rb` provides language selection, the title, the shared `lib/mfacts.rb` menu, the HTML structure, and JavaScript configuration.
- `kcor.js` retrieves records from the Elasticsearch API and handles controls, aggregation, and Vega-Lite rendering.
- `kcor.css` contains KCOR-specific presentation; shared layout comes from `mfacts.css`.
- Japanese uses `?l=ja`; English uses `?l=en`.
