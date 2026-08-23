# Changelog

## 0.1.1 - 2026-08-23

- Fixed `CREATE INDEX` statement generation for column lists.

All notable changes to this project will be documented in this file.

## 0.1.0

- Initial release of `bloom_migrate`.
- Dialect-aware SQL DDL generation for SQLite and PostgreSQL from `bloom_db` `ModelMeta` and `FieldMeta`.
- Migration file parser for `migrations/<app>/NNNN_name.sql` supporting `-- up` and `-- down` (as well as `-- no-down`) sections mirroring `cloud-backend` convention.
- Transactional migration runner with `bloom_migrations` history tracking table.
- CLI tool `bloom_migrate` providing `makemigrations`, `migrate`, `rollback`, and `status` commands.
