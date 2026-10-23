# 公開Elasticsearch APIの運用

[English](ELASTICSEARCH_PUBLIC.md) | 日本語

`medicalfacts.info` は、5つのdatasetをHTTPSとnginx経由で読取専用公開します。
Elasticsearch自体の認証は維持し、browserやAPI clientには認証情報を渡しません。

server-side CGIは外部DNSやTLSを経由せず、loopback専用listener
`http://localhost:9401/elastic/`から同じ読取専用APIを使用します。公開datasetを読むCGIは
`espass.txt`を使用しません。listenerの番号は、8080がWordPressなどと衝突しやすく、
9200〜9400がElasticsearch自身のHTTP・transport範囲であるため9401としています。
別の番号にする場合は、CGIの環境変数`MSTATS_ELASTIC_URL`（例:
`http://localhost:9401/elastic`）をnginx設定と合わせます。

```text
公開名  Elasticsearchでの接続先
mstats  alias -> mstats20260819
kcor    alias -> kcor20260816
vdeath  alias -> vdeath20260816（接種後死亡data）
indiv   alias -> indiv20260816（週単位匿名化IND）
indivdth alias -> indivdth20260816（死亡者のみの週単位匿名化個票）
```

公開pathは次に限定します。

```text
/elastic/{mstats,kcor,vdeath,indiv,indivdth}/_search
/elastic/{mstats,kcor,vdeath,indiv,indivdth}/_count
/elastic/{mstats,kcor,vdeath,indiv,indivdth}/_mapping
/elastic/{mstats,kcor,vdeath,indiv,indivdth}/_field_caps
/elastic/{mstats,kcor,vdeath,indiv,indivdth}/_doc/{id}
```

`GET`、`POST`、CORS preflightの`OPTIONS`だけを受け付けます。`_doc/{id}`による
文書取得は`GET`と`OPTIONS`だけを受け付けます。Elasticsearch側でも
`config/elasticsearch/public-reader-role.json`により`read`と
`view_index_metadata`権限だけを許可します。

## 非公開credential

server上のrepository外に次のfileを置きます。

```text
~/.config/mstats/espublic.txt
```

形式:

```text
account:password
```

このaccountには公開読取専用roleだけを割り当てます。Nginxへ配置する設定には、このfileから
生成したBasic認証値が含まれるため、`/etc/nginx`内で非公開に保ちます。

## 配備順序

1. Elasticsearchの公開読取専用roleを作成または更新する。
2. `espublic.txt`から専用userを作成する。
3. 設定例から非公開Nginx設定を生成する。
4. `nginx -t`を実行する。
5. Nginxをreloadする。
6. client認証なしで5つの公開名を検証する。
7. 書込みAPIと対象外indexが403、404、または405になることを確認する。

内部listenerは`config/nginx/elasticsearch-internal.conf.example`を基に設定し、
外部interfaceでは待ち受けないでください。

Elasticsearchのanonymous認証を有効にせず、管理accountをNginx設定へ書いてはいけません。

利用者向けのquery例は[Elasticsearch APIの利用方法](ELASTICSEARCH_API_ja.md)を参照してください。

## 2026-10-24のサーバー移行

`medicalfacts.info`のCGIとElasticsearchはansinkoganei.orgと同じ新サーバーへ移行した。
旧サーバーはDNS切替中のアクセスを新側へ中継する。公開URLは変更しない。
`web/vaxx.rb`と、既存URL・cache workerの互換性を保つ`web/mortality.rb`・
`web/mortyear.rb`の直書き接続先も9401に揃えた。この3fileの直接接続先は固定9401で、
`MSTATS_ELASTIC_URL`による変更は共通helperを使う経路に適用する。
公開外の古いpageの機能改修は行わず、移行に必要な接続先の変更に限定した。
