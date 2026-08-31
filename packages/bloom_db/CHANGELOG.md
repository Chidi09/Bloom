# Changelog

## 0.1.3 - 2026-08-31

* Maintenance release for the current ORM runtime and transaction API.

## 0.1.2 - 2026-08-26

### Added
* `DbExecutor.transaction<R>(callback)` — atomic multi-statement transactions for both `SqliteDbExecutor` and `PostgresDbExecutor`. Commits on success, rolls back and rethrows the original exception on failure. `PostgresDbExecutor` delegates to `package:postgres`'s real `Connection.runTx()`.

## 0.1.1 - 2026-08-23

- Internal query-builder fixes. No public API changes.

## 0.1.0

Initial release.

- `QuerySet<T>` API: `filter`/`exclude`/`orderBy`/`limit`/`offset`/`get`/`first`/`all`/`exists`/
  `count`/`update`/`delete`/`bulkCreate`/`getOrCreate`/`updateOrCreate`/`values`/`valuesList`.
- `Q()` filter expressions with `&`/`|`/`~` composition; `F()` field expressions for atomic updates.
- `@BloomModel`/`@BloomField` annotations and manual `ModelMeta` declaration.
- `PostgresDbExecutor` and `SqliteDbExecutor`, symmetric dialect support.
- Parameterized SQL generation throughout — no string-interpolated filter values.
