# Changelog

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
