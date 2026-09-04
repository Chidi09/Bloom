import 'dart:async';
import 'package:bloom_server/bloom_server.dart';

/// Predicate deciding whether an immediate peer address represents a trusted reverse proxy or load balancer.
///
/// When this returns `true` for the immediate connection peer, forwarding headers (`CF-Connecting-IP`,
/// `X-Forwarded-For`, `X-Real-IP`, `True-Client-IP`) are inspected to identify downstream client IPs.
///
/// Example:
/// ```dart
/// bool isCloudflareOrInternal(String peer) {
///   return peer == '127.0.0.1' || peer.startsWith('10.0.');
/// }
/// ```
typedef BloomTrustedProxyPredicate = bool Function(String peerAddress);

/// Function signature for extracting the immediate peer IP or transport address from an incoming [BloomRequest].
///
/// Returns `null` if the immediate peer address cannot be determined.
typedef BloomPeerAddressExtractor = String? Function(BloomRequest request);

/// Function signature for extracting a rate-limiting key from an incoming [BloomRequest].
///
/// The returned string serves as the bucket identifier (e.g. client IP address, API key,
/// or authenticated user ID).
///
/// Example:
/// ```dart
/// String apiKeyExtractor(BloomRequest request) {
///   return request.headers['x-api-key'] ?? 'anonymous';
/// }
/// ```
typedef BloomRateLimitKeyExtractor = String Function(BloomRequest request);

/// Function signature for building a custom [BloomResponse] when a rate limit is exceeded.
///
/// Receives the incoming [request], the [retryAfter] duration before requests may resume,
/// and the maximum request [limit] configured for the window.
///
/// Example:
/// ```dart
/// BloomResponse customRateLimitHandler(
///   BloomRequest request,
///   Duration retryAfter,
///   int limit,
/// ) {
///   return BloomResponse.json(
///     {'error': 'quota_exceeded', 'retry_in_seconds': retryAfter.inSeconds},
///     statusCode: 429,
///   );
/// }
/// ```
typedef BloomRateLimitExceededHandler = BloomResponse Function(
  BloomRequest request,
  Duration retryAfter,
  int limit,
);

/// Evaluation result returned from a [BloomRateLimitStore].
class BloomRateLimitResult {
  /// Whether the request is permitted within the rate limit.
  final bool isAllowed;

  /// Maximum request limit configured for the sliding window.
  final int limit;

  /// Remaining number of requests permitted in the current window.
  final int remaining;

  /// Epoch timestamp in seconds when the rate limit window resets.
  final int resetEpochSeconds;

  /// Duration before requests may resume if rate limit was exceeded.
  final Duration retryAfter;

  /// Creates a [BloomRateLimitResult] instance.
  const BloomRateLimitResult({
    required this.isAllowed,
    required this.limit,
    required this.remaining,
    required this.resetEpochSeconds,
    required this.retryAfter,
  });

  /// Factory constructor for an allowed request.
  factory BloomRateLimitResult.allowed({
    required int limit,
    required int remaining,
    required int resetEpochSeconds,
  }) {
    return BloomRateLimitResult(
      isAllowed: true,
      limit: limit,
      remaining: remaining,
      resetEpochSeconds: resetEpochSeconds,
      retryAfter: Duration.zero,
    );
  }

  /// Factory constructor for a rate-limited / exceeded request.
  factory BloomRateLimitResult.exceeded({
    required int limit,
    required int resetEpochSeconds,
    required Duration retryAfter,
  }) {
    return BloomRateLimitResult(
      isAllowed: false,
      limit: limit,
      remaining: 0,
      resetEpochSeconds: resetEpochSeconds,
      retryAfter: retryAfter,
    );
  }
}

/// Abstract storage and evaluation strategy contract for rate limit tracking.
///
/// Implementations can back rate limiting via in-memory sliding windows ([BloomInMemoryRateLimitStore]),
/// shared database backends, distributed caches, or token bucket stores.
abstract class BloomRateLimitStore {
  /// Records a hit for [key] and evaluates rate limit status against [maxRequests] and [window].
  FutureOr<BloomRateLimitResult> recordAndCheck({
    required String key,
    required int maxRequests,
    required Duration window,
  });

  /// Resets all tracked rate limit state or clears a specific [key].
  FutureOr<void> reset([String? key]);

  /// Closes background timers or releases resources held by this store.
  FutureOr<void> dispose();
}

