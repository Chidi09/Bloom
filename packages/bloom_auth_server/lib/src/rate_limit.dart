// lib/src/rate_limit.dart
import 'dart:collection';

/// Exception thrown when rate limiting thresholds are exceeded within a time window.
class RateLimitException implements Exception {
  /// The rate limiting key (e.g. username, email, or IP address).
  final String key;

  /// Maximum allowed attempts within [window].
  final int maxAttempts;

  /// Duration of the sliding time window.
  final Duration window;

  /// Number of seconds until the caller may retry.
  final int retryAfterSeconds;

  /// Creates a [RateLimitException] with rate limiting metadata.
  const RateLimitException({
    required this.key,
    required this.maxAttempts,
    required this.window,
    required this.retryAfterSeconds,
  });

  @override
  String toString() =>
      'RateLimitException: Too many login attempts for "$key". '
      'Exceeded $maxAttempts attempts within ${window.inMinutes}m. '
      'Try again in ${retryAfterSeconds}s.';
}

/// Exception thrown when an account is locked out following consecutive failed authentication attempts.
///
/// Distinct from [RateLimitException]: a lockout rejects *all* attempts (even with correct credentials)
/// until the lockout duration expires.
class AccountLockedException implements Exception {
  /// The identifier of the locked account.
  final String key;

  /// Number of seconds remaining until the lockout expires.
  final int retryAfterSeconds;

  /// Timestamp when the lockout will expire.
  final DateTime lockedUntil;

  /// Creates an [AccountLockedException] with lockout metadata.
  const AccountLockedException({
    required this.key,
    required this.retryAfterSeconds,
    required this.lockedUntil,
  });

  @override
  String toString() =>
      'AccountLockedException: Account "$key" is locked due to too many failed attempts. '
      'Try again in ${retryAfterSeconds}s (locked until ${lockedUntil.toIso8601String()}).';
}

/// Status report resulting from evaluating a rate limit or lockout check.
class RateLimitStatus {
  /// Whether the request is permitted to proceed.
  final bool allowed;

  /// Whether the target key is actively locked out.
  final bool isLocked;

  /// Number of remaining allowed attempts in the current window before throttling/lockout.
  final int remainingAttempts;

  /// Total maximum attempts configured.
  final int maxAttempts;

  /// Number of seconds until the rate limit window or lockout expires (0 if not limited).
  final int retryAfterSeconds;

  /// Expiry timestamp for the active lockout or oldest attempt in window.
  final DateTime? resetAt;

  /// Creates a [RateLimitStatus] instance.
  const RateLimitStatus({
    required this.allowed,
    this.isLocked = false,
    required this.remainingAttempts,
    required this.maxAttempts,
    this.retryAfterSeconds = 0,
    this.resetAt,
  });

  /// Creates a permitted [RateLimitStatus] indicating the request is allowed.
  factory RateLimitStatus.permitted({
    required int remainingAttempts,
    required int maxAttempts,
  }) =>
      RateLimitStatus(
        allowed: true,
        isLocked: false,
        remainingAttempts: remainingAttempts,
        maxAttempts: maxAttempts,
      );

  /// Creates a throttled [RateLimitStatus] indicating rate limit exceeded.
  factory RateLimitStatus.throttled({
    required int maxAttempts,
    required int retryAfterSeconds,
    required DateTime resetAt,
  }) =>
      RateLimitStatus(
        allowed: false,
        isLocked: false,
        remainingAttempts: 0,
        maxAttempts: maxAttempts,
        retryAfterSeconds: retryAfterSeconds,
        resetAt: resetAt,
      );

  /// Creates a locked [RateLimitStatus] indicating account lockout.
  factory RateLimitStatus.locked({
    required int maxAttempts,
    required int retryAfterSeconds,
    required DateTime lockedUntil,
  }) =>
      RateLimitStatus(
        allowed: false,
        isLocked: true,
        remainingAttempts: 0,
        maxAttempts: maxAttempts,
        retryAfterSeconds: retryAfterSeconds,
        resetAt: lockedUntil,
      );
}

/// Internal record tracking lockout state for a single identifier.
class _LockoutEntry {
  int failedAttempts;
  DateTime firstFailedAt;
  DateTime? lockedUntil;

  _LockoutEntry({
    required this.failedAttempts,
    required this.firstFailedAt,
    this.lockedUntil,
  });
}

/// In-memory sliding-window rate limiter.
///
/// Tracks timestamps of attempts per key (e.g. username, email, or client IP).
/// Automatically evicts expired timestamps older than [window].
class InMemoryRateLimiter {
  /// Maximum number of allowed attempts within [window].
  final int maxAttempts;

  /// Duration of the sliding time window.
  final Duration window;
  final Map<String, List<DateTime>> _attempts = HashMap<String, List<DateTime>>();

