// lib/src/throttling.dart
import 'dart:async';
import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_server/bloom_server.dart';
import 'permissions.dart';

/// Parses a DRF-style rate string such as `"100/hour"` or `"5/minute"` into a count and [Duration].
///
/// Accepts unit identifiers:
/// - `second`, `sec`, `s`
/// - `minute`, `min`, `m`
/// - `hour`, `hr`, `h`
/// - `day`, `d`
/// along with plural forms (e.g. `seconds`, `hours`).
///
/// Returns a tuple of `(int count, Duration window)`, or `null` if [rate] is malformed.
///
/// Example:
/// ```dart
/// final parsed = parseRate('100/hour');
/// if (parsed != null) {
///   print('Count: ${parsed.$1}, Window: ${parsed.$2}');
/// }
/// ```
///
/// Mirrors `djangors_rest::parse_rate`.
(int, Duration)? parseRate(String rate) {
  final parts = rate.split('/');
  if (parts.length != 2) return null;

  final count = int.tryParse(parts[0].trim());
  if (count == null || count <= 0) return null;

  var period = parts[1].trim().toLowerCase();
  if (period.endsWith('s') && period.length > 1) {
    period = period.substring(0, period.length - 1);
  }

  final Duration duration;
  switch (period) {
    case 's':
    case 'sec':
    case 'second':
      duration = const Duration(seconds: 1);
      break;
    case 'm':
    case 'min':
    case 'minute':
      duration = const Duration(minutes: 1);
      break;
    case 'h':
    case 'hr':
    case 'hour':
      duration = const Duration(hours: 1);
      break;
    case 'd':
    case 'day':
      duration = const Duration(days: 1);
      break;
    default:
      return null;
  }

  return (count, duration);
}

/// Strategy for resolving the rate-limiting key for an incoming request.
///
/// Implement this class to group or partition rate limit budgets by custom request attributes.
///
/// Example:
/// ```dart
/// class ByApiKey extends BloomRateLimitKey {
///   const ByApiKey();
///
///   @override
///   String key(BloomRequest req) =>
///       req.headers['x-api-key'] ?? 'anonymous';
/// }
/// ```
abstract class BloomRateLimitKey {
  /// Creates a [BloomRateLimitKey] instance.
  const BloomRateLimitKey();

  /// Returns the unique identity string key representing [req].
  FutureOr<String> key(BloomRequest req);
}

/// Extracts the immediate socket/transport peer IP address from [req].
typedef PeerAddressExtractor = String? Function(BloomRequest req);

/// Predicate returning `true` if [peerIp] is a trusted reverse proxy (e.g. cloud load balancer, internal gateway).
typedef TrustedProxyPredicate = bool Function(String peerIp);

/// Default peer extractor when BloomRequest does not expose a transport peer.
///
/// Request parameters and HTTP headers are client-controlled, so applications behind a
/// proxy must provide [ByUserOrIp.peerExtractor] from their trusted server adapter.
String? defaultPeerAddressExtractor(BloomRequest req) {
  return null;
}

/// Default trusted proxy predicate: never trusts any proxy by default (secure by default).
bool defaultNeverTrustProxy(String peerIp) => false;

/// Keys by authenticated user ID when available, falling back to client IP with proxy verification.
///
/// If [resolveCurrentUserId] finds a verified user ID, returns `'user:<id>'`.
/// Otherwise, extracts the immediate transport peer using [peerExtractor].
///
/// **Setup required**: [BloomRequest] carries no TCP peer by itself, so the
/// default [peerExtractor] ([defaultPeerAddressExtractor]) returns `null` and
/// every anonymous caller shares [fallbackKey] (`anon:shared_untrusted`) —
/// one aggressive client can 429 everyone. Wire [peerExtractor] from your
/// server adapter (the socket remote address of the *immediate* peer) and set
/// [isTrustedProxy] for your load balancers:
///
/// ```dart
/// final keyStrategy = ByUserOrIp(
///   peerExtractor: (req) => req.params['tcp_peer'],
///   isTrustedProxy: (ip) => ip == '10.0.0.1',
/// );
/// ```
///
/// When the shared fallback is used for an unauthenticated request, a loud
/// one-time warning is printed so the misconfiguration cannot stay silent.
///
/// **Header Spoofing Protection**:
/// Client forwarding headers (`X-Forwarded-For`, `X-Real-IP`) are **NEVER trusted**
/// unless [isTrustedProxy] returns `true` for the verified immediate transport peer.
/// If no immediate transport peer is available, returns [fallbackKey] to prevent
/// unauthenticated attackers from spoofing arbitrary IP headers to bypass rate limits.
///
/// Example:
/// ```dart
/// final keyStrategy = ByUserOrIp(
///   peerExtractor: (req) => req.params['tcp_peer'],
///   isTrustedProxy: (ip) => ip == '127.0.0.1' || ip == '10.0.0.1',
/// );
/// final key = keyStrategy.key(request);
/// ```
///
/// Mirrors `djangors_rest::ByUserOrIp`.
class ByUserOrIp extends BloomRateLimitKey {
  /// Predicate confirming whether the immediate transport peer is a trusted reverse proxy.
  final TrustedProxyPredicate isTrustedProxy;

