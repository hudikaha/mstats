# Coverage of Japanese mortality data

English | [日本語](JAPAN_MORTALITY_COVERAGE_ja.md)

This table summarizes which publication series, age groups, and causes in Japan's e-Stat “Vital Statistics” can be used together by `mortyear.rb`, `mort.rb`, `cod.rb`, and `codtr.rb`.

| Years | Source | Table used | Age groups | Causes | Main values available |
|---:|---|---|---|---|---|
| 1999–2008 | [Final data](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053065&tclass4val=0) | Deaths by sex, five-year age group, and abridged cause classification | Yes | Yes | Annual: deaths, age-specific rates, all-age crude rate, and ASR |
| 1999–2008 | [Final data](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053065&tclass4val=0) | Deaths by sex, month of death, and abridged cause classification | No | Yes | Monthly and weekly: all-age cause-specific deaths and crude rates |
| 2009–2024 | [Final data, archived tables](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053074&tclass4=000001053089&tclass5val=0) | Deaths by month of death, sex, five-year age group, and abridged cause classification | Yes | Yes | Annual, monthly, and weekly: deaths, age-specific rates, and all-age crude rates. Annual: ASR |
| 2009–February 2026 | [Monthly provisional data](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0) | Deaths by abridged cause classification, sex, and age (five-year age groups, with school-age regroupings) | Yes | Yes | Annual, monthly, and weekly: deaths, age-specific rates, and all-age crude rates. Annual: ASR |

Weekly values are estimates reconstructed by allocating monthly death counts to weeks according to the number of calendar days. They do not reconstruct individual dates of death.

Where final and provisional data overlap, final data take precedence; provisional data extend the series beyond the last available month of final data. The coverage dates in this table are updated when the data are updated.

Annual final records use “Deaths by sex, five-year age group and abridged cause classification” in [e-Stat final mortality data](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053065&tclass4val=0). For 1999–2008, annual values come directly from this annual final table rather than from monthly sums.

ASRs are calculated by direct standardization from annual age-specific deaths and population. In older population tables the oldest ages are grouped as 75-plus or 85-plus. Deaths and standard-population weights are therefore combined to match the published population grouping. ASRs for those years are a coarser approximation than ASRs for years with detailed oldest-age groups. The 75-plus value is only an intermediate ASR input and is not stored as an Elasticsearch field.

Population data come from [e-Stat “Population Estimates: Population on the First Day of Each Month”](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0). STMF supplements weekly all-cause data, while UN monthly deaths supplement only monthly all-age, all-cause data.
