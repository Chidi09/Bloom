// lib/src/isr.dart
//
// Pure-Dart page-level Incremental Static Regeneration (ISR) revalidation
// contract and bounded in-memory renderer/store for Bloom JS Native.
// Safe for SSR (Dart VM), SSG, and browser/test environments (zero dart:io or package:web).

import 'dart:async';
import 'dart:collection';

/// Rendering and caching mode for a Bloom page or route.
enum BloomRenderMode {
  /// Always render dynamically per request (`Cache-Control: no-store`).
  ssr,

  /// Static output with no automatic time-based expiry unless invalidated.
  ssg,

  /// Incremental Static Regeneration: serve cached HTML and revalidate
  /// stale responses in the background after [BloomRevalidateConfig.revalidate].
  isr,
}

/// Cache lookup outcome returned by [BloomIsrRenderer.render].
enum BloomIsrCacheStatus {
  /// Fresh cached entry served without re-rendering.
  hit,

  /// Stale cached entry served immediately while background regeneration runs.
  stale,

  /// No cached entry existed; rendered synchronously and stored.
  miss,

  /// Caching bypassed (for example [BloomRenderMode.ssr] or personalized request).
  bypass,
}

/// Declarative per-route caching and revalidation configuration.
///
/// ```dart
/// final route = BloomRoute(
///   '/products/:id',
///   builder: (params) => ProductPage(id: params['id']!),
///   revalidate: const BloomRevalidateConfig.isr(
///     revalidate: Duration(seconds: 60),
///     tags: ['products'],
///   ),
/// );
/// ```
class BloomRevalidateConfig {
  /// Rendering strategy (`ssr`, `ssg`, or `isr`).
  final BloomRenderMode mode;

  /// Revalidation window for ISR entries. `null` means no time-based expiry.
  final Duration? revalidate;

  /// Cache invalidation tags associated with rendered entries.
  final List<String> tags;

  /// Lowercased request header names included in the cache key.
  final List<String> varyHeaders;

  /// Query parameter names included in the cache key.
  final List<String> varyQueryParams;

  /// Whether requests carrying `Authorization` or `Cookie` headers may be cached.
  ///
  /// Defaults to `false` to prevent accidental caching of personalized responses.
  final bool allowPersonalized;

  /// Creates a page revalidation configuration.
  const BloomRevalidateConfig({
    this.mode = BloomRenderMode.ssr,
    this.revalidate,
    this.tags = const [],
    this.varyHeaders = const [],
    this.varyQueryParams = const [],
    this.allowPersonalized = false,
  });

  /// Dynamic per-request SSR configuration (never cached).
  const BloomRevalidateConfig.ssr()
      : mode = BloomRenderMode.ssr,
        revalidate = null,
        tags = const [],
        varyHeaders = const [],
        varyQueryParams = const [],
        allowPersonalized = false;

  /// Static generation configuration (cached until explicitly invalidated).
  const BloomRevalidateConfig.ssg({
    this.tags = const [],
    this.varyHeaders = const [],
    this.varyQueryParams = const [],
    this.allowPersonalized = false,
  })  : mode = BloomRenderMode.ssg,
        revalidate = null;

  /// Incremental Static Regeneration configuration with a [revalidate] window.
  const BloomRevalidateConfig.isr({
    required Duration this.revalidate,
    this.tags = const [],
    this.varyHeaders = const [],
    this.varyQueryParams = const [],
    this.allowPersonalized = false,
  }) : mode = BloomRenderMode.isr;

  /// Computes a deterministic cache key for [path], incorporating configured
  /// [varyQueryParams] and [varyHeaders].
  String cacheKeyFor(
    String path, {
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
  }) {
    final normalizedPath = _normalizePath(path);
    final parts = <String>[normalizedPath];

    if (varyQueryParams.isNotEmpty) {
      final sortedParams = List<String>.from(varyQueryParams)..sort();
      final qParts = <String>[];
      for (final name in sortedParams) {
        final val = query[name];
        if (val != null) {
          qParts.add('${Uri.encodeQueryComponent(name)}='
              '${Uri.encodeQueryComponent(val)}');
        }
      }
      if (qParts.isNotEmpty) {
        parts.add('q:${qParts.join('&')}');
      }
    }

    if (varyHeaders.isNotEmpty) {
      final lowerHeaders = <String, String>{
        for (final e in headers.entries) e.key.toLowerCase(): e.value,
      };
      final sortedHeaders = varyHeaders.map((h) => h.toLowerCase()).toList()
        ..sort();
      final hParts = <String>[];
      for (final name in sortedHeaders) {
        final val = lowerHeaders[name];
        if (val != null) {
          hParts.add('$name=$val');
        }
      }
      if (hParts.isNotEmpty) {
        parts.add('h:${hParts.join('&')}');
      }
    }

    return parts.join('|');
  }

