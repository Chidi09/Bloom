// lib/src/data/query.dart
import 'dart:async';
import '../core/logger.dart';
import '../state/signals.dart';
import 'cache.dart';

/// Execution status of a [BloomQuery].
///
/// Example:
/// ```dart
/// if (userQuery.status.value == QueryStatus.loading) {
///   // show loading skeleton
/// }
/// ```
enum QueryStatus {
  /// Query has not started fetching yet.
  idle,

  /// Initial fetch is currently in progress.
  loading,

  /// Query fetched data successfully.
  success,

  /// Query encountered an error during fetch.
  error,
}

/// Asynchronous data fetcher function for a query.
typedef QueryFetcher<T> = Future<T> Function();

/// A reactive asynchronous query with automatic caching, stale-while-revalidate, and deduplication.
///
/// Subscribes to global [BloomData] cache invalidation events and exposes reactive
/// signals for [data], [status], [error], [isFetching], and [isStale].
///
/// Example:
/// ```dart
/// final userQuery = BloomQuery<User>(
///   key: ['user', 42],
///   fetch: () => api.fetchUser(42),
///   staleTime: const Duration(minutes: 5),
/// );
///
/// print(userQuery.data.value?.name);
/// ```
class BloomQuery<T> {
  /// Unique cache key identifying this query.
  final List<dynamic> key;

  /// Asynchronous function that fetches fresh data from network or database.
  final QueryFetcher<T> fetch;

  /// Duration after which cached data is considered stale and revalidated on access.
  final Duration staleTime;

  /// Maximum duration to keep cached data in memory before garbage collection.
  final Duration cacheTime;

  /// Whether this query automatically fetches on initialization (defaults to true).
  final bool enabled;

  /// Number of retry attempts on network/fetch failure (defaults to 2).
  final int retry;

  /// Base delay duration between retry attempts (defaults to 500ms).
  final Duration retryDelay;

  late final Signal<T?> _data;
  late final Signal<QueryStatus> _status;
  late final Signal<Object?> _error;
  late final Signal<bool> _isFetching;
  late final Signal<bool> _isStale;

  StreamSubscription<void>? _invalidationSub;
  bool _isDisposed = false;

  /// Creates a [BloomQuery] with cache key, fetcher, and configuration options.
  BloomQuery({
    required this.key,
    required this.fetch,
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.enabled = true,
    this.retry = 2,
    this.retryDelay = const Duration(milliseconds: 500),
  }) {
    // Check initial cache state
    final cachedEntry = BloomData.getEntry<T>(key);
    final initialData = cachedEntry?.data;
    final isStaleInitial = cachedEntry?.shouldRevalidate ?? true;

    _data = signal<T?>(initialData, debugLabel: 'query.data[${BloomData.normalizeKey(key)}]');
    _status = signal<QueryStatus>(
      initialData != null ? QueryStatus.success : QueryStatus.idle,
      debugLabel: 'query.status',
    );
    _error = signal<Object?>(null, debugLabel: 'query.error');
    _isFetching = signal<bool>(false, debugLabel: 'query.isFetching');
    _isStale = signal<bool>(isStaleInitial, debugLabel: 'query.isStale');

    // Subscribe to cache invalidations
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

  /// Reactive signal containing the current data value [T], or `null`.
  ReadonlySignal<T?> get data => _data.readonly();

  /// Reactive signal containing the current query status.
  ReadonlySignal<QueryStatus> get status => _status.readonly();

  /// Reactive signal containing the error object if the query failed, or `null`.
  ReadonlySignal<Object?> get error => _error.readonly();

  /// Reactive signal indicating whether a network fetch is actively occurring in background.
  ReadonlySignal<bool> get isFetching => _isFetching.readonly();

  /// Reactive signal indicating whether the current data is considered stale.
  ReadonlySignal<bool> get isStale => _isStale.readonly();

  /// Whether the query is currently performing its initial loading fetch.
  bool get isLoading => _status.value == QueryStatus.loading;

  /// Whether the query has resolved successfully with cached or fresh data.
  bool get isSuccess => _status.value == QueryStatus.success;

  /// Whether the query has failed with an error.
  bool get isError => _status.value == QueryStatus.error;

  /// Whether valid data is currently available in this query.
  bool get hasData => _data.value != null;

  /// Manually triggers a fresh background revalidation.
  ///
  /// Example:
  /// ```dart
  /// final freshData = await userQuery.refetch();
  /// ```
  Future<T?> refetch() async {
    return _executeFetch();
  }

  /// Marks this query as invalidated and triggers an immediate background refetch.
  ///
  /// Example:
  /// ```dart
  /// userQuery.invalidate();
  /// ```
  void invalidate() {
    BloomData.invalidateQueries(key);
  }

  /// Overrides data directly in memory cache and notifies all active observers.
  ///
  /// Example:
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

    int attempt = 0;
    while (attempt <= retry) {
      try {
        final result = await BloomData.deduplicate<T>(key, fetch);
        if (_isDisposed) return null;

        // Store into BloomData global cache
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
      } catch (err, st) {
        attempt++;
        if (attempt > retry) {
          if (_isDisposed) return null;
          logger.error('Query [${BloomData.normalizeKey(key)}] fetch failed after $retry retries: $err', err, st);
          _error.value = err;
          _status.value = QueryStatus.error;
          _isFetching.value = false;
          return null;
        }
        await Future.delayed(retryDelay * attempt);
      }
    }
    return null;
  }

  /// Disposes this query instance, unregisters invalidation listeners, and releases cache slots.
  ///
  /// Example:
  /// ```dart
  /// userQuery.dispose();
  /// ```
  void dispose() {
    _isDisposed = true;
    _invalidationSub?.cancel();
    BloomData.releaseListener(key);
  }
}

/// Creates a declarative, cached asynchronous query.
///
/// Example:
/// ```dart
/// final postsQuery = query<List<Post>>(
///   key: ['posts'],
///   fetch: () => api.fetchPosts(),
///   staleTime: const Duration(minutes: 2),
/// );
/// ```
BloomQuery<T> query<T>({
  required List<dynamic> key,
  required QueryFetcher<T> fetch,
  Duration staleTime = const Duration(minutes: 5),
  Duration cacheTime = const Duration(minutes: 30),
  bool enabled = true,
  int retry = 2,
  Duration retryDelay = const Duration(milliseconds: 500),
}) {
  return BloomQuery<T>(
    key: key,
    fetch: fetch,
    staleTime: staleTime,
    cacheTime: cacheTime,
    enabled: enabled,
    retry: retry,
    retryDelay: retryDelay,
  );
}
