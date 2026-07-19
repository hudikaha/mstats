# mstats

English | [日本語](README_ja.md)

`mstats` is the source repository for mortality, cause-of-death, population,
vaccination, and related statistical visualizations published at
[medicalfacts.info](https://medicalfacts.info/). It contains Ruby CGI pages,
shared presentation code, data converters, Elasticsearch mappings, Logstash
templates, and maintenance documentation.

Source datasets, generated cumulative CSV files, credentials, and local
Logstash configurations are not stored in this repository. They remain outside
Git and are connected through local paths, environment variables, or symbolic
links.

## Layout

```text
bin/       Repository maintenance utilities
cdeath/    Cause-of-death and population processing and web applications
lib/       Shared menu, page layout, QR, and Elasticsearch helpers
vdeath/    Vaccination/death analyses and KCOR
web/       Other maintained CGI pages and converted static content
docs/      Repository-wide architecture, data, and security notes
data       Local symbolic link to an external data directory
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

Large datasets are not committed. The local `data` entry points to
`~/work/mstats/data`; other source directories are also connected without
copying their contents into Git. `cdeath/Makefile` provides fetch, validation,
conversion, upload, and one-shot Logstash targets.

The common cause-of-death and population schema is called **mstats2026**. KCOR
uses a separate `kcor2025` index because its document structure and query model
differ from mstats2026.

## Security

Never commit passwords, tokens, private source credentials, `.env` files, or
machine-specific Logstash configurations. Code must obtain secrets from an
external file or environment variable. See [Security](docs/SECURITY.md).

## License

This software is available under the [MIT License](LICENSE).

## Documentation

- [Documentation index](docs/README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Data](docs/DATA.md)
- [Security](docs/SECURITY.md)

## Text and comments

Text files use UTF-8 without a BOM, LF line endings, and a final newline. Ruby
comments for non-obvious maintenance boundaries are bilingual: Japanese first,
followed by English. Short comments may contain both languages on one line.

## History

This repository is a clean successor to the private historical `mstats2025`
repository. Historical Git data and the former `old/` directory were
intentionally not imported.
