# Data formats

English | [日本語](DATA_ja.md)

The data handled by this repository consists of `mstats`, `kcor`, `vdeath`, and
`afterdose`, which use different aggregation units, plus the CSV formats used to
generate and validate them. See [Using the Elasticsearch API](ELASTICSEARCH_API.md)
for public query examples.

## mstats (no public CSV)

One `mstats` record represents values for a location, period, category, cause,
sex, and series, with totals and available age groups. Monthly records contain
`yearmonth`; weekly records contain `yearweek`.

| Field | Type | Meaning |
|---|---|---|
| `id` | keyword | Unique record identifier |
| `loc_code` | keyword | Lowercase location code; normally ISO 3166-1 alpha-3 for countries and codes such as `jp132101` for municipalities |
| `location` | keyword | Location name |
| `world_region` | keyword | Broad UN geographic region, when supplied by an international source |
| `date` | date | First day of a month or the reference date for a week |
| `yearmonth` / `yearweek` | keyword | Period code such as `2009m01` / `2009w02` |
| `year`, `month`, `week` | integer | Calendar year, month, or week number; units that do not apply are absent |
| `category` | keyword | `death` or `pop` |
| `death_code` | keyword | Cause-of-death code; `00000` means all causes |
| `death_cause` | keyword | Cause-of-death name |
| `sex` | keyword | `male`, `female`, `both`, and related source categories |
| `rate` | keyword | Empty for counts, `crude_rate` for crude rates, `asr` for directly age-standardized rates, and legacy values such as `adj` or `amr` |
| `algo` | keyword | Method for a comparative or derived series; empty for source values |
| `type` | keyword | Population-series class such as `conf`, `est`, or `jpns` |
| `age_all` | scaled_float | Value for all ages |
| `age_*` | scaled_float | Age-group value such as `age_00_04`, `age_80_84`, or `age_100over` |

`age_*` fields use `scaled_float` with a scaling factor of 100. Integer monthly
counts and populations can therefore share fields with adjusted weekly values
that have two decimal places. An empty value means that the source does not
provide that group; it does not mean zero.

IDs normally join location, period, category, rate, cause, algorithm, type, and
sex with `_`. For example, `jpn_2009w02_death__00000__both` is the source-value
record for Japan, ISO week 2 of 2009, all causes, and both sexes.

Annual records contain `year` but neither `yearmonth` nor `yearweek`. U.S. annual
birth records store births in `category=birth`, `age_all`. Infant deaths are the
`age_0` value of the all-cause (`death_code=00000`) death record. The OECD
perinatal-mortality indicator uses `death_code=PERM`; its `age_all` value is an
approximate event count reconstructed from the published rounded rate and the
available birth denominator, and is marked `algo=reconstructed`. `PERM` is an
OECD indicator code, not an ICD cause code.

For OECD-covered countries other than Japan and the United States, infant and
perinatal death counts are reconstructed from OECD rates and the matching
annual births in UN WPP 2024. These approximate series use
`algo=reconstructed` and `type=oecd_wpp2024`. Missing OECD years are not
interpolated. Because rounded rates are combined with WPP-estimated births,
these series are less precise than series based on national official counts.

For Japanese perinatal mortality, deliveries (births plus fetal deaths at 22 completed
weeks or later) are stored in `category=delivery`, `age_all`. Official `death_code=PERM`
counts use this denominator, while approximate `algo=reconstructed` series use births.

UN World Population Prospects 2024 annual records use `algo=un_wpp2024` and
cover 1950–2100. Values through 2023 have `type=estimate`; later medium-variant
values have `type=projection_medium`. Population records with those types are
1 July population. Separate `exposure_estimate` and
`exposure_projection_medium` population records contain annual population
exposure and age groups used as mortality-rate denominators. All-cause death
counts use `death_code=00000`; `rate=crude_rate` is per 100,000 population.
`rate=asr` uses direct standardization to the WHO world standard population
(world average for 2000–2025), is stored in `age_all`, and uses
`algo=un_wpp2024_who_standard`. These WPP values are UN estimates and
projections, not reported vital-registration counts.

## kcor / CUMD-WK (public CSV: `*-CUMD-WK.csv.xz` in the [kkcor directory](https://fujikawa.org/pub/kkcor/))

One `kcor` record contains cumulative deaths through a particular week for a
cohort fixed by age group and dose count at the cutoff. Its source CSV suffix is
`CUMD-WK`.

| Field | Type | Meaning |
|---|---|---|
| `id` | keyword | Unique ID in `areacode_cutoff_cweek_age_dose` form |
| `areacode` | keyword | Municipality code |
| `area`, `areaj` | keyword | English and Japanese municipality names |
| `cutoff` | date | Date on which cohort age and dose count are fixed |
| `cweek` | keyword | ISO week at which the cumulative value is observed |
| `date` | date | Sunday ending `cweek` |
| `age` | keyword | Age group at cutoff, such as `00-09` or `80+` |
| `dose` | integer | Dose count at cutoff; `0` is the unvaccinated cohort |
| `deaths` | integer | Cumulative deaths after cutoff and through `date` |
| `pop` | integer | Observed cohort population at the start of the week; present when derivable from the source |

