# morttr.rb 公開URLパラメーター仕様

[English](URL_PARAMETERS.md) | 日本語

この文書は、`morttr.rb`で同じグラフを共有・再現するための公開URL仕様です。
ここで示す短い正規名は`morttr.rb`と検証版`morttr2.rb`へ実装済みです。
旧URLも読み込めます。対応関係は末尾の「旧URLからの移行」にまとめます。

## 基本規則

- 一つの論理的な選択は一つのparameterへ格納します。
- 複数値はliteralの`~`で連結します。`%7E`へescapeする必要はありません。
- 年や年齢階級の範囲は両端を含みます。
- 真偽値は有効時だけ`=1`を付け、無効時はparameter自体を省略します。
- 既定値を省略しても同じグラフを再現できる場合、共有URLでは省略できます。
- 適用できないparameterは無視し、次にURLを生成するときに除去します。
- 正規名と旧名が同時に指定された場合は正規名を優先します。
- parameterの依存関係は一つのtreeでは表せないため、各表の「適用条件」で示します。

## 基本選択

| parameter | 値 | 既定値 | 適用条件・意味 |
|---|---|---|---|
| `l` | `ja`, `en` | browser言語 | `ja`は日本語、`en`は英語 |
| `mode` | `country`, `series` | `country` | `country`は複数の国・地域を一つの共通条件で比較。`series`は一つの国・地域について複数の年齢、死因、週次手法などを比較 |
| `period` | `calendar`, `flu27`, `flu36`, `weekly` | `calendar` | `calendar`は暦年、`flu27`は第27週開始、`flu36`は第36週開始のinfluenza年、`weekly`は週次の観測値・超過／過少死亡推移・累積 |
| `metric` | `deaths`, `std`, `crude`, `asr`, `birth` | 年次は`asr`、週次は`deaths` | `deaths`は実死亡数、`std`は標準人口換算死亡数、`crude`は粗死亡率、`asr`は年齢調整死亡率、`birth`は出生数を分母とする死亡率 |
| `ages` | `all`, `0`, 年齢階級・範囲 | `all` | 年齢選択。後述の形式を使う |
| `sex` | `both`, `male`, `female` | `both` | 男女計、男性、女性。`both`は正規URLでは省略可 |
| `c` | 地域codeを`~`で連結 | 表示種別ごとの既定地域 | 国・地域選択 |
| `dcodes` | 死因・症例codeを`~`で連結 | 全死因 | 死因または症例系列を選べる表示 |
| `inc` | `1` | 無効（省略） | 癌罹患系列を含める場合 |

`metric=birth`では男女別にせず、`sex`が指定されても`both`として扱います。

### `mode`による選択数

`mode`は他のparameterの単純な親ではありません。比較の単位に応じて、同じparameterが
単一選択または複数選択になります。

| 選択対象 | `mode=country` | `mode=series` |
|---|---|---|
| `c` | 複数の国・地域 | 一つの国・地域 |
| `ages`, `dcodes` | 共通条件として原則一つ | 複数系列を作成可 |
| `algo`, `ref` | それぞれ一つ | それぞれ複数可。`~`で連結 |

実際に選べる年齢、死因、指標、地域は、期間とdataの有無にも依存します。したがって、
この表はparameterをtreeへ固定するものではなく、URL値の個数を定めるものです。

### 期間をまたぐ適用条件

| parameter群 | `calendar` | `flu27`, `flu36` | `weekly` |
|---|---|---|---|
| `mode`, `metric`, `ages`, `sex`, `c`, `dcodes` | 使用 | 使用。ただし元dataの選択肢に限定 | 使用。ただし元dataの選択肢に限定 |
| `from` | 使用 | 使用 | 使用 |
| `fit`, `family`, `interval` | 使用 | 使用 | 不使用 |
| `algo`, `ref`, `cum`, `deficit` | 不使用 | 不使用 | 使用 |
| `covid`, `vaxx` | 不使用 | 不使用 | 条件を満たす場合に使用 |
| `zero` | 対象グラフがある場合に使用 | 対象グラフがある場合に使用 | 対象グラフがある場合に使用 |

`metric`、`ages`、`sex`、重畳表示の可否は相互に関係します。詳細は各parameterの
「適用条件」を正本とします。

地域・指標・開始年を指定しない年次表示は、日本・英国・スウェーデン・米国の
年齢調整死亡率を2000年から表示します。`period=weekly`だけを指定した場合は、
日本・イングランド・スウェーデン・米国の週次死亡数を2015年から、
Farrington型・2015–2019年固定基準で表示します。

### 年齢と複数値

単独の5歳階級内ではunderscoreを使い、複数の選択値は`~`で連結します。
連続する階級は、最初の下限と最後の上限を使った範囲表記にも圧縮できます。

```text
ages=00_04
ages=00_04~10_14
ages=00-09
ages=00-99
ages=80-100plus
```

全年齢は`ages=all`、0歳のみは`ages=0`です。influenza年では、
`ages=00-14~15-64`のように元dataの年齢階級を使います。

## 表示期間と予測計算

| parameter | 値 | 既定値 | 適用条件・意味 |
|---|---|---|---|
| `from` | `YYYY` | 年次2000、週次2015 | X軸の表示開始年 |
| `fit` | `YYYY` | 暦年2019、influenza年2018 | 年次・influenza年の予測モデルに使う学習終了年 |
| `family` | `quasi`, `poisson` | `quasi` | `quasi`は観測dataの過分散を反映する準Poisson、`poisson`は平均と分散が等しいと仮定するPoisson |
| `interval` | `approx`, `sim` | `sim` | `approx`は解析的な近似で準Poissonに使用。`sim`はsimulationでPoissonに使用可能 |

