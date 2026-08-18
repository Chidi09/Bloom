// lib/src/data/query.dart
import 'dart:async';
import '../core/logger.dart';
import '../state/signals.dart';
import 'cache.dart';

/// Execution status of a [BloomQuery].
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
class BloomQuery<T> {
  /// Unique cache key identifying this query.
  final List<dynamic> key;

  /// Asynchronous function that fetches fresh data.
  final QueryFetcher<T> fetch;

  /// Duration after which cached data is considered stale.
  final Duration staleTime;

  /// Maximum duration to keep cached data in memory before garbage collection.
  final Duration cacheTime;

  /// Whether this query automatically fetches on initialization.
  final bool enabled;

  /// Number of retry attempts on network/fetch failure.
  final int retry;

  /// Base delay duration between retry attempts.
  final Duration retryDelay;

  late final Signal<T?> _data;
  late final Signal<QueryStatus> _status;
  late final Signal<Object?> _error;
  late final Signal<bool> _isFetching;
  late final Signal<bool> _isStale;

  StreamSubscription<void>? _invalidationSub;
  bool _isDisposed = false;

  /// Creates a [BloomQuery] with cache key, fetcher, and configuration.
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

  /// Reactive signal containing the current data value, or null.
  ReadonlySignal<T?> get data => _data.readonly();

  /// Reactive signal containing the current query status.
  ReadonlySignal<QueryStatus> get status => _status.readonly();

  /// Reactive signal containing the error object if the query failed.
  ReadonlySignal<Object?> get error => _error.readonly();

  /// Reactive signal indicating whether a network fetch is actively occurring in background.
  ReadonlySignal<bool> get isFetching => _isFetching.readonly();

  /// Reactive signal indicating whether the current data is considered stale.
  ReadonlySignal<bool> get isStale => _isStale.readonly();

  /// Whether the query is currently performing its initial loading fetch.
  bool get isLoading => _status.value == QueryStatus.loading;

  /// Whether the query has resolved successfully.
  bool get isSuccess => _status.value == QueryStatus.success;

  /// Whether the query has failed with an error.
  bool get isError => _status.value == QueryStatus.error;

  /// Whether valid data is currently available in this query.
  bool get hasData => _data.value != null;

  /// Manually trigger a fresh background revalidation.
  Future<T?> refetch() async {
    return _executeFetch();
  }

  /// Mark this query as invalidated and refetch immediately.
  void invalidate() {
    BloomData.invalidateQueries(key);
  }

  /// Override data in memory cache and notify active observers.
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

  /// Disposes this query instance and releases cache invalidation listener subscriptions.
  void dispose() {
    _isDisposed = true;
    _invalidationSub?.cancel();
    BloomData.releaseListener(key);
  }
}

/// Create a declarative, cached asynchronous query.
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
