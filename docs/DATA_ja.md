# データ形式

[English](DATA.md) | 日本語

このrepositoryで扱うデータは、集計単位の異なる`mstats`、`kcor`、`vdeath`、`afterdose`と、
それらの生成・検証に用いるCSV形式から構成されます。公開APIのquery例は
[Elasticsearch APIの利用方法](ELASTICSEARCH_API_ja.md)を参照してください。

## mstats（公開CSVなし）

`mstats`の1 recordは、ある地域・期間・category・死因・性別・系列について、全年齢または
年齢階級別の値を表します。月次recordは`yearmonth`、週次recordは`yearweek`を持ちます。

| field | 型 | 意味 |
|---|---|---|
| `id` | keyword | recordを一意に識別するID |
| `loc` | keyword | 小文字の地域code。国は原則ISO 3166-1 alpha-3、都道府県は`jp01`～`jp47`、市区町村は`jp13210`など |
| `area` | keyword | 英語の地域名 |
| `areaj` | keyword | 日本語の地域名 |
| `date` | date | 月次は月初、週次は対象週の基準日 |
| `yearmonth` / `yearweek` | keyword | `2009m01` / `2009w02`形式の期間code |
| `year`, `month`, `week` | integer | 暦年、月、週番号。該当しない単位は存在しない |
| `category` | keyword | `death`（死亡）、`incidence`（罹患）、`pop`（人口）など |
| `dcode` | keyword | category内の疾病・死因・指標code。全死因は`allcause` |
| `death_cause` | keyword | 疾病・死因・指標名 |
| `sex` | keyword | `male`、`female`、`both`など |
| `rate` | keyword | 空欄は件数、`crude`は粗死亡率、`asr`は直接法による年齢調整死亡率 |
| `algo` | keyword | 比較・派生系列の計算法。元の値では空欄 |
| `type` | keyword | 必要最小限の系列識別子。`cfm`、`est`、`stmf`、`recon`など |
| `src_url` | keyword配列、非index | そのrecordの作成に使った元dataを示す1個以上のURL |
| `age_all` | scaled_float | 全年齢の値 |
| `age_*` | scaled_float | `age_00_04`、`age_75plus`、`age_80_84`、`age_100plus`などの年齢階級値 |

`age_*`は小数第2位まで保持できる`scaled_float`（scaling factor 100）です。そのため整数の
月次死亡数・人口と、小数を含む週次補正値を同じfieldで扱えます。空欄は0ではなく、元資料に
その区分がないことを表します。

`age_75plus`、`age_85plus`、`age_100plus`は、それぞれ75歳以上、85歳以上、100歳以上を
表します。元資料に上限なし階級がある場合はその値を使い、詳細な重複しない階級だけがある場合は
合計して作成します。人向け表示は`75+`、`85+`、`100+`です。

IDは地域、期間、category、rate、死因、algo、type、性別の正確に8要素を`_`で連結します。
要素内のunderscoreは禁止し、空要素も空の位置として残します。
例えば`jpn_2009w02_death__allcause__stmfrecon_both`は、日本、2009年第2週、全死因、男女計の元系列です。

地域別menuの分類はrecordとは別に管理し、`mstats`には地域区分fieldを格納しません。

