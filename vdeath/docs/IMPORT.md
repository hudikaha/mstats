# Importing vdeath Individual Records

English | [日本語](IMPORT_ja.md)

`import/vdeathp.rb` reads municipal resident, vaccination, and death records through one normalized loader and dispatches processing through subcommands.

```sh
vdeathp.rb personyear [options] INPUT...
vdeathp.rb afterdose  [options] INPUT...
vdeathp.rb kcor      [options] INPUT...
vdeathp.rb anonymize [options] INPUT...
vdeathp.rb excess    [options] INPUT...
```

- `personyear`: person-time by calendar period, age, and dose
- `afterdose`: person-time by week since each dose
- `kcor`: cumulative deaths for cohorts fixed at each cutoff
- `anonymize`: anonymous individual records with entry, exit, death, and dose dates rounded to ISO-week Sundays
- `excess`: annual deaths and age-standardized results, including long-term records without vaccination histories

The public two-pass workflow first runs `anonymize` to create `IND-WKA`, then
runs `personyear` or `afterdose` again using that CSV. These outputs retain the
regular steps (`1`, `3`, `6`, `all`, `week`). Running the aggregation on daily
source records with `--step-prefix org` creates comparison steps such as
`org1` and `orgweek`.

Common options are `--headers FILE[,FILE...]`, `--output FILE`, `--age-reference DATE`,
`--age-seed-version VERSION`, `--open-age-max AGE`, `--allow-dup-id`,
`--prohibit-reason-in`, and `--report FILE`. Use `--iso-week-dates` for source dates
stored as week numbers and `--first-infection-only` when reinfections add rows for the
same person. `--areacode`, `--area`, and `--areaj` supply area metadata when the source
has no corresponding fields. Use `--skip-source-header` when `--headers` remaps a CSV
that also contains its own header row. When `--age-reference` is omitted, the day after the latest death in all inputs is used.
Municipal CSV files without an embedded header require `--headers`. A CSV with its own header row, including `anonymize` output, can be read again without `--headers`.

The program derives a possible birth-date interval from an exact age, age band, or a
birth-year band in the `birth_year` field. It chooses a reproducible virtual birthday
using a SHA-256 digest of the area code, record ID, source age or birth-year band, and
seed version. `anonymize` writes this non-real date as `vbirthday`. When a CSV containing `vbirthday` is read again, that value is used as the birthday and is not regenerated. `personyear` splits person-days at birthdays and assigns deaths to age on the date of death.

Example:

```sh
./vdeathp.rb personyear \
  --headers src/jp132101_example_header.csv \
  --steps 1,3,6,all \
  --ages 00-09,10-19,80+,all \
  --output outputs/jp132101_example_PY.csv \
  src/jp132101_example_all.csv
```

The previous multi-purpose implementation is preserved as `import/vdeathp-20251027.rb`.

`import/Makefile` generates `PY`, `PY-WKD`, `CUMD-WK`, and `IND-WKA` for each municipality. Osaka, whose source contains death records only, produces `CUMD-WK` and `DTH-WKA`.

```sh
cd vdeath/import
make              # all municipalities
make jp132101     # Koganei only
make FORCE=1      # regenerate existing outputs
make cze          # generate vdeath and KCOR from Czech official weekly records
```

The Czech official CSV remains outside Git under `~/work/vdeath-src/Czech`. Its 53
fields are mapped by `import/headers/czech-2024-01.csv`, and the source header row is skipped. Rows for second and later
infections are excluded, and five-year `RokNarozeni` birth-year bands produce virtual
birthdays. Because the source is already weekly, Czech output has no daily-precision
`org*` comparison series.

`*-IND-WKA.csv` and `*-DTH-WKA.csv` are anonymized individual records generated from
private daily individual CSVs. They are published in Elasticsearch as `indiv`
and `indivdth`, respectively. Because their dates are rounded to ISO weeks, these
public datasets support reproducibility and validation but do not retain daily precision.

The default view of [`vdeath.rb`](https://medicalfacts.info/vdeath.rb) is calculated from
the private daily CSVs before anonymization and therefore has higher precision. The
page's `src` option can also display a series recalculated from the public
`indiv` dataset. Death-only records use the
same anonymization format in `indivdth`.
Comparing the two makes the aggregation differences caused by weekly anonymization
visible.

The difference can sometimes be seen directly in the graph. It could be reduced
somewhat by allocating records from weeks crossing a month boundary between the
adjacent months according to the number of days, but that adjustment is not currently
implemented.
