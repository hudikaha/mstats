# WEB_TESTS

`mstats`の物理index切替前後に、保守対象Web pageの入力復元、系列、描画を確認する。
実行条件の正本は`web-tests.json`とし、この文書は検査意図と手動操作を一覧にする。

## 検査層

| 層 | 対象 | 判定 |
|---|---:|---|
| HTTP・HTML | 32 URL | HTTP成功、完全なHTML、Vega data、期待文字列 |
| 描画後DOM | 32 URL | loading終了、Vega描画、選択control、期待表示 |
| 操作 | 下表で操作を指定した代表例 | URL更新、control連動、再描画、再読込み復元 |
| 目視 | 代表8 URL | screenshotで線、帯、panel、軸、余白、文字切れを確認 |

## mortyear2.rb

| ID | 検査概要 | URL | 操作 |
|---|---|---|---|
| MY01 | 日本女性ASR。人口動態全死因、癌死亡4系列、癌罹患4系列の同時表示 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=female&ages=all&dcodes=allcause%7Eallcancer%7Ec53-c55%7Ec54%7Ec53&include_incidence=1&c=jpn) | tooltipを確認。「罹患も表示」を解除し9系列から5系列になることを確認 |
| MY02 | 日本全年齢死亡数。確定値と概数の接続 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=1999&mode=series&period=calendar&metric=deaths&sex=both&ages=all&dcodes=allcause&c=jpn) | 開く |
| MY03 | 日本女性20–24歳。年齢URL復元 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=female&ages=20-24&dcodes=allcause&c=jpn) | 再読込み後も20–24歳の選択が残ることを確認 |
| MY04 | 日本男性全年齢ASR。2015年人口モデル | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=male&ages=all&dcodes=allcause&c=jpn) | 開く |
| MY05 | 複数国の暦年ASRと国別panel | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=asr&sex=both&ages=all&c=jpn%7Edeu%7Efra%7Egbr%7Eusa) | 国を一つ解除・再選択しpanelとURLが連動することを確認 |
| MY06 | 複数国の0歳人口当たり死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=crude_rate&sex=both&ages=0&c=jpn%7Edeu%7Efra%7Egbr%7Eusa) | 開く |
| MY07 | 各国公式値が乏しい地域のWPP系列 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=crude_rate&sex=both&ages=all&c=afg%7Ebra%7Eind%7Enga) | 開く |
| MY08 | 第27週開始インフルエンザ年ASR。ENGを含むSTMF地域 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2018&start_year=2000&mode=country&period=flu27&metric=asr&sex=both&ages=all&c=jpn%7Eswe%7Eeng%7Eusa) | 暦年へ切替え、ENG/GBR変換と学習終了年を確認 |
| MY09 | 第36週開始インフルエンザ年ASR | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2018&start_year=2000&mode=country&period=flu36&metric=asr&sex=both&ages=all&c=jpn%7Eswe%7Eeng%7Eusa) | 開く |
| MY10 | インフルエンザ年65–74歳粗死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2018&start_year=2000&mode=country&period=flu27&metric=crude_rate&sex=both&ages=65-74&c=jpn%7Eswe%7Eeng%7Eusa) | 週次・月次表示を切替え、再読込み後も状態が一致することを確認 |
| MY11 | 日本・米国の乳児死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=birth_rate&dcodes=infant&c=jpn%7Eusa) | 年齢menuが消え、出生関連症例と対応国だけになることを確認 |
| MY12 | 米国の乳児・周産期死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=birth_rate&dcodes=infant%7Eperm&c=usa) | 乳児・周産期の二系列を確認 |
| MY13 | 日本・米国の周産期死亡率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=country&period=calendar&metric=birth_rate&dcodes=perm&c=jpn%7Eusa) | 対応しない国が選択肢から除かれることを確認 |
| MY14 | 癌死亡4部位 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=female&ages=all&dcodes=allcancer%7Ec53-c55%7Ec54%7Ec53&c=jpn) | 開く |
| MY15 | 癌死亡・罹患の追加と解除 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=female&ages=all&dcodes=allcancer%7Ec53-c55%7Ec54%7Ec53&include_incidence=1&c=jpn) | 「罹患も表示」を切替える |
| MY16 | 男性の全部位癌死亡・罹患 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=asr&sex=male&ages=all&dcodes=allcancer&include_incidence=1&c=jpn) | 開く |
| MY17 | 女性子宮頸癌の粗死亡率・粗罹患率 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=female&ages=all&dcodes=c53&include_incidence=1&c=jpn) | 開く |
| MY18 | 75歳以上の詳細年齢範囲と`age_75plus` | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=both&ages=75-100plus&dcodes=allcause&c=jpn) | slider・checkbox・URLが75歳以上を復元することを確認 |
| MY19 | Poisson近似区間 | [開く](https://medicalfacts.info/mortyear2.rb?l=ja&train_to=2019&start_year=2000&mode=series&period=calendar&metric=crude_rate&sex=both&ages=all&dcodes=allcause&chart_model=poisson&interval=analytic&c=jpn) | 準PoissonとPoissonを切替え、帯色とsimulation controlを確認 |
| MY20 | 英語、準Poisson、canonical小文字URL | [開く](https://medicalfacts.info/mortyear2.rb?l=en&train_to=2019&start_year=2000&mode=country&period=calendar&metric=asr&sex=both&ages=all&chart_model=quasi_poisson&c=jpn%7Eswe%7Eusa) | 日本語へ切替えてURLと表示を確認 |

## mort2.rb

| ID | 検査概要 | URL | 操作 |
|---|---|---|---|
| MO01 | 年代別死亡統計の標準表示 | [開く](https://medicalfacts.info/mort2.rb?l=ja) | 開く |
| MO02 | 日本、全死因、女性、75–84歳 | [開く](https://medicalfacts.info/mort2.rb?l=ja&c=jpn&dcodes=allcause&sexes=female&ages=age_75_84) | 選択状態を確認 |
| MO03 | 複数地域選択と系列分離 | [開く](https://medicalfacts.info/mort2.rb?l=ja&c=jpn%7Eswe&dcodes=allcause&ages=age_all) | 地域を解除・再選択 |
| MO04 | 英語表示 | [開く](https://medicalfacts.info/mort2.rb?l=en&c=jpn&dcodes=allcause&ages=age_all) | 開く |

## cod2.rb

| ID | 検査概要 | URL | 操作 |
|---|---|---|---|
| CO01 | 日本月次死因pageの標準表示 | [開く](https://medicalfacts.info/cod2.rb?l=ja) | 開く |
| CO02 | 大分類上位10死因、2020年差、複数panel | [開く](https://medicalfacts.info/cod2.rb?l=ja&years=2021-2025&ages=all&sex=both&graph_type=yearly_diff_2020&top=dai10&columns=3&death_codes=04000%7E05000%7E06000%7E09000%7E10000%7E11000%7E14000%7E18000%7E20000%7E22000&scale=individual&adjustment=none&regression=2020) | 開く |
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

- HTTP・HTML 32件: 170.79秒、平均5.34秒、最長MY04 10.88秒。
- 描画後DOM 32件: 166.90秒、平均5.22秒、最長MY05 10.49秒。
- UI操作 8件: 78.63秒、平均9.83秒、最長MY20 15.18秒。
- 代表screenshot 8件: 55.46秒、平均6.93秒、最長MY01 14.05秒。8件を目視確認済み。
- CSVからのcatalog生成: 104秒、9 CSV、239地域、55,836系列。
- 正式名・alias切替前のHTTP・HTML 32件: 142.71秒、平均4.46秒、全件合格。
- 正式名・alias切替前の描画後DOM 32件: 144.42秒、平均4.51秒、全件合格。
- alias切替後のHTTP・HTML 32件: 137.69秒、平均4.30秒、全件合格。
- alias切替後の代表DOM 8件: 39.57秒、平均4.95秒、全件合格。

正式名は`ruby cdeath/bin/test-web.rb --formal`および
`node cdeath/bin/test-web-dom.js --formal`で、同じ検査定義を使う。
