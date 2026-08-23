import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:signals/signals.dart';

/// Execution status lifecycle of a [BloomQuery].
enum QueryStatus {
  /// Query is initialized but has not commenced fetching (or [BloomQuery.enabled] is `false`).
  idle,

  /// Initial network fetch is in progress with no cached data available.
  loading,

  /// Query resolved successfully and valid data is accessible in [BloomQuery.data].
  success,

  /// Query execution encountered an unhandled exception, accessible in [BloomQuery.error].
  error,
}

/// A cached record containing fetched data, timestamps, and TTL settings.
///
/// Tracks the freshness and eviction lifecycle of cached query results managed by [BloomData].
class QueryCacheEntry<T> {
  /// The structured query cache key identifying this record.
  final List<dynamic> key;

  /// The cached data payload, or `null` if uninitialized.
  T? data;

  /// The timestamp when this record was last successfully fetched or updated.
  DateTime updatedAt;

  /// Duration after [updatedAt] during which data is considered fresh before revalidation is needed.
  Duration staleTime;

  /// Duration after [updatedAt] after which data is completely expired and evicted from use.
  Duration cacheTime;

  /// Whether this entry has been explicitly marked as stale via invalidation.
  bool isStale;

  /// Creates a [QueryCacheEntry] recording [key], [data], and freshness parameters.
  QueryCacheEntry({
    required this.key,
    this.data,
    required this.updatedAt,
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.isStale = false,
  });

  /// Whether the entry has exceeded its [cacheTime] TTL relative to `DateTime.now()`.
  bool get isExpired => DateTime.now().difference(updatedAt) > cacheTime;

  /// Whether this entry is flagged as [isStale] or has exceeded its [staleTime] duration.
  bool get shouldRevalidate =>
      isStale || DateTime.now().difference(updatedAt) > staleTime;
}

/// Global query cache manager and request deduplicator for Bloom JS Native applications.
///
/// [BloomData] provides a centralized, pure-Dart memory cache for asynchronous queries:
/// - **Key Normalization**: Deterministically serializes complex structured keys (Strings, Lists, Maps)
///   via [normalizeKey].
/// - **Request Deduplication**: Collapses concurrent identical requests into a single in-flight `Future`
///   via [deduplicate].
/// - **Cache Invalidation**: Notifies active [BloomQuery] instances via [invalidateQueries] using prefix matching.
/// - **Direct Manipulation**: Allows optimistic cache writing via [setQueryData] and direct inspection via [getQueryData].
/// - **SSR Dehydration & Hydration**: Serializes cache snapshots to JSON via [dehydrate] or [dehydrateToScriptTag],
///   and restores them on the client via [hydrate] or [hydrateFromJson] with zero redundant fetches.
///
/// ### SSR & Browser Compatibility
/// Pure Dart with zero Flutter or DOM dependencies. In SSR environments, [BloomData] can be pre-populated
/// with server data before rendering or cleared between requests via [clear].
///
/// ### Example
/// ```dart
/// // Manually prime or update the cache
/// BloomData.setQueryData<User>(['user', 123], (old) => updatedUser);
///
/// // Invalidate all queries under the 'user' prefix
/// BloomData.invalidateQueries(['user']);
/// ```
///
/// See also:
/// - [BloomQuery], the reactive query coordinator that reads from and populates [BloomData].
/// - [BloomInfiniteQuery], for paginated and cursor-based infinite queries.
/// - [BloomMutation], for executing mutations that invalidate or optimistically update [BloomData].
class BloomData {
  BloomData._();

  static final Map<String, QueryCacheEntry<dynamic>> _cache =
      HashMap<String, QueryCacheEntry<dynamic>>();
  static final Map<String, StreamController<void>> _invalidationControllers =
      HashMap<String, StreamController<void>>();
  static final Map<String, Completer<dynamic>> _inFlightRequests =
      HashMap<String, Completer<dynamic>>();

  /// Converts a structured key list into a normalized, canonical string key.
  ///
  /// Maps and Iterables within the key are recursively normalized and sorted to guarantee
  /// identical canonical string representations regardless of map key insertion order.
  ///
  /// ```dart
  /// final keyStr = BloomData.normalizeKey(['tasks', {'status': 'done', 'page': 1}]);
  /// // Produces: "tasks:{page: 1, status: done}"
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

  /// Invalidates all cached queries matching [keyPrefix] and notifies active [BloomQuery] subscribers.
  ///
  /// Sets `isStale = true` on matching cache entries and triggers invalidation streams, causing
  /// active enabled [BloomQuery] instances to automatically refetch in the background.
  ///
  /// An empty prefix `[]` matches and invalidates all queries in the cache.
  ///
  /// ```dart
  /// // Invalidate all tasks
  /// BloomData.invalidateQueries(['tasks']);
  ///
  /// // Invalidate a specific task
  /// BloomData.invalidateQueries(['tasks', 42]);
  /// ```
  static void invalidateQueries(List<dynamic> keyPrefix) {
    final prefixStr = normalizeKey(keyPrefix);
    final matchingKeys = <String>{};
    for (final entry in _cache.values) {
      if (_matchesKey(entry.key, keyPrefix)) {
        entry.isStale = true;
        matchingKeys.add(normalizeKey(entry.key));
      }
    }
    for (final keyStr in _invalidationControllers.keys) {
      if (prefixStr.isEmpty || keyStr == prefixStr || keyStr.startsWith('$prefixStr:')) {
        matchingKeys.add(keyStr);
      }
    }
    for (final keyStr in matchingKeys) {
      _invalidationControllers[keyStr]?.add(null);
    }
  }

