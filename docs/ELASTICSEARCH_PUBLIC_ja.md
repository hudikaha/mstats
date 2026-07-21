# 公開Elasticsearch APIの運用

[English](ELASTICSEARCH_PUBLIC.md) | 日本語

`medicalfacts.info` は、4つのdatasetをHTTPSとnginx経由で読取専用公開します。
Elasticsearch自体の認証は維持し、browserやAPI clientには認証情報を渡しません。

server-side CGIは外部DNSやTLSを経由せず、loopback専用listener
`http://localhost:8080/elastic/`から同じ読取専用APIを使用します。公開datasetを読むCGIは
`espass.txt`を使用しません。

```text
公開名  Elasticsearchでの接続先
mstats  alias -> mstats20260719
kcor    alias -> kcor2025
vdeath  index vdeath
vdeath2026  index vdeath2026（年齢補正の比較用data）
```

公開pathは次に限定します。

```text
/elastic/{mstats,kcor,vdeath,vdeath2026}/_search
/elastic/{mstats,kcor,vdeath,vdeath2026}/_count
/elastic/{mstats,kcor,vdeath,vdeath2026}/_mapping
/elastic/{mstats,kcor,vdeath,vdeath2026}/_field_caps
/elastic/{mstats,kcor,vdeath,vdeath2026}/_doc/{id}
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
6. client認証なしで4つの公開名を検証する。
7. 書込みAPIと対象外indexが403、404、または405になることを確認する。

内部listenerは`config/nginx/elasticsearch-internal.conf.example`を基に設定し、
外部interfaceでは待ち受けないでください。

Elasticsearchのanonymous認証を有効にせず、管理accountをNginx設定へ書いてはいけません。

利用者向けのquery例は[Elasticsearch APIの利用方法](ELASTICSEARCH_API_ja.md)を参照してください。
