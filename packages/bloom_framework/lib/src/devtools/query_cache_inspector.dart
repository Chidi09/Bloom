// lib/src/devtools/query_cache_inspector.dart
import 'dart:collection';
import '../data/cache.dart';

class QueryCacheDescriptor {
  final String key;
  final DateTime updatedAt;
  final bool isStale;
  final bool isExpired;
  final int staleTimeMs;
  final int cacheTimeMs;
  final bool hasData;

  QueryCacheDescriptor({
    required this.key,
    required this.updatedAt,
    required this.isStale,
    required this.isExpired,
    required this.staleTimeMs,
    required this.cacheTimeMs,
    required this.hasData,
  });

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
