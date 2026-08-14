// lib/src/data/cache.dart
import 'dart:async';
import 'dart:collection';
import '../core/logger.dart';

class QueryCacheEntry<T> {
  final List<dynamic> key;
  T? data;
  DateTime updatedAt;
  Duration staleTime;
  Duration cacheTime;
  bool isStale;

  QueryCacheEntry({
    required this.key,
    this.data,
    required this.updatedAt,
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.isStale = false,
  });

  bool get isExpired =>
      DateTime.now().difference(updatedAt) > cacheTime;

  bool get shouldRevalidate =>
      isStale || DateTime.now().difference(updatedAt) > staleTime;
}

/// Global query cache manager for Bloom Data.
class BloomData {
  static final Map<String, QueryCacheEntry<dynamic>> _cache =
      HashMap<String, QueryCacheEntry<dynamic>>();
  static final Map<String, StreamController<void>> _invalidationControllers =
      HashMap<String, StreamController<void>>();
  static final Map<String, Completer<dynamic>> _inFlightRequests =
      HashMap<String, Completer<dynamic>>();

  /// Converts a key list like `['users', 42, 'posts']` to a normalized string key.
  static String normalizeKey(List<dynamic> key) {
    return key.map((e) => e.toString()).join(':');
  }

  /// Check if a query key matches a given prefix key.
  static bool matchesKey(List<dynamic> candidateKey, List<dynamic> prefix) {
    if (prefix.isEmpty) return true;
    if (candidateKey.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (candidateKey[i].toString() != prefix[i].toString()) {
        return false;
      }
    }
    return true;
  }

  /// Invalidate queries matching [keyPrefix]. All active listeners will trigger background revalidation.
  static void invalidateQueries(List<dynamic> keyPrefix) {
    final prefixStr = normalizeKey(keyPrefix);
    logger.debug('BloomData: Invalidating queries matching [$prefixStr]');

    final matchingKeys = <String>[];
    for (final entryKey in _cache.keys) {
      final entry = _cache[entryKey]!;
      if (matchesKey(entry.key, keyPrefix)) {
        entry.isStale = true;
        matchingKeys.add(entryKey);
      }
    }

    for (final keyStr in matchingKeys) {
      _invalidationControllers[keyStr]?.add(null);
    }
  }

  /// Mark queries matching [keyPrefix] as stale without immediately refetching.
  static void markStale(List<dynamic> keyPrefix) {
    for (final entry in _cache.values) {
      if (matchesKey(entry.key, keyPrefix)) {
        entry.isStale = true;
      }
    }
  }

  /// Set cache data directly for a given key.
  static void setQueryData<T>(List<dynamic> key, T Function(T? oldData) updater) {
    final keyStr = normalizeKey(key);
    final existing = _cache[keyStr] as QueryCacheEntry<T>?;
    final newData = updater(existing?.data);

    _cache[keyStr] = QueryCacheEntry<T>(
      key: key,
      data: newData,
      updatedAt: DateTime.now(),
      staleTime: existing?.staleTime ?? const Duration(minutes: 5),
      cacheTime: existing?.cacheTime ?? const Duration(minutes: 30),
      isStale: false,
    );

    _invalidationControllers[keyStr]?.add(null);
  }

  /// Get cached query data if available.
  static T? getQueryData<T>(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    final entry = _cache[keyStr];
    if (entry != null && !entry.isExpired) {
      return entry.data as T?;
    }
    return null;
  }

  /// Get full cache entry for internal query lifecycle management.
  static QueryCacheEntry<T>? getEntry<T>(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    return _cache[keyStr] as QueryCacheEntry<T>?;
  }

  /// Store or update a cache entry.
  static void putEntry<T>(QueryCacheEntry<T> entry) {
    final keyStr = normalizeKey(entry.key);
    _cache[keyStr] = entry;
  }

  /// Listen for invalidation events on a specific query key.
  static Stream<void> onInvalidated(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    return _invalidationControllers
        .putIfAbsent(keyStr, () => StreamController<void>.broadcast())
        .stream;
  }

  /// Request deduplication: ensures multiple simultaneous fetches for the same key share a single Future.
  static Future<T> deduplicate<T>(List<dynamic> key, Future<T> Function() fetcher) {
    final keyStr = normalizeKey(key);
    if (_inFlightRequests.containsKey(keyStr)) {
      return _inFlightRequests[keyStr]!.future as Future<T>;
    }

    final completer = Completer<T>();
    _inFlightRequests[keyStr] = completer;

    fetcher().then((val) {
      _inFlightRequests.remove(keyStr);
      completer.complete(val);
    }).catchError((err, st) {
      _inFlightRequests.remove(keyStr);
      completer.completeError(err, st);
    });

    return completer.future;
  }

  /// Refreshes all currently stale cached queries.
  static void refreshStaleQueries() {
    for (final entry in _cache.values) {
      if (entry.shouldRevalidate) {
        final keyStr = normalizeKey(entry.key);
        _invalidationControllers[keyStr]?.add(null);
      }
    }
  }

  /// Clear all query cache entries.
  static void clear() {
    _cache.clear();
    for (final ctrl in _invalidationControllers.values) {
      ctrl.close();
    }
    _invalidationControllers.clear();
    _inFlightRequests.clear();
  }
}
