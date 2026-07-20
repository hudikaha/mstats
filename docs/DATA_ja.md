# データ

[English](DATA.md) | 日本語

このrepositoryは変換scriptとschemaを収録し、原dataと生成dataは収録しません。ローカルの
source pathは分野別文書に記し、必要に応じてsymbolic linkで表現します。

**mstats2026** 形式は日本の死因・人口recordをElasticsearchの `mstats2026` indexへ統合
します。IDと地域codeは小文字を正規形とします。元の死亡数と人口を保存し、人口当たり値と
年齢調整系列は表示時に計算します。

KCORは別の `kcor2025` indexを使用します。browserは公開Elasticsearch alias `kcor`から
取得します。field定義、source位置、更新方法は分野別文書を参照してください。
