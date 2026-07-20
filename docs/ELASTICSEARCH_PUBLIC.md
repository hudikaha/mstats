# Public Elasticsearch API

English | [日本語](ELASTICSEARCH_PUBLIC_ja.md)

`medicalfacts.info` publishes read-only searches for three datasets through
HTTPS and nginx. Elasticsearch remains authenticated; browsers and API clients
do not receive Elasticsearch credentials.

Server-side CGI uses the same read-only API through the loopback-only listener
at `http://localhost:8080/elastic/`, avoiding external DNS and TLS. CGI
that reads public datasets does not use `espass.txt`.

```text
public name  Elasticsearch target
mstats       alias -> mstats20260719
kcor         alias -> kcor2025
vdeath       index vdeath
```

The public paths are limited to:

```text
/elastic/{mstats,kcor,vdeath}/_search
/elastic/{mstats,kcor,vdeath}/_count
/elastic/{mstats,kcor,vdeath}/_mapping
/elastic/{mstats,kcor,vdeath}/_field_caps
/elastic/{mstats,kcor,vdeath}/_doc/{id}
```

Only `GET`, `POST`, and CORS preflight `OPTIONS` are accepted. Direct document
retrieval through `_doc/{id}` accepts only `GET` and `OPTIONS`. Elasticsearch
also enforces the `read` and `view_index_metadata` privileges in
`config/elasticsearch/public-reader-role.json`.

## Private credential

Create the following file outside the repository on the server:

```text
~/.config/mstats/espublic.txt
```

Its format is:

```text
account:password
```

The account is assigned only the public-reader role. The rendered nginx
configuration contains a Basic authorization value derived from this file and
must remain private under `/etc/nginx`.

## Deployment order

1. Create or update the Elasticsearch public-reader role.
2. Create the dedicated user from `espublic.txt`.
3. Render the private nginx configuration from the example.
4. Run `nginx -t`.
5. Reload nginx.
6. Test all three aliases without client credentials.
7. Confirm write APIs and unrelated indices return 403 or 404.

Configure the internal listener from
`config/nginx/elasticsearch-internal.conf.example`, and never bind it to an
external interface.

Do not enable Elasticsearch anonymous authentication and do not put the
administrative account in nginx configuration.

See [Using the Elasticsearch API](ELASTICSEARCH_API.md) for client query
examples.
