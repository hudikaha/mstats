# 公開URLパラメーターの規則

[English](URL_PARAMETERS.md) | 日本語

グラフpageのURLには、同じグラフを共有・再現できるよう選択状態を保存します。`cod.rb`と
`morttr.rb`では、複数の死因・年齢について次の形式を標準とします。

## 基本規則

- 短縮形式を定義した選択内容は、原則として一つのparameterへ格納します。
- 連続しない複数値は`~`で区切ります。
- 連続する年・年齢階級は、両端を含む範囲へ圧縮します。
- 旧URLの反復parameterは読み込み互換として残しますが、form送信時には標準の短縮形式を生成します。

## 死因・症例

一つの`dcodes` parameterを使い、複数codeを`~`で連結します。

```text
dcodes=infant~perm
dcodes=04000~05000~06000
```

`morttr.rb`は旧名`death_codes`や反復parameterも読み込めますが、formから送信すると
`dcodes`一つの上記形式になります。

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

互換性のため、`morttr.rb`は`age=age_00_04&age=age_05_09`のような旧形式も読み込めます。
formから送信すると`ages=00-09`になります。

## 性別

`morttr.rb`の男女別系列は`sex=male`または`sex=female`で指定します。男女計は既定値のため、
標準URLでは`sex`を省略します。出生関連死亡率は男女別にせず、`sex`指定があっても男女計として扱います。

## 年

複数年を個別選択できるpageでは、年にも同じ区切り・範囲規則を使います。

```text
years=2021-2025
years=2019~2021-2025
```

これらはURL上の表現であり、Elasticsearch document IDの要素とは別です。

## 週次の過少死亡

`morttr.rb`の週次表示では、`include_deficit=1`を指定すると、基準線を下回る週の負の差を
推移と累積の両方へ含めます。このparameterがない場合は負の差を0として、従来の累積超過死亡を
表示します。

## グラフ表示control

`morttr.rb`のグラフだけに作用する表示controlは、`zero_base=1`、`covid_overlay=1`、
`vaxx_overlay=1`でURLへ保存します。モデルは`chart_model=quasi_poisson`または
`chart_model=poisson`、区間は`interval=auto`または`interval=analytic`です。
補助的な週次・月次表示の切替えは、意図的にURLへ保存しません。

地域・指標・開始年を指定しない年次表示は、日本・英国・スウェーデン・米国の年齢調整死亡率を
2000年から表示します。`period=weekly`だけを指定した場合は、日本・イングランド・
スウェーデン・米国の週次死亡数を2015年から、Farrington型・2015–2019年基準で表示します。