  /// Whether a request with [headers] is eligible for cached serving/storage.
  bool isCacheableRequest({Map<String, String> headers = const {}}) {
    if (mode == BloomRenderMode.ssr) return false;
    if (allowPersonalized) return true;
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if ((key == 'authorization' || key == 'cookie') &&
          entry.value.trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Generates an HTTP `Cache-Control` header value matching this configuration.
  String toCacheControlHeader() {
    switch (mode) {
      case BloomRenderMode.ssr:
        return 'no-store';
      case BloomRenderMode.ssg:
        if (revalidate == null) {
          return 'public, max-age=31536000, immutable';
        }
        final secs = revalidate!.inSeconds < 0 ? 0 : revalidate!.inSeconds;
        return 'public, s-maxage=$secs, stale-while-revalidate=$secs';
      case BloomRenderMode.isr:
        final secs =
            (revalidate?.inSeconds ?? 0) < 0 ? 0 : (revalidate?.inSeconds ?? 0);
        return 'public, s-maxage=$secs, stale-while-revalidate=$secs';
    }
  }
}

String _normalizePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '/';
  var clean = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  while (clean.length > 1 && clean.endsWith('/')) {
    clean = clean.substring(0, clean.length - 1);
  }
  return clean;
}

/// A cached HTML response entry stored by a [BloomIsrStore].
class BloomIsrEntry {
  /// Rendered HTML payload.
  final String html;

  /// HTTP status code associated with this entry.
  final int statusCode;

  /// Additional response headers stored with this entry.
  final Map<String, String> headers;

  /// Timestamp when [html] was generated.
  final DateTime generatedAt;

  /// Optional staleness threshold; `null` means the entry never expires by time.
  final Duration? revalidateAfter;

  /// Invalidation tags associated with this entry.
  final List<String> tags;

  /// Creates an immutable [BloomIsrEntry].
  BloomIsrEntry({
    required this.html,
    this.statusCode = 200,
    Map<String, String> headers = const {},
    required this.generatedAt,
    this.revalidateAfter,
    List<String> tags = const [],
  })  : headers = Map<String, String>.unmodifiable(headers),
        tags = List<String>.unmodifiable(tags);

  /// Whether this entry is still fresh at [now].
  bool isFresh(DateTime now) {
    final window = revalidateAfter;
    if (window == null) return true;
    return now.difference(generatedAt) < window;
  }

  /// Whether this entry has exceeded [revalidateAfter] at [now].
  bool isStale(DateTime now) => !isFresh(now);
}

/// Pluggable storage backend for [BloomIsrRenderer].
abstract interface class BloomIsrStore {
  /// Retrieves a cached entry by [key], or `null` if absent.
  FutureOr<BloomIsrEntry?> get(String key);

  /// Stores or replaces [entry] under [key].
  FutureOr<void> put(String key, BloomIsrEntry entry);

  /// Deletes a single cached entry by [key].
  FutureOr<void> delete(String key);

  /// Deletes all entries tagged with [tag] and returns the number removed.
  FutureOr<int> deleteByTag(String tag);

  /// Removes all entries from the store.
  FutureOr<void> clear();
}

/// Bounded in-memory LRU [BloomIsrStore].
class MemoryBloomIsrStore implements BloomIsrStore {
  /// Maximum number of entries retained before evicting the least-recently used.
  final int maxEntries;

  final LinkedHashMap<String, BloomIsrEntry> _entries =
      LinkedHashMap<String, BloomIsrEntry>();

  /// Creates a bounded in-memory ISR store with capacity [maxEntries].
  MemoryBloomIsrStore({this.maxEntries = 500}) {
    if (maxEntries <= 0) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0');
    }
  }

  /// Current number of cached entries.
  int get length => _entries.length;

  @override
  BloomIsrEntry? get(String key) {
    final existing = _entries.remove(key);
    if (existing == null) return null;
    _entries[key] = existing;
    return existing;
  }

  @override
  void put(String key, BloomIsrEntry entry) {
    _entries.remove(key);
    _entries[key] = entry;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  void delete(String key) {
    _entries.remove(key);
  }

  @override
  int deleteByTag(String tag) {
    final keysToRemove = <String>[];
    for (final entry in _entries.entries) {
      if (entry.value.tags.contains(tag)) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _entries.remove(key);
    }
    return keysToRemove.length;
  }

  @override
  void clear() {
    _entries.clear();
  }
}

/// Result returned by [BloomIsrRenderer.render].
class BloomIsrResult {
  /// Rendered HTML payload.
  final String html;

  /// HTTP status code.
  final int statusCode;