  static bool _matchesKey(List<dynamic> candidateKey, List<dynamic> prefix) {
    if (prefix.isEmpty) return true;
    if (candidateKey.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (_canonical(candidateKey[i]) != _canonical(prefix[i])) return false;
    }
    return true;
  }

  /// Directly updates cached query data for [key] using a transformation [updater] callback.
  ///
  /// Creates a new [QueryCacheEntry] or updates an existing one, marks it fresh (`isStale = false`),
  /// and notifies invalidation listeners.
  ///
  /// ```dart
  /// BloomData.setQueryData<List<Task>>(['tasks'], (oldTasks) => [...?oldTasks, newTask]);
  /// ```
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

  /// Retrieves non-expired cached query data for [key], or returns `null` if absent or expired.
  ///
  /// ```dart
  /// final cachedUser = BloomData.getQueryData<User>(['user', 'current']);
  /// ```
  static T? getQueryData<T>(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    final entry = _cache[keyStr];
    if (entry != null && !entry.isExpired) {
      return entry.data as T?;
    }
    return null;
  }

  /// Deduplicates concurrent asynchronous requests sharing the same cache [key].
  ///
  /// If a request for [key] is already in-flight, returns the existing active `Future`.
  /// Otherwise, executes [fetcher], broadcasts the result to all callers, and cleans up upon completion.
  ///
  /// ```dart
  /// final result = await BloomData.deduplicate(['items'], () => client.get('/items'));
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
    }).catchError((Object err, StackTrace st) {
      _inFlightRequests.remove(keyStr);
      completer.completeError(err, st);
    });

    return completer.future;
  }

  /// Returns a broadcast [Stream] that emits whenever queries matching [key] are invalidated.
  ///
  /// Subscribed to by [BloomQuery] to trigger background re-fetching.
  static Stream<void> onInvalidated(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    return _invalidationControllers
        .putIfAbsent(keyStr, () => StreamController<void>.broadcast())
        .stream;
  }

  /// Directly inserts or overwrites a [QueryCacheEntry] in the cache.
  static void putEntry<T>(QueryCacheEntry<T> entry) {
    _cache[normalizeKey(entry.key)] = entry;
  }

  /// Retrieves the raw [QueryCacheEntry] for [key], returning `null` if missing or expired.
  static QueryCacheEntry<T>? getEntry<T>(List<dynamic> key) {
    final entry = _cache[normalizeKey(key)];
    if (entry != null && !entry.isExpired) return entry as QueryCacheEntry<T>?;
    return null;
  }

  /// Serializes the current [BloomData] cache into a plain, JSON-encodable Map.
  ///
  /// Extracts cache records, preserving structured query keys, data payloads,
  /// timestamps ([QueryCacheEntry.updatedAt]), [QueryCacheEntry.staleTime],
  /// [QueryCacheEntry.cacheTime], and [QueryCacheEntry.isStale] flags so freshness
  /// is preserved across process boundaries during SSR dehydration and client hydration.
  ///
  /// Pass [shouldDehydrate] to filter which entries are included (e.g. to exclude
  /// private session queries or other user data). By default, all non-expired entries
  /// are included.
  ///
  /// Supply [serialize] to convert custom domain objects into JSON-compatible values
  /// (such as `Map<String, dynamic>`). If [serialize] is omitted and an entry's data is
  /// not directly JSON-encodable (or does not provide a `.toJson()` method), an [ArgumentError]
  /// is thrown with details identifying the offending query key.
  ///
  /// ### End-to-End SSR Example
  /// ```dart
  /// // ── 1. Server-Side Rendering (SSR) ──────────────────────────────────
  /// // Populate cache during server render
  /// BloomData.setQueryData<User>(['user', 42], (_) => currentUser);
  ///
  /// // Dehydrate cache state to embed in the HTML response
  /// final dehydrated = BloomData.dehydrate(
  ///   serialize: (data, key) => data is User ? data.toJson() : data,
  /// );
  /// final scriptTag = BloomData.dehydrateToScriptTag(state: dehydrated);
  ///
  /// // ── 2. Client-Side Hydration ────────────────────────────────────────
  /// // On the browser, parse embedded JSON and hydrate BloomData before mounting
  /// BloomData.hydrate(
  ///   dehydrated,
  ///   deserialize: (json, key) => key.first == 'user' ? User.fromJson(json as Map<String, dynamic>) : json,
  /// );
  ///
  /// // A query constructed here finds the fresh cache entry and does NOT refetch:
  /// final userQuery = query<User>(
  ///   key: ['user', 42],
  ///   fetch: () => httpClient.get('/api/user/42'),
  /// );
  /// assert(userQuery.status.value == QueryStatus.success);
  /// assert(userQuery.isFetching.value == false);
  /// ```
  ///
  /// See also:
  /// - [hydrate], to restore dehydrated state on the client.
  /// - [dehydrateToScriptTag], to serialize and format as a safe HTML script tag.
  /// - [hydrateFromJson], to restore cache from a JSON string.
  static Map<String, dynamic> dehydrate({
    bool Function(QueryCacheEntry<dynamic> entry)? shouldDehydrate,
    dynamic Function(dynamic data, List<dynamic> key)? serialize,
  }) {
    final queries = <Map<String, dynamic>>[];

    for (final entry in _cache.values) {
      if (entry.isExpired) continue;
      if (shouldDehydrate != null && !shouldDehydrate(entry)) continue;

      final dynamic serializedData;
      if (serialize != null) {
        serializedData = serialize(entry.data, entry.key);
      } else {
        serializedData = entry.data;
      }

      // Verify that serializedData is JSON-encodable when no custom serialize function handles it.
      try {
        jsonEncode(serializedData);
      } catch (e) {
        throw ArgumentError(
          'Data for query key "${normalizeKey(entry.key)}" is not JSON-encodable: $e. '
          'Provide a custom `serialize` function to BloomData.dehydrate() to convert domain objects.',
        );
      }

      queries.add({
        'key': entry.key,
        'data': serializedData,
        'updatedAt': entry.updatedAt.toIso8601String(),
        'staleTimeMs': entry.staleTime.inMilliseconds,
        'cacheTimeMs': entry.cacheTime.inMilliseconds,
        'isStale': entry.isStale,
      });
    }

    return {'queries': queries};
  }

  /// Restores cache records from a [dehydratedState] Map into the [BloomData] cache.
  ///
  /// Reconstitutes [QueryCacheEntry] instances with their original timestamps,
  /// stale times, cache times, and stale flags. Freshly hydrated entries are
  /// immediately recognized as fresh by [BloomQuery] and [BloomInfiniteQuery],
  /// starting in [QueryStatus.success] with data present and avoiding redundant SSR double-fetches.
  ///
  /// Supply [deserialize] to convert raw JSON values back into domain models.
  ///
  /// ```dart
  /// BloomData.hydrate(
  ///   dehydratedMap,
  ///   deserialize: (rawJson, key) {
  ///     if (key.first == 'todos') {
  ///       return (rawJson as List).map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList();
  ///     }
  ///     return rawJson;
  ///   },
  /// );
  /// ```
  ///
  /// See also:
  /// - [dehydrate], to capture the cache into a serializable structure.
  /// - [hydrateFromJson], for direct hydration from a raw JSON string.
  static void hydrate(
    Map<String, dynamic> dehydratedState, {
    dynamic Function(dynamic json, List<dynamic> key)? deserialize,
  }) {
    final queriesRaw = dehydratedState['queries'];
    if (queriesRaw is! List) return;

    for (final item in queriesRaw) {
      if (item is! Map) continue;
      final itemMap = Map<String, dynamic>.from(item);
      final key = itemMap['key'] as List<dynamic>?;
      if (key == null) continue;

      final rawData = itemMap['data'];
      final data = deserialize != null ? deserialize(rawData, key) : rawData;

      final updatedAtStr = itemMap['updatedAt'] as String?;
      final updatedAt = updatedAtStr != null
          ? DateTime.tryParse(updatedAtStr) ?? DateTime.now()
          : DateTime.now();

      final staleTimeMs = itemMap['staleTimeMs'] as int? ??
          itemMap['staleTime'] as int? ??
          300000;
      final cacheTimeMs = itemMap['cacheTimeMs'] as int? ??
          itemMap['cacheTime'] as int? ??
          1800000;
      final isStale = itemMap['isStale'] as bool? ?? false;

      final entry = QueryCacheEntry<dynamic>(
        key: key,
        data: data,
        updatedAt: updatedAt,
        staleTime: Duration(milliseconds: staleTimeMs),
        cacheTime: Duration(milliseconds: cacheTimeMs),
        isStale: isStale,
      );

      putEntry(entry);
    }
  }

  /// Serializes cache state into an HTML `<script type="application/json">` tag string.
  ///
  /// Safely escapes the serialized JSON payload by encoding `<` as `\u003c`, preventing
  /// malicious script injection or HTML syntax collisions (e.g. embedded `</script>` tags).
  ///
  /// If [state] is omitted, automatically calls [dehydrate] with [shouldDehydrate] and [serialize].
  ///
  /// ```dart
  /// final scriptHtml = BloomData.dehydrateToScriptTag(
  ///   id: '__BLOOM_DATA__',
  ///   serialize: (data, key) => (data as dynamic).toJson(),
  /// );
  /// // Emits: '<script id="__BLOOM_DATA__" type="application/json">{...}</script>'
  /// ```
  ///
  /// See also:
  /// - [dehydrate], to generate the raw dehydrated state map.
  /// - [hydrateFromJson], to deserialize and load the script content on the client.
  static String dehydrateToScriptTag({
    Map<String, dynamic>? state,
    String id = '__BLOOM_DATA__',
    bool Function(QueryCacheEntry<dynamic> entry)? shouldDehydrate,
    dynamic Function(dynamic data, List<dynamic> key)? serialize,
  }) {
    final payload = state ??
        dehydrate(
          shouldDehydrate: shouldDehydrate,
          serialize: serialize,
        );
    final jsonStr = jsonEncode(payload);
    final safeJson = jsonStr.replaceAll('<', r'\u003c');
    return '<script id="$id" type="application/json">$safeJson</script>';
  }

  /// Parses a serialized JSON string and restores the cache entries into [BloomData].
  ///
  /// Pure Dart and safe for SSR, VM, and browser environments. Extracts the dehydrated
  /// state and populates the cache using [hydrate].
  ///
  /// In the browser, obtain the string content from the DOM element (e.g. via `package:web`)
  /// and pass it to this method before mounting components.
  ///
  /// ```dart
  /// // In client application bootstrap:
  /// const jsonString = '{"queries": [...]}';
  /// BloomData.hydrateFromJson(
  ///   jsonString,
  ///   deserialize: (json, key) => Todo.fromJson(json as Map<String, dynamic>),
  /// );
  /// ```
  ///
  /// See also:
  /// - [hydrate], to restore from an already-decoded Map.
  /// - [dehydrateToScriptTag], to generate the script tag during SSR.
  static void hydrateFromJson(
    String jsonString, {
    dynamic Function(dynamic json, List<dynamic> key)? deserialize,
  }) {
    final decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic>) {
      hydrate(decoded, deserialize: deserialize);
    } else if (decoded is Map) {
      hydrate(Map<String, dynamic>.from(decoded), deserialize: deserialize);
    }
  }

  /// Clears all cached query entries, active in-flight request deduplication trackers,
  /// and invalidation controllers.
  ///
  /// Recommended in test `tearDown()` or between SSR requests.
  ///
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
  }
}

