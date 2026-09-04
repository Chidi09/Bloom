# Changelog

## 0.1.5 - 2026-09-04

### Fixed
* **`getOrCreate`/`updateOrCreate` race (#15)**: the check-then-insert sequence now runs inside a transaction; if the insert loses a race against a concurrent writer (unique violation), the row is re-fetched and returned with `created: false` instead of surfacing the error. Nests cleanly inside caller transactions (savepoints on SQLite).

## 0.1.4 - 2026-09-04

### Fixed
* **`count()` ignores `limit`/`offset` (#10)**: the count aggregation no longer includes paging, so a queryset with `OFFSET` beyond the row count returns the filtered total instead of throwing `BloomOrmNotFoundError`.
* **LIKE lookups escape wildcards (#12)**: `contains`/`icontains`/`startsWith`/`endsWith`/`iexact` escape `%`, `_`, and `\` in user input and emit `ESCAPE '\'`, so input matches literally instead of over-matching.
* **Unfiltered bulk writes refused (#14)**: `QuerySet.update`/`delete` without filters throw `BloomOrmInvalidQueryError` unless `allowUnfiltered: true` is passed, so one call can no longer wipe a table by accident.
* **Data-layer hardening (#15)**: `QuerySet.limit`/`offset` reject negative values; PostgreSQL-only `regex`/`iregex` lookups fail clearly on SQLite; each executor bounds `queryLog` to `kMaxQueryLogEntries` (1000); nested SQLite transactions use savepoints instead of issuing nested `BEGIN`; PostgreSQL TLS setup is documented for production.
* **`valuesList` honors `flat` (#19)**: `valuesList(db, field, flat: false)` (and the `values_list` alias) now returns one `{field: value}` map per row — the same shape as `.values(db, [field])` — instead of silently ignoring the parameter and always returning bare values. `flat: true` (the default) behavior is unchanged.

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
