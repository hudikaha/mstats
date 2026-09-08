# Proposed public URL parameters for morttr.rb

English | [日本語](URL_PARAMETERS_ja.md)

This document proposes the public URL format used to share and reproduce the
same graph in `morttr.rb`. The short canonical names described here have not yet
been implemented in Ruby. The mapping from current URLs is listed under
“Migration from legacy URLs” at the end.

## General rules

- Store one logical selection in one parameter.
- Join multiple values with a literal `~`; it does not need to be escaped as `%7E`.
- Year and age-band ranges are inclusive.
- Write a Boolean parameter as `=1` only when enabled; omit it when disabled.
- Defaults may be omitted from a shared URL when the same graph remains reproducible.
- Ignore parameters that do not apply and remove them the next time the URL is generated.
- If a canonical and legacy name are both present, the canonical name takes precedence.
- Dependencies do not form a single tree, so each table states its own applicability conditions.

## Basic selections

| Parameter | Values | Default | Applicability and meaning |
|---|---|---|---|
| `l` | `ja` | Browser language | Japanese display |
| `l` | `en` | Browser language | English display |
| `mode` | `country` | `country` | Compare multiple countries or regions under one common condition |
| `mode` | `series` | `country` | Compare multiple ages, causes, weekly algorithms, or other series for one country or region |
| `period` | `calendar` | `calendar` | Calendar years from January 1 through December 31 |
| `period` | `flu27` | `calendar` | Influenza years from week 27 through week 26 of the next year |
| `period` | `flu36` | `calendar` | Influenza years from week 36 through week 35 of the next year |
| `period` | `weekly` | `calendar` | Weekly observations, excess/deficit trends, and cumulative values |
| `metric` | `deaths` | Annual: `asr`; weekly: `deaths` | Observed death count |
| `metric` | `std` | Same as above | Death count converted to the selected standard population |
| `metric` | `crude` | Same as above | Crude mortality rate |
| `metric` | `asr` | Same as above | Age-standardized mortality rate |
| `metric` | `birth` | Same as above | Infant, perinatal, or similar mortality rate using births as the denominator |
| `ages` | `all`, `0`, age bands or ranges | `all` | Age selection in the format below |
| `sex` | `both` | `both` | Both sexes; may be omitted from a canonical URL |
| `sex` | `male` | `both` | Male, where a sex-specific series exists |
| `sex` | `female` | `both` | Female, where a sex-specific series exists |
| `c` | Region codes joined with `~` | View-specific locations | Country or region selection |
| `dcodes` | Cause or case codes joined with `~` | All causes | Views that allow cause or case series |
| `inc` | `1` | Disabled (omitted) | Include cancer-incidence series |

`metric=birth` is not separated by sex and treats any supplied `sex` value as
`both`.

### Number of selections by `mode`

`mode` is not a simple parent of the other parameters. The same parameter is
single- or multi-valued according to the unit being compared.

| Selection | `mode=country` | `mode=series` |
|---|---|---|
| `c` | Multiple countries or regions | One country or region |
| `ages`, `dcodes` | Normally one shared condition | May create multiple series |
| `algo`, `ref` | One value each | May contain multiple values joined with `~` |

Available ages, causes, metrics, and locations also depend on the period and
the presence of source data. This table therefore specifies URL cardinality;
it does not force the parameters into a fixed tree.

### Cross-period applicability

| Parameter group | `calendar` | `flu27`, `flu36` | `weekly` |
|---|---|---|---|
| `mode`, `metric`, `ages`, `sex`, `c`, `dcodes` | Used | Used, limited by source data | Used, limited by source data |
| `from` | Used | Used | Used |
| `fit`, `family`, `interval` | Used | Used | Not used |
| `algo`, `ref`, `cum`, `deficit` | Not used | Not used | Used |
| `covid`, `vaxx` | Not used | Not used | Used when their conditions are met |
| `zero` | Used when an applicable graph exists | Used when an applicable graph exists | Used when an applicable graph exists |

`metric`, `ages`, `sex`, and overlay availability also constrain one another.
The applicability entry for each parameter is authoritative for those details.

With no location, metric, or start year specified, the annual view starts in
2000 with age-standardized mortality for Japan, the United Kingdom, Sweden, and
the United States. A URL containing only `period=weekly` starts in 2015 with
weekly death counts for Japan, England, Sweden, and the United States, using the
Farrington-style algorithm and the fixed 2015–2019 reference period.

### Ages and multiple values

Use an underscore inside a single five-year age-band key and `~` between
non-contiguous bands. Compress contiguous bands using the first lower bound and
the last upper bound.

```text
ages=00_04
ages=00_04~10_14
ages=00-09
ages=00-99
ages=80-100plus
```

Use `ages=all` for all ages and `ages=0` for age zero alone. Influenza-year
views use their source bands, for example `ages=00-14~15-64`.

## Display period and prediction calculation