/// A reactive asynchronous query manager with automatic caching, request deduplication,
/// background revalidation, and invalidation listening.
///
/// [BloomQuery] integrates asynchronous data fetching into Bloom's signal-based reactivity:
/// - **Stale-While-Revalidate**: If cached data exists in [BloomData], it is returned immediately
///   with [status] set to [QueryStatus.success], while an asynchronous background revalidation
///   runs if the entry [QueryCacheEntry.shouldRevalidate].
/// - **Reactive Signals**: Exposes [data], [status], [error], [isFetching], and [isStale] as
///   [ReadonlySignal] instances that automatically trigger re-renders in `Live` or `Show` widgets.
/// - **Deduplication**: Automatically deduplicates concurrent calls to the same [key] via [BloomData.deduplicate].
/// - **Auto Invalidation**: Listens to [BloomData.invalidateQueries] events matching [key] to automatically refetch.
///
/// ### Backend Behavior
/// - **Browser (`mount`)**: Initiates network fetching on creation (if [enabled]), listens for invalidations,
///   and updates reactive signals as results arrive.
/// - **SSR (`renderToHtml`)**: Synchronously evaluates current signal values. If data was preloaded
///   into [BloomData] before rendering, SSR renders the success state immediately.
///
/// ### Example
/// ```dart
/// final userQuery = query<User>(
///   key: ['users', 123],
///   fetch: () => httpClient.get<User>('/users/123'),
///   staleTime: Duration(minutes: 2),
/// );
///
/// BloomNode buildUserProfile() {
///   return Live(() => switch (userQuery.status.value) {
///     QueryStatus.loading => P(text: 'Loading user...'),
///     QueryStatus.error => P(text: 'Error: ${userQuery.error.value}'),
///     QueryStatus.success => Div(children: [
///         H1(text: userQuery.data.value?.name ?? 'Unknown'),
///         if (userQuery.isFetching.value) Span(text: 'Updating...'),
///       ]),
///     QueryStatus.idle => P(text: 'Idle'),
///   });
/// }
/// ```
///
/// See also:
/// - [query], the convenience factory function for creating queries.
/// - [BloomInfiniteQuery], for paginated and cursor-based infinite queries.
/// - [BloomData], the underlying cache manager.
/// - [BloomMutation], for performing mutations and invalidating query keys.
class BloomQuery<T> {
  /// The structured query cache key identifying this query.
  final List<dynamic> key;

