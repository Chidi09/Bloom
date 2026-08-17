# Bloom Cache (`bloom_cache`)

A robust, server-side caching abstraction and backends for Bloom applications, modeled on `djangors-cache`.

This package is designed for caching expensive server-side computations (e.g. database queries, rendered template fragments, third-party API responses, and entire HTTP route responses) across requests on the server.

> **Note**: This is distinct from `bloom_framework`'s client-side `BloomData` cache (`lib/src/data/cache.dart`). `bloom_cache` runs on the backend server.

---

## Key Features

- **Unified `BloomCache` API**: Simple `get<T>`, `set<T>`, `delete`, `clear`, and `getOrSet<T>` interface.
- **Cache Stampede Prevention**: `getOrSet` automatically deduplicates concurrent in-flight computations for the same key, ensuring `compute()` is called only once under high concurrency.
- **In-Memory LRU Backend**: Capacity-bounded in-memory cache with true $O(1)$ Least-Recently-Used (LRU) eviction backed by Dart's `LinkedHashMap`.
- **Database Backend**: SQL-backed cache storing entries in `bloom_cache_entries` via Bloom's unified `DbExecutor` (supporting SQLite and PostgreSQL).
- **Redis Backend**: Distributed caching powered by the official `package:redis` driver with millisecond-level TTL expiration.
- **HTTP Response Caching Middleware**: `BloomCacheMiddleware` caches full GET route responses for Bloom API endpoints and SSR handlers with automatic cookie/opt-out protection.

---

## Serialization Constraint

All cached values (`T`) **must round-trip through JSON serialization**.

Because persistent backends such as Redis and SQL databases cannot store arbitrary in-memory Dart heap objects directly, values are serialized using `jsonEncode` and deserialized using `jsonDecode`.

Supported types for `T`:
- Primitive types: `String`, `int`, `double`, `bool`, `num`
- Structured types: `Map<String, dynamic>`, `List<dynamic>`, `List<String>`, `List<int>`, `List<Map<String, dynamic>>`
- Custom classes that provide `toJson()` and can be reconstructed from JSON.

---

## Usage Examples

### 1. In-Memory Cache (LRU)

`InMemoryCache` holds up to `maxCapacity` entries. When capacity is exceeded, the least-recently-used item is evicted immediately. Expiration TTL is checked on every read.

```dart
import 'package:bloom_cache/bloom_cache.dart';

void main() async {
  // Create an in-memory cache bounded to 1,000 items
  final cache = InMemoryCache(maxCapacity: 1000);

  // Basic get / set
  await cache.set('greeting', 'Hello, Bloom!', ttl: Duration(minutes: 10));
  final greeting = await cache.get<String>('greeting');
  print(greeting); // "Hello, Bloom!"

  // getOrSet: computes and caches if missing; deduplicates concurrent callers
  final stats = await cache.getOrSet<Map<String, dynamic>>(
    'dashboard:stats',
    () async {
      return {'activeUsers': 420, 'updatedAt': DateTime.now().toIso8601String()};
    },
    ttl: Duration(minutes: 5),
  );

  print(stats['activeUsers']); // 420
}
```

---

### 2. Database Cache (`DatabaseCache`)

`DatabaseCache` persists cached entries to an SQL database table (`bloom_cache_entries`) using `bloom_db`'s unified `DbExecutor`. It supports both PostgreSQL (`PostgresDbExecutor`) and SQLite (`SqliteDbExecutor`).

```dart
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_cache/bloom_cache.dart';

void main() async {
  // Open SQLite or connect to PostgreSQL using bloom_db
  final db = SqliteDbExecutor.openFile('app.db');
  // Or: final db = await PostgresDbExecutor.connectUrl('postgres://user:pass@localhost:5432/app');

  final cache = DatabaseCache(db);

  // Store JSON-encodable objects with a TTL
  await cache.set('user:101:profile', {
    'id': 101,
    'username': 'alice',
    'roles': ['admin', 'editor'],
  }, ttl: Duration(hours: 1));

  // Retrieve cached profile
  final profile = await cache.get<Map<String, dynamic>>('user:101:profile');
  print(profile?['username']); // "alice"

  // Prune all expired entries from database
  final deletedCount = await cache.pruneExpired();
  print('Pruned $deletedCount expired rows.');
}
```

---

### 3. Redis Cache (`RedisCache`)

`RedisCache` uses the official `package:redis` driver. It supports connecting via connection parameters, Redis connection URLs (`redis://...` / `rediss://...`), or an existing `Command` instance.

```dart
import 'package:bloom_cache/bloom_cache.dart';

void main() async {
  // Connect via URL or host/port
  final cache = RedisCache.fromUrl('redis://:secret@localhost:6379/0', prefix: 'myapp');
  // Or: final cache = RedisCache(host: 'localhost', port: 6379, prefix: 'myapp');

  // getOrSetFragment convenience helper
  final report = await getOrSetFragment<Map<String, dynamic>>(
    cache,
    'monthly-sales-report',
    () async {
      // Expensive DB query or report aggregation
      return {'totalSales': 154200.50, 'currency': 'USD'};
    },
    ttl: Duration(minutes: 30),
  );

  print(report['totalSales']); // 154200.50

  // Close connection when application shuts down
  await cache.close();
}
```

---

### 4. HTTP Response Caching Middleware (`BloomCacheMiddleware`)

`BloomCacheMiddleware` is a `BloomMiddleware` that caches entire `GET` HTTP responses (status code, headers, body bytes) for a configurable TTL.

```dart
import 'package:bloom_framework/bloom_framework.dart';
import 'package:bloom_cache/bloom_cache.dart';

void main() {
  final cache = InMemoryCache(maxCapacity: 5000);

  final cacheMiddleware = BloomCacheMiddleware(
    cache: cache,
    ttl: Duration(minutes: 5),
    excludePaths: ['/api/auth', '/healthz'],
  );

  // Use in your Bloom server pipeline:
  // server.use(cacheMiddleware);
}
```

#### Opt-Out / Non-Cacheable Rules:
- **Method Check**: Only `GET` requests are cached. `POST`, `PUT`, `DELETE`, etc. always bypass the cache.
- **Cookie Protection**: Any response setting a cookie (`Set-Cookie` header) is **never cached** to prevent session leakage across users.
- **Opt-Out Headers**: Handlers can opt out dynamically by returning `x-bloom-no-cache: true` or `cache-control: no-store` / `no-cache`.
- **Status Codes**: Only successful 2xx responses (`200`–`299`) are cached.

---

## Concurrency & Deduplication (`getOrSet`)

`getOrSet` implements in-flight `Future` deduplication to prevent **cache stampedes** (thundering herd problem).

When multiple concurrent requests miss the cache for the same key simultaneously:
1. The first caller invokes `compute()` and stores the pending `Future` in an internal deduplication map.
2. Concurrent callers await the existing pending `Future` rather than executing duplicate `compute()` calls.
3. Once computed, the result is saved to the cache backend and returned to all awaiting callers.
4. If `compute()` throws an error, the exception propagates to all callers, the in-flight future is cleaned up, and nothing is cached.
