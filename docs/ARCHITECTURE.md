# Architecture

English | [日本語](ARCHITECTURE_ja.md)

```text
external source data
        -> Ruby converters and Make targets
        -> timestamped CSV files outside Git
        -> one-shot Logstash imports
        -> Elasticsearch indices
        -> Ruby CGI pages or exported JSON
        -> medicalfacts.info
```

`lib/mfacts.rb` is the shared Ruby layer for the maintained CGI pages. It reads
`lib/menu.yml`, renders the common page structure, and provides authenticated
Elasticsearch request helpers. Page-specific files remain responsible for
queries, transformations, and Vega-Lite specifications.

`cdeath` owns Japanese cause-of-death and population processing. `vdeath` owns
vaccination/death analyses and KCOR. Other maintained pages live under `web`.
Large datasets remain external; symbolic links express local relationships
without copying those datasets into Git.
