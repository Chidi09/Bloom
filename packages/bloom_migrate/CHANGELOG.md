# Changelog

## 0.1.4 - 2026-09-04

### Changed
* **Empty `-- up` migration warning (#15)**: a migration whose `-- up` section parses empty (usually a marker typo such as `-- UP`) now emits a loud warning at parse time, since it previously applied nothing yet recorded as applied.
* **`_ensureChecksumColumn` no longer swallows all errors (#15)**: after a failed `ALTER TABLE` it verifies the column is actually present and readable; any other failure (read-only database, missing permissions) now raises a `StateError` instead of hiding behind "column exists".

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