  /// The asynchronous fetch function executed to retrieve data.
  final Future<T> Function() fetch;

  /// Duration after a successful fetch during which data is considered fresh before revalidation.
  final Duration staleTime;

  /// Duration after a fetch after which cached data is evicted from the cache.
  final Duration cacheTime;

  /// Whether this query should automatically fetch on instantiation and upon invalidation.
  final bool enabled;

  late final Signal<T?> _data;
  late final Signal<QueryStatus> _status;
  late final Signal<Object?> _error;
  late final Signal<bool> _isFetching;
  late final Signal<bool> _isStale;

  StreamSubscription<void>? _invalidationSub;
  bool _isDisposed = false;

  /// Creates a [BloomQuery] and immediately checks cache freshness or initiates a fetch if [enabled].
  ///
  /// If [initialData] is provided and no cache entry exists for [key], the query initializes in
  /// [QueryStatus.success] with that data and writes it to [BloomData] without firing an initial fetch.
  BloomQuery({
    required this.key,
    required this.fetch,
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.enabled = true,
    T? initialData,
  }) {
    final cachedEntry = BloomData.getEntry<dynamic>(key);
    T? effectiveData;
    bool isStaleInitial;

    if (cachedEntry != null) {
      effectiveData = cachedEntry.data as T?;
      isStaleInitial = cachedEntry.shouldRevalidate;
    } else if (initialData != null) {
      effectiveData = initialData;
      isStaleInitial = false;
      BloomData.putEntry<T>(
        QueryCacheEntry<T>(
          key: key,
          data: initialData,
          updatedAt: DateTime.now(),
          staleTime: staleTime,
          cacheTime: cacheTime,
          isStale: false,
        ),
      );
    } else {
      effectiveData = null;
      isStaleInitial = true;
    }

    _data = signal<T?>(effectiveData);
    _status = signal<QueryStatus>(
      effectiveData != null ? QueryStatus.success : QueryStatus.idle,
    );
    _error = signal<Object?>(null);
    _isFetching = signal<bool>(false);
    _isStale = signal<bool>(isStaleInitial);

    _invalidationSub = BloomData.onInvalidated(key).listen((_) {
      _isStale.value = true;
      if (enabled && !_isDisposed) {
        refetch();
      }
    });

    if (enabled) {
      final entry = BloomData.getEntry<dynamic>(key);
      if (entry == null || entry.shouldRevalidate) {
        _executeFetch();
      }
    }
  }

