# vdeath個票変換

[English](IMPORT.md) | 日本語

`import/vdeathp.rb`は自治体から開示された住民・接種・死亡個票を共通形式で読み、目的別のsubcommandで集計する。

```sh
vdeathp.rb personyear [options] INPUT...
vdeathp.rb afterdose  [options] INPUT...
vdeathp.rb kcor      [options] INPUT...
vdeathp.rb anonymize [options] INPUT...
vdeathp.rb excess    [options] INPUT...
```

- `personyear`: 暦月、3箇月、6箇月、全期間の年齢・接種回数別人年集計
- `afterdose`: 接種後の経過週別人年集計
- `kcor`: cutoff時点のcohort別累積死亡数
- `anonymize`: 転入、転出、死亡、接種日をISO週の日曜へ丸めた匿名個票
- `excess`: 接種歴を含まない長期個票にも使える年別死亡・年齢調整集計

公開用の2段階処理では、最初に`anonymize`で`IND-WKA`を作り、そのCSVを入力として
`personyear`または`afterdose`をもう一度実行します。この出力は通常の`1`、`3`、`6`、
`all`、`week`を使います。日単位の元個票に`--step-prefix org`を付けて同じ集計を行うと、
`org1`や`orgweek`という比較系列になります。

共通optionは`--headers FILE[,FILE...]`、`--output FILE`、`--age-reference DATE`、
`--age-seed-version VERSION`、`--open-age-max AGE`、`--allow-dup-id`、
`--prohibit-reason-in`、`--report FILE`である。週番号を日付として持つ入力では
`--iso-week-dates`、再感染で同一人物の行が増える入力では`--first-infection-only`を使う。
元CSVにもheaderがあり、別の対応headerを`--headers`で与える場合は`--skip-source-header`を使う。
入力に地域fieldがない場合は`--areacode`、`--area`、`--areaj`で指定できる。
`--spread-weekly-dates SEED`は週次化された接種日、死亡日、転入日、転出日を、人物IDとISO週に対するSHA-256から月曜〜日曜へ決定的に分散する。同じ人物の同じ週はeventの種類によらず同じ日になる。同一人物に同一ISO週の複数接種がある場合、その人物は不正な接種系列として集計から除外し、reportの`same_week_doses`へ数える。
`personyear`は人物ごとに観察時系列を一度だけ作り、期間の内部を差分配列で集計する。旧実装との検算が必要な場合だけ`--legacy-personyear`を指定できる。
`--progress-total PEOPLE`を指定すると、phaseの開始と処理人口10%ごとの人数・経過時間をstderrへ表示する。
`--age-reference`を省略すると、全入力中の最終死亡日の翌日を年齢基準日にする。
元のheaderを含まない自治体CSVには`--headers`が必要である。`anonymize`出力のように先頭行にheaderを持つCSVは、`--headers`なしで再入力できる。

1歳年齢、年齢区分、または`birth_year` fieldの出生年区分から可能な生年月日範囲を求め、
地域code、個票ID、元年齢または出生年区分、seed versionのSHA-256から再現可能な仮想誕生日を決める。
`anonymize`は実際の誕生日ではないこの日付を`vbirthday`として出力する。`vbirthday`を持つCSVを再入力した場合は、それを誕生日として使い、再生成しない。`personyear`では誕生日を跨ぐperson-daysを前後の年齢群へ分割し、死亡は死亡日の年齢群へ入れる。

例:

```sh
./vdeathp.rb personyear \
  --headers src/jp132101_example_header.csv \
  --steps 1,3,6,all \
  --ages 00-09,10-19,80+,all \
  --output outputs/jp132101_example_PY.csv \
  src/jp132101_example_all.csv
```

旧式の複数用途版は`import/vdeathp-20251027.rb`として保存している。

`import/Makefile`は自治体ごとに`PY`、`PY-WKD`、`CUMD-WK`、`IND-WKA`を生成する。死亡者個票だけの大阪市は`CUMD-WK`と`DTH-WKA`を生成する。

```sh
cd vdeath/import
make              # 全自治体
make jp132101     # 小金井市だけ
make FORCE=1      # 既存出力も再生成
make cze          # チェコ公式週次個票からvdeathとKCORを生成
```

チェコ公式CSVはrepository外の`~/work/vdeath-src/Czech`に置き、53 fieldの対応は
`import/headers/czech-2024-01.csv`で指定し、元CSVのheader行は読み飛ばす。`Infekce`が2以上の再感染行を除外し、
`RokNarozeni`の5年出生年区分からvirtual birthdayを生成する。元dataがすでに週単位なので、
チェコでは日単位の`org*`比較系列を作らない。

`*-IND-WKA.csv`と`*-DTH-WKA.csv`は、非公開の日単位個票CSVから生成した匿名化個票です。これらはそれぞれElasticSearchの`indiv`と`indivdth`として公開します。公開個票は日付を週単位へ丸めているため、内部処理の再現・検証に使えますが、日単位の精度は失われています。

[`vdeath.rb`](https://medicalfacts.info/vdeath.rb)のデフォルト表示は、公開用に匿名化する前の非公開日単位CSVから計算した、より精度の高い系列です。ページの`src`オプションで、公開`indiv`の日付を人物・ISO週ごとに週内分散して再解析した匿名化データ系列も表示できます。死亡者のみの`indivdth`も同じ匿名化形式です。両者を比較することで、週単位匿名化による集計差を確認できます。

週次化されたevent日には、seed、地域code、人物ID、ISO週のSHA-256から月曜〜日曜を割り当てる。同じ人物・同じ週の接種、死亡、転入、転出は同じ日になるため、週内で人工的な前後関係を作らない。この再構成により、全eventを日曜日へ集中させたときの4週月・5週月による周期的な差を抑える。
