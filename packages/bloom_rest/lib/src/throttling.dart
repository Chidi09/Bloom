// lib/src/throttling.dart
import 'dart:async';
import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_framework/bloom_server.dart';
import 'permissions.dart';

/// Parses a DRF-style rate string such as `"100/hour"` or `"5/minute"` into a count and [Duration].
///
/// Accepts:
/// - `second`, `sec`, `s`
/// - `minute`, `min`, `m`
/// - `hour`, `hr`, `h`
/// - `day`, `d`
/// along with plural forms (e.g. `seconds`, `hours`).
///
/// Returns `null` for malformed rate strings.
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
abstract class BloomRateLimitKey {
  const BloomRateLimitKey();

  /// Returns the unique identity key for [req].
  FutureOr<String> key(BloomRequest req);
}

/// Keys by authenticated user ID when available, falling back to client IP.
///
/// Mirrors `djangors_rest::ByUserOrIp`.
class ByUserOrIp extends BloomRateLimitKey {
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
/// Uses sliding window / bucket timestamp lists in the cache store.
///
/// Mirrors `djangors_rest::Throttle`.
class BloomThrottle {
  /// Unique scope isolating this budget from other endpoints.
  final String scope;

  /// Maximum requests allowed in [window].
  final int maxRequests;

  /// Time window duration.
  final Duration window;

  /// Underlying [BloomCache] instance.
  final BloomCache cache;

  /// Key derivation strategy (defaults to [ByUserOrIp]).
  final BloomRateLimitKey keyStrategy;

  BloomThrottle({
    required this.scope,
    required this.maxRequests,
    required this.window,
    required this.cache,
    this.keyStrategy = const ByUserOrIp(),
  });

  /// Factory constructor parsing a rate string like `"100/hour"` with [cache].
  ///
  /// Throws [ArgumentError] if [rate] is invalid.
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
  /// Returns `true` if allowed, `false` if throttled (429 Too Many Requests).
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
