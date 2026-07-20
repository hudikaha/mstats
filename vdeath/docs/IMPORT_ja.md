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

共通optionは`--headers FILE[,FILE...]`、`--output FILE`、`--age-reference DATE`、
`--age-seed-version VERSION`、`--open-age-max AGE`、`--allow-dup-id`、
`--prohibit-reason-in`、`--report FILE`である。`--age-reference`を省略すると、全入力中の最終死亡日の翌日を年齢基準日にする。
元のheaderを含まない自治体CSVには`--headers`が必要である。`anonymize`出力のように先頭行にheaderを持つCSVは、`--headers`なしで再入力できる。

1歳年齢または年齢区分から可能な生年月日範囲を求め、自治体code、個票ID、元年齢、seed versionのSHA-256から再現可能な仮想誕生日を決める。`anonymize`は実際の誕生日ではないこの日付を`vbirthday`として出力する。`vbirthday`を持つCSVを再入力した場合は、それを誕生日として使い、再生成しない。`personyear`では誕生日を跨ぐperson-daysを前後の年齢群へ分割し、死亡は死亡日の年齢群へ入れる。

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
