import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_rest/bloom_rest.dart';
import 'package:test/test.dart';

void main() {
  group('parseRate', () {
    test('parses valid rates for second, minute, hour, day and shortforms', () {
      final s = parseRate('10/s');
      expect(s?.$1, 10);
      expect(s?.$2, const Duration(seconds: 1));

      final sec = parseRate('15/sec');
      expect(sec?.$1, 15);
      expect(sec?.$2, const Duration(seconds: 1));

      final seconds = parseRate('20/seconds');
      expect(seconds?.$1, 20);
      expect(seconds?.$2, const Duration(seconds: 1));

      final m = parseRate('5/m');
      expect(m?.$1, 5);
      expect(m?.$2, const Duration(minutes: 1));

      final min = parseRate('60/min');
      expect(min?.$1, 60);
      expect(min?.$2, const Duration(minutes: 1));

      final minute = parseRate('100/minute');
      expect(minute?.$1, 100);
      expect(minute?.$2, const Duration(minutes: 1));

      final h = parseRate('500/h');
      expect(h?.$1, 500);
      expect(h?.$2, const Duration(hours: 1));

      final hr = parseRate('1000/hr');
      expect(hr?.$1, 1000);
      expect(hr?.$2, const Duration(hours: 1));

      final hour = parseRate('5000/hour');
      expect(hour?.$1, 5000);
      expect(hour?.$2, const Duration(hours: 1));

      final d = parseRate('10000/d');
      expect(d?.$1, 10000);
      expect(d?.$2, const Duration(days: 1));

      final day = parseRate('20000/day');
      expect(day?.$1, 20000);
      expect(day?.$2, const Duration(days: 1));
    });

    test('returns null for invalid rate strings', () {
      expect(parseRate(''), isNull);
      expect(parseRate('invalid'), isNull);
      expect(parseRate('0/minute'), isNull);
      expect(parseRate('-5/hour'), isNull);
      expect(parseRate('100/year'), isNull);
      expect(parseRate('abc/sec'), isNull);
      expect(parseRate('100/'), isNull);
      expect(parseRate('/hour'), isNull);
    });
  });

  group('ByUserOrIp & Header Spoofing Protection', () {
    test('uses authenticated user ID when verified identity is present', () {
      const strategy = ByUserOrIp();
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api'),
        params: {'auth_user_id': 'user_42'},
        headers: {'x-forwarded-for': '1.2.3.4'},
      );
      expect(strategy.key(req), 'user:user_42');
    });

    test('falls back to non-spoofable fallback key when peer is unavailable',
        () {
      const strategy = ByUserOrIp();
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api'),
        headers: {
          'x-forwarded-for': '203.0.113.195',
          'x-real-ip': '203.0.113.195',
        },
      );
      // Without a verified transport peer from the socket, client headers MUST NOT be trusted
      expect(strategy.key(req), 'anon:shared_untrusted');
    });

    test(
        'uses verified transport peer and ignores spoofed headers when peer is untrusted',
        () {
      final strategy = ByUserOrIp(
        peerExtractor: (req) => '198.51.100.23',
      );
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api'),
        headers: {
          'x-forwarded-for': '203.0.113.195',
          'x-real-ip': '203.0.113.195',
        },
      );
      // Immediate transport peer is not a trusted proxy, so forwarding headers are ignored
      expect(strategy.key(req), 'anon:198.51.100.23');
    });

    test(
        'trusts forwarding headers when immediate peer is confirmed by trusted proxy predicate',
        () {
      final strategy = ByUserOrIp(
        isTrustedProxy: (ip) => ip == '127.0.0.1' || ip == '10.0.0.1',
        peerExtractor: (req) => '127.0.0.1',
      );
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api'),
        headers: {
          'x-forwarded-for': '203.0.113.50, 10.0.0.1',
        },
      );
      expect(strategy.key(req), 'anon:203.0.113.50');
    });

    test(
        'falls back to trusted proxy peer IP when forwarding headers are absent',
        () {
      final strategy = ByUserOrIp(
        isTrustedProxy: (ip) => ip == '127.0.0.1',
        peerExtractor: (req) => '127.0.0.1',
      );
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api'),
        params: {'peer_ip': '127.0.0.1'},
      );
      expect(strategy.key(req), 'anon:127.0.0.1');
    });

    test('supports custom fallbackKey and custom peer extractor', () {
      final strategy = ByUserOrIp(
        fallbackKey: 'anon:custom_fallback',
        peerExtractor: (req) => req.params['socket_addr']?.split(':').first,
      );
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api'),
        params: {'socket_addr': '192.168.1.100:54321'},
      );
      expect(strategy.key(req), 'anon:192.168.1.100');

      final noPeerReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api'),
      );
      expect(strategy.key(noPeerReq), 'anon:custom_fallback');
    });

    group('shared anonymous bucket (#8)', () {
      BloomRequest anonReq({String? forwardedFor}) => BloomRequest(
            method: 'GET',
            uri: Uri.parse('http://localhost/api'),
            headers: {
              if (forwardedFor != null) 'x-forwarded-for': forwardedFor
            },
          );

      test('default setup shares one budget across spoofed IPs', () async {
        ByUserOrIp.resetSharedBucketWarning();
        final throttle = BloomThrottle.fromRate(
          scope: 'shared_bucket_demo',
          rate: '2/minute',
          atomicStore: InMemoryAtomicThrottleStore(),
          keyStrategy: const ByUserOrIp(),
        );
        // Two anonymous callers consume the single shared budget…
        expect(await throttle.allowRequest(anonReq()), isTrue);
        expect(await throttle.allowRequest(anonReq(forwardedFor: '9.9.9.9')),
            isTrue);
        // …so a third anonymous caller (even with a different spoofed IP)
        // is 429'd: spoofed headers never create a new bucket.
        expect(
            await throttle.allowRequest(anonReq(forwardedFor: '10.10.10.10')),
            isFalse);
      });

      test('wired peerExtractor isolates per-client budgets', () async {
        final throttle = BloomThrottle.fromRate(
          scope: 'isolated_demo',
          rate: '1/minute',
          atomicStore: InMemoryAtomicThrottleStore(),
          keyStrategy: ByUserOrIp(
            peerExtractor: (req) => req.params['tcp_peer'],
          ),
        );
        BloomRequest peerReq(String ip) => BloomRequest(
              method: 'GET',
              uri: Uri.parse('http://localhost/api'),
              params: {'tcp_peer': ip},
            );
        expect(await throttle.allowRequest(peerReq('1.1.1.1')), isTrue);
        // Same peer exhausted…
        expect(await throttle.allowRequest(peerReq('1.1.1.1')), isFalse);
        // …but a different peer is unaffected.
        expect(await throttle.allowRequest(peerReq('2.2.2.2')), isTrue);
      });

      test('authenticated users get independent budgets', () async {
        final throttle = BloomThrottle.fromRate(
          scope: 'user_demo',
          rate: '1/minute',
          atomicStore: InMemoryAtomicThrottleStore(),
          keyStrategy: const ByUserOrIp(),
        );
        BloomRequest userReq(String id) => BloomRequest(
              method: 'GET',
              uri: Uri.parse('http://localhost/api'),
              params: {'auth_user_id': id},
            );
        expect(await throttle.allowRequest(userReq('alice')), isTrue);
        expect(await throttle.allowRequest(userReq('alice')), isFalse);
        expect(await throttle.allowRequest(userReq('bob')), isTrue);
      });
    });
  });

  group('InMemoryAtomicThrottleStore', () {
    test('enforces atomic rate limits up to maxRequests', () async {
      final store = InMemoryAtomicThrottleStore();
      const window = Duration(seconds: 10);
      const key = 'test_client';

      expect(await store.allowRequest(key, 3, window), isTrue);
      expect(await store.allowRequest(key, 3, window), isTrue);
      expect(await store.allowRequest(key, 3, window), isTrue);
      // 4th request exceeds maxRequests = 3
      expect(await store.allowRequest(key, 3, window), isFalse);
    });

    test('clear removes tracked limit state', () async {
      final store = InMemoryAtomicThrottleStore();
      const window = Duration(seconds: 10);
      const key = 'test_client';

      await store.allowRequest(key, 1, window);
      expect(await store.allowRequest(key, 1, window), isFalse);

      store.clear();
      expect(await store.allowRequest(key, 1, window), isTrue);
    });
  });

  group('BloomThrottle with atomicStore & cache fallback', () {
    test('BloomThrottle with atomicStore limits requests accurately', () async {
      final throttle = BloomThrottle.fromRate(
        scope: 'test_api',
        rate: '2/minute',
        atomicStore: InMemoryAtomicThrottleStore(),
        keyStrategy: ByUserOrIp(
          isTrustedProxy: defaultNeverTrustProxy,
          peerExtractor: (req) => '10.1.1.1',
        ),
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/test'),
      );

      expect(await throttle.allowRequest(req), isTrue);
      expect(await throttle.allowRequest(req), isTrue);
      expect(await throttle.allowRequest(req), isFalse);
    });

    test('InMemoryAtomicThrottleStore evicts least-recently-used keys',
        () async {
      final store = InMemoryAtomicThrottleStore(maxKeys: 2);
      const window = Duration(minutes: 1);

      expect(await store.allowRequest('a', 1, window), isTrue);
      expect(await store.allowRequest('b', 1, window), isTrue);
      // Touch b so a is the least recently used key.
      expect(await store.allowRequest('b', 1, window), isFalse);
      expect(await store.allowRequest('c', 1, window), isTrue);
      // a was evicted and receives a fresh budget.
      expect(await store.allowRequest('a', 1, window), isTrue);
      store.clear();
    });

    test(
        'BloomThrottle with BloomCache fallback functions for basic rate limiting',
        () async {
      final cache = InMemoryCache();
      final throttle = BloomThrottle.fromRate(
        scope: 'cache_api',
        rate: '2/minute',
        cache: cache,
        keyStrategy: ByUserOrIp(
          peerExtractor: (req) => '10.2.2.2',
        ),
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/test'),
      );

      expect(await throttle.allowRequest(req), isTrue);
      expect(await throttle.allowRequest(req), isTrue);
      expect(await throttle.allowRequest(req), isFalse);
    });

    test('custom BloomRateLimitKey strategy is preserved', () async {
      final throttle = BloomThrottle(
        scope: 'custom_key',
        maxRequests: 1,
        window: const Duration(minutes: 1),
        atomicStore: InMemoryAtomicThrottleStore(),
        keyStrategy: _CustomHeaderKeyStrategy('x-tenant-id'),
      );

      final reqA = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        headers: {'x-tenant-id': 'tenant_alpha'},
      );
      final reqB = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        headers: {'x-tenant-id': 'tenant_beta'},
      );

      expect(await throttle.allowRequest(reqA), isTrue);
      expect(
          await throttle.allowRequest(reqA), isFalse); // tenant_alpha throttled

      expect(await throttle.allowRequest(reqB),
          isTrue); // tenant_beta has separate quota
    });

    test('throws ArgumentError on invalid rate string', () {
      expect(
        () => BloomThrottle.fromRate(
          scope: 'err',
          rate: 'invalid_rate',
          atomicStore: InMemoryAtomicThrottleStore(),
        ),
        throwsArgumentError,
      );
    });
  });
}

class _CustomHeaderKeyStrategy extends BloomRateLimitKey {
  final String headerName;
  const _CustomHeaderKeyStrategy(this.headerName);

  @override
  String key(BloomRequest req) => req.headers[headerName] ?? 'none';
}
