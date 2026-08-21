# WEB_TESTS

`mstats`の物理index切替前後に、保守対象Web pageの入力復元、系列、描画を確認する。
実行条件の正本は`web-tests.json`とし、この文書は検査意図と手動操作を一覧にする。
複数値の区切り`~`は、文書、検査定義、AIによる実行のいずれでも`%7E`へ変換せず、そのまま保持する。
shellではURL全体をsingle quoteで囲むか、必要な文字だけをescapeして扱う。

## 検査設計の意図

検査URLは、機能を一つずつ孤立させるのではなく、同じ入力で複数のdata経路を通すように選ぶ。
index移行で起きやすいfield名、ID、`type`、`dcode`、`sex`、年齢field、人口recordの不整合を、
表示結果の欠落・混入・期間切断として検出するためである。

特に`mortyear`の癌統合検査は、次の考え方で組み立てる。

- 全死因、全部位癌、女性特有癌、男性特有癌を同時に選び、人口動態死亡と癌死亡を一度に読む。
- 「罹患も表示」を有効にし、死亡と罹患、MCIJの2015年までとNCRの2016年以後を同時に読む。
- 実死亡数、粗死亡率、年齢調整死亡率を変え、母数なし、人口record、年齢階級別死亡・人口recordの3経路を通す。
- 男女、男性、女性を変え、`both`、明示的な性別、性特有癌から全体表示への補完、非該当系列の除外を調べる。
- 男女の性特有癌の率では、反対の性を含む母数であることがtitleに明示されるかも調べる。

このためMY21–MY29は、同じ死因・罹患選択を保ったまま、指標3種類×性別3種類だけを変える
直交した9 URLとする。単に9 pageが開くことではなく、次を一組として判定する。

| 検査軸 | 選択 | 検出する不整合 |
|---|---|---|
| 指標 | 実死亡数 | 死亡・罹患recordの値、死因分類、MCIJ/NCRの接続 |
| 指標 | 粗死亡率 | 死亡・罹患recordと選択性別の人口recordとの結合 |
| 指標 | 年齢調整死亡率 | 年齢階級別の死亡・罹患・人口、標準人口による計算 |
| 性別 | 男女 | `both`と、性特有系列から全体表示への補完。titleには性別を付けない |
| 性別 | 男性 | 男性人口、男性title、前立腺癌、女性特有癌の非表示 |
| 性別 | 女性 | 女性人口、女性title、子宮頸癌、男性特有癌の非表示 |
| source境界 | 2015/2016 | MCIJ最終年とNCR開始年が切れず、2016年以後だけにもならないこと |

## mstatsを読むWeb pageと役割

同じ`web-tests.json`を、開発名では`*2.rb`、正式名では`*.rb`へ適用する。
これにより、検査内容を移植時に書き換えて合格させてしまうことを防ぐ。

| 開発名 → 正式名 | ID | 主に検査するもの |
|---|---|---|
| `mortyear2.rb` → `mortyear.rb` | MY01–MY30 | 年次・週次・月次、各国比較、出生関連、癌死亡・罹患、回帰区間、URL/GUI復元 |
| `mort2.rb` → `mort.rb` | MO01–MO07 | STMF長期系列、日本・海外の超過死亡、地域・性別・年齢・死因によるID検索と系列分離 |
| `cod2.rb` → `cod.rb` | CO01–CO05 | 日本月次死因、年齢field、人口当たり、2015年標準人口換算、複数panel |
| `codtr2.rb` → `codtr.rb` | CT01–CT03 | 日本死因長期推移、性別・年齢選択、入力復元 |

### 各pageで残す代表的な検査理由

| ID群 | この検査を残す理由 |
|---|---|
| MY01–MY04 | 日本の確定値・概数、性別、任意年齢、ASRの基本経路を確認する |
| MY05–MY07 | 各国公式値、UN WPP補完、複数国panel、0歳人口を確認する |
| MY08–MY10 | STMFから暦年・インフルエンザ年を作る経路と週次・月次表示を確認する |
| MY11–MY13 | 出生数を母数とする乳児・周産期系列と、対応国によるmenu制限を確認する |
| MY14–MY17 | 癌menuと「罹患も表示」の手動操作を少数系列で確認する |
| MY18–MY20 | `age_75plus`、Poisson表示、英語/canonical URLを確認する |
| MY21–MY29 | 癌統合表示を指標3種類×性別3種類で系統的に確認する |
| MY30 | Farrington型の固定基準2種・移動基準と、観測・超過推移・累積の3段表示を確認する |
| MO01–MO07 | 日本・海外の観測値と超過死亡3指標、複数地域、年齢・性別・死因、日英表示を確認する |
| CO01–CO05 | `cod`固有の月次集計、年齢URL復元、人口・標準人口計算を確認する |
| CT01–CT03 | `codtr`固有の長期系列と、性別・年齢checkboxの復元を確認する |

