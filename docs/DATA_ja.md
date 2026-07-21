# データ形式

[English](DATA.md) | 日本語

このrepositoryで扱うデータは、集計単位の異なる`mstats`、`kcor`、`vdeath`、`afterdose`と、
それらの生成・検証に用いるCSV形式から構成されます。公開APIのquery例は
[Elasticsearch APIの利用方法](ELASTICSEARCH_API_ja.md)を参照してください。

## mstats

`mstats`の1 recordは、ある地域・期間・category・死因・性別・系列について、全年齢または
年齢階級別の値を表します。月次recordは`yearmonth`、週次recordは`yearweek`を持ちます。

| field | 型 | 意味 |
|---|---|---|
| `id` | keyword | recordを一意に識別するID |
| `loc_code` | keyword | 小文字の地域code。国は原則ISO 3166-1 alpha-3、自治体は`jp132101`など |
| `location` | keyword | 地域名 |
| `date` | date | 月次は月初、週次は対象週の基準日 |
| `yearmonth` / `yearweek` | keyword | `2009m01` / `2009w02`形式の期間code |
| `year`, `month`, `week` | integer | 暦年、月、週番号。該当しない単位は存在しない |
| `category` | keyword | `death`（死亡）または`pop`（人口） |
| `death_code` | keyword | 死因code。全死因は`00000` |
| `death_cause` | keyword | 死因名 |
| `sex` | keyword | `male`、`female`、`both`など |
| `rate` | keyword | 空欄は元の値、`adj`は年齢補正系列、`amr`は年齢調整した年換算死亡率系列 |
| `algo` | keyword | 比較・派生系列の計算法。元の値では空欄 |
| `type` | keyword | 人口系列の区分。`conf`、`est`、`jpns`など |
| `age_all` | scaled_float | 全年齢の値 |
| `age_*` | scaled_float | `age_00_04`、`age_80_84`、`age_100over`などの年齢階級値 |

`age_*`は小数第2位まで保持できる`scaled_float`（scaling factor 100）です。そのため整数の
月次死亡数・人口と、小数を含む週次補正値を同じfieldで扱えます。空欄は0ではなく、元資料に
その区分がないことを表します。

IDは原則として地域、期間、category、rate、死因、algo、type、性別を`_`で連結します。
例えば`jpn_2009w02_death__00000__both`は、日本、2009年第2週、全死因、男女計の元系列です。

## kcor / CUMD-WK

`kcor`の1 recordは、cutoff時点の年齢階級・接種回数で固定したcohortについて、cutoff後の
ある週までに発生した累積死亡数を表します。元になるCSVのsuffixは`CUMD-WK`です。

| field | 型 | 意味 |
|---|---|---|
| `id` | keyword | `areacode_cutoff_cweek_age_dose`形式の一意なID |
| `areacode` | keyword | 自治体code |
| `area`, `areaj` | keyword | 英語・日本語の自治体名 |
| `cutoff` | date | cohortの年齢と接種回数を固定する日 |
| `cweek` | keyword | 累積値を観測するISO週 |
| `date` | date | `cweek`の日曜日 |
| `age` | keyword | cutoff時点の年齢階級。`00-09`、`80+`など |
| `dose` | integer | cutoff時点の接種回数。`0`は未接種cohort |
| `deaths` | integer | cutoffより後、`date`までの累積死亡数 |

Web applicationは`/elastic/kcor/_search`を検索し、選択したcutoffのrecordを取得します。

## vdeath / PY

`PY`の1 recordは、自治体・集計期間・年齢階級・接種回数の組合せにおけるperson-timeと死亡を
表します。`vdeath`の表示に用いる基本形式です。

| field | 型 | 意味 |
|---|---|---|
| `id` | keyword | 自治体、step、period、age、doseから作るID |
| `areacode`, `area`, `areaj` | keyword | 自治体codeと英語・日本語名 |
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

公開index `vdeath2026`には日付精度の異なる2系列があります。通常の`1`、`3`、`6`、
`all`、`week`は、公開した週単位匿名化`IND-WKA` CSVを再入力して計算した系列です。
`org1`、`org3`、`org6`、`orgall`、`orgweek`は日単位の元個票から計算した比較系列です。
各pageは通常系列をdefaultで使い、比較時だけ`org*`を選択します。

## afterdose / PY-WKD

`PY-WKD`は`PY`と同じfieldを持ちますが、`step=week`、`period=W01`〜`W99`です。各接種状態の
開始日を0日として、接種後第何週にperson-timeと死亡が発生したかを表します。次の接種、死亡、
転出または観察終了で、その接種状態のperson-timeは終了します。

## IND-WKA / DTH-WKA

`IND-WKA`は個人単位の匿名化CSVです。死亡者だけを含む資料には`DTH-WKA`というsuffixを使います。
実際の個票IDは出力せず、日付はISO週の日曜日へ丸めます。

| field | 意味 |
|---|---|
| `id` | 自治体code、年齢階級、元IDのhashから作る匿名ID |
| `areacode`, `area`, `areaj` | 自治体codeと名称 |
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
