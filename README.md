# mstats

English | [日本語](README_ja.md)

`mstats` is a repository for medical statistics. It retrieves and analyzes
statistics published by governments and other organizations and, when needed,
reprocesses them into consistent formats. The results are presented as graphs
and other forms at [medicalfacts.info](https://medicalfacts.info/) and are also
provided as a RESTful API through Elasticsearch. The repository contains Ruby
CGI pages, shared presentation code, data converters, Elasticsearch mappings,
Logstash templates, and maintenance documentation.

## Layout

```text
bin/       Repository maintenance utilities
cdeath/    Cause-of-death and population processing and web applications
lib/       Shared menu, page layout, QR, and Elasticsearch helpers
vdeath/    Vaccination/death analyses and KCOR
web/       Other maintained CGI pages and converted static content
docs/      Repository-wide architecture, data, and security notes
```

Component documentation is available in
[`cdeath/README.md`](cdeath/README.md), [Data](docs/DATA.md), and
[`vdeath/docs/KCOR.md`](vdeath/docs/KCOR.md).

## Web applications

The shared menu is defined in [`lib/menu.yml`](lib/menu.yml).
[`lib/mfacts.rb`](lib/mfacts.rb) renders the common menu, title, QR code, and
Elasticsearch helpers. Individual Ruby pages provide their queries,
transformations, and Vega-Lite specifications.

Example file deployment:

```sh
scp lib/mfacts.rb fujikawa.org:fujikawa/covid19/lib/mfacts.rb
scp web/example.rb fujikawa.org:fujikawa/covid19/example.rb
```

## Data

Published data is divided into formats according to purpose:

- `mstats`: mortality and population by country or area, month or week, cause, sex, and age group
- `kcor`: weekly cumulative deaths after a cutoff for cohorts defined by dose count at that cutoff
- `vdeath`: people, person-days, deaths, and mortality by municipality, period, age group, and dose count
- `afterdose`: person-time and deaths by week since vaccination

`mstats`, `kcor`, and `vdeath` can be queried through the
[public Elasticsearch API](docs/ELASTICSEARCH_API.md). See [Data formats](docs/DATA.md)
for record meanings, CSV fields, time and age conventions, and anonymization.

## Security

Never commit passwords, tokens, private source credentials, `.env` files, or
machine-specific Logstash configurations. Code must obtain secrets from an
external file or environment variable. See [Security](docs/SECURITY.md).

## License

This software is available under the [MIT License](LICENSE).

## Documentation

- [Documentation index](docs/README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Data formats](docs/DATA.md)
- [Security](docs/SECURITY.md)

## Text and comments

Text files use UTF-8 without a BOM, LF line endings, and a final newline. Ruby
comments for non-obvious maintenance boundaries are bilingual: Japanese first,
followed by English. Short comments may contain both languages on one line.