## index移行時の実行順

1. `*2.rb`をloopback Elasticsearchと移行先の物理index名で実行し、CGIが完全なHTMLを返すことを確認する。
2. 開発名のHTTP・HTML検査、描画後DOM検査、代表操作・目視検査を行う。
3. 合格した同じfileを正式名へ反映する。検査のために正式版だけ別実装にしない。
4. 正式名へ同じ検査定義を`--formal`で適用し、現行aliasで回帰がないことを確認する。
5. `mstats` aliasを新しい物理indexへ切り替える。
6. 正式名のHTTP・HTML検査を再実行し、代表DOMと目視を確認する。

`*2.rb`のlocal検査では、公開host名を物理index名として扱わない。Elasticsearch接続はloopback、
検索対象は明示した物理indexとし、Web server用credentialの読取り可否をCGI本体の不具合と混同しない。

## 検査層

| 層 | 対象 | 判定 |
|---|---:|---|
| HTTP・HTML | 45 URL | HTTP成功、完全なHTML、Vega data、期待文字列 |
| 描画後DOM | 45 URL | loading終了、Vega描画、選択control、期待表示 |
| 操作 | 下表で操作を指定した代表例 | URL更新、control連動、再描画、再読込み復元 |
| 目視 | 代表8 URL | screenshotで線、帯、panel、軸、余白、文字切れを確認 |

## mortyear2.rb

| ID | 検査概要 | URL | 操作 |
|---|---|---|---|
| MY01 | 日本女性ASR。人口動態全死因、癌死亡4系列、癌罹患4系列の同時表示 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=female&ages=all&dcodes=allcause~allcancer~c53-c55~c54~c53&include_incidence=1&c=jpn) | tooltipを確認。「罹患も表示」を解除し9系列から5系列になることを確認 |
| MY02 | 日本全年齢死亡数。確定値と概数の接続 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=1999&mode=series&period=calendar&metric=deaths&sex=both&ages=all&dcodes=allcause&c=jpn) | 開く |
| MY03 | 日本女性20–24歳。年齢URL復元 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=female&ages=20-24&dcodes=allcause&c=jpn) | 再読込み後も20–24歳の選択が残ることを確認 |
| MY04 | 日本男性全年齢ASR。2015年人口モデル | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=male&ages=all&dcodes=allcause&c=jpn) | 開く |
| MY05 | 複数国の暦年ASRと国別panel | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=asr&sex=both&ages=all&c=jpn~deu~fra~gbr~usa) | 国を一つ解除・再選択しpanelとURLが連動することを確認 |
| MY06 | 複数国の0歳人口当たり死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=crude_rate&sex=both&ages=0&c=jpn~deu~fra~gbr~usa) | 開く |
| MY07 | 各国公式値が乏しい地域のWPP系列 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=crude_rate&sex=both&ages=all&c=afg~bra~ind~nga) | 開く |
| MY08 | 第27週開始インフルエンザ年ASR。ENGを含むSTMF地域 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2018&start_year=2000&mode=country&period=flu27&metric=asr&sex=both&ages=all&c=jpn~swe~eng~usa) | 暦年へ切替え、ENG/GBR変換と学習終了年を確認 |
| MY09 | 第36週開始インフルエンザ年ASR | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2018&start_year=2000&mode=country&period=flu36&metric=asr&sex=both&ages=all&c=jpn~swe~eng~usa) | 開く |
| MY10 | インフルエンザ年65–74歳粗死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2018&start_year=2000&mode=country&period=flu27&metric=crude_rate&sex=both&ages=65-74&c=jpn~swe~eng~usa) | 週次・月次表示を切替え、再読込み後も状態が一致することを確認 |
| MY11 | 日本・米国の乳児死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=birth_rate&dcodes=infant&c=jpn~usa) | 年齢menuが消え、出生関連症例と対応国だけになることを確認 |
| MY12 | 米国の乳児・周産期死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=birth_rate&dcodes=infant~perm&c=usa) | 乳児・周産期の二系列を確認 |
| MY13 | 日本・米国の周産期死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=birth_rate&dcodes=perm&c=jpn~usa) | 対応しない国が選択肢から除かれることを確認 |
| MY14 | 癌死亡4部位 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=female&ages=all&dcodes=allcancer~c53-c55~c54~c53&c=jpn) | 開く |
| MY15 | 癌死亡・罹患の追加と解除 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=female&ages=all&dcodes=allcancer~c53-c55~c54~c53&include_incidence=1&c=jpn) | 「罹患も表示」を切替える |
| MY16 | 男性の全部位癌死亡・罹患 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=male&ages=all&dcodes=allcancer&include_incidence=1&c=jpn) | 開く |
| MY17 | 女性子宮頸癌の粗死亡率・粗罹患率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=female&ages=all&dcodes=c53&include_incidence=1&c=jpn) | 開く |
| MY18 | 75歳以上の詳細年齢範囲と`age_75plus` | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=both&ages=75-100plus&dcodes=allcause&c=jpn) | slider・checkbox・URLが75歳以上を復元することを確認 |
| MY19 | Poisson近似区間 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=both&ages=all&dcodes=allcause&chart_model=poisson&interval=analytic&c=jpn) | 準PoissonとPoissonを切替え、帯色とsimulation controlを確認 |
| MY20 | 英語、準Poisson、canonical小文字URL | [開く](https://medicalfacts.info/mortyear2.rb?l=en&train_to=2019&start_year=2000&mode=country&period=calendar&metric=asr&sex=both&ages=all&chart_model=quasi_poisson&c=jpn~swe~usa) | 日本語へ切替えてURLと表示を確認 |
| MY21 | 死亡数・男女 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=deaths&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 性特有癌の全体表示への補完と罹患接続を確認 |
| MY22 | 死亡数・男性 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=deaths&sex=male&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 前立腺癌を表示し、子宮頸癌を表示しないことを確認 |
| MY23 | 死亡数・女性 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=deaths&sex=female&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 子宮頸癌を表示し、前立腺癌を表示しないことを確認 |
| MY24 | 粗死亡率・男女 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 性特有癌の全体表示への補完と粗罹患率を確認 |
| MY25 | 粗死亡率・男性 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=male&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 男性人口を分母とする率と非該当系列の除外を確認 |
| MY26 | 粗死亡率・女性 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=female&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 女性人口を分母とする率と非該当系列の除外を確認 |
| MY27 | 年齢調整死亡率・男女 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 性特有癌の全体表示への補完と年齢調整罹患率を確認 |
| MY28 | 年齢調整死亡率・男性 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=male&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 男性ASRと非該当系列の除外を確認 |
| MY29 | 年齢調整死亡率・女性 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=female&include_incidence=1&ages=all&dcodes=allcause~allcancer~c53~c61&c=jpn) | 女性ASRと非該当系列の除外を確認 |
| MY30 | 日本Farrington型の3基準と各系列3段表示 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&start_year=2009&mode=series&period=weekly&metric=crude_rate&ages=all&dcodes=allcause&c=jpn&weekly_method=farrington&weekly_baseline=fixed_2015_2019~fixed_2016_2020~rolling) | 3基準が選択され、各基準に観測・超過推移・累積の3段が描かれることを確認 |