  /// Extractor resolving the immediate socket/transport peer IP from the request.
  final PeerAddressExtractor peerExtractor;

  /// Shared non-spoofable fallback key returned when immediate peer IP cannot be resolved.
  final String fallbackKey;

  /// Whether the shared-bucket misconfiguration warning was already printed.
  static bool _warnedSharedBucket = false;

  /// Resets the one-time shared-bucket warning (primarily for tests).
  static void resetSharedBucketWarning() {
    _warnedSharedBucket = false;
  }

  /// Creates a [ByUserOrIp] key strategy.
  const ByUserOrIp({
    this.isTrustedProxy = defaultNeverTrustProxy,
    this.peerExtractor = defaultPeerAddressExtractor,
    this.fallbackKey = 'anon:shared_untrusted',
  });

  @override
  String key(BloomRequest req) {
    final userId = resolveCurrentUserId(req);
    if (userId != null && userId.isNotEmpty) {
      return 'user:$userId';
    }

    final peerIp = peerExtractor(req);
    if (peerIp == null || peerIp.isEmpty) {
      // Transport peer is unavailable; do NOT trust client forwarding headers.
      // Warn loudly (once) when using the default extractor: every anonymous
      // caller shares one global budget until peerExtractor is wired.
      if (identical(peerExtractor, defaultPeerAddressExtractor) &&
          !_warnedSharedBucket) {
        _warnedSharedBucket = true;
        // ignore: avoid_print
        print(
          '[bloom_rest] WARNING: ByUserOrIp is rate-limiting all anonymous '
          'clients under the single shared "$fallbackKey" bucket because no '
          'peerAddressExtractor is configured. One aggressive client can 429 '
          'everyone. Wire peerExtractor from your server adapter (immediate '
          'TCP peer) — see ByUserOrIp docs.',
        );
      }
      return fallbackKey;
    }

    if (isTrustedProxy(peerIp)) {
      final forwarded =
          req.headers['x-forwarded-for']?.split(',').first.trim() ??
              req.headers['x-real-ip']?.trim();
      if (forwarded != null && forwarded.isNotEmpty) {
        return 'anon:$forwarded';
      }
    }

    return 'anon:$peerIp';
  }
}

/// Interface for atomic rate-limiting storage engines.
///
/// Implementations record request timestamps and enforce rate limits atomically
/// without get-modify-set race conditions across concurrent processes or async tasks.
abstract class BloomAtomicThrottleStore {
  /// Base const constructor for atomic throttle stores.
  const BloomAtomicThrottleStore();

  /// Atomically attempts to record a request for [key] within [window] and checks if permitted.
  ///
  /// Returns `true` if the request is permitted within [maxRequests], or `false`
  /// if throttled (HTTP 429).
  Future<bool> allowRequest(String key, int maxRequests, Duration window);
}

/// In-memory implementation of [BloomAtomicThrottleStore].
///
/// Executes sliding-window timestamp calculations synchronously within the Dart isolate
/// event loop to guarantee atomic token accounting without async interleaving.
class InMemoryAtomicThrottleStore extends BloomAtomicThrottleStore {
  final Map<String, List<int>> _storage = {};

  /// Creates a new [InMemoryAtomicThrottleStore].
  InMemoryAtomicThrottleStore();

  @override
  Future<bool> allowRequest(
      String key, int maxRequests, Duration window) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - window.inMilliseconds;

    final timestamps = _storage.putIfAbsent(key, () => <int>[]);
    timestamps.removeWhere((t) => t <= cutoff);

    if (timestamps.length >= maxRequests) {
      return false;
    }

    timestamps.add(now);
    return true;
  }

  /// Clears all stored rate limit keys.
  void clear() => _storage.clear();
}