  /// Reactive signal holding the resolved query data, or `null` if uninitialized/loading.
  ///
  /// Reading `.value` in a `Live` widget creates a reactive dependency.
  ReadonlySignal<T?> get data => _data.readonly();

  /// Reactive signal holding the current lifecycle [QueryStatus] (`idle`, `loading`, `success`, `error`).
  ReadonlySignal<QueryStatus> get status => _status.readonly();

  /// Reactive signal holding any unhandled exception thrown during [fetch], or `null` on success.
  ReadonlySignal<Object?> get error => _error.readonly();

  /// Reactive signal indicating whether a network fetch is actively in-flight (including background revalidations).
  ReadonlySignal<bool> get isFetching => _isFetching.readonly();

  /// Reactive signal indicating whether the current data is stale and awaiting background revalidation.
  ReadonlySignal<bool> get isStale => _isStale.readonly();

  /// Whether the query is currently performing its initial fetch with no data available.
  bool get isLoading => _status.value == QueryStatus.loading;

  /// Whether the query resolved successfully and contains valid [data].
  bool get isSuccess => _status.value == QueryStatus.success;

  /// Whether the query failed with an [error].
  bool get isError => _status.value == QueryStatus.error;

  /// Whether the query has non-null [data] available (either fresh or stale).
  bool get hasData => _data.value != null;

  /// Manually triggers a network re-fetch for this query, returning the resolved result.
  ///
  /// ```dart
  /// await userQuery.refetch();
  /// ```
  Future<T?> refetch() async => _executeFetch();

  /// Manually updates the cached and signal data for this query without triggering a network fetch.
  ///
  /// Resets [status] to [QueryStatus.success], clears [error], and marks data as fresh (`isStale = false`).
  ///
  /// ```dart
  /// userQuery.setData(updatedUser);
  /// ```
  void setData(T newData) {
    BloomData.setQueryData<T>(key, (_) => newData);
    _data.value = newData;
    _status.value = QueryStatus.success;
    _error.value = null;
    _isStale.value = false;
  }

  Future<T?> _executeFetch() async {
    if (_isDisposed) return null;
    if (_data.value == null) {
      _status.value = QueryStatus.loading;
    }
    _isFetching.value = true;

    try {
      final result = await BloomData.deduplicate<T>(key, fetch);
      if (_isDisposed) return null;

      BloomData.putEntry<T>(
        QueryCacheEntry<T>(
          key: key,
          data: result,
          updatedAt: DateTime.now(),
          staleTime: staleTime,
          cacheTime: cacheTime,
          isStale: false,
        ),
      );

      _data.value = result;
      _status.value = QueryStatus.success;
      _error.value = null;
      _isFetching.value = false;
      _isStale.value = false;
      return result;
    } catch (err) {
      if (_isDisposed) return null;
      _error.value = err;
      _status.value = QueryStatus.error;
      _isFetching.value = false;
      return null;
    }
  }

  /// Cancels the query's invalidation stream subscription and prevents future state updates.
  ///
  /// Call when the enclosing controller or component unmounts.
  ///
  /// ```dart
  /// userQuery.dispose();
  /// ```
  void dispose() {
    _isDisposed = true;
    _invalidationSub?.cancel();
  }
}

/// Creates a reactive [BloomQuery] configured with [key], [fetch], and caching durations.
///
/// Convenience factory function for [BloomQuery].
///
/// ```dart
/// final todosQuery = query<List<Todo>>(
///   key: ['todos'],
///   fetch: () => api.getTodoList(),
///   staleTime: Duration(minutes: 5),
/// );
/// ```
BloomQuery<T> query<T>({
  required List<dynamic> key,
  required Future<T> Function() fetch,
  Duration staleTime = const Duration(minutes: 5),
  Duration cacheTime = const Duration(minutes: 30),
  bool enabled = true,
  T? initialData,
}) {
  return BloomQuery<T>(
    key: key,
    fetch: fetch,
    staleTime: staleTime,
    cacheTime: cacheTime,
    enabled: enabled,
    initialData: initialData,
  );
}

/// Function signature for fetching a single page of type [TPage] using page parameter [TParam].
///
/// ```dart
/// InfiniteQueryFn<List<Post>, int> fetchPostsPage = (pageIndex) => api.fetchPosts(page: pageIndex);
/// ```
typedef InfiniteQueryFn<TPage, TParam> = Future<TPage> Function(TParam pageParam);

/// Function signature for deriving the next page parameter from the [lastPage] and [allPages].
///
/// Returns `null` when there are no further pages available.
///
/// ```dart
/// GetNextPageParamFn<List<Post>, int> getNextPage = (lastPage, allPages) =>
///     lastPage.isNotEmpty ? allPages.length + 1 : null;
/// ```
typedef GetNextPageParamFn<TPage, TParam> = TParam? Function(
  TPage lastPage,
  List<TPage> allPages,
);

