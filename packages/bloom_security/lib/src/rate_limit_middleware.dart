import 'dart:async';
import 'package:bloom_framework/bloom_server.dart';

/// Function signature for extracting a rate-limiting key from a request.
typedef BloomRateLimitKeyExtractor = String Function(BloomRequest request);

/// Function signature for building a custom response when rate limit is exceeded.
typedef BloomRateLimitExceededHandler = BloomResponse Function(
  BloomRequest request,
  Duration retryAfter,
  int limit,
);

/// In-memory sliding-window rate limiting middleware for Bloom applications.
///
/// Features:
/// - Exact sliding-window timestamp tracking preventing burst attacks across fixed window boundaries.
/// - Concurrency-safe in Dart isolate event loops (atomic synchronous check-and-increment before yield).
/// - Default client IP extraction with proxy/CDN header awareness (`CF-Connecting-IP`, `X-Forwarded-For`, `X-Real-IP`).
/// - Standard rate-limiting headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After`).
/// - Automatic periodic memory cleanup of idle client buckets.
class BloomRateLimitMiddleware implements BloomMiddleware {
  /// Maximum number of allowed requests within the time [window].
  final int maxRequests;

  /// Time duration of the sliding window.
  final Duration window;

  /// Custom key extractor function. Defaults to client IP address.
  final BloomRateLimitKeyExtractor keyExtractor;

  /// Custom handler when rate limit is exceeded.
  final BloomRateLimitExceededHandler? onRateLimitExceeded;

  /// Set of keys or IP addresses that bypass rate limiting.
  final Set<String> whitelist;

  /// Whether to include `X-RateLimit-*` headers in all responses.
  final bool includeHeaders;

  // In-memory sliding window bucket store: Map<Key, List<TimestampMillis>>
  final Map<String, List<int>> _buckets = {};
  Timer? _cleanupTimer;

