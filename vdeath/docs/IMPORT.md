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
- `anonymize`: anonymous individual records with dates rounded to ISO-week Sundays
- `excess`: annual deaths and age-standardized results, including long-term records without vaccination histories

Common options are `--headers FILE[,FILE...]`, `--output FILE`, `--age-reference DATE`,
`--age-seed-version VERSION`, `--open-age-max AGE`, `--allow-dup-id`,
`--prohibit-reason-in`, and `--report FILE`. When `--age-reference` is omitted, the day after the latest death in all inputs is used.

The program derives a possible birth-date interval from an exact age or age band. It chooses a reproducible imputed birth date using a SHA-256 digest of the municipality code, record ID, source age, and seed version. `personyear` splits person-days at birthdays and assigns deaths to age on the date of death. Imputed birth dates are never exported.

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
