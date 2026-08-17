# Changelog

## 0.1.0

- Initial release of `bloom_cache`.
- Core abstract `BloomCache` interface with JSON round-trip serialization and concurrent `getOrSet` deduplication.
- `InMemoryCache` with real LRU eviction using `LinkedHashMap` and capacity bounds.
- `DatabaseCache` backed by `bloom_db` and its unified `DbExecutor` abstraction (PostgreSQL & SQLite).
- `RedisCache` backed by the official `package:redis` driver with TTL (millisecond precision) support.
- `BloomCacheMiddleware` for route-level HTTP response caching on GET requests with header/path opt-out controls.
