# Public URL parameter conventions

English | [日本語](URL_PARAMETERS_ja.md)

Graph-page URLs preserve the selected state so that a graph can be shared and
reproduced. `cod.rb` and `mortyear.rb` use the following canonical forms for
multi-value cause and age parameters.

## General rules

- Store one logical selection in one parameter whenever the page defines a
  compact representation for it.
- Separate non-contiguous values with `~`.
- Compress contiguous years or age bands into an inclusive range.
- Keep readers compatible with older repeated parameters, but generate the
  canonical compact form when the form is submitted.

## Causes

Use one `death_codes` parameter and join multiple codes with `~`.

```text
death_codes=infant~perm
death_codes=04000~05000~06000
```

`mortyear.rb` also accepts older URLs containing repeated `death_codes`
parameters, but rewrites a submitted selection in the form above.

## Ages

Five-year age-band keys use an underscore inside a single band. Separate
non-contiguous bands with `~`.

```text
ages=00_04
ages=00_04~10_14
```

Compress contiguous bands by writing the lower bound of the first band and the
upper bound of the last band.

```text
ages=00-09       # 00_04 and 05_09
ages=00-99       # 00_04 through 95_99
ages=80-100plus  # 80_84 through 100plus
```

Use `ages=all` for all ages and `ages=0` for age zero alone. Influenza-year
views use their source bands, such as `ages=00-14~15-64`.

For compatibility, `mortyear.rb` also accepts repeated legacy fields such as
`age=age_00_04&age=age_05_09`. Submitting the form generates `ages=00-09`.

## Years

Pages that allow multiple individual years use the same separator and range
rules.

```text
years=2021-2025
years=2019~2021-2025
```

These are URL representations, not Elasticsearch document-ID components.
