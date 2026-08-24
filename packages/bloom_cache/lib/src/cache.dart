// lib/src/cache.dart
import 'dart:async';
import 'dart:convert';

/// Lean read-only cache interface adhering to the Interface Segregation Principle.
///
/// Consumers that only require cache read operations (such as query services or
/// read-only view models) can depend on [BloomCacheReader] without exposing
/// write or invalidation capabilities.
///
/// Example:
/// ```dart
/// Future<UserProfile> loadProfile(BloomCacheReader cache, String userId) async {
///   final cached = await cache.get<Map<String, dynamic>>('user:$userId');
///   if (cached != null) return UserProfile.fromJson(cached);
///   // fetch from DB...
/// }
/// ```
abstract class BloomCacheReader {
  /// Retrieves the value associated with [key] if present and not expired.
  ///
  /// The stored JSON payload is automatically deserialized and cast to [T]
  /// via [decodeCacheValue].
  ///
  /// Returns `null` if the [key] does not exist or if its time-to-live has expired.
  ///
  /// Example:
  /// ```dart
  /// final user = await cache.get<Map<String, dynamic>>('user:101');
  /// final count = await cache.get<int>('page_views');
  /// ```
  Future<T?> get<T>(String key);

  /// Retrieves the value for [key] if present and unexpired; otherwise invokes
  /// [compute], caches the returned value under [key] with optional [ttl] and [tags],
  /// and returns the result.
  ///
  /// If multiple concurrent asynchronous callers request the same missing [key],
  /// the underlying [BloomCache] implementation deduplicates the computation so that
  /// [compute] is invoked only once, preventing cache stampedes (thundering herds).
  ///
  /// Parameters:
  /// - [key]: The cache identifier to lookup or populate.
  /// - [compute]: The asynchronous computation factory to execute on cache miss.
  /// - [ttl]: Optional time-to-live duration before the newly stored entry expires.
  /// - [tags]: Optional list of cache tags to associate with the newly stored entry.
  ///
  /// Returns the cached or computed value of type [T].
  ///
  /// Example:
  /// ```dart
  /// final report = await cache.getOrSet<Map<String, dynamic>>(
  ///   'monthly_report:2026-08',
  ///   () => generateMonthlyReport(),
  ///   ttl: const Duration(hours: 1),
  ///   tags: ['reports', 'billing'],
  /// );
  /// ```
  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
    List<String>? tags,
  });
}

/// Lean write-only/mutation cache interface adhering to the Interface Segregation Principle.
///
/// Consumers that only require write or invalidation operations (such as event
/// listeners or background mutation jobs) can depend on [BloomCacheWriter].
///
/// Example:
/// ```dart
/// Future<void> onUserUpdated(BloomCacheWriter cache, String userId) async {
///   await cache.delete('user:$userId');
///   await cache.invalidateTag('users');
/// }
/// ```
abstract class BloomCacheWriter {
  /// Stores [value] under [key] with an optional time-to-live [ttl] and optional [tags].
  ///
  /// The [value] must be JSON-encodable (e.g. primitives, [Map], [List], or objects
  /// providing a `toJson()` method).
  ///
  /// If [ttl] is provided, the entry will be considered expired once the duration elapses.
  /// If [tags] is provided, the entry is indexed under those tags for bulk invalidation.
  /// When overwriting an existing key with new tags, any previously associated tags for
  /// that key are replaced.
  ///
  /// Example:
  /// ```dart
  /// await cache.set(
  ///   'post:12',
  ///   {'title': 'Bloom Release', 'published': true},
  ///   ttl: const Duration(hours: 2),
  ///   tags: ['posts', 'author:5'],
  /// );
  /// ```
  Future<void> set<T>(String key, T value, {Duration? ttl, List<String>? tags});

  /// Deletes the cache entry associated with [key].
  ///
  /// Also removes the [key] from any tag association indices. If [key] does not
  /// exist, this operation completes silently without throwing an error.
  ///
  /// Example:
  /// ```dart
  /// await cache.delete('session:token_123');
  /// ```
  Future<void> delete(String key);

  /// Clears all entries and all tag associations from this cache.
  ///
  /// Example:
  /// ```dart
  /// await cache.clear();
  /// ```
  Future<void> clear();

