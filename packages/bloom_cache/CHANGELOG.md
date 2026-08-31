# Changelog

## 0.3.1 - 2026-08-31

### Security & Reliability Hardening
* **Atomic Redis Lua Scripts & Key-to-Tag Index**: Replaced all `KEYS`-based tag maintenance with atomic Lua scripts and tracked key-to-tag indexes (`__key_tags:<key>`). `set`, `delete`, and `invalidateTags` now execute atomically in Redis in O(T) time without global key scanning.
* **Safe Scan-Based Redis Clearing**: `clear` now performs cursor-based `SCAN` batch deletions in Lua matching the configured prefix and never executes `FLUSHDB`. Clearing an unprefixed `RedisCache` is rejected by default to prevent accidental data loss, requiring explicit `allowEmptyPrefixClear: true`.
* **Transactional SQL DatabaseCache**: Wrapped `DatabaseCache.set`, `delete`, `clear`, `invalidateTags`, and `pruneExpired` in atomic database transactions.
* **Tag Cleanup in Expired Pruning**: `DatabaseCache.pruneExpired` now transactionally deletes corresponding tag associations in `${tableName}_tags` alongside expired cache rows.

## 0.3.0 - 2026-08-24

### Added
* Tag-based cache invalidation.

## 0.2.0 - 2026-08-23

### Breaking
- Now depends on `bloom_server` instead of `bloom_framework`. Imports change from
  `package:bloom_framework/bloom_server.dart` to `package:bloom_server/bloom_server.dart`.
- **No longer requires Flutter.** The package now resolves against the Flutter-free
  `bloom_server` core, so it can be used from a plain `dart run`/`dart compile` backend.

## 0.1.0

- Initial release of `bloom_cache`.
- Core abstract `BloomCache` interface with JSON round-trip serialization and concurrent `getOrSet` deduplication.
- `InMemoryCache` with real LRU eviction using `LinkedHashMap` and capacity bounds.
- `DatabaseCache` backed by `bloom_db` and its unified `DbExecutor` abstraction (PostgreSQL & SQLite).
- `RedisCache` backed by the official `package:redis` driver with TTL (millisecond precision) support.
- `BloomCacheMiddleware` for route-level HTTP response caching on GET requests with header/path opt-out controls.
