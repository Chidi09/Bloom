import 'package:bloom_cache/bloom_cache.dart';
import 'package:test/test.dart';

void main() {
  group('tag-based invalidation', () {
    late InMemoryCache cache;

    setUp(() {
      cache = InMemoryCache(maxCapacity: 100);
    });

    test('invalidateTag removes exactly the entries carrying that tag',
        () async {
      await cache.set('product:1', 'widget', tags: ['products']);
      await cache.set('product:2', 'gadget', tags: ['products']);
      await cache.set('user:1', 'ada', tags: ['users']);

      await cache.invalidateTag('products');

      expect(await cache.get<String>('product:1'), isNull);
      expect(await cache.get<String>('product:2'), isNull);
      expect(await cache.get<String>('user:1'), 'ada');
    });

    test('an entry with two tags is removed by either one', () async {
      await cache.set('page:home', 'html-a', tags: ['pages', 'products']);
      await cache.invalidateTag('products');
      expect(await cache.get<String>('page:home'), isNull);

      // And symmetrically, via the other tag.
      await cache.set('page:home', 'html-b', tags: ['pages', 'products']);
      await cache.invalidateTag('pages');
      expect(await cache.get<String>('page:home'), isNull);
    });

    test('untagged entries survive invalidation', () async {
      await cache.set('plain', 'value');
      await cache.set('tagged', 'value', tags: ['t']);

      await cache.invalidateTag('t');

      expect(await cache.get<String>('plain'), 'value');
      expect(await cache.get<String>('tagged'), isNull);
    });

    test('invalidateTags clears across several tags in one call', () async {
      await cache.set('a', 1, tags: ['x']);
      await cache.set('b', 2, tags: ['y']);
      await cache.set('c', 3, tags: ['z']);

      await cache.invalidateTags(['x', 'y']);

      expect(await cache.get<int>('a'), isNull);
      expect(await cache.get<int>('b'), isNull);
      expect(await cache.get<int>('c'), 3);
    });

    test('invalidating a tag that was never used is a no-op', () async {
      await cache.set('a', 1, tags: ['x']);

      await cache.invalidateTag('never-used');
      await cache.invalidateTags(['also-new', 'brand-new']);
      await cache.invalidateTags([]);

      expect(await cache.get<int>('a'), 1);
    });

    test(
        'getOrSet labels the computed entry, and invalidation forces recompute',
        () async {
      var computeCount = 0;
      Future<String> compute() async {
        computeCount++;
        return 'computed-$computeCount';
      }

      final first = await cache.getOrSet<String>('k', compute, tags: ['t']);
      final second = await cache.getOrSet<String>('k', compute, tags: ['t']);
      expect(first, 'computed-1');
      expect(second, 'computed-1',
          reason: 'second call must be served from cache');
      expect(computeCount, 1);

      await cache.invalidateTag('t');

      final third = await cache.getOrSet<String>('k', compute, tags: ['t']);
      expect(third, 'computed-2');
      expect(computeCount, 2);
    });

    test('overwriting a key with different tags drops the old associations',
        () async {
      await cache.set('k', 'v1', tags: ['old']);
      await cache.set('k', 'v2', tags: ['new']);

      // The old tag must no longer reach this key, or invalidating an
      // unrelated tag would silently evict a live entry.
      await cache.invalidateTag('old');
      expect(await cache.get<String>('k'), 'v2');

      await cache.invalidateTag('new');
      expect(await cache.get<String>('k'), isNull);
    });

    test('LRU eviction leaves no key reachable through its tag', () async {
      final small = InMemoryCache(maxCapacity: 2);
      await small.set('a', 'va', tags: ['tagA']);
      await small.set('b', 'vb', tags: ['tagB']);
      // Inserting a third entry evicts 'a'.
      await small.set('c', 'vc', tags: ['tagC']);

      expect(await small.get<String>('a'), isNull,
          reason: 'a should be evicted');

      // Invalidating the evicted key's tag must neither resurrect it nor
      // disturb the entries that are still live.
      await small.invalidateTag('tagA');
      expect(await small.get<String>('b'), 'vb');
      expect(await small.get<String>('c'), 'vc');
    });

    test('delete removes the key from its tag index', () async {
      await cache.set('k', 'v', tags: ['t']);
      await cache.delete('k');
      await cache.set('other', 'v2', tags: ['t']);

      await cache.invalidateTag('t');
      expect(await cache.get<String>('other'), isNull);
    });

    test('clear wipes tag associations too', () async {
      await cache.set('k', 'v', tags: ['t']);
      await cache.clear();
      expect(cache.size, 0);

      await cache.set('k2', 'v2');
      await cache.invalidateTag('t');

      expect(await cache.get<String>('k2'), 'v2',
          reason: 'a stale tag association must not survive clear()');
    });
  });

  group('existing behaviour is unchanged when tags are never passed', () {
    late InMemoryCache cache;

    setUp(() {
      cache = InMemoryCache(maxCapacity: 100);
    });

    test('set/get/delete/clear still work', () async {
      await cache.set('a', 'value');
      expect(await cache.get<String>('a'), 'value');

      await cache.delete('a');
      expect(await cache.get<String>('a'), isNull);

      await cache.set('b', 'value-b');
      await cache.clear();
      expect(await cache.get<String>('b'), isNull);
      expect(cache.size, 0);
    });

    test('ttl expiry still works', () async {
      await cache.set('short', 'gone', ttl: const Duration(milliseconds: 20));
      expect(await cache.get<String>('short'), 'gone');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await cache.get<String>('short'), isNull);
    });

    test('getOrSet without tags still deduplicates and caches', () async {
      var calls = 0;
      Future<int> compute() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 42;
      }

      // Concurrent callers must collapse into a single computation.
      final results = await Future.wait([
        cache.getOrSet<int>('n', compute),
        cache.getOrSet<int>('n', compute),
        cache.getOrSet<int>('n', compute),
      ]);

      expect(results, [42, 42, 42]);
      expect(calls, 1);
    });
  });
}
