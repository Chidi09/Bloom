// lib/src/cache_middleware.dart
import 'dart:convert';
import 'package:bloom_server/bloom_server.dart';
import 'cache.dart';

/// Serializable representation of an HTTP response stored in cache.
class _CachedResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String bodyBase64;

  _CachedResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBase64,
  });

  Map<String, dynamic> toJson() => {
        'status': statusCode,
        'headers': headers,
        'body': bodyBase64,
      };

  factory _CachedResponse.fromJson(Map<String, dynamic> json) {
    return _CachedResponse(
      statusCode: json['status'] as int,
      headers: (json['headers'] as Map).cast<String, String>(),
      bodyBase64: json['body'] as String,
    );
  }

  BloomResponse toBloomResponse() {
    final resHeaders = Map<String, String>.from(headers);
    resHeaders['x-bloom-cache'] = 'HIT';

    return BloomResponse(
      statusCode: statusCode,
      headers: resHeaders,
      body: base64Decode(bodyBase64),
    );
  }

  factory _CachedResponse.fromBloomResponse(BloomResponse response) {
    return _CachedResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      bodyBase64: base64Encode(response.body),
    );
  }
}

/// HTTP-level response caching middleware for Bloom API routes and SSR servers.
///
/// Mirrors the design of `djangors-cache`'s `CacheLayer` / `CacheService`:
/// - Intercepts incoming `GET` requests only; non-`GET` requests pass through untouched.
/// - Caches entire HTTP responses (status code, headers, and body payload) under a key
///   derived from the request path and query parameters (`$keyPrefix:path?query`).
/// - On cache hits, returns the cached [BloomResponse] immediately with `x-bloom-cache: HIT`.
/// - On cache misses, passes down to the downstream handler, caches eligible responses, and
///   attaches `x-bloom-cache: MISS`.
///
/// ### Caching Eligibility & Opt-Out Rules
/// A response is cached only if ALL of the following criteria are met:
/// 1. HTTP method is `GET`.
/// 2. Request path does not match any prefix in [excludePaths].
/// 3. Custom [shouldCache] filter returns `true` (if provided).
/// 4. Response status code is in the 2xx range (200-299).
/// 5. Response does NOT set cookies (no `Set-Cookie` header).
/// 6. Response does NOT include `x-bloom-no-cache: true` or `1`.
/// 7. Response `Cache-Control` header does NOT contain `no-store`, `no-cache`, or `private`.
/// 8. If [requireExplicitCacheable] is `true`, response MUST include `x-bloom-cacheable: true`.
///
/// Example:
/// ```dart
/// final app = BloomServer();
/// final cache = InMemoryCache(maxCapacity: 1000);
///
/// app.use(BloomCacheMiddleware(
///   cache: cache,
///   ttl: const Duration(minutes: 10),
///   excludePaths: ['/api/auth', '/api/checkout'],
/// ));
/// ```
class BloomCacheMiddleware implements BloomMiddleware {
  /// The [BloomCache] backend where responses are stored.
  final BloomCache cache;

  /// Time-to-live duration for cached responses.
  ///
  /// Defaults to 5 minutes.
  final Duration ttl;

  /// Key prefix for cached HTTP responses in [cache].
  ///
  /// Defaults to `'http_cache'`.
  final String keyPrefix;

  /// List of URL path prefixes that should be excluded from caching.
  ///
  /// A path matches if it is identical to an exclusion entry or starts with `$path/`.
  /// Defaults to an empty list.
  final List<String> excludePaths;

  /// Optional custom filter predicate to determine whether a given [request] should be cached.
  ///
  /// If provided and returns `false`, caching is bypassed for this request.
  final bool Function(BloomRequest request)? shouldCache;

  /// Whether responses require an explicit `x-bloom-cacheable: true` header to be cached.
  ///
  /// When `true`, opt-in mode is enabled. Defaults to `false` (opt-out mode).
  final bool requireExplicitCacheable;