  /// Response headers.
  final Map<String, String> headers;

  /// Cache status (`hit`, `stale`, `miss`, or `bypass`).
  final BloomIsrCacheStatus cacheStatus;

  /// Recommended `Cache-Control` header value.
  final String cacheControl;

  /// Creates a [BloomIsrResult].
  BloomIsrResult({
    required this.html,
    this.statusCode = 200,
    Map<String, String> headers = const {},
    required this.cacheStatus,
    required this.cacheControl,
  }) : headers = Map<String, String>.unmodifiable(headers);
}

/// Coordinates stale-while-revalidate rendering, deduplication, and invalidation
/// for pages configured with [BloomRevalidateConfig].
class BloomIsrRenderer {
  final BloomIsrStore _store;
  final DateTime Function() _clock;
  final Map<String, Future<BloomIsrEntry>> _inFlight = {};

  /// Creates a [BloomIsrRenderer] backed by [store] (defaults to [MemoryBloomIsrStore]).
  BloomIsrRenderer({
    BloomIsrStore? store,
    DateTime Function()? clock,
  })  : _store = store ?? MemoryBloomIsrStore(),
        _clock = clock ?? DateTime.now;

  /// Renders or serves a cached response for [path] according to [config].
  Future<BloomIsrResult> render({
    required String path,
    required BloomRevalidateConfig config,
    required FutureOr<String> Function() renderHtml,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    int statusCode = 200,
  }) async {
    if (!config.isCacheableRequest(headers: headers)) {
      final html = await renderHtml();
      return BloomIsrResult(
        html: html,
        statusCode: statusCode,
        cacheStatus: BloomIsrCacheStatus.bypass,
        cacheControl: config.mode == BloomRenderMode.ssr
            ? config.toCacheControlHeader()
            : 'private, no-store',
      );
    }

    final key = config.cacheKeyFor(path, query: query, headers: headers);
    final existing = await _store.get(key);
    final now = _clock();

    if (existing != null) {
      if (existing.isFresh(now)) {
        return BloomIsrResult(
          html: existing.html,
          statusCode: existing.statusCode,
          headers: existing.headers,
          cacheStatus: BloomIsrCacheStatus.hit,
          cacheControl: config.toCacheControlHeader(),
        );
      }

      // Stale-while-revalidate: trigger background regeneration (deduplicated)
      // and return the stale entry immediately.
      _regenerate(
        key: key,
        config: config,
        renderHtml: renderHtml,
        statusCode: statusCode,
      ).ignore();

      return BloomIsrResult(
        html: existing.html,
        statusCode: existing.statusCode,
        headers: existing.headers,
        cacheStatus: BloomIsrCacheStatus.stale,
        cacheControl: config.toCacheControlHeader(),
      );
    }

    final generated = await _regenerate(
      key: key,
      config: config,
      renderHtml: renderHtml,
      statusCode: statusCode,
    );
    return BloomIsrResult(
      html: generated.html,
      statusCode: generated.statusCode,
      headers: generated.headers,
      cacheStatus: BloomIsrCacheStatus.miss,
      cacheControl: config.toCacheControlHeader(),
    );
  }

  Future<BloomIsrEntry> _regenerate({
    required String key,
    required BloomRevalidateConfig config,
    required FutureOr<String> Function() renderHtml,
    required int statusCode,
  }) {
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final completer = Completer<BloomIsrEntry>();
    _inFlight[key] = completer.future;

    () async {
      try {
        final html = await renderHtml();
        final entry = BloomIsrEntry(
          html: html,
          statusCode: statusCode,
          generatedAt: _clock(),
          revalidateAfter: config.revalidate,
          tags: config.tags,
        );
        await _store.put(key, entry);
        completer.complete(entry);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _inFlight.remove(key);
      }
    }();

    return completer.future;
  }

  /// Invalidates the cached entry for [path] (and any [varyQueryParams]/[varyHeaders]
  /// specified in [config]).
  Future<void> revalidatePath(
    String path, {
    BloomRevalidateConfig config = const BloomRevalidateConfig.ssg(),
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
  }) async {
    final key = config.cacheKeyFor(path, query: query, headers: headers);
    await _store.delete(key);
  }

  /// Invalidates all cached entries tagged with [tag] and returns the count removed.
  Future<int> revalidateTag(String tag) async {
    return await _store.deleteByTag(tag);
  }

  /// Awaits all currently in-flight background regenerations.
  Future<void> drainPending() async {
    while (_inFlight.isNotEmpty) {
      final snapshot = List<Future<BloomIsrEntry>>.of(_inFlight.values);
      for (final f in snapshot) {
        try {
          await f;
        } catch (_) {}
      }
    }
  }
}