`family`は確率分布・分散の仮定、`interval`は区間を求める計算法を表します。
週次のFarrington型やEuroMOMO型は、この二つとは別に`algo`で指定します。

## 週次の基準と累積

| parameter | 値 | 既定値 | 適用条件・意味 |
|---|---|---|---|
| `algo` | `mean`, `farrington`, `euromomo` | `farrington` | `mean`は各基準年の同じ週を使う平均・範囲、`farrington`はFarrington型、`euromomo`はEuroMOMO型の期待値・予測区間 |
| `ref` | `YYYY-YYYY`, `prevN` | `2015-2019` | `period=weekly`の基準期間。固定年範囲、または各年の直前N年 |
| `cum` | `YYYY` | `2021` | `period=weekly`の累積超過・過少死亡の開始年 |
| `deficit` | `1` | 無効（省略） | 負の差を週次推移と累積へ含める |

`cum`は基準期間を決める`ref`とは独立です。たとえば、2015–2019年を基準にして
2020年から累積する場合は`ref=2015-2019&cum=2020`とします。省略時は2021年から
累積します。

`ref=2014-2018`のような任意の固定5年間に加え、将来は`ref=prev3`から
`ref=prev10`までを受け付ける方針とします。menuは代表的なpresetだけを提示しても
構いません。`algo=mean`でも平均年数は`ref`が決めるため、algorithm名に`5`を含めません。

## グラフ付近の表示control

| parameter | 値 | 既定値 | 適用条件・意味 |
|---|---|---|---|
| `zero` | `1` | 無効（省略） | 対象グラフのY軸を0から表示 |
| `covid` | `1` | 無効（省略） | 週次、男女計、全年齢かつ`deaths`または`crude`でCOVID-19死亡を重ねる。`asr`では使用不可 |
| `vaxx` | `1` | 無効（省略） | 週次でdataがある場合にワクチン接種を重ねる。`asr`でも使用可 |

表示条件を切り替えてcontrolが一時的に使えなくなった場合、その選択状態は画面内では
保持できます。ただし、共有URLを正規化するときは、現在の表示へ適用できないparameterを
除去します。補助的な週次・月次表示の切替えは、意図的にURLへ保存しません。

## iframeへの埋込み

`i=1`、`i=on`、`i=true`でグラフだけを表示します（大文字・小文字は区別しません）。
未指定、`i=0`、`i=off`、`i=false`、その他の値では通常表示です。
メニュー、ページ見出し、操作欄、ダウンロードボタン、説明・出典欄を非表示にします。
グラフの条件は通常と同じURL parameterで指定でき、描画・計算中の表示とエラー表示は残します。

```text
morttr.rb?i=1&period=weekly&c=jpn
```

## URL専用のグラフ寸法

`height=200`で各panelの描画領域を高さ200pxにします（見出し・軸の余白は別）。
50以上の整数を指定します。省略・不正値の場合は従来どおり、主panelは260px、
週次の超過死亡・累積panelは各115pxです。

`width=800`または`width=800px`でグラフ領域全体の幅を800pxにします。
`width=80%`では親の本文領域の80%となり、リサイズにも追従します。幅には軸の余白を含みます。
正の数を受け付け、省略・不正値の場合は従来の可変幅です。固定幅は狭いiframeからはみ出す場合があります。

通常表示・iframe表示の両方で使用できます。formに編集可能な入力欄は設けず、
有効な指定値だけhidden fieldで再送信時にも保持します。

```text
morttr.rb?i=1&period=weekly&c=jpn&height=200&width=80%
```

## 開発・debug用

`calc=ruby|js`はRuby経路とJavaScript経路を比較するための開発用parameterです。
一般利用者向けのcontrolにはせず、正規の共有URLには含めません。

## 正規URLの例

指定を明記した週次URL:

```text
morttr.rb?l=ja&mode=country&period=weekly&metric=asr&ages=all&c=jpn~swe~gbr&algo=farrington&ref=prev5&cum=2021&vaxx=1
```

既定値を省略した同等の短縮URL:

```text
morttr.rb?l=ja&period=weekly&metric=asr&c=jpn~swe~gbr&ref=prev5&vaxx=1
```

## 旧URLからの移行

以下は読み込み互換のために受け付ける旧名・旧値です。form送信や共有URL生成では
左側を出力せず、右側の正規形式へ変換します。

| 旧指定 | 正規指定 |
|---|---|
| `age=age_00_04`などの反復 | `ages=00_04`などを`~`または範囲で統合 |
| `death_codes`または反復した死因parameter | `dcodes`一つへ`~`で統合 |
| `include_incidence=1` | `inc=1` |
| `start_year=YYYY` | `from=YYYY` |
| `train_to=YYYY` | `fit=YYYY` |
| `chart_model=quasi_poisson|poisson` | `family=quasi|poisson` |
| `interval=analytic|auto` | `interval=approx|sim` |
| `weekly_method=five_year|farrington|euromomo` | `algo=mean|farrington|euromomo` |
| `weekly_baseline=fixed_2015_2019|fixed_2016_2020|rolling`（`fixed`は2015–2019） | `ref=2015-2019|2016-2020|prev5` |
| `include_deficit=1` | `deficit=1` |
| `zero_base=1` | `zero=1` |
| `covid_overlay=1` | `covid=1` |
| `vaxx_overlay=1` | `vaxx=1` |
| `metric=crude_rate|std_deaths|birth_rate` | `metric=crude|std|birth` |
| `sex=both` | `sex`を省略 |
