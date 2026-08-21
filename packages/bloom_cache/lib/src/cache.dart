// lib/src/cache.dart
import 'dart:async';
import 'dart:convert';

/// Lean read-only cache interface (Interface Segregation Principle).
abstract class BloomCacheReader {
  /// Retrieves the value associated with [key] if present and not expired.
  ///
  /// Returns `null` if the key is missing or has expired.
  Future<T?> get<T>(String key);

  /// Retrieves [key] if present and unexpired; otherwise executes [compute],
  /// caches the returned value under [key] with optional [ttl], and returns it.
  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  });
}

/// Lean write-only/mutation cache interface (Interface Segregation Principle).
abstract class BloomCacheWriter {
  /// Stores [value] under [key] with an optional time-to-live [ttl].
  ///
  /// The [value] must be JSON-encodable (e.g. primitives, [Map], [List], or objects
  /// providing a `toJson()` method).
  Future<void> set<T>(String key, T value, {Duration? ttl});

  /// Deletes the cache entry associated with [key].
  Future<void> delete(String key);

  /// Clears all entries from this cache.
  Future<void> clear();
}

/// Server-side caching abstraction for Bloom applications.
///
/// Provides a unified key-value caching interface supporting in-memory LRU,
/// database-backed, and Redis backends. Cached values must be JSON-encodable
/// so they round-trip cleanly across in-memory and persistent backends.
abstract class BloomCache implements BloomCacheReader, BloomCacheWriter {
  /// Deduplication map tracking in-flight asynchronous computations to prevent
  /// cache stampedes (thundering herd problem) under concurrent requests.
  final Map<String, Future<dynamic>> _inFlight = {};

  @override
  Future<T?> get<T>(String key);

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl});

  @override
  Future<void> delete(String key);

  @override
  Future<void> clear();

  @override
  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  }) async {
    // 1. Fast check for an in-flight computation already in progress.
    if (_inFlight.containsKey(key)) {
      final inFlightFuture = _inFlight[key];
      if (inFlightFuture != null) {
        final result = await inFlightFuture;
        return result as T;
      }
    }

    // 2. Check existing cache value.
    final cached = await get<T>(key);
    if (cached != null) {
      return cached;
    }

    // 3. Double-check in-flight map in case another caller initiated during our get().
    if (_inFlight.containsKey(key)) {
      final inFlightFuture = _inFlight[key];
      if (inFlightFuture != null) {
        final result = await inFlightFuture;
        return result as T;
      }
    }

    // 4. Initiate computation and store in in-flight deduplication map.
    final future = () async {
      final value = await compute();
      await set<T>(key, value, ttl: ttl);
      return value;
    }();

    _inFlight[key] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }
}

/// Helper function to retrieve or compute a template fragment or expensive value.
///
/// Mirrors `djangors-cache`'s `get_or_set_fragment` entrypoint.
Future<T> getOrSetFragment<T>(
  BloomCache cache,
  String key,
  Future<T> Function() compute, {
  Duration? ttl,
}) {
  return cache.getOrSet<T>(key, compute, ttl: ttl);
}

/// Decodes raw JSON data or strings into typed value [T].
T? decodeCacheValue<T>(dynamic raw) {
  if (raw == null) return null;

  final decoded = raw is String ? jsonDecode(raw) : raw;
  if (decoded == null) return null;

  if (decoded is T) {
    return decoded;
  }

  // Handle Map casting
  if (decoded is Map) {
    if (identical(T, Map<String, dynamic>) || identical(T, dynamic)) {
      return decoded.cast<String, dynamic>() as T;
    }
    return decoded as T;
  }

  // Handle List casting
  if (decoded is List) {
    if (T == List<String>) return decoded.cast<String>() as T;
    if (T == List<int>) return decoded.cast<int>() as T;
    if (T == List<double>) return decoded.cast<double>() as T;
    if (T == List<dynamic>) return decoded.cast<dynamic>() as T;
    if (T == List<Map<String, dynamic>>) {
      return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList() as T;
    }
  }

  return decoded as T;
}
