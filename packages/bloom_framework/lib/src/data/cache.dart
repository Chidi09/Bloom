// lib/src/data/cache.dart
import 'dart:async';
import 'dart:collection';
import '../core/logger.dart';

/// A single cached query record containing fetched data, timestamps, and TTL settings.
///
/// Encapsulates the normalized [key], cached [data] payload, last [updatedAt] timestamp,
/// and TTL durations ([staleTime], [cacheTime]).
///
/// Example:
/// ```dart
/// final entry = QueryCacheEntry<List<String>>(
///   key: ['posts', 'featured'],
///   data: ['Post 1', 'Post 2'],
///   updatedAt: DateTime.now(),
///   staleTime: const Duration(minutes: 2),
/// );
/// ```
class QueryCacheEntry<T> {
  /// Normalized key list uniquely identifying this query.
  final List<dynamic> key;

  /// Cached data payload.
  T? data;

  /// Timestamp when this entry was last fetched or updated.
  DateTime updatedAt;

  /// Duration after which data is considered stale and background revalidation should occur.
  Duration staleTime;

  /// Maximum duration to keep this entry in memory before garbage collection.
  Duration cacheTime;

  /// Whether this entry has been explicitly invalidated or marked stale.
  bool isStale;

  /// Creates a [QueryCacheEntry] record.
  QueryCacheEntry({
    required this.key,
    this.data,
    required this.updatedAt,
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.isStale = false,
  });

  /// Whether this cache entry has exceeded its [cacheTime] lifetime and should be evicted.
  bool get isExpired =>
      DateTime.now().difference(updatedAt) > cacheTime;

  /// Whether this cache entry is stale and should be revalidated on access.
  bool get shouldRevalidate =>
      isStale || DateTime.now().difference(updatedAt) > staleTime;
}

/// Global query cache manager for Bloom Data with automated periodic TTL garbage collection and request deduplication.
///
/// Provides in-memory caching, stale-while-revalidate invalidation cascades,
/// and concurrent in-flight request deduplication across widget subtrees.
///
/// Example:
/// ```dart
/// BloomData.setQueryData(['user', 42], (_) => {'name': 'Alice'});
/// final user = BloomData.getQueryData<Map<String, dynamic>>(['user', 42]);
/// BloomData.invalidateQueries(['user']);
/// ```
class BloomData {
  static final Map<String, QueryCacheEntry<dynamic>> _cache =
      HashMap<String, QueryCacheEntry<dynamic>>();
  static final Map<String, StreamController<void>> _invalidationControllers =
      HashMap<String, StreamController<void>>();
  static final Map<String, Completer<dynamic>> _inFlightRequests =
      HashMap<String, Completer<dynamic>>();
  static final Map<String, int> _listenerCounts = HashMap<String, int>();

  static Timer? _gcTimer;

  /// Starts automated periodic garbage collection running every [interval] (defaults to 5 minutes).
  ///
  /// Example:
  /// ```dart
  /// BloomData.startGarbageCollector(interval: const Duration(minutes: 10));
  /// ```
  static void startGarbageCollector({Duration interval = const Duration(minutes: 5)}) {
    _gcTimer?.cancel();
    _gcTimer = Timer.periodic(interval, (_) => garbageCollect());
  }

  /// Stops automated periodic garbage collection.
  static void stopGarbageCollector() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  /// Converts a key list (e.g. `['users', 42, 'posts']`) into a deterministic normalized string key.
  ///
  /// Example:
  /// ```dart
  /// print(BloomData.normalizeKey(['users', 42])); // 'users:42'
  /// ```
  static String normalizeKey(List<dynamic> key) => key.map(_canonical).join(':');

  static String _canonical(dynamic e) {
    if (e is Map) {
      final entries = e.entries.map((kv) => '${kv.key}: ${_canonical(kv.value)}').toList()..sort();
      return '{${entries.join(', ')}}';
    }
    if (e is Iterable) return '[${e.map(_canonical).join(', ')}]';
    return e.toString();
  }

