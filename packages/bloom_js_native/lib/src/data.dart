import 'dart:async';
import 'dart:collection';

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
  BloomQuery({
    required this.key,
    required this.fetch,
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.enabled = true,
  }) {
    final cachedEntry = BloomData.getEntry<T>(key);
    final initialData = cachedEntry?.data;
    final isStaleInitial = cachedEntry?.shouldRevalidate ?? true;

    _data = signal<T?>(initialData);
    _status = signal<QueryStatus>(
      initialData != null ? QueryStatus.success : QueryStatus.idle,
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
      if (cachedEntry == null || cachedEntry.shouldRevalidate) {
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
}) {
  return BloomQuery<T>(
    key: key,
    fetch: fetch,
    staleTime: staleTime,
    cacheTime: cacheTime,
    enabled: enabled,
  );
}
