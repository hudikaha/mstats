# Coverage of Japanese mortality data

English | [日本語](JAPAN_MORTALITY_COVERAGE_ja.md)

This table summarizes which period, publication series, age groups, and causes can be used together by `mortyear.rb`, `mort.rb`, `cod.rb`, and `codtr.rb`.

| Period | Years | Source | Age groups | Causes | Age × cause | Main values available |
|---|---:|---|---|---|---|---|
| Annual | 1999 onward | Final Vital Statistics, annual | Yes | Yes | Yes | Deaths, age-specific rates, all-age crude rate, ASR |
| Monthly | 1999–2008 | Final data, month of death × cause | No | Yes | No | All-age cause-specific deaths and crude rates |
| Weekly | 1999–2008 | Reconstructed by day allocation from monthly final data | No | Yes | No | All-age cause-specific deaths and crude rates |
| Monthly | 2009 onward | Final data, month × age × cause | Yes | Yes | Yes | Deaths, age-specific rates, all-age crude rate |
| Weekly | 2009 onward | Reconstructed by day allocation from monthly final data | Yes | Yes | Yes | Deaths, age-specific rates, all-age crude rate |
| Monthly | 2009 onward | Monthly provisional Vital Statistics | Yes | Yes | Yes | Deaths, age-specific rates, all-age crude rate |
| Weekly | 2009 onward | Reconstructed by day allocation from monthly provisional data | Yes | Yes | Yes | Deaths, age-specific rates, all-age crude rate |

Annual final records use “Deaths by sex, five-year age group and abridged cause classification” in [e-Stat Vital Statistics](https://www.e-stat.go.jp/stat-search/files?layout=datalist&toukei=00450011&tstat=000001028897&cycle=7). For 1999–2008, annual values come directly from this annual final table rather than from monthly sums.

ASRs are calculated by direct standardization from annual age-specific deaths and population. In older population tables the oldest ages are grouped as 75-plus or 85-plus. Deaths and standard-population weights are therefore combined to match the published population grouping. ASRs for those years are a coarser approximation than ASRs for years with detailed oldest-age groups. The 75-plus value is only an intermediate ASR input and is not stored as an Elasticsearch field.

Weekly reconstructed values allocate each monthly death count to weeks according to the number of calendar days; they do not reconstruct individual dates of death. STMF supplements weekly all-cause data, while UN monthly deaths supplement only monthly all-age, all-cause data.