  /// Checks whether a [candidateKey] matches a given [prefix] key list.
  ///
  /// Example:
  /// ```dart
  /// BloomData.matchesKey(['users', 42, 'profile'], ['users', 42]); // true
  /// ```
  static bool matchesKey(List<dynamic> candidateKey, List<dynamic> prefix) {
    if (prefix.isEmpty) return true;
    if (candidateKey.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (_canonical(candidateKey[i]) != _canonical(prefix[i])) {
        return false;
      }
    }
    return true;
  }

  /// Invalidates all cached queries matching [keyPrefix].
  ///
  /// All active listeners matching the prefix trigger background revalidation.
  ///
  /// Example:
  /// ```dart
  /// BloomData.invalidateQueries(['users']);
  /// ```
  static void invalidateQueries(List<dynamic> keyPrefix) {
    final prefixStr = normalizeKey(keyPrefix);
    logger.debug('BloomData: Invalidating queries matching [$prefixStr]');

    final matchingKeys = <String>{};
    for (final entry in _cache.values) {
      if (matchesKey(entry.key, keyPrefix)) {
        entry.isStale = true;
        matchingKeys.add(normalizeKey(entry.key));
      }
    }

    // Also reach queries that have never cached a successful result.
    for (final keyStr in _invalidationControllers.keys) {
      if (_matchesNormalizedPrefix(keyStr, keyPrefix)) matchingKeys.add(keyStr);
    }

    for (final keyStr in matchingKeys) {
      _invalidationControllers[keyStr]?.add(null);
    }
  }

  static bool _matchesNormalizedPrefix(String keyStr, List<dynamic> prefix) {
    final prefixStr = normalizeKey(prefix);
    if (prefixStr.isEmpty || keyStr == prefixStr) return true;
    return keyStr.startsWith('$prefixStr:');
  }

  /// Marks queries matching [keyPrefix] as stale without triggering immediate refetch.
  ///
  /// Example:
  /// ```dart
  /// BloomData.markStale(['posts']);
  /// ```
  static void markStale(List<dynamic> keyPrefix) {
    for (final entry in _cache.values) {
      if (matchesKey(entry.key, keyPrefix)) {
        entry.isStale = true;
      }
    }
  }