Series with `pop` include zero-death weeks beginning with the week after the cutoff,
so weekly deaths can be recovered from consecutive `deaths` values. `pop` starts
with the cohort observed at the cutoff and is the number still under observation
at the beginning of each week; deaths and move-outs during that week are subtracted
before the following week. It is therefore a decreasing fixed-cohort population,
not the municipality's general population. Osaka has death-only source data and
therefore has no `pop` field.

The web application queries `/elastic/kcor/_search` for the selected cutoff.

## vdeath / PY (no public PY CSV; displayed through Elasticsearch)

One `PY` record represents person-time and deaths for a municipality, aggregation
period, age group, and dose count. It is the basic format used by `vdeath`.

| Field | Type | Meaning |
|---|---|---|
| `id` | keyword | ID built from municipality, step, period, age, and dose |
| `areacode`, `area`, `areaj` | keyword | Municipality code and English/Japanese names |
| `step` | keyword / integer | `1`, `3`, or `6` months, or `all` |
| `period` | keyword | Period code such as `2024m01` |
| `age` | keyword | Age group such as `00-09`, `80+`, or `all` |
| `dose` | keyword / integer | Dose count; `vaxx` combines one or more doses and `all` combines every dose count |
| `lives` | integer | People contributing person-days during the period |
| `persondays` | integer | Total observed person-days |
| `deaths` | integer | Deaths during the period |
| `rr0` | number | Mortality-rate ratio to dose 0 for the same period and age |
| `lb0`, `ub0` | number | 95% confidence interval for `rr0` |
| `mortality` | number | Deaths per 100,000 person-years |
| `lbm`, `ubm` | number | 95% confidence interval for `mortality` |

Age is evaluated within each period. Person-days crossing a virtual birthday
are split between the age groups before and after that date.

The public `vdeath` dataset has two date-precision series. Regular steps
(`1`, `3`, `6`, `all`, and `week`) are calculated by re-reading published
weekly-anonymized `IND-WKA` CSV. `org1`, `org3`, `org6`, `orgall`, and `orgweek`
are comparison calculations from daily source records. The pages use regular
steps by default and select `org*` only for comparison.

## afterdose / PY-WKD (no public CSV; displayed through Elasticsearch)

`PY-WKD` uses the same fields as `PY`, with `step=week` and periods `W01` through
`W99`. It records person-time and deaths by week since the beginning of each dose
state. That state ends at the next dose, death, move out, or observation limit.

## IND-WKA / DTH-WKA (public CSV: [kkcor directory](https://fujikawa.org/pub/kkcor/); Japanese names are in the [Japanese directory](https://fujikawa.org/pub/kkcor/ja/))

`IND-WKA` is an anonymized individual-record CSV. `DTH-WKA` is the suffix used
when the source contains death records only. Original record IDs are not
exported, and event dates are rounded to Sundays ending their ISO weeks.

| Field | Meaning |
|---|---|
| `id` | Anonymous ID derived from municipality, age group, and a hash of the source ID |
| `areacode`, `area`, `areaj` | Municipality code and names |
| `age`, `date_age` | Age group and its reference date |
| `vbirthday` | Hash-selected virtual birthday within the possible age range; not an actual birthday |
| `cweek_in`, `date_in` | ISO week of entry and its Sunday |
| `cweek_out`, `date_out` | ISO week of exit and its Sunday |
| `cweek_death`, `date_death` | ISO week of death and its Sunday |
| `dose_final` | Last recorded dose count |
| `cweek_doseN`, `date_doseN` | ISO week of dose N and its Sunday |
| `pharma_doseN` | Normalized product or manufacturer for dose N |

`vbirthday` is reproducible for the same input and seed. When this CSV is read
again by `vdeathp.rb`, `vbirthday` is used as the birthday. Because event dates
are rounded to weeks, small boundary differences are expected between results
from original records and results after re-import.

## Missing values and units

- Empty means unavailable in the source or not applicable to the record.
- `0` is an observed zero and is distinct from empty.
- Date fields use `YYYY-MM-DD`; ISO weeks use `YYYY-Www`.
- `deaths` and `lives` count people, `persondays` counts person-days, and `mortality` is per 100,000 person-years.
- Some datasets contain both the Elasticsearch `_id` and an `id` or `doc_id` field in `_source`.

Use the API `_mapping` or `_field_caps` endpoint to inspect the exact current mapping.

## Anonymization and comparison series

`IND-WKA` is the published weekly-anonymized individual dataset. `vdeathp.rb anonymize` rounds event dates to ISO-week Sundays and does not publish actual birthdays. It derives a reproducible `vbirthday` from the age or age-group range, source-ID hash, and seed version. This is a virtual birthday, not an actual birthday, and is an internal reference date reproducible from the same input and seed.

Public `IND-WKA` / `DTH-WKA` records are anonymized individual datasets generated
from private daily individual CSVs and published in Elasticsearch as `indiv` /
`indivdth`. The default `vdeath.rb` view is calculated from the private daily CSVs
before anonymization and therefore has higher precision. Its source option can also
display a series recalculated from public `indiv`, allowing the two results to be
compared.

`vdeathp.rb` provides `personyear`, `afterdose`, `kcor`, `anonymize`, and `excess` subcommands. `import/Makefile` generates municipality-level `IND-WKA`, `PY`, `PY-WKD`, and `CUMD-WK` outputs together.