| Parameter | Values | Default | Applicability and meaning |
|---|---|---|---|
| `from` | `YYYY` | Annual: 2000; weekly: 2015 | First year displayed on the X axis |
| `fit` | `YYYY` | Calendar: 2019; influenza year: 2018 | Last training year for annual and influenza-year prediction models |
| `family` | `quasi` | `quasi` | Quasi-Poisson; estimate overdispersion from observations and reflect it in prediction intervals |
| `family` | `poisson` | `quasi` | Poisson; assume that the mean and variance are equal |
| `interval` | `approx` | `sim` | Analytic approximation; used for quasi-Poisson intervals |
| `interval` | `sim` | `sim` | Simulation interval; available with Poisson |

`family` identifies the probability and dispersion assumption, while `interval`
identifies how the interval is calculated. Weekly Farrington-style and
EuroMOMO-style calculations are selected separately with `algo`.

## Weekly reference and accumulation

| Parameter | Values | Default | Applicability and meaning |
|---|---|---|---|
| `algo` | `mean` | `farrington` | Mean and range from the corresponding week in each reference year selected by `ref` |
| `algo` | `farrington` | `farrington` | Farrington-style expected value and prediction interval |
| `algo` | `euromomo` | `farrington` | EuroMOMO-style expected value and prediction interval |
| `ref` | `YYYY-YYYY`, `prevN` | `2015-2019` | Fixed reference years or the preceding N years when `period=weekly` |
| `cum` | `YYYY` | `2021` | First year included in cumulative weekly excess or deficit mortality |
| `deficit` | `1` | Disabled (omitted) | Include negative differences in weekly trends and cumulative values |

`cum` is independent of `ref`, which determines the reference period. For
example, use `ref=2015-2019&cum=2020` to retain the 2015–2019 reference while
accumulating from 2020. Omitting `cum` starts accumulation in 2021.

In addition to an arbitrary fixed period such as `ref=2014-2018`, the planned
reader will accept `ref=prev3` through `ref=prev10`. The menu may expose only
representative presets. The reference length is controlled by `ref` even when
`algo=mean`, so the algorithm name does not contain `5`.

## Controls beside the graph

| Parameter | Values | Default | Applicability and meaning |
|---|---|---|---|
| `zero` | `1` | Disabled (omitted) | Start the applicable Y axis at zero |
| `covid` | `1` | Disabled (omitted) | Overlay COVID-19 deaths for weekly, both-sex, all-age `deaths` or `crude` views; unavailable for `asr` |
| `vaxx` | `1` | Disabled (omitted) | Overlay vaccination data in weekly views where available; allowed with `asr` |

When a view change makes a control temporarily unavailable, its state may be
retained within the page. Canonicalizing a shared URL removes parameters that
do not apply to the current view. The optional detailed weekly/monthly view is
intentionally not persisted in the URL.

## Development and debugging

`calc=ruby|js` selects the Ruby or JavaScript path for comparison during
development. It is not a public control and must not appear in canonical shared
URLs.

## Canonical URL examples

A weekly URL with selections stated explicitly:

```text
morttr.rb?l=ja&mode=country&period=weekly&metric=asr&ages=all&c=jpn~swe~gbr&algo=farrington&ref=prev5&cum=2021&vaxx=1
```

The equivalent compact URL with reproducible defaults omitted:

```text
morttr.rb?l=ja&period=weekly&metric=asr&c=jpn~swe~gbr&ref=prev5&vaxx=1
```

## Migration from legacy URLs

The following legacy names and values remain accepted for input compatibility.
Form submission and shared-URL generation must emit only the canonical form on
the right.

| Legacy form | Canonical form |
|---|---|
| Repeated `age=age_00_04` and similar fields | Combine into `ages=00_04`, using `~` or a range |
| `death_codes` or repeated cause parameters | Combine into one `dcodes` value with `~` |
| `include_incidence=1` | `inc=1` |
| `start_year=YYYY` | `from=YYYY` |
| `train_to=YYYY` | `fit=YYYY` |
| `chart_model=quasi_poisson` | `family=quasi` |
| `chart_model=poisson` | `family=poisson` |
| `interval=analytic` | `interval=approx` |
| `interval=auto` | `interval=sim` |
| `weekly_method=five_year` | `algo=mean` |
| `weekly_method=farrington` | `algo=farrington` |
| `weekly_method=euromomo` | `algo=euromomo` |
| `weekly_baseline=fixed_2015_2019` or `fixed` | `ref=2015-2019` |
| `weekly_baseline=fixed_2016_2020` | `ref=2016-2020` |
| `weekly_baseline=rolling` | `ref=prev5` |
| `include_deficit=1` | `deficit=1` |
| `zero_base=1` | `zero=1` |
| `covid_overlay=1` | `covid=1` |
| `vaxx_overlay=1` | `vaxx=1` |
| `metric=crude_rate` | `metric=crude` |
| `metric=std_deaths` | `metric=std` |
| `metric=birth_rate` | `metric=birth` |
| `sex=both` | Omit `sex` |