  /// Creates an [InMemoryRateLimiter] with [maxAttempts] (default 5) and [window] (default 15 minutes).
  ///
  /// Throws [ArgumentError] if [maxAttempts] is less than 1.
  InMemoryRateLimiter({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 15),
  }) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Must be at least 1');
    }
  }

  /// Evaluates rate limit status for [key] without recording an attempt.
  RateLimitStatus check(String key) {
    try {
      final now = DateTime.now().toUtc();
      final timestamps = _attempts[key];
      if (timestamps == null || timestamps.isEmpty) {
        return RateLimitStatus.permitted(
          remainingAttempts: maxAttempts,
          maxAttempts: maxAttempts,
        );
      }

      // Evict entries outside the sliding window
      timestamps.removeWhere((t) => now.difference(t) >= window);

      if (timestamps.length >= maxAttempts) {
        final oldestInWindow = timestamps.first;
        final expiresAt = oldestInWindow.add(window);
        final retrySecs = (expiresAt.difference(now).inSeconds).clamp(1, window.inSeconds);

        return RateLimitStatus.throttled(
          maxAttempts: maxAttempts,
          retryAfterSeconds: retrySecs,
          resetAt: expiresAt,
        );
      }

      return RateLimitStatus.permitted(
        remainingAttempts: maxAttempts - timestamps.length,
        maxAttempts: maxAttempts,
      );
    } catch (_) {
      // Fail closed on unexpected internal error
      return RateLimitStatus.throttled(
        maxAttempts: maxAttempts,
        retryAfterSeconds: window.inSeconds,
        resetAt: DateTime.now().toUtc().add(window),
      );
    }
  }

  /// Records an attempt for [key] and returns whether it is within limits.
  /// Throws [RateLimitException] if the attempt limit is exceeded.
  void recordAttempt(String key) {
    final status = check(key);
    if (!status.allowed) {
      throw RateLimitException(
        key: key,
        maxAttempts: maxAttempts,
        window: window,
        retryAfterSeconds: status.retryAfterSeconds,
      );
    }

    final now = DateTime.now().toUtc();
    final list = _attempts.putIfAbsent(key, () => <DateTime>[]);
    list.add(now);
  }

  /// Clears attempt history for [key].
  void reset(String key) {
    _attempts.remove(key);
  }

  /// Clears all recorded rate limiting entries across all keys.
  void clear() {
    _attempts.clear();
  }
}

/// In-memory account lockout tracker.
///
/// Mirrors `PersistentLockoutBackend` and `django-axes` semantics in-memory:
/// tracks consecutive failed authentication attempts per identifier. Once
/// consecutive failures reach [maxAttempts], the account is locked for [lockoutDuration].
/// During lockout, any request is rejected upfront, even with correct credentials.
class InMemoryLockoutManager {
  /// Number of consecutive failed attempts required to trigger an account lockout.
  final int maxAttempts;

  /// Duration for which an account remains locked after reaching [maxAttempts] failures.
  final Duration lockoutDuration;
  final Map<String, _LockoutEntry> _lockouts = HashMap<String, _LockoutEntry>();