/// In-memory sliding-window implementation of [BloomRateLimitStore].
///
/// Features:
/// - Sub-millisecond sliding-window timestamp tracking preventing burst attacks across fixed window boundaries.
/// - Concurrency-safe in Dart isolate event loops (synchronous check-and-increment operations).
/// - Periodic memory pruning of stale timestamp entries.
class BloomInMemoryRateLimitStore implements BloomRateLimitStore {
  final Map<String, List<int>> _buckets = {};
  Timer? _cleanupTimer;

  /// Longest window ever enforced by this store (ms). The periodic prune
  /// must retain entries for at least this long, otherwise long windows
  /// (e.g. 1 hour) would be silently unenforced by an early cutoff.
  /// Starts at the legacy 10-minute horizon.
  int _longestWindowMs = 600000;

  /// Minimum retention applied by the periodic prune even for short windows.
  static const int _minRetentionMs = 60000;

  /// Creates an in-memory sliding-window rate limit store.
  BloomInMemoryRateLimitStore({
    Duration cleanupInterval = const Duration(minutes: 5),
  }) {
    if (cleanupInterval > Duration.zero) {
      _cleanupTimer =
          Timer.periodic(cleanupInterval, (_) => _pruneStaleBuckets());
    }
  }

  @override
  BloomRateLimitResult recordAndCheck({
    required String key,
    required int maxRequests,
    required Duration window,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = window.inMilliseconds;
    if (windowMs > _longestWindowMs) _longestWindowMs = windowMs;
    final windowStart = now - windowMs;

    final timestamps = _buckets.putIfAbsent(key, () => []);
    timestamps.removeWhere((ts) => ts < windowStart);

    final currentCount = timestamps.length;
    if (currentCount >= maxRequests) {
      final oldestTimestamp = timestamps.first;
      final resetAtMs = oldestTimestamp + windowMs;
      final retryAfterMs = (resetAtMs - now).clamp(1000, windowMs);
      final retryAfter = Duration(milliseconds: retryAfterMs);
      final resetSeconds = (resetAtMs / 1000).ceil();

      return BloomRateLimitResult.exceeded(
        limit: maxRequests,
        resetEpochSeconds: resetSeconds,
        retryAfter: retryAfter,
      );
    }

    timestamps.add(now);
    final remaining = (maxRequests - timestamps.length).clamp(0, maxRequests);
    final resetAtMs = timestamps.first + windowMs;
    final resetSeconds = (resetAtMs / 1000).ceil();

    return BloomRateLimitResult.allowed(
      limit: maxRequests,
      remaining: remaining,
      resetEpochSeconds: resetSeconds,
    );
  }

  @override
  void reset([String? key]) {
    if (key != null) {
      _buckets.remove(key);
    } else {
      _buckets.clear();
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _buckets.clear();
  }

  void _pruneStaleBuckets({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    // Retain entries for the longest window ever enforced (at least the
    // minimum retention). A fixed cutoff ignores the configured window and
    // silently unenforces long windows.
    var horizon = _longestWindowMs;
    if (horizon < _minRetentionMs) horizon = _minRetentionMs;
    final cutoff = now - horizon;
    _buckets.removeWhere((_, timestamps) {
      timestamps.removeWhere((ts) => ts < cutoff);
      return timestamps.isEmpty;
    });
  }

  /// Testing hook: runs the stale-bucket prune as of [now] (defaults to the
  /// clock). Exposed so long-window retention can be verified without
  /// waiting out real windows.
  void debugPrune({DateTime? now}) {
    _pruneStaleBuckets(nowMs: now?.millisecondsSinceEpoch);
  }
}

/// Hardened sliding-window rate limiting middleware for Bloom applications.
///
/// Features:
/// - Exact sliding-window tracking preventing burst attacks.
/// - Secure proxy header defense: does NOT trust `CF-Connecting-IP`, `X-Forwarded-For`,
///   `X-Real-IP`, or `True-Client-IP` unless [isTrustedProxy] approves the immediate peer.
/// - Safe non-spoofable fallback key (`'anonymous_peer'`) when peer address is unavailable.
/// - Pluggable [BloomRateLimitStore] extension point suitable for shared/distributed backends.
/// - Standard rate-limiting headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After`).
///
/// **Setup required for anonymous traffic**: [BloomRequest] carries no TCP peer,
/// so without [peerAddressExtractor] every anonymous client shares the single
/// `'anonymous_peer'` bucket (one aggressive client 429s everyone). Wire it
/// from your server adapter — the *immediate* TCP peer, never a client header:
///
/// Example:
/// ```dart
/// final rateLimiter = BloomRateLimitMiddleware(
///   maxRequests: 100,
///   window: const Duration(minutes: 1),
///   peerAddressExtractor: (req) => req.params['tcp_peer'],
///   isTrustedProxy: (peer) => peer == '10.0.0.1',
///   whitelist: {'127.0.0.1'},
/// );
/// router.use(rateLimiter);
/// ```
class BloomRateLimitMiddleware implements BloomMiddleware {
  /// Maximum number of allowed requests within the time [window].
  final int maxRequests;

  /// Time duration of the sliding window.
  final Duration window;

  /// Custom key extractor function. Defaults to secure client IP extraction.
  final BloomRateLimitKeyExtractor keyExtractor;

  /// Custom handler returning a custom [BloomResponse] when rate limit is exceeded.
  final BloomRateLimitExceededHandler? onRateLimitExceeded;

  /// Set of keys or IP addresses that bypass rate limiting completely.
  final Set<String> whitelist;

  /// Whether to include `X-RateLimit-*` headers in responses.
  final bool includeHeaders;

  /// Underlying storage strategy for recording and evaluating rate limits.
  final BloomRateLimitStore store;

  /// Whether [store] was created by this middleware (and must be disposed
  /// if construction fails validation, so no background timer leaks).
  final bool _ownsStore;

  /// Predicate determining whether an immediate peer address is trusted to forward client IP headers.
  final BloomTrustedProxyPredicate? isTrustedProxy;

  /// Optional extractor for the immediate peer address from the incoming [BloomRequest].
  final BloomPeerAddressExtractor? peerAddressExtractor;

  /// Whether the shared-bucket misconfiguration warning was already printed.
  static bool _warnedAnonymousBucket = false;

  /// Resets the one-time shared-bucket warning (primarily for tests).
  static void resetAnonymousBucketWarning() {
    _warnedAnonymousBucket = false;
  }

  /// Creates a hardened sliding-window rate limiter middleware.
  ///
  /// - [maxRequests]: Maximum requests permitted within [window] (must be > 0, defaults to 60).
  /// - [window]: Sliding window duration (must be > [Duration.zero], defaults to 1 minute).
  /// - [keyExtractor]: Custom key extraction function. If omitted, uses hardened IP extraction.
  /// - [onRateLimitExceeded]: Optional custom handler when rate limit is exceeded.
  /// - [whitelist]: Set of keys/IPs exempt from rate limiting.
  /// - [includeHeaders]: Whether to emit `X-RateLimit-*` headers (defaults to `true`).
  /// - [cleanupInterval]: Periodic memory cleanup interval for default in-memory store (defaults to 5 minutes).
  /// - [store]: Optional custom [BloomRateLimitStore] backend.
  /// - [isTrustedProxy]: Optional predicate determining if immediate peer IP is trusted.
  /// - [peerAddressExtractor]: Optional peer IP extractor.
  BloomRateLimitMiddleware({
    this.maxRequests = 60,
    this.window = const Duration(minutes: 1),
    BloomRateLimitKeyExtractor? keyExtractor,
    this.onRateLimitExceeded,
    this.whitelist = const {},
    this.includeHeaders = true,
    Duration cleanupInterval = const Duration(minutes: 5),
    BloomRateLimitStore? store,
    this.isTrustedProxy,
    this.peerAddressExtractor,
  })  : store = store ??
            BloomInMemoryRateLimitStore(cleanupInterval: cleanupInterval),
        _ownsStore = store == null,
        keyExtractor = keyExtractor ??
            _createDefaultKeyExtractor(isTrustedProxy, peerAddressExtractor) {
    try {
      _validateArgs(maxRequests, window, cleanupInterval);
    } catch (_) {
      // Construction failed after the initializer list already created the
      // default store (and its periodic timer): dispose it so the timer
      // cannot keep the isolate alive with no owner to dispose it.
      if (_ownsStore) this.store.dispose();
      rethrow;
    }
  }

  static void _validateArgs(
      int maxRequests, Duration window, Duration cleanupInterval) {
    if (maxRequests <= 0) {
      throw ArgumentError.value(
        maxRequests,
        'maxRequests',
        'maxRequests must be greater than 0',
      );
    }
    if (window <= Duration.zero) {
      throw ArgumentError.value(
        window,
        'window',
        'window duration must be greater than Duration.zero',
      );
    }
    if (cleanupInterval <= Duration.zero) {
      throw ArgumentError.value(
        cleanupInterval,
        'cleanupInterval',
        'cleanupInterval must be greater than Duration.zero',
      );
    }
  }

  /// Cancels background cleanup timers and clears rate-limit state in the underlying store.
  void dispose() {
    store.dispose();
  }

  /// Resets rate-limit state in the underlying store.
  void reset([String? key]) {
    store.reset(key);
  }

  /// Intercepts the incoming [request] and enforces rate limits against the client key.
  @override
  Future<BloomResponse?> handle(
      BloomRequest request, BloomNextFunction next) async {
    final key = keyExtractor(request);

    // Whitelisted keys bypass rate limiting completely
    if (whitelist.contains(key)) {
      return await next();
    }

    final result = await store.recordAndCheck(
      key: key,
      maxRequests: maxRequests,
      window: window,
    );

    if (!result.isAllowed) {
      final retryAfterSeconds =
          (result.retryAfter.inMilliseconds / 1000).ceil();

      if (onRateLimitExceeded != null) {
        final customRes = onRateLimitExceeded!(
          request,
          result.retryAfter,
          maxRequests,
        );
        _applyRateLimitHeaders(
          customRes.headers,
          limit: maxRequests,
          remaining: 0,
          resetEpochSeconds: result.resetEpochSeconds,
          retryAfterSeconds: retryAfterSeconds,
        );
        return customRes;
      }

      final errorHeaders = <String, String>{};
      _applyRateLimitHeaders(
        errorHeaders,
        limit: maxRequests,
        remaining: 0,
        resetEpochSeconds: result.resetEpochSeconds,
        retryAfterSeconds: retryAfterSeconds,
      );

      return BloomResponse.json(
        {
          'error': 'Too Many Requests',
          'statusCode': 429,
          'message':
              'Rate limit exceeded. Please retry in $retryAfterSeconds seconds.',
          'retryAfterSeconds': retryAfterSeconds,
        },
        statusCode: 429,
        headers: errorHeaders,
      );
    }

    final response = await next();

    if (includeHeaders) {
      _applyRateLimitHeaders(
        response.headers,
        limit: maxRequests,
        remaining: result.remaining,
        resetEpochSeconds: result.resetEpochSeconds,
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
    headers['x-ratelimit-limit'] = limit.toString();
    headers['x-ratelimit-remaining'] = remaining.toString();
    headers['x-ratelimit-reset'] = resetEpochSeconds.toString();

    if (retryAfterSeconds != null) {
      headers['retry-after'] = retryAfterSeconds.toString();
    }
  }

  static BloomRateLimitKeyExtractor _createDefaultKeyExtractor(
    BloomTrustedProxyPredicate? isTrustedProxy,
    BloomPeerAddressExtractor? peerAddressExtractor,
  ) {
    return (BloomRequest request) {
      // 1. Resolve immediate peer address
      final peerAddress =
          peerAddressExtractor?.call(request) ?? _extractImmediatePeer(request);

      // 2. If peer address is unavailable, use safe non-spoofable fallback.
      // Warn loudly (once) when no extractor is wired: every anonymous
      // client then shares one global budget.
      if (peerAddress == null || peerAddress.trim().isEmpty) {
        if (peerAddressExtractor == null &&
            !_warnedAnonymousBucket) {
          _warnedAnonymousBucket = true;
          // ignore: avoid_print
          print(
            '[bloom_security] WARNING: rate-limiting all anonymous clients '
            'under the single shared "anonymous_peer" bucket because no '
            'peerAddressExtractor is configured. One aggressive client can '
            '429 everyone (self-DoS). Wire peerAddressExtractor from your '
            'server adapter — see BloomRateLimitMiddleware docs.',
          );
        }
        return 'anonymous_peer';
      }

      final cleanPeer = peerAddress.trim();

      // 3. Inspect forwarding headers ONLY if immediate peer is an approved trusted proxy
      if (isTrustedProxy != null && isTrustedProxy(cleanPeer)) {
        final headers = request.headers;

        final cfIp = _getHeader(headers, 'cf-connecting-ip');
        if (cfIp != null && cfIp.trim().isNotEmpty) {
          return cfIp.trim();
        }

        final xForwardedFor = _getHeader(headers, 'x-forwarded-for');
        if (xForwardedFor != null && xForwardedFor.trim().isNotEmpty) {
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

        return cleanPeer;
      }

      // 4. Untrusted peer: rate limit directly by immediate peer address
      return cleanPeer;
    };
  }

  static String? _extractImmediatePeer(BloomRequest request) {
    // BloomRequest does not expose the TCP peer. HTTP headers are client-controlled,
    // so callers must provide peerAddressExtractor when proxy-aware limiting is needed.
    return null;
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
