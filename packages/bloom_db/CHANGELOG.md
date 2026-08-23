# Changelog

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
