# Data formats

English | [日本語](DATA_ja.md)

The data handled by this repository consists of `mstats`, `kcor`, `vdeath`, and
`afterdose`, which use different aggregation units, plus the CSV formats used to
generate and validate them. See [Using the Elasticsearch API](ELASTICSEARCH_API.md)
for public query examples.

## mstats

One `mstats` record represents values for a location, period, category, cause,
sex, and series, with totals and available age groups. Monthly records contain
`yearmonth`; weekly records contain `yearweek`.

| Field | Type | Meaning |
|---|---|---|
| `id` | keyword | Unique record identifier |
| `loc_code` | keyword | Lowercase location code; normally ISO 3166-1 alpha-3 for countries and codes such as `jp132101` for municipalities |
| `location` | keyword | Location name |
| `date` | date | First day of a month or the reference date for a week |
| `yearmonth` / `yearweek` | keyword | Period code such as `2009m01` / `2009w02` |
| `year`, `month`, `week` | integer | Calendar year, month, or week number; units that do not apply are absent |
| `category` | keyword | `death` or `pop` |
| `death_code` | keyword | Cause-of-death code; `00000` means all causes |
| `death_cause` | keyword | Cause-of-death name |
| `sex` | keyword | `male`, `female`, `both`, and related source categories |
| `rate` | keyword | Empty for source values, `adj` for age-adjusted series, or `amr` for age-adjusted annualized mortality-rate series |
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

## kcor / CUMD-WK

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

The web application queries `/elastic/kcor/_search` for the selected cutoff.

## vdeath / PY

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

## afterdose / PY-WKD

`PY-WKD` uses the same fields as `PY`, with `step=week` and periods `W01` through
`W99`. It records person-time and deaths by week since the beginning of each dose
state. That state ends at the next dose, death, move out, or observation limit.

## IND-WKA / DTH-WKA

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
