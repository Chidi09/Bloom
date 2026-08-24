/// Server-side caching abstraction and backends for Bloom applications.
///
/// Modeled on `djangors-cache`, this package provides unified key-value caching
/// across multiple storage backends with automatic cache stampede deduplication,
/// tag-based bulk invalidation, and HTTP response caching middleware.
///
/// ### Core Abstractions
/// - [BloomCache]: Unified abstract cache interface implementing both [BloomCacheReader]
///   and [BloomCacheWriter].
/// - [BloomCacheReader]: Interface Segregation Principle (ISP) read interface providing
///   [BloomCacheReader.get] and [BloomCacheReader.getOrSet].
/// - [BloomCacheWriter]: ISP write/mutation interface providing [BloomCacheWriter.set],
///   [BloomCacheWriter.delete], [BloomCacheWriter.clear], and tag invalidation methods
///   ([BloomCacheWriter.invalidateTag], [BloomCacheWriter.invalidateTags]).
///
/// ### Storage Backends
/// - [InMemoryCache]: Fast in-memory cache bounded by [InMemoryCache.maxCapacity] with
///   Least-Recently-Used (LRU) eviction and O(1) tag invalidation.
/// - [DatabaseCache]: SQL database persistence backed by `package:bloom_db` (compatible with
///   PostgreSQL and SQLite) with lazy table initialization and tag association tables.
/// - [RedisCache]: Distributed cache backed by Redis via `package:redis` with millisecond-precision
///   native TTL (`PX`), prefix namespacing, and Redis SET-based tag grouping.
///
/// ### HTTP Caching Middleware
/// - [BloomCacheMiddleware]: Pluggable middleware for `package:bloom_server` that caches
///   idempotent GET responses, respects `Cache-Control` / `x-bloom-no-cache` opt-outs, and
///   adds `x-bloom-cache: HIT`/`MISS` response headers.
///
/// ### Example Usage
/// ```dart
/// import 'package:bloom_cache/bloom_cache.dart';
///
/// void main() async {
///   // 1. Initialize an in-memory cache bounded to 1,000 items
///   final cache = InMemoryCache(maxCapacity: 1000);
///
///   // 2. Store a value with tags and a 10-minute TTL
///   await cache.set(
///     'article:42',
///     {'title': 'Bloom Architecture', 'views': 1200},
///     ttl: const Duration(minutes: 10),
///     tags: ['articles', 'author:1'],
///   );
///
///   // 3. Read cached JSON payload
///   final article = await cache.get<Map<String, dynamic>>('article:42');
///   print(article?['title']); // "Bloom Architecture"
///
///   // 4. getOrSet: computes and caches if missing; deduplicates concurrent callers
///   final stats = await cache.getOrSet<Map<String, dynamic>>(
///     'dashboard:stats',
///     () async {
///       return {'activeUsers': 420, 'updatedAt': DateTime.now().toIso8601String()};
///     },
///     ttl: const Duration(minutes: 5),
///   );
///   print(stats['activeUsers']); // 420
///
///   // 5. Invalidate all entries tagged with 'articles'
///   await cache.invalidateTag('articles');
/// }
/// ```
library;

export 'src/cache.dart';
export 'src/in_memory_cache.dart';
export 'src/database_cache.dart';
export 'src/redis_cache.dart';
export 'src/cache_middleware.dart';