## mort2.rb

| ID | 検査概要 | URL | 操作 |
|---|---|---|---|
| MO01 | 日本・海外の観測年間死亡率 | [開く](https://medicalfacts.info/mort2.rb?l=ja&types=death_crude&cmpys=5&cmpto=2019&ages=age_all&sexes=both&c=jpn~swe~eng&dcodes=allcause) | 超過計算前の基礎系列と3地域の分離を確認 |
| MO02 | 日本・海外の年間死亡率の差 | [開く](https://medicalfacts.info/mort2.rb?l=ja&types=death_crude_diff&cmpys=5&cmpto=2019&ages=age_all&sexes=both&c=jpn~swe~eng&dcodes=allcause) | crude rateからの差分計算を確認。空のVega valuesは不合格とする |
| MO03 | 日本・海外の超過死亡率 | [開く](https://medicalfacts.info/mort2.rb?l=ja&types=death_crude_excess&cmpys=5&cmpto=2019&ages=age_all&sexes=both&c=jpn~swe~eng&dcodes=allcause) | crude rateからの超過計算を確認 |
| MO04 | 日本・海外の累積超過死亡率 | [開く](https://medicalfacts.info/mort2.rb?l=ja&types=death_crude_cumuldiff&cmpys=5&cmpto=2019&ages=age_all&sexes=both&c=jpn~swe~eng&dcodes=allcause) | 累積計算と3地域の系列分離を確認 |
| MO05 | 日本・海外の女性65–74歳超過死亡率 | [開く](https://medicalfacts.info/mort2.rb?l=ja&types=death_crude_excess&cmpys=5&cmpto=2019&ages=age_65_74&sexes=female&c=jpn~swe~eng&dcodes=allcause) | 性別・年齢fieldとURL復元を確認 |
| MO06 | 日本女性・卵巣癌の超過死亡率 | [開く](https://medicalfacts.info/mort2.rb?l=ja&types=death_crude_excess&cmpys=5&cmpto=2019&ages=age_all&sexes=female&c=jpn&dcodes=02114) | 日本の死因別record、性別、ID組立てを確認 |
| MO07 | 日本・海外の超過死亡率、英語 | [開く](https://medicalfacts.info/mort2.rb?l=en&types=death_crude_excess&cmpys=5&cmpto=2019&ages=age_all&sexes=both&c=jpn~swe~eng&dcodes=allcause) | 英語titleと地域名を確認 |

MO系列ではHTMLとmenu文字列だけでなく、Vega `values`に1 record以上あることを必須とする。
既定表示開始は比較基準2015–2019年の先頭である2015年とし、元dataの開始年は日本1999年、
スウェーデン2000年、イングランド2010年、最終年は少なくとも2025年まであることを確認する。
検査設計時に、GUI掲載の`types=death__diff`（週間死亡数の差）はVega `values`が空になることを確認した。
さらに、観測record自体は存在するが、`diff5to2019`、`excess5to2019`、`cumuldiff`のalgo recordが
Vega `values`へ入らず、対応するderived graphが空になることを確認した。表示処理の未解決事項として残す。
GUI非掲載の`death__excess`は検査対象外とする。

## cod2.rb

| ID | 検査概要 | URL | 操作 |
|---|---|---|---|
| CO01 | 日本月次死因pageの標準表示 | [開く](https://medicalfacts.info/cod2.rb?l=ja) | 開く |
| CO02 | 大分類上位10死因、2020年差、複数panel | [開く](https://medicalfacts.info/cod2.rb?l=ja&years=2021-2025&ages=all&sex=both&graph_type=yearly_diff_2020&top=dai10&columns=3&death_codes=04000~05000~06000~09000~10000~11000~14000~18000~20000~22000&scale=individual&adjustment=none&regression=2020) | 開く |
| CO03 | 0–4歳だけの死因表示と年齢復元 | [開く](https://medicalfacts.info/cod2.rb?l=ja&years=2024&ages=00_04&sex=both&graph_type=monthly&top=dai10&scale=individual) | 再読込み後も0–4歳だけが選択されることを確認 |
| CO04 | 人口当たり、2015年標準人口換算 | [開く](https://medicalfacts.info/cod2.rb?l=ja&years=2024&ages=all&sex=both&graph_type=monthly&top=dai10&per_capita=true&adjustment=jp2015std) | 開く |
| CO05 | 英語表示 | [開く](https://medicalfacts.info/cod2.rb?l=en&years=2024&ages=all&sex=both&graph_type=monthly&top=dai10) | 開く |

## codtr2.rb

| ID | 検査概要 | URL | 操作 |
|---|---|---|---|
| CT01 | 主要死因長期推移の標準表示 | [開く](https://medicalfacts.info/codtr2.rb?l=ja) | 開く |
| CT02 | 女性、0–4歳の主要死因推移 | [開く](https://medicalfacts.info/codtr2.rb?l=ja&sex=f&00_04=true) | 年齢・性別の選択状態を確認 |
| CT03 | 英語表示 | [開く](https://medicalfacts.info/codtr2.rb?l=en&sex=both&all=on) | 開く |

## 計測記録

以下は32 URLだった時点の移行実測であり、現在の44 URLの所要時間ではない。
現行系列を次のindex移行で一括実行したときに、44 URLの実測へ更新する。

- HTTP・HTML 32件: 170.79秒、平均5.34秒、最長MY04 10.88秒。
- 描画後DOM 32件: 166.90秒、平均5.22秒、最長MY05 10.49秒。
- UI操作 8件: 78.63秒、平均9.83秒、最長MY20 15.18秒。
- 代表screenshot 8件: 55.46秒、平均6.93秒、最長MY01 14.05秒。8件を目視確認済み。
- CSVからのcatalog生成: 104秒、9 CSV、239地域、55,836系列。
- 正式名・alias切替前のHTTP・HTML 32件: 142.71秒、平均4.46秒、全件合格。
- 正式名・alias切替前の描画後DOM 32件: 144.42秒、平均4.51秒、全件合格。
- alias切替後のHTTP・HTML 32件: 137.69秒、平均4.30秒、全件合格。
- alias切替後の代表DOM 8件: 39.57秒、平均4.95秒、全件合格。
- 2026-08-20 公開`mort.rb`の強化後MO01–MO07: 19.73秒、平均2.82秒、最長MO05 3.87秒。
  観測値MO01は合格、derived algoを要求するMO02–MO07は6件不合格。

正式名は`ruby cdeath/bin/test-web.rb --formal`および
`node cdeath/bin/test-web-dom.js --formal`で、同じ検査定義を使う。
