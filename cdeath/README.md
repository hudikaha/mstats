# cdeath

Cause-of-death and all-cause mortality data processing and web pages.

## Current layout

```text
cdeath/
├── web/                 CGI web pages
├── import/              Source CSV converters
├── src/                 Links to external source-data directories
├── out/                 Link to the external generated-data directory
├── config/logstash/     Elasticsearch import settings
└── docs/                Data model and migration notes
```

CSV files are not stored below this repository. Source and generated CSV paths
must point to external data directories.

## Routine update

Population, cause-of-death, and STMF source CSVs are read through links below
`src/`. Generated CSVs are written through the `out` link. Run either
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
new timestamped `mstats2026` CSVs only when local source files changed. The
cause converter reads the source files once and creates separate monthly and
weekly outputs in the same run. The latest cumulative files are then uploaded
and Logstash is run once. `make all` performs both steps. Progress summaries
are printed normally; command logs are kept below `tmp/make` and printed only
when that command fails.

Useful separate stages are `make fetch`, `make fetch-pop`, `make fetch-death`,
`make check`, `make csv`, `make upload`, and `make logstash`. Override
`POP_ARCHIVE_DIR`, `DATA_DIR`, or `SERVER` on the command line when the local
layout differs.

`make csv` creates separate monthly and weekly cause-of-death files together.
The weekly file contains the raw-count, `adj`, and `amr` series used by
`mort.rb`. `make mort-csv` remains available to rebuild only the weekly file
from existing monthly and population outputs.

`make stmf-csv STMF_SOURCE=/path/to/stmf.csv` converts the HMD pooled STMF CSV
to the same canonical weekly format. HMD download credentials and the fetched
source file remain outside this repository.

Store the HMD login as `account:password` in
`~/.config/mstats/hmdpass.txt`, or set `HMD_EMAIL` and `HMD_PASSWORD` outside
the repository. Then run `make fetch-stmf` to download a timestamped pooled
CSV through `src/stmf` and update its local `stmf.csv` link. Override
the file location with `HMD_CREDENTIALS_FILE`. The password is read directly
by Ruby and is not passed in command-line arguments.

Current data links:

```text
cdeath/src/causejp -> ~/work/mstats/causejp
cdeath/src/popjp   -> ~/work/mstats/popjp
cdeath/src/stmf    -> ~/work/mstats/stmf
cdeath/out         -> ~/work/mstats/data
```

## mstats2026 CSV generation

Before import, validate one or more canonical CSV files together. This checks
period fields, duplicate IDs, categories, age values, cause-code systems,
source URLs, and infant-rate/birth-denominator pairs:

```sh
make validate-csv FILES='out/jp-yearly-mstats2026.csv out/us-infant-yearly-mstats2026.csv'
```

Annual records have `year` but neither `yearmonth` nor `yearweek`. Monthly and
weekly consumers explicitly require their own period field, so annual records
in the same Elasticsearch index are not selected by those screens. Generate a
complete-year Japanese file from the latest monthly death and population CSVs
with `make yearly-csv`. Death counts are summed over 12 months; population is a
days-in-month-weighted annual mean; annual rates are recalculated from those two
values. Incomplete years are omitted.

Generate the U.S. annual birth, infant-death, and reconstructed OECD perinatal
records separately with `make us-yearly-csv`. Generate Japanese annual records
with `make jp-yearly-csv` and UN WPP records with `make wpp-yearly-csv`.
Generate approximate infant and perinatal records for other OECD-covered
countries with `make oecd-infant-yearly-csv`; this combines OECD-published rates
with annual births from UN WPP 2024 and does not import the resulting CSV.
The Makefile keeps the rebuild courses separate: `upload-official` /
`logstash-official`, `upload-hmd` / `logstash-hmd`, and `upload-wpp` /
`logstash-wpp`. Every Logstash target requires an explicit physical destination,
whose default is `YEARLY_INDEX=mstats20260814`. After validation, switch the
public logical name atomically with
`make switch-mstats-alias YEARLY_INDEX=mstats20260814`. `mortyear.rb` reads
annual records from Elasticsearch and does not read a Web-local CSV.

Monthly and weekly cause-of-death CSVs in one pass:

```sh
ruby cdeath/import/causejp.rb \
  --population cdeath/out/jp-pop-mstats2026.csv \
  --monthly-out cdeath/out/jp-dcause-mstats2026.csv \
  --weekly-out cdeath/out/jp-dcause-weekly-mstats2026.csv \
  cdeath/src/causejp/*.csv
```

Population CSV:

```sh
ruby cdeath/import/jp-pop.rb cdeath/src/popjp/*.csv \
  > cdeath/out/jp-pop-mstats2026.csv
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

The current physical index is `mstats20260813`. It was created with the mapping in
`config/elasticsearch/mstats20260813-mapping.json`; every `age_*` field uses
`scaled_float` with a scaling factor of 100. Monthly integers and weekly values
rounded to two decimal places can therefore share the same fields. The mapping
keeps dynamic fields enabled and applies the numeric rule through an
`age_*` dynamic template.

The private server configuration `~/mstats/mstats2026.conf` has four inputs for
monthly population, monthly causes, weekly Japanese causes, and weekly STMF
data. Credentials are read from the private credential file when Make invokes
Logstash. The public logical name `mstats` is an alias
for `mstats20260813`.

The server has `/Users -> /home`, so `mstats2026.conf` follows the existing
fixed-path convention and reads `/Users/magician/mstats/*.csv`. Import through
Make, which supplies the private credentials and uses one Logstash worker
because CSV header autodetection is stateful:

```sh
make -C cdeath logstash
```

Logstash writes through the logical `mstats` alias, while
`cdeath/web/cod.rb`, `cdeath/web/codtr.rb`, and `web/mort.rb` query the logical
`mstats` alias through the read-only API.
