# KCOR

[English](KCOR.md) | 日本語

## 配置

`vdeath`は`cdeath`と同格の分野とし、KCORは`vdeath`内で扱います。

```text
vdeath/
├── web/
│   ├── kcor.rb
│   ├── kcor.js
│   └── kcor.css
├── import/
│   └── vdeathp.rb
└── config/
    ├── elasticsearch/kcor2025-mapping.json
    └── logstash/kcor2025.conf
```

## Elasticsearch

- 実体index名は`kcor2025`、公開・検索用aliasは`kcor`です。
- `kcor.js`は公開API `/elastic/kcor/_search`からcutoff一覧と選択cutoffのrecordを取得します。
- `index.max_result_window`とbrowserの1回のrequest上限は100万件です。
- `mstats2026`とはdocument schemaもindexも統合しません。
- 旧`kkcor` indexは使用しません。
- `CUMD-WK` CSVの10 fieldをすべて保存します。

```text
id, areacode, area, areaj, cutoff, cweek, date, age, dose, deaths
```

`dose`と`deaths`は整数、`cutoff`と`date`は日付、それ以外はkeywordです。
Elasticsearchの`_id`にはCSVの`id`を使用し、`id` fieldも`_source`に残します。
`kcor.rb`は日本の自治体に加えて、`areacode=cze`のチェコ全国系列も同じ形式で表示します。

## Gamma-frailty用週次risk set

`CUMD-WK-G`は特定のKCOR versionによる補正結果ではなく、gamma-frailtyを含むKCOR解析で
共通利用する補正前の週次基礎形式である。`vdeathp.rb kcor --risk-output FILE`は従来の
`CUMD-WK`と同じcohort走査から次のfieldを出力する。

```text
id, areacode, area, areaj, cutoff, cweek, date, age, dose,
cohort_size, at_risk, deaths_week, deaths, censored_week
```

- `cohort_size`: cutoff時点の固定cohort人数
- `at_risk`: 対象週開始時の観察中生存人数
- `deaths_week`: 対象週の死亡数
- `deaths`: cutoff後の累積死亡数
- `censored_week`: 対象週に転出などで観察終了した人数

`theta`、quiet window、補正後hazard、KCOR値は解析versionに依存するため保存しない。
本番dataは完全な元個票から生成する。死亡者だけの`DTH-WKA`からはrisk setを作れない。
`--output`を省略して`--risk-output`だけを指定すれば、G形式だけを生成できる。

## 単純gamma-frailty fitting

`import/kcor_gamma.rb`は`CUMD-WK-G`を読み、area・cutoff・age・doseごとに
constant-baseline gamma-frailty modelをquiet windowへ非線形最小二乗fittingする。
[`kcorg.rb`](https://medicalfacts.info/kcorg.rb)は推定した`theta`でgamma inversionを行い、
初期表示では累積死亡人数と、fit終了週を選ぶquiet window sliderを表示する。表示とは独立して、
fit範囲をcutoffから選択終了週までとしてbrowser内で`theta`と`k`を推定する。Gamma補正を
適用すると、観測累積hazardとGamma補正後累積hazardの表示へ切り替える。
Gamma補正前の4週以降は、選択区間内でcohort 1へ一定倍率を掛けたときのcohort 2との
二乗誤差が最小になる倍率をfitし、各cohortを1本の累積死亡人数線で表示する。
終了週sliderは0週から1週刻みとし、0〜3週ではfitしない。4週以上ではGamma補正の
表示状態にかかわらずfitする。複数の地域・年齢・接種回数を選択した場合は、
週初risk人数と週死亡数を各cohort内で週ごとに合算してからfitする。
観測線を細く残して補正線を太く表示し、`k2/k1`をcohort 1へ掛けて自動的に基準化する。
手動の水準調整は使用しない。
大阪市はrisk setがないため選択できない。

```text
MR(t)   = deaths_week(t) / at_risk(t)
h(t)    = -log(1 - MR(t))
Hobs(t) = sum h(t)
Hobs(t) = log(1 + theta * k * t) / theta
H0(t)   = (exp(theta * Hobs(t)) - 1) / theta
```

`theta=0`では`Hobs(t)=k*t`、`H0(t)=Hobs(t)`の極限を用いる。例えば次のように実行する。

```sh
ruby import/kcor_gamma.rb \
  --quiet-start 2022-W24 --quiet-end 2024-W16 \
  --output ../outputs/cze_Czech-Republic_GAMMA-CONSTANT-PARAMS.csv \
  --series-output ../outputs/cze_Czech-Republic_GAMMA-CONSTANT-SERIES.csv \
  ../outputs/cze_Czech-Republic_CUMD-WK-G.csv
```

parameter出力には`theta`、週単位の`k`、quiet point数、RMSE、境界解を示す`fit_status`を保存する。series出力は
各週の観測hazard、観測累積hazard、gamma inversion後の累積hazardを保存する。
これはconstant baselineを仮定する単純modelであり、Gompertz baselineやquiet pointの
反復選択を使う新しいKCOR versionとは区別する。したがってraw形式名はversion番号を持たない
`CUMD-WK-G`とし、解析結果にはmethodと条件を明示する。

## 公開データ

Elasticsearchを正本とし、`kcor.js`は公開API `/elastic/kcor/_search`を直接検索します。
最初にcutoff一覧と既定値に必要なmetadataを取得し、選択したcutoffについて次のfieldを取得します。

```text
areacode, area, areaj, date, age, dose, deaths
```

browserは選択中のcutoffだけを取得し、地域・年齢・接種回数の変更は通信せずに再集計します。
一度取得したcutoffはpage内でcacheします。

## Web application

- `kcor.rb`は言語判定、title、`lib/mfacts.rb`の共通menu、HTMLの骨組み、JS設定を出力します。
- `kcor.js`はElasticsearch APIからの取得、選択UI、集計、Vega-Lite描画を担当します。
- `kcor.css`はKCOR固有の表示だけを担当し、共通layoutは`mfacts.css`を使用します。
- 日本語版は`?l=ja`、英語版は`?l=en`です。
