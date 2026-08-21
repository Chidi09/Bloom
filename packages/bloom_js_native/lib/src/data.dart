import 'dart:async';
import 'dart:collection';

import 'package:signals/signals.dart';

/// Execution status of a [BloomQuery].
enum QueryStatus {
  idle,
  loading,
  success,
  error,
}

/// A cached record containing fetched data, timestamps, and TTL settings.
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

  bool get isExpired => DateTime.now().difference(updatedAt) > cacheTime;
  bool get shouldRevalidate =>
      isStale || DateTime.now().difference(updatedAt) > staleTime;
}

/// Global query cache manager for Bloom JS Native.
class BloomData {
  BloomData._();

  static final Map<String, QueryCacheEntry<dynamic>> _cache =
      HashMap<String, QueryCacheEntry<dynamic>>();
  static final Map<String, StreamController<void>> _invalidationControllers =
      HashMap<String, StreamController<void>>();
  static final Map<String, Completer<dynamic>> _inFlightRequests =
      HashMap<String, Completer<dynamic>>();

  /// Converts a key list to a normalized string key.
  static String normalizeKey(List<dynamic> key) => key.map(_canonical).join(':');

  static String _canonical(dynamic e) {
    if (e is Map) {
      final entries = e.entries.map((kv) => '${kv.key}: ${_canonical(kv.value)}').toList()..sort();
      return '{${entries.join(', ')}}';
    }
    if (e is Iterable) return '[${e.map(_canonical).join(', ')}]';
    return e.toString();
  }

  /// Invalidate queries matching [keyPrefix].
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

  /// Set cache data directly.
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

  /// Request deduplication.
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

  /// Listen for invalidations.
  static Stream<void> onInvalidated(List<dynamic> key) {
    final keyStr = normalizeKey(key);
    return _invalidationControllers
        .putIfAbsent(keyStr, () => StreamController<void>.broadcast())
        .stream;
  }

  /// Store entry.
  static void putEntry<T>(QueryCacheEntry<T> entry) {
    _cache[normalizeKey(entry.key)] = entry;
  }

  /// Get raw entry.
  static QueryCacheEntry<T>? getEntry<T>(List<dynamic> key) {
    final entry = _cache[normalizeKey(key)];
    if (entry != null && !entry.isExpired) return entry as QueryCacheEntry<T>?;
    return null;
  }

  /// Clear all cache state.
  static void clear() {
    _cache.clear();
    for (final ctrl in _invalidationControllers.values) {
      ctrl.close();
    }
    _invalidationControllers.clear();
    _inFlightRequests.clear();
  }
}

/// A reactive asynchronous query with automatic caching and deduplication.
class BloomQuery<T> {
  final List<dynamic> key;
  final Future<T> Function() fetch;
  final Duration staleTime;
  final Duration cacheTime;
  final bool enabled;

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

  ReadonlySignal<T?> get data => _data.readonly();
  ReadonlySignal<QueryStatus> get status => _status.readonly();
  ReadonlySignal<Object?> get error => _error.readonly();
  ReadonlySignal<bool> get isFetching => _isFetching.readonly();
  ReadonlySignal<bool> get isStale => _isStale.readonly();

  bool get isLoading => _status.value == QueryStatus.loading;
  bool get isSuccess => _status.value == QueryStatus.success;
  bool get isError => _status.value == QueryStatus.error;
  bool get hasData => _data.value != null;

  Future<T?> refetch() async => _executeFetch();

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

  void dispose() {
    _isDisposed = true;
    _invalidationSub?.cancel();
  }
}

/// Helper function to create a [BloomQuery].
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