  /// Creates a sliding-window rate limiter middleware.
  ///
  /// - [maxRequests]: Maximum requests permitted within [window] duration per client key.
  /// - [window]: Sliding window duration (defaults to 1 minute).
  /// - [keyExtractor]: Custom function to extract a unique client key (defaults to client IP / reverse proxy headers).
  /// - [onRateLimitExceeded]: Optional handler returning a custom [BloomResponse] when rate limit is exceeded.
  /// - [whitelist]: Set of keys or IPs that are exempt from rate limiting.
  /// - [includeHeaders]: Whether to emit `X-RateLimit-*` and `Retry-After` headers on responses.
  /// - [cleanupInterval]: Frequency at which idle client buckets are purged from memory.
  BloomRateLimitMiddleware({
    this.maxRequests = 60,
    this.window = const Duration(minutes: 1),
    BloomRateLimitKeyExtractor? keyExtractor,
    this.onRateLimitExceeded,
    this.whitelist = const {},
    this.includeHeaders = true,
    Duration cleanupInterval = const Duration(minutes: 5),
  }) : keyExtractor = keyExtractor ?? _defaultIpExtractor {
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) => _pruneAllStaleBuckets());
  }

  /// Cancels background cleanup timers.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _buckets.clear();
  }

  /// Resets all rate-limit buckets.
  void reset() {
    _buckets.clear();
  }

  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    final key = keyExtractor(request);

    // Whitelisted keys bypass rate limiting completely
    if (whitelist.contains(key)) {
      return await next();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = window.inMilliseconds;
    final windowStart = now - windowMs;

    // CONCURRENCY SAFETY:
    // The check, timestamp pruning, threshold calculation, and token addition are executed
    // synchronously without any `await` or asynchronous yields. In the Dart isolate execution
    // model, this guarantees atomic check-and-increment operations across concurrent HTTP requests.
    final timestamps = _buckets.putIfAbsent(key, () => []);

    // Prune timestamps older than current sliding window
    timestamps.removeWhere((ts) => ts < windowStart);

    final currentCount = timestamps.length;

    if (currentCount >= maxRequests) {
      final oldestTimestamp = timestamps.first;
      final resetAtMs = oldestTimestamp + windowMs;
      final retryAfterMs = (resetAtMs - now).clamp(1000, windowMs);
      final retryAfter = Duration(milliseconds: retryAfterMs);
      final retryAfterSeconds = (retryAfterMs / 1000).ceil();
      final resetSeconds = (resetAtMs / 1000).ceil();

      if (onRateLimitExceeded != null) {
        final customRes = onRateLimitExceeded!(request, retryAfter, maxRequests);
        _applyRateLimitHeaders(
          customRes.headers,
          limit: maxRequests,
          remaining: 0,
          resetEpochSeconds: resetSeconds,
          retryAfterSeconds: retryAfterSeconds,
        );
        return customRes;
      }

      final errorHeaders = <String, String>{};
      _applyRateLimitHeaders(
        errorHeaders,
        limit: maxRequests,
        remaining: 0,
        resetEpochSeconds: resetSeconds,
        retryAfterSeconds: retryAfterSeconds,
      );

      return BloomResponse.json(
        {
          'error': 'Too Many Requests',
          'statusCode': 429,
          'message': 'Rate limit exceeded. Please retry in $retryAfterSeconds seconds.',
          'retryAfterSeconds': retryAfterSeconds,
        },
        statusCode: 429,
        headers: errorHeaders,
      );
    }

    // Record this request
    timestamps.add(now);

    final remaining = (maxRequests - timestamps.length).clamp(0, maxRequests);
    final resetAtMs = timestamps.first + windowMs;
    final resetSeconds = (resetAtMs / 1000).ceil();

    final response = await next();

    if (includeHeaders) {
      _applyRateLimitHeaders(
        response.headers,
        limit: maxRequests,
        remaining: remaining,
        resetEpochSeconds: resetSeconds,
      );
    }

    return response;
  }

  void _applyRateLimitHeaders(
    Map<String, String> headers, {
    required int limit,
    required int remaining,
    required int resetEpochSeconds,
    int? retryAfterSeconds,
  }) {
    headers['X-RateLimit-Limit'] = limit.toString();
    headers['x-ratelimit-limit'] = limit.toString();
    headers['X-RateLimit-Remaining'] = remaining.toString();
    headers['x-ratelimit-remaining'] = remaining.toString();
    headers['X-RateLimit-Reset'] = resetEpochSeconds.toString();
    headers['x-ratelimit-reset'] = resetEpochSeconds.toString();

    if (retryAfterSeconds != null) {
      headers['Retry-After'] = retryAfterSeconds.toString();
      headers['retry-after'] = retryAfterSeconds.toString();
    }
  }

  void _pruneAllStaleBuckets() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = now - window.inMilliseconds;

    _buckets.removeWhere((key, timestamps) {
      timestamps.removeWhere((ts) => ts < windowStart);
      return timestamps.isEmpty;
    });
  }

  static String _defaultIpExtractor(BloomRequest request) {
    // Check common reverse-proxy headers in order of preference
    final headers = request.headers;

    final cfIp = _getHeader(headers, 'cf-connecting-ip');
    if (cfIp != null && cfIp.trim().isNotEmpty) {
      return cfIp.trim();
    }

    final xForwardedFor = _getHeader(headers, 'x-forwarded-for');
    if (xForwardedFor != null && xForwardedFor.trim().isNotEmpty) {
      // First IP in comma-separated list is the client origin
      final ips = xForwardedFor.split(',');
      if (ips.isNotEmpty && ips.first.trim().isNotEmpty) {
        return ips.first.trim();
      }
    }

    final xRealIp = _getHeader(headers, 'x-real-ip');
    if (xRealIp != null && xRealIp.trim().isNotEmpty) {
      return xRealIp.trim();
    }

    final trueClientIp = _getHeader(headers, 'true-client-ip');
    if (trueClientIp != null && trueClientIp.trim().isNotEmpty) {
      return trueClientIp.trim();
    }

    return 'unknown_client';
  }

  static String? _getHeader(Map<String, String> headers, String name) {
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value;
      }
    }
    return null;
  }
}