  /// Creates an [InMemoryLockoutManager] with [maxAttempts] (default 5) and [lockoutDuration] (default 1 hour).
  ///
  /// Throws [ArgumentError] if [maxAttempts] is less than 1.
  InMemoryLockoutManager({
    this.maxAttempts = 5,
    this.lockoutDuration = const Duration(hours: 1),
  }) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Must be at least 1');
    }
  }

  /// Checks if [key] is currently locked out.
  ///
  /// Returns [RateLimitStatus.locked] if actively locked, or [RateLimitStatus.permitted] if allowed.
  RateLimitStatus check(String key) {
    try {
      final now = DateTime.now().toUtc();
      final entry = _lockouts[key];

      if (entry == null) {
        return RateLimitStatus.permitted(
          remainingAttempts: maxAttempts,
          maxAttempts: maxAttempts,
        );
      }

      if (entry.lockedUntil != null) {
        if (entry.lockedUntil!.isAfter(now)) {
          final retrySecs = entry.lockedUntil!.difference(now).inSeconds.clamp(1, lockoutDuration.inSeconds);
          return RateLimitStatus.locked(
            maxAttempts: maxAttempts,
            retryAfterSeconds: retrySecs,
            lockedUntil: entry.lockedUntil!,
          );
        } else {
          // Lockout expired - clean up entry so fresh failures start from 1
          _lockouts.remove(key);
          return RateLimitStatus.permitted(
            remainingAttempts: maxAttempts,
            maxAttempts: maxAttempts,
          );
        }
      }

      final remaining = (maxAttempts - entry.failedAttempts).clamp(0, maxAttempts);
      return RateLimitStatus.permitted(
        remainingAttempts: remaining,
        maxAttempts: maxAttempts,
      );
    } catch (_) {
      // Fail closed on error
      final fallbackUntil = DateTime.now().toUtc().add(lockoutDuration);
      return RateLimitStatus.locked(
        maxAttempts: maxAttempts,
        retryAfterSeconds: lockoutDuration.inSeconds,
        lockedUntil: fallbackUntil,
      );
    }
  }

  /// Records a failed authentication attempt. Increments consecutive failure counter
  /// and locks the account if [maxAttempts] is reached.
  void recordFailure(String key) {
    final now = DateTime.now().toUtc();
    final entry = _lockouts[key];

    if (entry == null) {
      final lockedUntil = maxAttempts <= 1 ? now.add(lockoutDuration) : null;
      _lockouts[key] = _LockoutEntry(
        failedAttempts: 1,
        firstFailedAt: now,
        lockedUntil: lockedUntil,
      );
      return;
    }

    // If previous lockout window expired, restart count from 1
    if (entry.lockedUntil != null && entry.lockedUntil!.isBefore(now)) {
      entry.failedAttempts = 1;
      entry.firstFailedAt = now;
      entry.lockedUntil = maxAttempts <= 1 ? now.add(lockoutDuration) : null;
      return;
    }

    entry.failedAttempts += 1;
    if (entry.failedAttempts >= maxAttempts) {
      entry.lockedUntil = now.add(lockoutDuration);
    }
  }

  /// Records a successful authentication attempt. Clears all failed streaks and lockouts.
  void recordSuccess(String key) {
    _lockouts.remove(key);
  }

  /// Manually clears lockout state for [key].
  void reset(String key) {
    _lockouts.remove(key);
  }

  /// Clears all lockouts.
  void clear() {
    _lockouts.clear();
  }
}

/// Unified authentication rate limiter and lockout manager.
///
/// Combines sliding-window rate throttling with account lockout protection.
/// Fail-closed security design guarantees that unexpected exceptions deny access.
class AuthRateLimiter {
  /// The underlying sliding-window rate limiter.
  final InMemoryRateLimiter rateLimiter;

  /// The underlying consecutive-failure lockout manager.
  final InMemoryLockoutManager lockoutManager;

  /// Creates a unified [AuthRateLimiter] combining rate throttling and account lockout.
  ///
  /// [maxAttempts] is the maximum allowed attempts before throttling / lockout (default 5).
  /// [window] is the sliding time window duration (default 15 minutes).
  /// [lockoutDuration] is the duration an account remains locked (default 1 hour).
  AuthRateLimiter({
    int maxAttempts = 5,
    Duration window = const Duration(minutes: 15),
    Duration lockoutDuration = const Duration(hours: 1),
  })  : rateLimiter = InMemoryRateLimiter(
          maxAttempts: maxAttempts,
          window: window,
        ),
        lockoutManager = InMemoryLockoutManager(
          maxAttempts: maxAttempts,
          lockoutDuration: lockoutDuration,
        );

  /// Validates both lockout status and rate limit window before processing an auth request.
  /// Throws [AccountLockedException] if locked, or [RateLimitException] if throttled.
  RateLimitStatus verifyAllowed(String key) {
    // 1. Check account lockout first (rejects upfront, even correct credentials)
    final lockoutStatus = lockoutManager.check(key);
    if (!lockoutStatus.allowed) {
      throw AccountLockedException(
        key: key,
        retryAfterSeconds: lockoutStatus.retryAfterSeconds,
        lockedUntil: lockoutStatus.resetAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
    }

    // 2. Check sliding window rate limit
    final rateStatus = rateLimiter.check(key);
    if (!rateStatus.allowed) {
      throw RateLimitException(
        key: key,
        maxAttempts: rateLimiter.maxAttempts,
        window: rateLimiter.window,
        retryAfterSeconds: rateStatus.retryAfterSeconds,
      );
    }

    return rateStatus;
  }

  /// Call this when an authentication attempt fails.
  /// Records failure for both the rate limit sliding window and consecutive lockout counter.
  void recordFailure(String key) {
    try {
      rateLimiter.recordAttempt(key);
    } catch (_) {
      // Ignored here because we still want lockout tracking to record
    }
    lockoutManager.recordFailure(key);
  }

  /// Call this when an authentication attempt succeeds.
  /// Clears the lockout failure streak while preserving sliding-window integrity.
  void recordSuccess(String key) {
    lockoutManager.recordSuccess(key);
  }

  /// Resets all state for [key].
  void reset(String key) {
    rateLimiter.reset(key);
    lockoutManager.reset(key);
  }
}