/// DRF-style request throttle supporting atomic storage engines and [BloomCache] backends.
///
/// Tracks sliding-window request timestamps per unique caller key derived by [keyStrategy].
/// When the request count exceeds [maxRequests] within [window], subsequent requests
/// are denied with HTTP 429 Too Many Requests.
///
/// ### Concurrency & Atomicity Contract
/// - When configured with a [BloomAtomicThrottleStore] via [atomicStore], rate limiting
///   is enforced atomically without get-modify-set races.
/// - When configured with a generic [cache] ([BloomCache]), operations perform an async
///   get-modify-set sequence. This cache-backed path is **unsuitable for distributed,
///   multi-process, or high-concurrency race-free enforcement** unless backed by an
///   atomic store.
///
/// Example:
/// ```dart
/// final throttle = BloomThrottle.fromRate(
///   scope: 'articles_api',
///   rate: '60/minute',
///   atomicStore: InMemoryAtomicThrottleStore(),
/// );
///
/// if (!await throttle.allowRequest(request)) {
///   return BloomResponse.json({'error': 'Too Many Requests'}, statusCode: 429);
/// }
/// ```
///
/// Mirrors `djangors_rest::Throttle`.
class BloomThrottle {
  /// Unique scope isolating this budget from other endpoints.
  final String scope;

  /// Maximum requests allowed within [window].
  final int maxRequests;

  /// Time window duration.
  final Duration window;

  /// Underlying [BloomCache] instance for non-atomic caching fallback.
  ///
  /// NOTE: The generic [BloomCache] interface does not provide atomic sliding-window primitives.
  /// The [cache] path performs a non-atomic get-modify-set cycle and is not suitable for
  /// race-free distributed concurrent rate-limiting. For atomic enforcement, use [atomicStore].
  final BloomCache? cache;

  /// Optional atomic rate-limiting store.
  final BloomAtomicThrottleStore? atomicStore;

  /// Key derivation strategy (defaults to [ByUserOrIp]).
  final BloomRateLimitKey keyStrategy;

  /// Creates a [BloomThrottle] with explicit [maxRequests] and [window].
  BloomThrottle({
    required this.scope,
    required this.maxRequests,
    required this.window,
    this.cache,
    this.atomicStore,
    this.keyStrategy = const ByUserOrIp(),
  }) : assert(
          cache != null || atomicStore != null,
          'Either cache or atomicStore must be provided to BloomThrottle.',
        );

  /// Factory constructor parsing a rate string like `"100/hour"` with [cache] or [atomicStore].
  ///
  /// Throws [ArgumentError] if [rate] format is invalid.
  factory BloomThrottle.fromRate({
    required String scope,
    required String rate,
    BloomCache? cache,
    BloomAtomicThrottleStore? atomicStore,
    BloomRateLimitKey keyStrategy = const ByUserOrIp(),
  }) {
    final parsed = parseRate(rate);
    if (parsed == null) {
      throw ArgumentError.value(
        rate,
        'rate',
        'Invalid rate string format. Expected format like "100/hour", "10/minute", "5/s".',
      );
    }
    return BloomThrottle(
      scope: scope,
      maxRequests: parsed.$1,
      window: parsed.$2,
      cache: cache,
      atomicStore: atomicStore,
      keyStrategy: keyStrategy,
    );
  }

  /// Checks if [req] is within rate limits.
  ///
  /// Returns `true` if the request is permitted, or `false` if throttled (HTTP 429).
  Future<bool> allowRequest(BloomRequest req) async {
    final identKey = await keyStrategy.key(req);
    final throttleKey = 'throttle:$scope:$identKey';

    if (atomicStore != null) {
      return await atomicStore!.allowRequest(throttleKey, maxRequests, window);
    }

    // Non-atomic fallback path via BloomCache.
    // NOTE: This get-modify-set cycle across asynchronous cache boundaries is subject
    // to race conditions under concurrent requests. Use BloomAtomicThrottleStore for
    // atomic race-free rate limiting.
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = window.inMilliseconds;
    final cutoff = now - windowMs;

    final timestamps =
        (await cache!.get<List<dynamic>>(throttleKey)) ?? <dynamic>[];
    final active = timestamps
        .map((t) => t is int ? t : int.tryParse(t.toString()) ?? 0)
        .where((t) => t > cutoff)
        .toList();

    if (active.length >= maxRequests) {
      return false;
    }

    active.add(now);
    await cache!.set<List<int>>(
      throttleKey,
      active,
      ttl: window,
    );
    return true;
  }
}
