/// Server-side caching abstraction and backends for Bloom applications.
///
/// Modeled on `djangors-cache`, this package provides unified key-value caching
/// across in-memory LRU, SQL database (`bloom_db`), and Redis backends with
/// automatic cache stampede deduplication and HTTP response caching middleware.
///
/// Example usage:
/// ```dart
/// import 'package:bloom_cache/bloom_cache.dart';
///
/// void main() async {
///   // Create an in-memory cache bounded to 1,000 items
///   final cache = InMemoryCache(maxCapacity: 1000);
///
///   // Basic get / set
///   await cache.set('greeting', 'Hello, Bloom!', ttl: Duration(minutes: 10));
///   final greeting = await cache.get<String>('greeting');
///   print(greeting); // "Hello, Bloom!"
///
///   // getOrSet: computes and caches if missing; deduplicates concurrent callers
///   final stats = await cache.getOrSet<Map<String, dynamic>>(
///     'dashboard:stats',
///     () async {
///       return {'activeUsers': 420, 'updatedAt': DateTime.now().toIso8601String()};
///     },
///     ttl: Duration(minutes: 5),
///   );
///
///   print(stats['activeUsers']); // 420
/// }
/// ```
library;

export 'src/cache.dart';
export 'src/in_memory_cache.dart';
export 'src/database_cache.dart';
export 'src/redis_cache.dart';
export 'src/cache_middleware.dart';