  /// Sets cache data directly for a given [key] using an [updater] transformation function.
  ///
  /// Example:
  /// ```dart
  /// BloomData.setQueryData<User>(['user', 1], (old) => old?.copyWith(name: 'Bob'));
  /// ```
  static void setQueryData<T>(List<dynamic> key, T? Function(T? oldData) updater) {
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

  /// Retrieves cached query data for [key] if available and unexpired, or returns `null`.
  ///
  /// Example:
  /// ```dart
  /// final cachedUser = BloomData.getQueryData<User>(['user', 1]);
  /// ```
  static T? getQueryData<T>(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    final entry = _cache[keyStr];
    if (entry != null) {
      if (entry.isExpired) {
        _cache.remove(keyStr);
        _disposeController(keyStr);
        return null;
      }
      return entry.data as T?;
    }
    return null;
  }

  /// Retrieves a full cached [QueryCacheEntry] for [key] if available and unexpired.
  ///
  /// Example:
  /// ```dart
  /// final entry = BloomData.getEntry<User>(['user', 1]);
  /// if (entry != null && entry.shouldRevalidate) { ... }
  /// ```
  static QueryCacheEntry<T>? getEntry<T>(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    final entry = _cache[keyStr];
    if (entry != null && entry.isExpired) {
      _cache.remove(keyStr);
      _disposeController(keyStr);
      return null;
    }
    return entry as QueryCacheEntry<T>?;
  }

  /// Removes a specific query cache entry by [key].
  ///
  /// Example:
  /// ```dart
  /// BloomData.removeEntry(['user', 1]);
  /// ```
  static void removeEntry(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    _cache.remove(keyStr);
    _disposeController(keyStr);
  }

  /// Stores or updates a raw cache [entry] in memory.
  static void putEntry<T>(QueryCacheEntry<T> entry) {
    final keyStr = normalizeKey(entry.key);
    _cache[keyStr] = entry;
  }

  /// Removes all expired entries from cache memory to reclaim resources.
  ///
  /// Returns the number of entries evicted.
  ///
  /// Example:
  /// ```dart
  /// final evictedCount = BloomData.garbageCollect();
  /// ```
  static int garbageCollect() {
    final expiredKeys = <String>[];
    for (final entryKey in _cache.keys) {
      final entry = _cache[entryKey]!;
      if (entry.isExpired && (_listenerCounts[entryKey] ?? 0) == 0) {
        expiredKeys.add(entryKey);
      }
    }
    for (final k in expiredKeys) {
      _cache.remove(k);
      _disposeController(k);
    }
    if (expiredKeys.isNotEmpty) {
      logger.debug('BloomData: Evicted ${expiredKeys.length} expired query cache entries.');
    }
    return expiredKeys.length;
  }

  /// Listens for invalidation events broadcast on a specific query [key].
  ///
  /// Returns a broadcast [Stream]. Callers must call [releaseListener] on teardown.
  static Stream<void> onInvalidated(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    _listenerCounts[keyStr] = (_listenerCounts[keyStr] ?? 0) + 1;
    return _invalidationControllers
        .putIfAbsent(keyStr, () => StreamController<void>.broadcast())
        .stream;
  }

  /// Releases a listener slot previously acquired via [onInvalidated].
  static void releaseListener(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    final count = _listenerCounts[keyStr] ?? 0;
    if (count <= 1) {
      _listenerCounts.remove(keyStr);
    } else {
      _listenerCounts[keyStr] = count - 1;
    }
  }

  /// Closes and removes the invalidation controller for [keyStr] only if it has
  /// no live listeners, leaving it open and untouched otherwise.
  static void _disposeController(String keyStr) {
    if ((_listenerCounts[keyStr] ?? 0) == 0) {
      _invalidationControllers.remove(keyStr)?.close();
    }
  }

  /// Request deduplication: ensures multiple concurrent fetches for the same [key] share a single [Future].
  ///
  /// Example:
  /// ```dart
  /// final data = await BloomData.deduplicate(['items'], () => fetchItemsFromApi());
  /// ```
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

  /// Refreshes all currently stale cached queries across the application.
  static void refreshStaleQueries() {
    for (final entry in _cache.values) {
      if (entry.shouldRevalidate) {
        final keyStr = normalizeKey(entry.key);
        _invalidationControllers[keyStr]?.add(null);
      }
    }
  }

  /// Total count of cached query entries currently in memory.
  static int get entryCount => _cache.length;

  /// Returns a snapshot summary of all active cache entries for DevTools visual inspection.
  static List<Map<String, dynamic>> dumpCache() {
    final list = <Map<String, dynamic>>[];
    for (final entry in _cache.values) {
      list.add({
        'key': normalizeKey(entry.key),
        'updatedAt': entry.updatedAt.toIso8601String(),
        'isStale': entry.isStale,
        'isExpired': entry.isExpired,
        'staleTimeMs': entry.staleTime.inMilliseconds,
        'cacheTimeMs': entry.cacheTime.inMilliseconds,
        'hasData': entry.data != null,
      });
    }
    return list;
  }

  /// Clears all query cache entries, cancels pending requests, and resets listeners.
  ///
  /// Example:
  /// ```dart
  /// BloomData.clear();
  /// ```
  static void clear() {
    _cache.clear();
    for (final ctrl in _invalidationControllers.values) {
      ctrl.close();
    }
    _invalidationControllers.clear();
    _inFlightRequests.clear();
    _listenerCounts.clear();
  }
}
