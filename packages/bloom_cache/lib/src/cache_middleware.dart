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
///   derived from the request path and query parameters (`path?query`).
/// - On cache hits, returns the cached [BloomResponse] immediately with `x-bloom-cache: HIT`.
/// - Supports multiple opt-out mechanisms:
///   - Route handlers can send `x-bloom-no-cache: true` or `cache-control: no-store` / `no-cache`.
///   - Responses that set cookies (`set-cookie` header) are never cached to avoid leaking session data.
///   - Configurable [excludePaths] prefix list and custom [shouldCache] filter predicate.
class BloomCacheMiddleware implements BloomMiddleware {
  /// The [BloomCache] backend where responses are stored.
  final BloomCache cache;

  /// Time-to-live duration for cached responses.
  final Duration ttl;

  /// Key prefix for cached HTTP responses.
  final String keyPrefix;

  /// List of URL paths that should be excluded from caching.
  final List<String> excludePaths;

  /// Custom filter function to determine whether a given request should be cached.
  final bool Function(BloomRequest request)? shouldCache;

  /// If true, only responses with `x-bloom-cacheable: true` header will be cached.
  final bool requireExplicitCacheable;

  /// Creates a [BloomCacheMiddleware] instance.
  const BloomCacheMiddleware({
    required this.cache,
    this.ttl = const Duration(minutes: 5),
    this.keyPrefix = 'http_cache',
    this.excludePaths = const [],
    this.shouldCache,
    this.requireExplicitCacheable = false,
  });

  /// Computes the unique cache key for a given [request].
  String cacheKeyFor(BloomRequest request) {
    final query = request.uri.hasQuery ? '?${request.uri.query}' : '';
    return '$keyPrefix:${request.path}$query';
  }

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
