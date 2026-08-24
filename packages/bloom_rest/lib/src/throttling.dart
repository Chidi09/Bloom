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

/// Keys by authenticated user ID when available, falling back to client IP.
///
/// If [resolveCurrentUserId] finds a verified user ID, returns `'user:<id>'`.
/// Otherwise checks `X-Forwarded-For`, `X-Real-IP`, `Remote-Addr`, returning `'anon:<ip>'`.
///
/// Example:
/// ```dart
/// const keyStrategy = ByUserOrIp();
/// final key = keyStrategy.key(request);
/// ```
///
/// Mirrors `djangors_rest::ByUserOrIp`.
class ByUserOrIp extends BloomRateLimitKey {
  /// Creates a [ByUserOrIp] key strategy.
  const ByUserOrIp();

  @override
  String key(BloomRequest req) {
    final userId = resolveCurrentUserId(req);
    if (userId != null && userId.isNotEmpty) {
      return 'user:$userId';
    }

    final ip = req.headers['x-forwarded-for']?.split(',').first.trim() ??
        req.headers['x-real-ip'] ??
        req.headers['remote-addr'] ??
        '127.0.0.1';
    return 'anon:$ip';
  }
}

/// DRF-style request throttle built on top of [BloomCache].
///
/// Tracks sliding-window request timestamps in [cache] per unique caller key.
/// When the request count exceeds [maxRequests] within [window], subsequent requests
/// are denied with HTTP 429 Too Many Requests.
///
/// Example:
/// ```dart
/// final throttle = BloomThrottle.fromRate(
///   scope: 'articles_api',
///   rate: '60/minute',
///   cache: memoryCache,
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

  /// Underlying [BloomCache] instance storing sliding timestamp windows.
  final BloomCache cache;

  /// Key derivation strategy (defaults to [ByUserOrIp]).
  final BloomRateLimitKey keyStrategy;

  /// Creates a [BloomThrottle] with explicit [maxRequests] and [window].
  BloomThrottle({
    required this.scope,
    required this.maxRequests,
    required this.window,
    required this.cache,
    this.keyStrategy = const ByUserOrIp(),
  });

  /// Factory constructor parsing a rate string like `"100/hour"` with [cache].
  ///
  /// Throws [ArgumentError] if [rate] format is invalid.
  factory BloomThrottle.fromRate({
    required String scope,
    required String rate,
    required BloomCache cache,
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
      keyStrategy: keyStrategy,
    );
  }

  /// Checks if [req] is within rate limits.
  ///
  /// Returns `true` if the request is permitted, or `false` if throttled (HTTP 429).
  Future<bool> allowRequest(BloomRequest req) async {
    final identKey = await keyStrategy.key(req);
    final cacheKey = 'throttle:$scope:$identKey';
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = window.inMilliseconds;
    final cutoff = now - windowMs;

    // We store timestamps of requests in the current window as a list of integers
    final timestamps = (await cache.get<List<dynamic>>(cacheKey)) ?? <dynamic>[];
    final active = timestamps
        .map((t) => t is int ? t : int.tryParse(t.toString()) ?? 0)
        .where((t) => t > cutoff)
        .toList();

    if (active.length >= maxRequests) {
      return false;
    }

    active.add(now);
    await cache.set<List<int>>(
      cacheKey,
      active,
      ttl: window,
    );
    return true;
  }
}