  /// Removes every entry labelled with [tag].
  ///
  /// Invalidation is atomic from the perspective of subsequent [get] calls.
  /// Specifying a tag that has no associated entries is a safe no-op.
  ///
  /// Example:
  /// ```dart
  /// await cache.invalidateTag('articles');
  /// ```
  Future<void> invalidateTag(String tag);

  /// Removes every entry labelled with ANY tag present in [tags] in a single pass.
  ///
  /// If an entry is tagged with multiple tags in [tags], it is deleted once without errors.
  /// If [tags] is empty or contains non-existent tags, this is a safe no-op.
  ///
  /// Example:
  /// ```dart
  /// await cache.invalidateTags(['articles', 'categories', 'homepage']);
  /// ```
  Future<void> invalidateTags(List<String> tags);
}

/// Server-side caching abstraction for Bloom applications.
///
/// Provides a unified key-value caching interface supporting in-memory LRU,
/// database-backed, and Redis backends. Cached values must be JSON-encodable
/// so they round-trip cleanly across in-memory and persistent backends.
///
/// Implements both [BloomCacheReader] and [BloomCacheWriter].
///
/// Example:
/// ```dart
/// final BloomCache cache = InMemoryCache(maxCapacity: 500);
///
/// await cache.set('config:rate_limit', 100, ttl: const Duration(minutes: 30));
/// final limit = await cache.get<int>('config:rate_limit');
/// ```
abstract class BloomCache implements BloomCacheReader, BloomCacheWriter {
  /// Deduplication map tracking in-flight asynchronous computations to prevent
  /// cache stampedes (thundering herd problem) under concurrent requests.
  final Map<String, Future<dynamic>> _inFlight = {};

  @override
  Future<T?> get<T>(String key);

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl, List<String>? tags});

  @override
  Future<void> delete(String key);

  @override
  Future<void> clear();

  @override
  Future<void> invalidateTag(String tag);

  @override
  Future<void> invalidateTags(List<String> tags);

  /// Retrieves the cached value for [key], or calls [compute] to generate, cache,
  /// and return it with cache stampede protection.
  ///
  /// If multiple concurrent asynchronous tasks invoke [getOrSet] for the same [key]
  /// simultaneously while the key is missing or being computed:
  /// 1. The first caller initiates [compute] and registers the in-flight [Future].
  /// 2. All subsequent callers await that identical in-flight [Future] without executing [compute].
  /// 3. Once computation finishes and the value is cached, all waiting callers receive the result.
  ///
  /// Parameters:
  /// - [key]: The cache key.
  /// - [compute]: The computation callback invoked if no cached value is present.
  /// - [ttl]: Optional duration after which the cached entry expires.
  /// - [tags]: Optional list of tags to label the stored cache entry for bulk invalidation.
  ///
  /// Returns the cached or computed value of type [T].
  @override
  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
    List<String>? tags,
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
      await set<T>(key, value, ttl: ttl, tags: tags);
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
/// Mirrors `djangors-cache`'s `get_or_set_fragment` entrypoint. Delegates directly
/// to [cache.getOrSet].
///
/// Example:
/// ```dart
/// final html = await getOrSetFragment(
///   cache,
///   'sidebar_html:user_1',
///   () => renderSidebar(user),
///   ttl: const Duration(minutes: 15),
/// );
/// ```
Future<T> getOrSetFragment<T>(
  BloomCache cache,
  String key,
  Future<T> Function() compute, {
  Duration? ttl,
}) {
  return cache.getOrSet<T>(key, compute, ttl: ttl);
}

/// Decodes raw JSON data or string payloads into a strongly-typed value [T].
///
/// Handles automatic type coercion and casting for:
/// - Primitives (`int`, `double`, `String`, `bool`).
/// - [Map] objects, casting to `Map<String, dynamic>`.
/// - [List] objects, casting to `List<String>`, `List<int>`, `List<double>`,
///   `List<dynamic>`, or `List<Map<String, dynamic>>`.
///
/// Returns `null` if [raw] is `null` or deserializes to `null`.
///
/// Example:
/// ```dart
/// final map = decodeCacheValue<Map<String, dynamic>>('{"name":"Bloom"}');
/// print(map?['name']); // "Bloom"
///
/// final list = decodeCacheValue<List<String>>('["a", "b", "c"]');
/// print(list?.length); // 3
/// ```
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

