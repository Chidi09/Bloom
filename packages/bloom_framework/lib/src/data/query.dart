// lib/src/data/query.dart
import 'dart:async';
import '../core/logger.dart';
import '../state/signals.dart';
import 'cache.dart';

enum QueryStatus { idle, loading, success, error }

typedef QueryFetcher<T> = Future<T> Function();

/// A reactive asynchronous query with automatic caching, stale-while-revalidate, and deduplication.
class BloomQuery<T> {
  final List<dynamic> key;
  final QueryFetcher<T> fetch;
  final Duration staleTime;
  final Duration cacheTime;
  final bool enabled;
  final int retry;
  final Duration retryDelay;

  late final Signal<T?> _data;
  late final Signal<QueryStatus> _status;
  late final Signal<Object?> _error;
  late final Signal<bool> _isFetching;
  late final Signal<bool> _isStale;

  StreamSubscription<void>? _invalidationSub;
  bool _isDisposed = false;

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

  // Public reactive accessors
  ReadonlySignal<T?> get data => _data.readonly();
  ReadonlySignal<QueryStatus> get status => _status.readonly();
  ReadonlySignal<Object?> get error => _error.readonly();
  ReadonlySignal<bool> get isFetching => _isFetching.readonly();
  ReadonlySignal<bool> get isStale => _isStale.readonly();

  bool get isLoading => _status.value == QueryStatus.loading;
  bool get isSuccess => _status.value == QueryStatus.success;
  bool get isError => _status.value == QueryStatus.error;
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