/// A reactive asynchronous paginated/infinite query coordinator with caching,
/// cursor/offset pagination, background revalidation, and invalidation tracking.
///
/// [BloomInfiniteQuery] extends Bloom's query system to support paginated datasets:
/// - **Page Accumulation**: Sequentially loads and appends pages into [data] / [pages]
///   as [fetchNextPage] is invoked.
/// - **Next Page Determination**: Derives the next page parameter via [getNextPageParam],
///   signaling end-of-list when it returns `null`.
/// - **Granular Spinners**: Distinguishes initial page loading ([isLoading]) from incremental
///   page loading ([isFetchingNextPage]) to support clean bottom loading spinners.
/// - **Concurrency Guard**: Prevents duplicate in-flight requests when [fetchNextPage]
///   is triggered multiple times concurrently.
/// - **Automatic Reset on Refetch**: [refetch] restarts from [initialPageParam] and replaces
///   stale accumulated pages rather than appending duplicates.
/// - **Cache & Invalidation**: Automatically persists pages to [BloomData] cache and revalidates
///   when matching query keys are invalidated via [BloomData.invalidateQueries].
///
/// ### SSR & Browser Behavior
/// - **SSR (`renderToHtml`)**: Synchronously evaluates current pages signal. If preloaded or hydrated,
///   renders initial pages in HTML.
/// - **Browser (`mount`)**: Initiates initial fetch if [enabled], subscribes to invalidations,
///   and updates reactive signals as subsequent pages are fetched.
///
/// ### Example
/// ```dart
/// final feedQuery = infiniteQuery<List<String>, int>(
///   key: ['feed'],
///   initialPageParam: 0,
///   fetch: (page) => api.fetchFeed(offset: page, limit: 10),
///   getNextPageParam: (lastPage, allPages) =>
///       lastPage.length == 10 ? allPages.length * 10 : null,
/// );
///
/// BloomNode buildFeed() {
///   return Div(
///     children: [
///       Live(() => switch (feedQuery.status.value) {
///         QueryStatus.loading => P(text: 'Loading initial feed...'),
///         QueryStatus.error => P(text: 'Error: ${feedQuery.error.value}'),
///         QueryStatus.success || QueryStatus.idle => Div(
///           children: [
///             for (final item in feedQuery.items) Div(text: item.toString()),
///             if (feedQuery.hasNextPage.value)
///               Button(
///                 text: feedQuery.isFetchingNextPage.value ? 'Loading more...' : 'Load More',
///                 on: {'click': (e) => feedQuery.fetchNextPage()},
///               ),
///           ],
///         ),
///       }),
///     ],
///   );
/// }
/// ```
///
/// See also:
/// - [infiniteQuery], the convenience factory function.
/// - [BloomPaginatedQuery], type alias for [BloomInfiniteQuery].
/// - [BloomQuery], for non-paginated single-resource queries.
/// - [BloomData], the underlying cache manager.
class BloomInfiniteQuery<TPage, TParam> {
  /// The structured query cache key identifying this query.
  final List<dynamic> key;

  /// The asynchronous fetch function executed to retrieve a single page.
  final InfiniteQueryFn<TPage, TParam> fetch;

  /// The parameter value used to request the first page.
  final TParam initialPageParam;

  /// Function deriving the parameter for the next page from the most recent page and all loaded pages.
  final GetNextPageParamFn<TPage, TParam> getNextPageParam;

  /// Duration after a successful fetch during which data is considered fresh before revalidation.
  final Duration staleTime;

  /// Duration after a fetch after which cached data is evicted from the cache.
  final Duration cacheTime;

  /// Whether this query should automatically fetch on instantiation and upon invalidation.
  final bool enabled;

  /// Optional function extracting a list of items from a page for the [items] convenience getter.
  final List<dynamic> Function(TPage page)? getItems;

  late final Signal<List<TPage>?> _data;
  late final Signal<QueryStatus> _status;
  late final Signal<Object?> _error;
  late final Signal<bool> _isFetching;
  late final Signal<bool> _isFetchingNextPage;
  late final Signal<bool> _hasNextPage;
  late final Signal<bool> _isStale;

  List<TParam> _pageParams = [];
  TParam? _nextPageParam;
  Future<List<TPage>?>? _inFlightNextPage;
  StreamSubscription<void>? _invalidationSub;
  bool _isDisposed = false;

  /// Creates a [BloomInfiniteQuery] and checks cache freshness or initiates an initial fetch.
  BloomInfiniteQuery({
    required this.key,
    required this.fetch,
    required this.initialPageParam,
    required this.getNextPageParam,
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.enabled = true,
    this.getItems,
    List<TPage>? initialData,
  }) {
    final rawEntry = BloomData.getEntry<dynamic>(key);
    List<TPage>? initialPages;
    bool isStaleInitial = true;

    if (rawEntry != null && rawEntry.data != null) {
      if (rawEntry.data is List<TPage>) {
        initialPages = rawEntry.data as List<TPage>;
      } else if (rawEntry.data is List) {
        initialPages = (rawEntry.data as List).cast<TPage>();
      }
      isStaleInitial = rawEntry.shouldRevalidate;
    } else if (initialData != null && initialData.isNotEmpty) {
      initialPages = initialData;
      isStaleInitial = false;
      BloomData.putEntry<List<TPage>>(
        QueryCacheEntry<List<TPage>>(
          key: key,
          data: initialData,
          updatedAt: DateTime.now(),
          staleTime: staleTime,
          cacheTime: cacheTime,
          isStale: false,
        ),
      );
    }

    _data = signal<List<TPage>?>(initialPages);
    _status = signal<QueryStatus>(
      initialPages != null && initialPages.isNotEmpty
          ? QueryStatus.success
          : QueryStatus.idle,
    );
    _error = signal<Object?>(null);
    _isFetching = signal<bool>(false);
    _isFetchingNextPage = signal<bool>(false);
    _isStale = signal<bool>(isStaleInitial);

    if (initialPages != null && initialPages.isNotEmpty) {
      _pageParams = [initialPageParam];
      _nextPageParam = getNextPageParam(initialPages.last, initialPages);
      _hasNextPage = signal<bool>(_nextPageParam != null);
    } else {
      _nextPageParam = initialPageParam;
      _hasNextPage = signal<bool>(false);
    }

    _invalidationSub = BloomData.onInvalidated(key).listen((_) {
      _isStale.value = true;
      if (enabled && !_isDisposed) {
        refetch();
      }
    });

    if (enabled) {
      if (rawEntry == null || rawEntry.shouldRevalidate) {
        if (initialPages == null || isStaleInitial) {
          _executeInitialFetch();
        }
      }
    }
  }

