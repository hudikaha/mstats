# 日本の死亡統計の収録範囲

[English](JAPAN_MORTALITY_COVERAGE.md) | 日本語

`mortyear.rb`、`mort.rb`、`cod.rb`、`codtr.rb`で使用するe-Stat「人口動態統計」について、公表系列・年齢階級・死因を同時に利用できる範囲を示します。

| 年代 | 元資料 | 使用表 | 年齢階級 | 死因簡単分類 | 作成できる主な値 |
|---:|---|---|---|---|---|
| 1999～2008年 | [確定数](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053065&tclass4val=0) | 死亡数，性・年齢（5歳階級）・死因（死因簡単分類）別 | あり | あり | 年次：死亡数、年齢階級別率、全年齢粗死亡率、ASR |
| 1999～2008年 | [確定数](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053065&tclass4val=0) | 死亡数，性・死亡月・死因（死因簡単分類）別 | なし | あり | 月次・週次：全年齢の死因別死亡数・粗死亡率 |
| 2009～2024年 | [確定数・保管統計表](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053074&tclass4=000001053089&tclass5val=0) | 死亡数，死亡月・性・年齢（5歳階級）・死因（死因簡単分類）別 | あり | あり | 年次・月次・週次：死亡数、年齢階級別率、全年齢粗死亡率。年次：ASR |
| 2009年～2026年2月 | [月報（概数）](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0) | 死亡数，死因（死因簡単分類）・性・年齢（5歳階級・小学生―中学生再掲）別 | あり | あり | 年次・月次・週次：死亡数、年齢階級別率、全年齢粗死亡率。年次：ASR |

週次値は、月次死亡数を各暦日の所属週へ日数按分して再構成した推計値です。個々の死亡日を復元した値ではありません。

確定数と概数が重なる期間は確定数を優先し、概数は確定数の最終月より後を補います。表の収録期間はデータ更新時に更新します。

年次確定数は、[e-Statの確定数・死亡](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053065&tclass4val=0)にある「死亡数，性・年齢（5歳階級）・死因（死因簡単分類）別」を使用します。1999～2008年の年次値は月次合計ではなく、この年次確定表を直接使用します。

ASRは年次の年齢階級別死亡数と人口から直接法で計算します。古い人口表では最高齢層が`75歳以上`または`85歳以上`にまとめられているため、その年に公表された人口階級へ死亡数と標準人口weightも合わせて集約します。この期間のASRは、詳細な高齢階級がある年より粗い近似です。`75歳以上`はASR計算途中の補助区分であり、Elasticsearch fieldとしては保存しません。

人口には、[e-Stat「人口推計 各月1日現在人口」](https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0)を使用します。[日本の超過死亡ダッシュボード](https://exdeaths-japan.org/)の実週次STMFは、全年齢の全死因、悪性新生物、循環器系、呼吸器系、老衰、自殺、COVID-19に使用します。実週次がある期間はこれを優先し、その他の期間・年齢階級は月次から按分した週次値で補います。UN月次死亡数は全年齢・全死因の月次補完にだけ使用します。
