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

## Weekly risk sets for gamma frailty

`CUMD-WK-G` is not output adjusted by a particular KCOR version. It is the raw weekly
format shared by KCOR analyses, including gamma-frailty variants.
`vdeathp.rb kcor --risk-output FILE` emits it during the same cohort pass that produces
the existing `CUMD-WK` output.

```text
id, areacode, area, areaj, cutoff, cweek, date, age, dose,
cohort_size, at_risk, deaths_week, deaths, censored_week
```

- `cohort_size`: fixed cohort population at the cutoff
- `at_risk`: living observed population at the start of the week
- `deaths_week`: deaths during the week
- `deaths`: cumulative deaths after the cutoff
- `censored_week`: observations ending during the week, such as move-outs

The format does not store theta, quiet windows, adjusted hazards, or KCOR values because
those depend on the analysis version. It can be generated from complete individual records
or `IND-WKA`, but not from death-only `DTH-WKA` input.
When only `--risk-output` is supplied, the program generates risk sets without replacing
the existing `CUMD-WK` output.

## Simple gamma-frailty fitting

`import/kcor_gamma.rb` reads `CUMD-WK-G` and fits a constant-baseline gamma-frailty
model by nonlinear least squares for each area, cutoff, age, and dose group within a
quiet window.

```text
MR(t)   = deaths_week(t) / at_risk(t)
h(t)    = -log(1 - MR(t))
Hobs(t) = sum h(t)
Hobs(t) = log(1 + theta * k * t) / theta
H0(t)   = (exp(theta * Hobs(t)) - 1) / theta
```

At `theta=0`, the limiting values `Hobs(t)=k*t` and `H0(t)=Hobs(t)` are used. For example:

```sh
ruby import/kcor_gamma.rb \
  --quiet-start 2022-W24 --quiet-end 2024-W16 \
  --output ../outputs/cze_Czech-Republic_GAMMA-CONSTANT-PARAMS.csv \
  --series-output ../outputs/cze_Czech-Republic_GAMMA-CONSTANT-SERIES.csv \
  ../outputs/cze_Czech-Republic_CUMD-WK-G.csv
```

The parameter output stores theta, weekly k, the number of quiet points, RMSE, and a
`fit_status` that identifies boundary solutions.
The optional series output stores weekly observed hazard, observed cumulative hazard,
and gamma-inverted cumulative hazard. This is a simple model with a constant baseline,
distinct from newer KCOR versions that use a Gompertz baseline and iterative quiet-point
selection. The raw format therefore remains the unversioned `CUMD-WK-G`; analysis outputs
must identify their method and conditions.

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
