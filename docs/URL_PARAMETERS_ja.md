# 公開URLパラメーターの規則

[English](URL_PARAMETERS.md) | 日本語

グラフpageのURLには、同じグラフを共有・再現できるよう選択状態を保存します。`cod.rb`と
`mortyear.rb`では、複数の死因・年齢について次の形式を標準とします。

## 基本規則

- 短縮形式を定義した選択内容は、原則として一つのparameterへ格納します。
- 連続しない複数値は`~`で区切ります。
- 連続する年・年齢階級は、両端を含む範囲へ圧縮します。
- 旧URLの反復parameterは読み込み互換として残しますが、form送信時には標準の短縮形式を生成します。

## 死因・症例

一つの`death_codes` parameterを使い、複数codeを`~`で連結します。

```text
death_codes=infant~perm
death_codes=04000~05000~06000
```

`mortyear.rb`は`death_codes`を複数回書いた旧URLも読み込めますが、formから送信すると上記形式になります。

## 年齢

単独の5歳階級内ではunderscoreを使い、連続しない階級は`~`で区切ります。

```text
ages=00_04
ages=00_04~10_14
```

連続する階級は、最初の階級の下限と最後の階級の上限で圧縮します。

```text
ages=00-09       # 00_04と05_09
ages=00-99       # 00_04から95_99
ages=80-100plus  # 80_84から100plus
```

全年齢は`ages=all`、0歳のみは`ages=0`です。インフルエンザ年では、
`ages=00-14~15-64`のように元dataの年齢階級を使います。

互換性のため、`mortyear.rb`は`age=age_00_04&age=age_05_09`のような旧形式も読み込めます。
formから送信すると`ages=00-09`になります。

## 年

複数年を個別選択できるpageでは、年にも同じ区切り・範囲規則を使います。

```text
years=2021-2025
years=2019~2021-2025
```

これらはURL上の表現であり、Elasticsearch document IDの要素とは別です。
