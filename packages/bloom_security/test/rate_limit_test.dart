import 'dart:async';
import 'dart:io';
import 'package:bloom_security/bloom_security.dart';
import 'package:bloom_server/bloom_server.dart';
import 'test_helpers.dart';

class _MockCustomRateLimitStore implements BloomRateLimitStore {
  int recordCount = 0;
  bool isDisposed = false;

  @override
  FutureOr<BloomRateLimitResult> recordAndCheck({
    required String key,
    required int maxRequests,
    required Duration window,
  }) {
    recordCount++;
    if (key == 'blocked_user') {
      return BloomRateLimitResult.exceeded(
        limit: maxRequests,
        resetEpochSeconds: 1234567890,
        retryAfter: const Duration(seconds: 45),
      );
    }
    return BloomRateLimitResult.allowed(
      limit: maxRequests,
      remaining: maxRequests - recordCount,
      resetEpochSeconds: 1234567890,
    );
  }

  @override
  FutureOr<void> reset([String? key]) {
    recordCount = 0;
  }

  @override
  FutureOr<void> dispose() {
    isDisposed = true;
  }
}

Future<void> runRateLimitTests() async {
  await group('BloomRateLimitMiddleware Security Tests', () {
    test(
        'Validates maxRequests > 0, window > Duration.zero, and cleanupInterval > Duration.zero',
        () {
      expectThrows<ArgumentError>(() {
        BloomRateLimitMiddleware(maxRequests: 0);
      });
      expectThrows<ArgumentError>(() {
        BloomRateLimitMiddleware(maxRequests: -5);
      });
      expectThrows<ArgumentError>(() {
        BloomRateLimitMiddleware(window: Duration.zero);
      });
      expectThrows<ArgumentError>(() {
        BloomRateLimitMiddleware(window: const Duration(seconds: -1));
      });
      expectThrows<ArgumentError>(() {
        BloomRateLimitMiddleware(cleanupInterval: Duration.zero);
      });
    });

    test(
        'Untrusted proxy headers defense: ignores spoofed headers from untrusted peer',
        () async {
      final rateLimiter = BloomRateLimitMiddleware(
        maxRequests: 2,
        window: const Duration(minutes: 1),
        peerAddressExtractor: (req) => req.headers['x-bloom-peer-ip'],
      );

      // Peer 198.51.100.1 sends request 1 with spoofed X-Forwarded-For: 1.1.1.1
      final req1 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/items'),
        headers: {
          'x-bloom-peer-ip': '198.51.100.1',
          'x-forwarded-for': '1.1.1.1',
        },
      );
      final res1 = await rateLimiter.handle(
          req1, () async => BloomResponse.json({'ok': true}));
      expect(res1?.statusCode, 200);
      expect(res1?.headers['x-ratelimit-remaining'], '1');

      // Peer 198.51.100.1 sends request 2 with spoofed X-Forwarded-For: 2.2.2.2
      final req2 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/items'),
        headers: {
          'x-bloom-peer-ip': '198.51.100.1',
          'x-forwarded-for': '2.2.2.2',
        },
      );
      final res2 = await rateLimiter.handle(
          req2, () async => BloomResponse.json({'ok': true}));
      expect(res2?.statusCode, 200);
      expect(res2?.headers['x-ratelimit-remaining'], '0');

      // Peer 198.51.100.1 sends request 3 with spoofed X-Forwarded-For: 3.3.3.3 -> must be rate limited!
      final req3 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/items'),
        headers: {
          'x-bloom-peer-ip': '198.51.100.1',
          'x-forwarded-for': '3.3.3.3',
        },
      );
      final res3 = await rateLimiter.handle(
          req3, () async => BloomResponse.json({'ok': true}));
      expect(res3?.statusCode, 429);
      expect(res3?.headers['x-ratelimit-remaining'], '0');
      expect(res3?.headers.containsKey('retry-after'), isTrue);

      rateLimiter.dispose();
    });

    test(
        'Safe fallback for unavailable peer address prevents spoofed header abuse',
        () async {
      final rateLimiter = BloomRateLimitMiddleware(
        maxRequests: 2,
        window: const Duration(minutes: 1),
        // No peerAddressExtractor and no transport peer headers -> peer address is unavailable
      );

      final req1 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/test'),
        headers: {'x-forwarded-for': '203.0.113.10'},
      );
      final res1 = await rateLimiter.handle(
          req1, () async => BloomResponse.json({'ok': true}));
      expect(res1?.statusCode, 200);

      final req2 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/test'),
        headers: {'cf-connecting-ip': '203.0.113.20'},
      );
      final res2 = await rateLimiter.handle(
          req2, () async => BloomResponse.json({'ok': true}));
      expect(res2?.statusCode, 200);

      final req3 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/test'),
        headers: {'x-real-ip': '203.0.113.30'},
      );
      final res3 = await rateLimiter.handle(
          req3, () async => BloomResponse.json({'ok': true}));
      expect(res3?.statusCode, 429);

      rateLimiter.dispose();
    });

    test(
        'Trusted proxy predicate: honors proxy headers only when peer is trusted',
        () async {
      final rateLimiter = BloomRateLimitMiddleware(
        maxRequests: 2,
        window: const Duration(minutes: 1),
        isTrustedProxy: (peer) => peer == '10.0.0.1',
        peerAddressExtractor: (req) => req.headers['x-bloom-peer-ip'],
      );

      // Request through trusted proxy 10.0.0.1 for client A
      final reqA1 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/test'),
        headers: {
          'x-bloom-peer-ip': '10.0.0.1',
          'x-forwarded-for': '192.168.1.100, 10.0.0.1',
        },
      );
      final resA1 = await rateLimiter.handle(
          reqA1, () async => BloomResponse.json({'ok': true}));
      expect(resA1?.statusCode, 200);
      expect(resA1?.headers['x-ratelimit-remaining'], '1');

      // Request through trusted proxy 10.0.0.1 for client B (separate bucket!)
      final reqB1 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/test'),
        headers: {
          'x-bloom-peer-ip': '10.0.0.1',
          'cf-connecting-ip': '192.168.1.200',
        },
      );
      final resB1 = await rateLimiter.handle(
          reqB1, () async => BloomResponse.json({'ok': true}));
      expect(resB1?.statusCode, 200);
      expect(resB1?.headers['x-ratelimit-remaining'], '1');

      rateLimiter.dispose();
    });

    test('Whitelist bypasses rate limiting', () async {
      final rateLimiter = BloomRateLimitMiddleware(
        maxRequests: 1,
        window: const Duration(minutes: 1),
        whitelist: {'trusted_admin'},
        keyExtractor: (req) => req.headers['x-user-id'] ?? 'anon',
      );

      final req1 = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/admin'),
        headers: {'x-user-id': 'trusted_admin'},
      );

      final res1 = await rateLimiter.handle(
          req1, () async => BloomResponse.json({'ok': true}));
      final res2 = await rateLimiter.handle(
          req1, () async => BloomResponse.json({'ok': true}));
      final res3 = await rateLimiter.handle(
          req1, () async => BloomResponse.json({'ok': true}));

      expect(res1?.statusCode, 200);
      expect(res2?.statusCode, 200);
      expect(res3?.statusCode, 200);

      rateLimiter.dispose();
    });

    test('Custom onRateLimitExceeded handler is invoked on quota exceeded',
        () async {
      final rateLimiter = BloomRateLimitMiddleware(
        maxRequests: 1,
        window: const Duration(minutes: 1),
        keyExtractor: (req) => 'fixed_user',
        onRateLimitExceeded: (req, retryAfter, limit) {
          return BloomResponse.json({
            'custom_error': 'quota_exceeded',
            'limit': limit,
          }, statusCode: 429);
        },
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/data'),
      );

      final res1 = await rateLimiter.handle(
          req, () async => BloomResponse.json({'ok': true}));
      expect(res1?.statusCode, 200);

      final res2 = await rateLimiter.handle(
          req, () async => BloomResponse.json({'ok': true}));
      expect(res2?.statusCode, 429);
      final json = res2?.bodyJson as Map<String, dynamic>;
      expect(json['custom_error'], 'quota_exceeded');
      expect(json['limit'], 1);

      rateLimiter.dispose();
    });

    test('Supports public BloomRateLimitStore strategy extension point',
        () async {
      final mockStore = _MockCustomRateLimitStore();
      final rateLimiter = BloomRateLimitMiddleware(
        maxRequests: 10,
        window: const Duration(minutes: 1),
        store: mockStore,
        keyExtractor: (req) => req.headers['x-api-key'] ?? 'guest',
      );

      final reqAllowed = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/items'),
        headers: {'x-api-key': 'valid_user'},
      );
      final resAllowed = await rateLimiter.handle(
          reqAllowed, () async => BloomResponse.json({'ok': true}));
      expect(resAllowed?.statusCode, 200);
      expect(mockStore.recordCount, 1);

      final reqBlocked = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/items'),
        headers: {'x-api-key': 'blocked_user'},
      );
      final resBlocked = await rateLimiter.handle(
          reqBlocked, () async => BloomResponse.json({'ok': true}));
      expect(resBlocked?.statusCode, 429);
      expect(resBlocked?.headers['retry-after'], '45');

      rateLimiter.reset();
      expect(mockStore.recordCount, 0);

      rateLimiter.dispose();
      expect(mockStore.isDisposed, isTrue);
    });

    test('Hour-long windows survive the periodic prune (#25)', () {
      final store = BloomInMemoryRateLimitStore(
        cleanupInterval: const Duration(hours: 1),
      );
      try {
        const window = Duration(hours: 1);
        final t0 = DateTime.now();

        // Exhaust a 3/hour budget.
        expect(
            store
                .recordAndCheck(key: 'client', maxRequests: 3, window: window)
                .isAllowed,
            isTrue);
        expect(
            store
                .recordAndCheck(key: 'client', maxRequests: 3, window: window)
                .isAllowed,
            isTrue);
        expect(
            store
                .recordAndCheck(key: 'client', maxRequests: 3, window: window)
                .isAllowed,
            isTrue);

        // 30 simulated minutes later the prune must NOT discard live entries:
        // sustained traffic still trips the limit.
        store.debugPrune(now: t0.add(const Duration(minutes: 30)));
        expect(
            store
                .recordAndCheck(key: 'client', maxRequests: 3, window: window)
                .isAllowed,
            isFalse);

        // Past the window the budget resets.
        store.debugPrune(now: t0.add(const Duration(minutes: 61)));
        expect(
            store
                .recordAndCheck(key: 'client', maxRequests: 3, window: window)
                .isAllowed,
            isTrue);
      } finally {
        store.dispose();
      }
    });

    test('Default 1-minute window behavior is unchanged (#25)', () {
      final store = BloomInMemoryRateLimitStore(
        cleanupInterval: const Duration(hours: 1),
      );
      try {
        const window = Duration(minutes: 1);
        final t0 = DateTime.now();

        expect(
            store
                .recordAndCheck(key: 'k', maxRequests: 1, window: window)
                .isAllowed,
            isTrue);
        // Within the window the prune retains the entry (as before).
        store.debugPrune(now: t0.add(const Duration(seconds: 30)));
        expect(
            store
                .recordAndCheck(key: 'k', maxRequests: 1, window: window)
                .isAllowed,
            isFalse);
        // Well past the legacy 10-minute horizon it is cleaned up.
        store.debugPrune(now: t0.add(const Duration(minutes: 11)));
        expect(
            store
                .recordAndCheck(key: 'k', maxRequests: 1, window: window)
                .isAllowed,
            isTrue);
      } finally {
        store.dispose();
      }
    });
  });
}

void main() async {
  resetTestCounts();
  await runRateLimitTests();
  exitCode = await reportTestResults();
}