  /// Reactive signal holding the accumulated list of resolved pages, or `null` if uninitialized.
  ReadonlySignal<List<TPage>?> get data => _data.readonly();

  /// Reactive signal holding the accumulated list of resolved pages (alias for [data]).
  ReadonlySignal<List<TPage>?> get pages => _data.readonly();

  /// Synchronous non-null snapshot of the current loaded pages.
  List<TPage> get pageList => _data.value ?? const [];

  /// Reactive signal holding the current lifecycle [QueryStatus].
  ReadonlySignal<QueryStatus> get status => _status.readonly();

  /// Reactive signal holding any unhandled exception thrown during fetching, or `null` on success.
  ReadonlySignal<Object?> get error => _error.readonly();

  /// Reactive signal indicating whether any network fetch is in-flight (initial, refetch, or next page).
  ReadonlySignal<bool> get isFetching => _isFetching.readonly();

  /// Reactive signal indicating whether a request for the *next* page is actively in-flight.
  ReadonlySignal<bool> get isFetchingNextPage => _isFetchingNextPage.readonly();

  /// Reactive signal indicating whether there is a subsequent page available to fetch.
  ReadonlySignal<bool> get hasNextPage => _hasNextPage.readonly();

  /// Reactive signal indicating whether the current cached page data is stale.
  ReadonlySignal<bool> get isStale => _isStale.readonly();

  /// Whether the query is performing its initial fetch with no pages loaded.
  bool get isLoading => _status.value == QueryStatus.loading;

  /// Whether the query has successfully resolved at least one page.
  bool get isSuccess => _status.value == QueryStatus.success;

  /// Whether the query failed with an [error].
  bool get isError => _status.value == QueryStatus.error;

  /// Whether the query currently holds any non-empty page data.
  bool get hasData => _data.value != null && _data.value!.isNotEmpty;

  /// The parameter values that were used to fetch each loaded page in order.
  List<TParam> get pageParams => List.unmodifiable(_pageParams);

  /// The next parameter value that will be passed to [fetch] on [fetchNextPage], or `null` if no more pages.
  TParam? get nextPageParam => _nextPageParam;

  /// Convenience getter returning all individual items across all loaded pages flattened into a single list.
  List<dynamic> get items {
    final currentPages = _data.value;
    if (currentPages == null || currentPages.isEmpty) return const [];
    if (getItems != null) {
      return currentPages.expand((p) => getItems!(p)).toList();
    }
    final result = <dynamic>[];
    for (final page in currentPages) {
      if (page is Iterable) {
        result.addAll(page);
      } else {
        result.add(page);
      }
    }
    return result;
  }

  /// Manually re-fetches the first page from scratch and replaces all accumulated pages.
  ///
  /// Resets page tracking to [initialPageParam] and refreshes the query cache.
  ///
  /// ```dart
  /// await feedQuery.refetch();
  /// ```
  Future<List<TPage>?> refetch() async => _executeInitialFetch();

  /// Fetches the subsequent page using [nextPageParam] and appends it to [pages].
  ///
  /// Automatically guarded against concurrent duplicate invocations: if a fetch is already
  /// in flight, returns the existing active Future.
  ///
  /// ```dart
  /// if (feedQuery.hasNextPage.value) {
  ///   await feedQuery.fetchNextPage();
  /// }
  /// ```
  Future<List<TPage>?> fetchNextPage() async {
    if (_isDisposed) return null;
    if (_isFetchingNextPage.value) return _inFlightNextPage;
    if (!_hasNextPage.value || _nextPageParam == null) return null;

    final paramToFetch = _nextPageParam as TParam;
    _isFetchingNextPage.value = true;
    _isFetching.value = true;

    final nextPageKey = [...key, 'page', BloomData._canonical(paramToFetch)];

    final future = () async {
      try {
        final result = await BloomData.deduplicate<TPage>(
          nextPageKey,
          () => fetch(paramToFetch),
        );

        if (_isDisposed) return null;

        final currentPages = _data.value ?? <TPage>[];
        final newPages = [...currentPages, result];
        _pageParams.add(paramToFetch);
        _nextPageParam = getNextPageParam(result, newPages);

        BloomData.putEntry<List<TPage>>(
          QueryCacheEntry<List<TPage>>(
            key: key,
            data: newPages,
            updatedAt: DateTime.now(),
            staleTime: staleTime,
            cacheTime: cacheTime,
            isStale: false,
          ),
        );

        _data.value = newPages;
        _status.value = QueryStatus.success;
        _error.value = null;
        _isFetchingNextPage.value = false;
        _isFetching.value = false;
        _hasNextPage.value = _nextPageParam != null;
        _isStale.value = false;
        return newPages;
      } catch (err) {
        if (_isDisposed) return null;
        _error.value = err;
        _isFetchingNextPage.value = false;
        _isFetching.value = false;
        return null;
      } finally {
        _inFlightNextPage = null;
      }
    }();

    _inFlightNextPage = future;
    return future;
  }