日本の実週次`stmf`は、[日本の超過死亡ダッシュボード](https://exdeaths-japan.org/)の
`Observed_weighted`を使用します。全国は`jpn`、都道府県は`jp01`～`jp47`で、全死因、
悪性新生物、循環器系、呼吸器系、老衰、自殺、COVID-19を収録します。COVID-19は同じ地域・週の
全死因からCOVID-19以外を引いた派生値です。独立に補正された値の差が負になる週は、0へ丸めず
欠測として収録しません。同じ週・条件に実週次`stmf`と月次按分の`stmfrecon`がある場合、表示に
必要な年齢fieldを持つ`stmf`を優先し、持たない場合は`stmfrecon`を使います。

全recordが`src_url`を持ちます。派生recordでは死亡数、分母人口、標準人口など複数の資料を
使う場合があるため、元CSVではJSON配列として格納します。Elasticsearchでは非indexの
`keyword`配列で、出典確認・表示のため`_source`には返りますが、検索条件や集計fieldには使えません。

年次recordは`year`を持ち、`yearmonth`と`yearweek`を持ちません。米国年次dataでは、
出生数を`category=birth`の`age_all`、乳児死亡数を全死因
（`dcode=allcause`）死亡recordの`age_0`へ格納します。OECDの周産期死亡指標は
`dcode=perm`を使い、公表された丸め済み率と利用可能な出生分母から逆算した近似件数を
`age_all`へ格納して、`type=recon`とします。`perm`はOECDの指標codeであり、
ICD死因codeではありません。

日本・米国以外のOECD収録国については、OECDの乳児死亡率・周産期死亡率と
UN WPP 2024の同年の出生数から死亡数を逆算します。これらは`type=recon`の近似系列です。
OECDの欠測年は補間しません。丸め済み率と
WPP推計出生数を組み合わせるため、各国公式死亡数による系列より精度が劣ります。

日本の周産期死亡では、分母となる出産数（出生数＋妊娠満22週以後の死産数）を
`category=delivery`の`age_all`へ格納します。`dcode=perm`の公式死亡数はこの分母を使い、
`type=recon`の近似系列は出生数を分母に使います。

国立がん研究センターが公開する年次がん統計は、死亡を`category=death,type=ncc`、
地域がん登録全国推計による罹患を`category=incidence,type=mcij`、全国がん登録による罹患を
`category=incidence,type=ncr`として格納します。`dcode`には`c53`（子宮頸部）、
`c53-c55`（子宮）、`allcancer`（全部位）など、同じcategory内で部位を識別するcodeを使います。
上皮内がんを含む重複系列は収録しません。

年齢調整では、各年の原資料で利用できる最細年齢階級を使います。MCIJの`85+`と、
全国がん登録の`85-89`、`90-94`、`95-99`、`100+`を年別に扱い、粗い階級しかない年は
死亡数または罹患数・人口・標準人口weightを同じ階級へ集約します。

UN World Population Prospects 2024の年次recordは1950～2100年を収録し、由来と状態を
`type=unwpp2024est`、`unwpp2024prj`、`unwpp2024expest`、`unwpp2024expprj`で区別します。
最初の2系列の人口は7月1日人口、`exp`系列は死亡率の分母に使う年間population exposureです。
全死因死亡数は`dcode=allcause`、`rate=crude`は人口10万人当たりです。`rate=asr`はWHO世界標準人口
（2000～2025年世界平均）への直接法による年齢調整死亡率を`age_all`へ格納し、
`algo=whostd`で区別します。WPPの値は国連推計・予測であり、各国が報告した
人口動態登録死亡数ではありません。

### mstats20260816のrecord構成と処理時間

| 区分 | record数 | CSV生成・検査時間 | Elasticsearch投入時間 |
|---|---:|---:|---:|
| 日本・月次死亡 | 83,748 |  |  |
| 日本・月次人口 | 1,890 |  |  |
| 日本・月次按分週次死亡 | 1,860,648 | 上記3系列合計 5分06秒 |  |
| 日本・年次死亡・人口・率 | 27,679 |  |  |
| 日本・乳児死亡 | 100 |  |  |
| 米国・出生関連年次 | 73 |  | 上記6系列合計 約21分38秒 |
| HMD STMF | 406,431 | 上記4系列合計 約28秒 | 約2分14秒 |
| 日本・旧期間確定人口 | 345 |  |  |
| 日本・確定月次死亡 | 125,352 |  |  |
| 日本・確定年次死亡・率 | 22,210 | 上記3系列合計 2分18秒 | 上記3系列合計 約1分55秒 |
| UN WPP | 521,454 | 約57秒 | 約2分52秒 |
| OECD出生関連 | 3,362 | 約2秒 | 約22秒 |
| UN月次死亡 | 81,768 | 約14秒 | 約53秒 |
| 日本・超過死亡dashboard実週次 | 402,750 | 約42秒 | 約2分04秒 |
| **合計** | **3,537,810** | **約9分47秒** | **約31分58秒** |

## kcor / CUMD-WK（公開CSV: [kkcor公開ディレクトリ](https://fujikawa.org/pub/kkcor/) の `*-CUMD-WK.csv.xz`）

`kcor`の1 recordは、cutoff時点の年齢階級・接種回数で固定したcohortについて、cutoff後の
ある週までに発生した累積死亡数を表します。元になるCSVのsuffixは`CUMD-WK`です。

| field | 型 | 意味 |
|---|---|---|
| `id` | keyword | `loc_cutoff_cweek_age_dose`形式の一意なID |
| `loc` | keyword | 地域code。日本の市区町村は`jp`と5桁の標準地域code |
| `area`, `areaj` | keyword | 英語・日本語の自治体名 |
| `cutoff` | date | cohortの年齢と接種回数を固定する日 |
| `cweek` | keyword | 累積値を観測するISO週 |
| `date` | date | `cweek`の日曜日 |
| `age` | keyword | cutoff時点の年齢階級。`00-09`、`80+`など |
| `dose` | integer | cutoff時点の接種回数。`0`は未接種cohort |
| `deaths` | integer | cutoffより後、`date`までの累積死亡数 |
| `pop` | integer | 対象週開始時の観察中cohort人数。算出可能な資料だけに存在 |

`pop`がある系列はcutoff翌週からゼロ死亡週も含むため、`deaths`の前週差から週死亡数を
復元できます。`pop`はcutoff時点で観察中の固定cohortから始まる各週初の観察中人数で、
その週の死亡者と転出者を次週までに差し引きます。したがって自治体の一般人口ではなく、
時間とともに減少する固定cohortの人数です。死亡者資料だけの大阪市には`pop`がありません。

Web applicationは`/elastic/kcor/_search`を検索し、選択したcutoffのrecordを取得します。

## vdeath / PY（国・自治体別の公開CSV: [kkcor公開ディレクトリ](https://fujikawa.org/pub/kkcor/) の `*_PY.csv.xz`）

`PY`の1 recordは、自治体・集計期間・年齢階級・接種回数の組合せにおけるperson-timeと死亡を
表します。`vdeath`の表示に用いる基本形式です。

| field | 型 | 意味 |
|---|---|---|
| `id` | keyword | 自治体、step、period、age、doseから作るID |
| `loc`, `area`, `areaj` | keyword | 地域codeと英語・日本語名 |
| `step` | keyword / integer | `1`、`3`、`6`か月または`all` |
| `period` | keyword | `2024m01`などの期間code |
| `age` | keyword | `00-09`、`80+`、`all`など |
| `dose` | keyword / integer | 接種回数。`vaxx`は1回以上、`all`は全接種回数の合計 |
| `lives` | integer | 期間中にperson-daysを持つ人数 |
| `persondays` | integer | 観察されたperson-daysの合計 |
| `deaths` | integer | 期間中の死亡数 |
| `rr0` | number | 同じ期間・年齢のdose 0に対する死亡率比 |
| `lb0`, `ub0` | number | `rr0`の95%信頼区間 |
| `mortality` | number | 10万人年当たり死亡率 |
| `lbm`, `ubm` | number | `mortality`の95%信頼区間 |

年齢は各期間中の年齢で判定し、誕生日を跨ぐperson-daysは前後の年齢階級へ分割します。

公開`vdeath`には生成元の異なる2系列があります。通常の`1`、`3`、`6`、`all`、`week`は
誰でも再現できる系列です。日本では公開した週単位匿名化`IND-WKA` CSVを再入力して計算し、
チェコでは政府公式個票から直接計算します。`org1`、`org3`、`org6`、`orgall`、`orgweek`は、
非公開の日単位情報開示個票から直接計算した比較系列です。

## afterdose / PY-WKD（公開CSVなし。表示はElasticsearch）

`PY-WKD`は`PY`と同じfieldを持ちますが、`step=week`、`period=W01`〜`W99`です。各接種状態の
開始日を0日として、接種後第何週にperson-timeと死亡が発生したかを表します。次の接種、死亡、
転出または観察終了で、その接種状態のperson-timeは終了します。

## IND-WKA / DTH-WKA（公開CSV: [kkcor公開ディレクトリ](https://fujikawa.org/pub/kkcor/)、日本語名は[日本語ディレクトリ](https://fujikawa.org/pub/kkcor/ja/)）

`IND-WKA`は個人単位の匿名化CSVです。死亡者だけを含む資料には`DTH-WKA`というsuffixを使います。
実際の個票IDは出力せず、日付はISO週の日曜日へ丸めます。

| field | 意味 |
|---|---|
| `id` | 自治体code、年齢階級、元IDのhashから作る匿名ID |
| `loc`, `area`, `areaj` | 地域codeと名称 |
| `age`, `date_age` | 年齢階級と、その年齢の基準日 |
| `vbirthday` | 年齢または年齢区分からhashで決めた仮想誕生日。実際の誕生日ではない |
| `cweek_in`, `date_in` | 転入のISO週と、その日曜日 |
| `cweek_out`, `date_out` | 転出のISO週と、その日曜日 |
| `cweek_death`, `date_death` | 死亡のISO週と、その日曜日 |
| `dose_final` | 記録された最終接種回数 |
| `cweek_doseN`, `date_doseN` | N回目接種のISO週と、その日曜日 |
| `pharma_doseN` | N回目接種の製品・製造元を正規化した値 |

`vbirthday`は同じ入力とseedでは再現可能です。このCSVを`vdeathp.rb`へ再入力すると、
`vbirthday`を誕生日として使用します。週単位へ丸めた日付を使うため、元個票からの集計と
再入力後の集計には小さな境界差が生じます。

## 欠損値と単位

- 空欄は原資料に値がない、またはそのfieldがrecordに適用されないことを表します。
- `0`は観測値が0であることを表し、空欄とは区別します。
- `date`系fieldは`YYYY-MM-DD`、ISO週は`YYYY-Www`です。
- `deaths`と`lives`は人数、`persondays`は人日、`mortality`は10万人年当たりです。
- APIではElasticsearchの`_id`と、`_source`内の`id`または`doc_id`が併存するdatasetがあります。

正確な現在のmappingはAPIの`_mapping`または`_field_caps`で確認できます。

## 匿名化と検証系列

`IND-WKA`は公開用の週単位匿名化個票です。`vdeathp.rb anonymize`は日付をISO週の日曜日へ丸め、実際の誕生日を公開せず、年齢または年齢区分と個票IDのhashから再現可能な`vbirthday`（仮想誕生日）を生成します。仮想誕生日は実在の誕生日ではなく、同じ入力とseedで再生成する内部基準日です。

公開`IND-WKA` / `DTH-WKA`は非公開の日単位個票CSVから生成した匿名化個票で、ElasticSearchの`indiv` / `indivdth`として公開します。`vdeath.rb`のデフォルト表示は匿名化前の日単位CSVから計算した高精度系列です。sourceオプションで公開`indiv`を再解析した匿名化系列も表示でき、両者を比較できます。

`vdeathp.rb`は`personyear`、`afterdose`、`kcor`、`anonymize`、`excess`のsubcommandを持ち、`import/Makefile`で自治体ごとの`IND-WKA`、`PY`、`PY-WKD`、`CUMD-WK`を生成します。
