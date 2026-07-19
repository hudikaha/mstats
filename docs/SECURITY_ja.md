# セキュリティ

[English](SECURITY.md) | 日本語

password、token、非公開取得元credential、`.env`、machine固有Logstash設定をcommitしては
いけません。非公開repositoryであることは秘密管理の代りになりません。

application codeはrepository外のファイルまたは環境変数から秘密を取得します。Git管理する
Logstash templateはpasswordを直書きせず `${ES_PASSWORD}` を参照します。Web serverが
公開するdirectoryへ秘密ファイルを置いてはいけません。

公開前にはstage済みtree全体をscanし、ignore対象とsymbolic linkを確認し、旧repositoryの
履歴が入っていないことを確認します。旧 `mstats2025` repositoryは非公開のままにします。