  /// Creates a [BloomCacheMiddleware] instance.
  ///
  /// Parameters:
  /// - [cache]: The underlying cache backend ([InMemoryCache], [DatabaseCache], or [RedisCache]).
  /// - [ttl]: Duration before cached responses expire. Defaults to 5 minutes.
  /// - [keyPrefix]: Cache key namespace. Defaults to `'http_cache'`.
  /// - [excludePaths]: Path prefixes to skip caching. Defaults to `[]`.
  /// - [shouldCache]: Custom request predicate to dynamically skip caching.
  /// - [requireExplicitCacheable]: If `true`, only responses with `x-bloom-cacheable: true` are cached.
  ///
  /// Example:
  /// ```dart
  /// final middleware = BloomCacheMiddleware(
  ///   cache: InMemoryCache(maxCapacity: 500),
  ///   ttl: const Duration(minutes: 15),
  ///   keyPrefix: 'v1_api',
  ///   excludePaths: ['/auth', '/admin'],
  /// );
  /// ```
  const BloomCacheMiddleware({
    required this.cache,
    this.ttl = const Duration(minutes: 5),
    this.keyPrefix = 'http_cache',
    this.excludePaths = const [],
    this.shouldCache,
    this.requireExplicitCacheable = false,
  });

  /// Computes the unique cache key for a given [request].
  ///
  /// Formats key as: `$keyPrefix:${request.path}?${request.uri.query}`
  /// (query string is omitted if empty).
  ///
  /// Example:
  /// ```dart
  /// // Produces 'http_cache:/api/users?page=2'
  /// final key = middleware.cacheKeyFor(request);
  /// ```
  String cacheKeyFor(BloomRequest request) {
    final query = request.uri.hasQuery ? '?${request.uri.query}' : '';
    return '$keyPrefix:${request.path}$query';
  }

  /// Processes the incoming [request] through the cache layer.
  ///
  /// Returns a cached [BloomResponse] on cache hit, or executes [next] and caches
  /// the returned response if eligible.
  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    // 1. Only GET requests are eligible for caching
    if (request.method.toUpperCase() != 'GET') {
      return next();
    }

    // 2. Check path exclusions
    for (final path in excludePaths) {
      if (request.path == path || request.path.startsWith('$path/')) {
        return next();
      }
    }

    // 3. Check custom shouldCache predicate
    if (shouldCache != null && !shouldCache!(request)) {
      return next();
    }

    final key = cacheKeyFor(request);

    // 4. Try reading cached response
    final cachedData = await cache.get<Map<String, dynamic>>(key);
    if (cachedData != null) {
      final cachedResponse = _CachedResponse.fromJson(cachedData);
      return cachedResponse.toBloomResponse();
    }

    // 5. Cache miss: execute downstream handler pipeline
    final response = await next();

    // 6. Inspect response eligibility for caching
    if (_isCacheable(response)) {
      final cached = _CachedResponse.fromBloomResponse(response);
      // Fire-and-forget cache set with configured TTL
      await cache.set(key, cached.toJson(), ttl: ttl);
    }

    response.headers['x-bloom-cache'] = 'MISS';
    return response;
  }

  bool _isCacheable(BloomResponse response) {
    // Only cache successful 2xx responses
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    // Never cache responses that issue cookies
    final hasSetCookie = response.headers.keys.any(
      (k) => k.toLowerCase() == 'set-cookie',
    );
    if (hasSetCookie) {
      return false;
    }

    // Check opt-out headers
    final noCacheHeader = response.headers['x-bloom-no-cache'] ??
        response.headers['X-Bloom-No-Cache'];
    if (noCacheHeader?.toLowerCase() == 'true' || noCacheHeader == '1') {
      return false;
    }

    final cacheControl = response.headers['cache-control'] ??
        response.headers['Cache-Control'];
    if (cacheControl != null) {
      final cc = cacheControl.toLowerCase();
      if (cc.contains('no-store') || cc.contains('no-cache') || cc.contains('private')) {
        return false;
      }
    }

    // If explicit cacheable marker is required, check for it
    if (requireExplicitCacheable) {
      final cacheableHeader = response.headers['x-bloom-cacheable'] ??
          response.headers['X-Bloom-Cacheable'];
      if (cacheableHeader?.toLowerCase() != 'true') {
        return false;
      }
    }

    return true;
  }
}

