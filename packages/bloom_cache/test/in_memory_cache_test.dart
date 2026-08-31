import 'package:bloom_cache/bloom_cache.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryCache basics', () {
    test('set then get round-trips a value', () async {
      final cache = InMemoryCache();
      await cache.set('k', {'x': 1});
      final value = await cache.get<Map<String, dynamic>>('k');
      expect(value, {'x': 1});
    });

    test('get returns null for a missing key', () async {
      final cache = InMemoryCache();
      expect(await cache.get<String>('missing'), isNull);
    });

    test('delete removes an entry', () async {
      final cache = InMemoryCache();
      await cache.set('k', 'v');
      await cache.delete('k');
      expect(await cache.get<String>('k'), isNull);
    });

    test('clear empties the cache', () async {
      final cache = InMemoryCache();
      await cache.set('a', 1);
      await cache.set('b', 2);
      await cache.clear();
      expect(cache.size, 0);
    });

    test('rejects a non-positive maxCapacity', () {
      expect(() => InMemoryCache(maxCapacity: 0), throwsArgumentError);
    });
  });

  group('TTL expiration', () {
    test('entry expires and is evicted after its TTL elapses', () async {
      final cache = InMemoryCache();
      await cache.set('k', 'v', ttl: const Duration(milliseconds: 20));
      expect(await cache.get<String>('k'), 'v');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(await cache.get<String>('k'), isNull);
    });

    test('entry without a TTL never expires', () async {
      final cache = InMemoryCache();
      await cache.set('k', 'v');
      await Future.delayed(const Duration(milliseconds: 20));
      expect(await cache.get<String>('k'), 'v');
    });
  });

  group('LRU eviction', () {
    test('evicts the least recently used entry when over capacity', () async {
      final cache = InMemoryCache(maxCapacity: 2);
      await cache.set('a', 1);
      await cache.set('b', 2);
      await cache.set('c', 3); // should evict 'a' (LRU)

      expect(await cache.get<int>('a'), isNull);
      expect(await cache.get<int>('b'), 2);
      expect(await cache.get<int>('c'), 3);
    });

    test('reading an entry refreshes its recency, protecting it from eviction',
        () async {
      final cache = InMemoryCache(maxCapacity: 2);
      await cache.set('a', 1);
      await cache.set('b', 2);
      // Touch 'a' so it becomes MRU; 'b' becomes LRU.
      await cache.get<int>('a');
      await cache.set('c', 3); // should evict 'b', not 'a'

      expect(await cache.get<int>('a'), 1);
      expect(await cache.get<int>('b'), isNull);
      expect(await cache.get<int>('c'), 3);
    });
  });

  group('getOrSet', () {
    test('computes and caches on a miss', () async {
      final cache = InMemoryCache();
      var computeCalls = 0;
      Future<int> compute() async {
        computeCalls++;
        return 42;
      }

      final first = await cache.getOrSet<int>('k', compute);
      final second = await cache.getOrSet<int>('k', compute);

      expect(first, 42);
      expect(second, 42);
      expect(computeCalls, 1,
          reason: 'compute should only run once on the first miss');
    });

    test('recomputes after the cached value expires', () async {
      final cache = InMemoryCache();
      var computeCalls = 0;
      Future<int> compute() async {
        computeCalls++;
        return computeCalls;
      }

      final first = await cache.getOrSet<int>('k', compute,
          ttl: const Duration(milliseconds: 20));
      await Future.delayed(const Duration(milliseconds: 50));
      final second = await cache.getOrSet<int>('k', compute,
          ttl: const Duration(milliseconds: 20));

      expect(first, 1);
      expect(second, 2);
      expect(computeCalls, 2);
    });
  });
}
