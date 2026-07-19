# cdeath

Cause-of-death and all-cause mortality data processing and web pages.

## Current layout

```text
cdeath/
├── web/                 CGI web pages
├── import/              Source CSV converters
├── src/                 Links to external source-data directories
├── config/logstash/     Elasticsearch import settings
└── docs/                Data model and migration notes
```

CSV files are not stored below this repository. Source and generated CSV paths
must point to external data directories.

## Routine update

Population source CSVs are read only from `~/work/mstats/popjp`.
Cause-of-death source CSVs are read from `src/causejp`. Run either
web-page-oriented alias:

```sh
cd cdeath
make cod
# or
make codtr
```

`make fetch` runs Codex non-interactively to check only the next unpublished
population and cause-of-death months; it does not inspect or validate existing
source CSV contents. `make cod` and `make codtr` do not start Codex: they create
new timestamped `mstats2026` CSVs only when local source files changed, upload
the latest cumulative files, and run Logstash once. `make all` performs both
steps. Progress summaries are printed normally; command logs are kept below
`tmp/make` and printed only when that command fails.

Useful separate stages are `make fetch`, `make fetch-pop`, `make fetch-death`,
`make check`, `make csv`, `make upload`, and `make logstash`. Override
`POP_ARCHIVE_DIR`, `DATA_DIR`, or `SERVER` on the command line when the local
layout differs.

Current source link:

```text
cdeath/src/causejp -> ../../../mstats-20250712/causejp
```

## mstats2026 CSV generation

Cause-of-death CSV:

```sh
ruby cdeath/import/jp-dcause.rb cdeath/src/causejp/*.csv \
  > "$MSTATS_DATA_DIR/jp-dcause-mstats2026.csv"
```

Population CSV:

```sh
ruby cdeath/import/jp-pop.rb SOURCE_DIR/*.csv \
  > "$MSTATS_DATA_DIR/jp-pop-mstats2026.csv"
```

Both commands produce the same mstats2026 CSV schema. On `fujikawa.org`, keep
timestamped files below `~/mstats/data/` and update the fixed-name links used by
Logstash:

An existing cumulative `jp-pop-*.csv` generated in the legacy schema can be
converted without returning to all of the source spreadsheets:

```sh
ruby cdeath/import/jp-pop-legacy.rb jp-pop-YYYYMMDD-HHMM.csv \
  > jp-pop-mstats2026.csv
```

```sh
cd ~/mstats
ln -sfn data/jp-dcause-mstats2026-YYYYMMDD-HHMM.csv jp-dcause-mstats2026.csv
ln -sfn data/jp-pop-mstats2026-YYYYMMDD-HHMM.csv jp-pop-mstats2026.csv
```

The server has `/Users -> /home`, so `mstats2026.conf` follows the existing
fixed-path convention and reads `/Users/magician/mstats/*.csv`. Import with one
Logstash worker because CSV header autodetection is stateful:

```sh
cd ~/mstats
sudo systemctl stop logstash
sudo /usr/share/logstash/bin/logstash --path.settings /etc/logstash \
  -w 1 -r -f mstats2026.conf
```

The target Elasticsearch index is `mstats2026`. The current `cdeath/web/cod.rb`
continues to use `health` until its search queries are migrated separately.
