// Regression tests for B1, B2, B3 of
// docs/hardening-phases/SPEC-doc-code-divergence-fixes.md
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  setUp(BloomData.clear);
  tearDown(BloomData.clear);

  group('B1: invalidateQueries reaches queries with no cache entry', () {
    test('a query that never fetched successfully still refetches on invalidate', () async {
      var shouldFail = true;
      var fetchCount = 0;

      final q = BloomQuery<String>(
        key: ['users', 'detail', '42'],
        retry: 0,
        fetch: () async {
          fetchCount++;
          if (shouldFail) throw StateError('offline');
          return 'ada';
        },
      );

      // Let the initial (failing) fetch settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(q.isError, isTrue, reason: 'query should be in the error state');
      expect(BloomData.getEntry<String>(['users', 'detail', '42']), isNull,
          reason: 'a failed fetch must not have written a cache entry');

      // The bug: with no cache entry, invalidate() used to signal nothing at all.
      shouldFail = false;
      q.invalidate();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fetchCount, greaterThan(1), reason: 'invalidate() must trigger a refetch');
      expect(q.data.value, 'ada');
      expect(q.isSuccess, isTrue);
      q.dispose();
    });

    test('prefix invalidation respects segment boundaries', () {
      final hits = <String>[];
      BloomData.onInvalidated(['users']).listen((_) => hits.add('users'));
      BloomData.onInvalidated(['users', 'detail', '42'])
          .listen((_) => hits.add('users:detail:42'));
      BloomData.onInvalidated(['usersettings', '1'])
          .listen((_) => hits.add('usersettings:1'));

      BloomData.invalidateQueries(['users']);

      return Future<void>.delayed(const Duration(milliseconds: 20), () {
        expect(hits, containsAll(<String>['users', 'users:detail:42']));
        expect(hits, isNot(contains('usersettings:1')),
            reason: 'prefix must not match across a partial segment');
      });
    });
  });

  group('B2: GC must not evict or close anything a live query listens to', () {
    test('an expired entry with a live listener survives GC and still invalidates', () async {
      var fetchCount = 0;
      final q = BloomQuery<String>(
        key: ['posts', 'list'],
        cacheTime: Duration.zero, // immediately expired
        fetch: () async {
          fetchCount++;
          return 'post-$fetchCount';
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fetchCount, 1);
      // NB: probe via entryCount, not getEntry() — getEntry() evicts expired
      // entries as a side effect of reading them.
      expect(BloomData.entryCount, 1);

      final evicted = BloomData.garbageCollect();
      expect(evicted, 0, reason: 'entry has a live listener, so it must not be evicted');

      // The bug: GC used to close the controller out from under the live query.
      q.invalidate();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fetchCount, greaterThan(1),
          reason: 'query must still receive invalidations after a GC pass');
      q.dispose();
    });

    test('constructing a second query on an expired key does not deafen the first', () async {
      var aFetches = 0;
      final a = BloomQuery<String>(
        key: ['shared', 'key'],
        cacheTime: Duration.zero,
        fetch: () async {
          aFetches++;
          return 'a';
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final before = aFetches;

      // BloomQuery's constructor calls BloomData.getEntry(), which used to close
      // the shared invalidation controller out from under query `a`.
      final b = BloomQuery<String>(
        key: ['shared', 'key'],
        cacheTime: Duration.zero,
        fetch: () async => 'b',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      BloomData.invalidateQueries(['shared', 'key']);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(aFetches, greaterThan(before),
          reason: 'query a must still receive invalidations after query b was created');
      a.dispose();
      b.dispose();
    });

    test('releasing the last listener allows the expired entry to be evicted', () async {
      final q = BloomQuery<String>(
        key: ['posts', 'gone'],
        cacheTime: Duration.zero,
        fetch: () async => 'x',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(BloomData.garbageCollect(), 0);

      q.dispose(); // releases the listener slot
      expect(BloomData.garbageCollect(), 1,
          reason: 'with zero listeners the expired entry is collectable');
    });
  });

  group('B3: normalizeKey is canonical and order-insensitive', () {
    test('maps with different insertion orders map to the same slot', () {
      final a = normalizeKeyOf(['users', 'list', {'status': 'active', 'page': 1}]);
      final b = normalizeKeyOf(['users', 'list', {'page': 1, 'status': 'active'}]);
      expect(a, b);
    });

    test('the two orderings share one cache entry', () {
      BloomData.putEntry<String>(QueryCacheEntry<String>(
        key: ['users', {'status': 'active', 'page': 1}],
        data: 'shared',
        updatedAt: DateTime.now(),
      ));
      expect(BloomData.entryCount, 1);

      expect(
        BloomData.getQueryData<String>(['users', {'page': 1, 'status': 'active'}]),
        'shared',
        reason: 'reordered map keys must resolve to the same cache slot',
      );
    });

    test('nested maps and iterables canonicalize recursively', () {
      final a = normalizeKeyOf([
        'q',
        {
          'filter': {'b': 2, 'a': 1},
          'tags': ['x', 'y'],
        }
      ]);
      final b = normalizeKeyOf([
        'q',
        {
          'tags': ['x', 'y'],
          'filter': {'a': 1, 'b': 2},
        }
      ]);
      expect(a, b);
    });

    test('matchesKey stays consistent with the new slot naming', () {
      expect(
        BloomData.matchesKey(
          ['users', {'status': 'active', 'page': 1}],
          ['users', {'page': 1, 'status': 'active'}],
        ),
        isTrue,
      );
    });
  });
}

String normalizeKeyOf(List<dynamic> key) => BloomData.normalizeKey(key);
