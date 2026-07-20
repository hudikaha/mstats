# Data

English | [日本語](DATA_ja.md)

The repository stores converters and schemas, not source or generated datasets.
Local source paths are documented by each component and may be represented by
symbolic links.

The **mstats2026** format unifies Japanese cause-of-death and population records
in the `mstats2026` Elasticsearch index. Identifiers and location codes use
lowercase canonical forms. Raw counts and populations are stored; derived
per-capita and age-adjusted series are calculated for presentation.

KCOR remains in the separate `kcor2025` index. The browser reads it through the
public `kcor` Elasticsearch alias. See the component documents for field
definitions, source locations, and update procedures.
