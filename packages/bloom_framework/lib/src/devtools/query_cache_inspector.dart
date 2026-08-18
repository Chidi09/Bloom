// lib/src/devtools/query_cache_inspector.dart
import 'dart:collection';
import '../data/cache.dart';

/// Visual descriptor for a cached query record displayed in DevTools.
class QueryCacheDescriptor {
  /// Query cache key string.
  final String key;

  /// Last updated timestamp.
  final DateTime updatedAt;

  /// Whether the entry is considered stale.
  final bool isStale;

  /// Whether the entry has expired past its TTL.
  final bool isExpired;

  /// Configured stale time in milliseconds.
  final int staleTimeMs;

  /// Configured cache retention time in milliseconds.
  final int cacheTimeMs;

  /// Whether non-null data is currently stored.
  final bool hasData;

  /// Creates a [QueryCacheDescriptor].
  QueryCacheDescriptor({
    required this.key,
    required this.updatedAt,
    required this.isStale,
    required this.isExpired,
    required this.staleTimeMs,
    required this.cacheTimeMs,
    required this.hasData,
  });

  /// Serializes descriptor to JSON map.
  Map<String, dynamic> toJson() => {
        'key': key,
        'updatedAt': updatedAt.toIso8601String(),
        'isStale': isStale,
        'isExpired': isExpired,
        'staleTimeMs': staleTimeMs,
        'cacheTimeMs': cacheTimeMs,
        'hasData': hasData,
      };
}

/// Visual query cache inspection and management engine for Bloom DevTools.
class BloomQueryCacheInspector {
  /// Inspects all active query cache entries.
  static List<QueryCacheDescriptor> inspectAll() {
    final raw = BloomData.dumpCache();
    final list = raw.map((m) => QueryCacheDescriptor(
          key: m['key'] as String,
          updatedAt: DateTime.parse(m['updatedAt'] as String),
          isStale: m['isStale'] as bool,
          isExpired: m['isExpired'] as bool,
          staleTimeMs: m['staleTimeMs'] as int,
          cacheTimeMs: m['cacheTimeMs'] as int,
          hasData: m['hasData'] as bool,
        )).toList();
    return UnmodifiableListView(list);
  }

  /// Purges an individual query cache key.
  static void purgeKey(List<dynamic> key) {
    BloomData.removeEntry(key);
  }

  /// Marks a query key as stale to trigger background revalidation.
  static void markStale(List<dynamic> key) {
    BloomData.markStale(key);
  }

  /// Purges all query cache entries immediately.
  static void purgeAll() {
    BloomData.clear();
  }
}
