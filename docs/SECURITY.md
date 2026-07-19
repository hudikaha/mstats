# Security

English | [日本語](SECURITY_ja.md)

Do not commit passwords, tokens, private source credentials, `.env` files, or
machine-specific Logstash configurations. A private repository is not a
substitute for secret management.

Application code must obtain secrets from an external file or an environment
variable. Tracked Logstash templates must refer to `${ES_PASSWORD}` instead of
containing a literal password. Secret files must not be placed in directories
served by a web server.

Before a public release, scan the complete staged tree, inspect ignored files
and symbolic links, and verify that no historical repository data has been
imported. The historical `mstats2025` repository remains private.
