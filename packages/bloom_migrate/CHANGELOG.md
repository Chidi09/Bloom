# Changelog

## 0.1.3 - 2026-09-04

### Changed
* Replaced the hand-rolled SHA-256 checksum implementation with `package:crypto`
  (`sha256.convert(utf8.encode(...))`). Digests are byte-identical to the previous
  implementation, so checksums stored in existing `bloom_migrations` tables remain
  valid. Fixes #13.

## 0.1.2 - 2026-08-31

* Added checksum validation to reject modified applied migrations.
* Added deployment locking and PostgreSQL dollar-quoted SQL parsing.

## 0.1.1 - 2026-08-23

- Fixed `CREATE INDEX` statement generation for column lists.

All notable changes to this project will be documented in this file.

## 0.1.0

- Initial release of `bloom_migrate`.
- Dialect-aware SQL DDL generation for SQLite and PostgreSQL from `bloom_db` `ModelMeta` and `FieldMeta`.
- Migration file parser for `migrations/<app>/NNNN_name.sql` supporting `-- up` and `-- down` (as well as `-- no-down`) sections mirroring `cloud-backend` convention.
- Transactional migration runner with `bloom_migrations` history tracking table.
- CLI tool `bloom_migrate` providing `makemigrations`, `migrate`, `rollback`, and `status` commands.