  /// Manually updates the accumulated pages without triggering a network fetch.
  ///
  /// ```dart
  /// feedQuery.setData([firstPage, secondPage]);
  /// ```
  void setData(List<TPage> newPages) {
    BloomData.setQueryData<List<TPage>>(key, (_) => newPages);
    _data.value = newPages;
    _status.value = QueryStatus.success;
    _error.value = null;
    _isStale.value = false;
    if (newPages.isNotEmpty) {
      _nextPageParam = getNextPageParam(newPages.last, newPages);
      _hasNextPage.value = _nextPageParam != null;
    } else {
      _nextPageParam = initialPageParam;
      _hasNextPage.value = false;
    }
  }

  Future<List<TPage>?> _executeInitialFetch() async {
    if (_isDisposed) return null;
    if (_data.value == null || _data.value!.isEmpty) {
      _status.value = QueryStatus.loading;
    }
    _isFetching.value = true;

    try {
      final firstPageKey = [...key, 'page', BloomData._canonical(initialPageParam)];
      final result = await BloomData.deduplicate<TPage>(
        firstPageKey,
        () => fetch(initialPageParam),
      );

      if (_isDisposed) return null;

      final newPages = <TPage>[result];
      _pageParams = <TParam>[initialPageParam];
      _nextPageParam = getNextPageParam(result, newPages);

      BloomData.putEntry<List<TPage>>(
        QueryCacheEntry<List<TPage>>(
          key: key,
          data: newPages,
          updatedAt: DateTime.now(),
          staleTime: staleTime,
          cacheTime: cacheTime,
          isStale: false,
        ),
      );

      _data.value = newPages;
      _status.value = QueryStatus.success;
      _error.value = null;
      _isFetching.value = false;
      _isFetchingNextPage.value = false;
      _hasNextPage.value = _nextPageParam != null;
      _isStale.value = false;
      return newPages;
    } catch (err) {
      if (_isDisposed) return null;
      _error.value = err;
      _status.value = QueryStatus.error;
      _isFetching.value = false;
      _isFetchingNextPage.value = false;
      return null;
    }
  }

  /// Cancels the invalidation subscription and halts future reactive updates.
  ///
  /// ```dart
  /// feedQuery.dispose();
  /// ```
  void dispose() {
    _isDisposed = true;
    _invalidationSub?.cancel();
  }
}

/// Creates a reactive [BloomInfiniteQuery] configured with pagination parameters.
///
/// Convenience factory function for [BloomInfiniteQuery].
///
/// ```dart
/// final feed = infiniteQuery<List<Post>, int>(
///   key: ['posts'],
///   initialPageParam: 1,
///   fetch: (page) => api.fetchPosts(page: page),
///   getNextPageParam: (lastPage, allPages) =>
///       lastPage.isNotEmpty ? allPages.length + 1 : null,
/// );
/// ```
BloomInfiniteQuery<TPage, TParam> infiniteQuery<TPage, TParam>({
  required List<dynamic> key,
  required Future<TPage> Function(TParam pageParam) fetch,
  required TParam initialPageParam,
  required TParam? Function(TPage lastPage, List<TPage> allPages) getNextPageParam,
  Duration staleTime = const Duration(minutes: 5),
  Duration cacheTime = const Duration(minutes: 30),
  bool enabled = true,
  List<dynamic> Function(TPage page)? getItems,
  List<TPage>? initialData,
}) {
  return BloomInfiniteQuery<TPage, TParam>(
    key: key,
    fetch: fetch,
    initialPageParam: initialPageParam,
    getNextPageParam: getNextPageParam,
    staleTime: staleTime,
    cacheTime: cacheTime,
    enabled: enabled,
    getItems: getItems,
    initialData: initialData,
  );
}

/// Alias for [BloomInfiniteQuery].
typedef BloomPaginatedQuery<TPage, TParam> = BloomInfiniteQuery<TPage, TParam>;

/// Alias for [infiniteQuery].
///
/// Creates a reactive [BloomPaginatedQuery] / [BloomInfiniteQuery] configured with pagination parameters.
///
/// ```dart
/// final feed = paginatedQuery<List<Post>, int>(
///   key: ['posts'],
///   initialPageParam: 1,
///   fetch: (page) => api.fetchPosts(page: page),
///   getNextPageParam: (lastPage, allPages) =>
///       lastPage.isNotEmpty ? allPages.length + 1 : null,
/// );
/// ```
BloomInfiniteQuery<TPage, TParam> paginatedQuery<TPage, TParam>({
  required List<dynamic> key,
  required Future<TPage> Function(TParam pageParam) fetch,
  required TParam initialPageParam,
  required TParam? Function(TPage lastPage, List<TPage> allPages) getNextPageParam,
  Duration staleTime = const Duration(minutes: 5),
  Duration cacheTime = const Duration(minutes: 30),
  bool enabled = true,
  List<dynamic> Function(TPage page)? getItems,
  List<TPage>? initialData,
}) =>
    infiniteQuery<TPage, TParam>(
      key: key,
      fetch: fetch,
      initialPageParam: initialPageParam,
      getNextPageParam: getNextPageParam,
      staleTime: staleTime,
      cacheTime: cacheTime,
      enabled: enabled,
      getItems: getItems,
      initialData: initialData,
    );

