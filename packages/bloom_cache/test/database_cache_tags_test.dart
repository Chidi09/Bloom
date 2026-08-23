import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:test/test.dart';

/// Exercises DatabaseCache against a real in-memory SQLite database.
///
/// The tag support is hand-written SQL, and SQL that merely compiles is not
/// SQL that runs -- table creation order, the ON CONFLICT upsert, and the
/// placeholder helper all have to actually work against an engine. An
/// in-memory database gives that for free, with no server to provision.
void main() {
  group('DatabaseCache tags (real SQLite)', () {
    late SqliteDbExecutor db;
    late DatabaseCache cache;

    setUp(() {
      db = SqliteDbExecutor.inMemory();
      cache = DatabaseCache(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('ensureTable creates both the cache and the tag table', () async {
      await cache.ensureTable();

      final rows = await db.fetchAll(
          "SELECT name FROM sqlite_master WHERE type='table'");
      final names = rows
          .map((r) => r.tryStringByName('name') ?? r.tryString(0))
          .whereType<String>()
          .toSet();

      expect(names, contains(cache.tableName));
      expect(names, contains(cache.tagTableName));
    });

    test('set/get round-trips without tags', () async {
      await cache.set('k', 'value');
      expect(await cache.get<String>('k'), 'value');
    });

    test('invalidateTag removes exactly the tagged rows', () async {
      await cache.set('product:1', 'widget', tags: ['products']);
      await cache.set('product:2', 'gadget', tags: ['products']);
      await cache.set('user:1', 'ada', tags: ['users']);

      await cache.invalidateTag('products');

      expect(await cache.get<String>('product:1'), isNull);
      expect(await cache.get<String>('product:2'), isNull);
      expect(await cache.get<String>('user:1'), 'ada');
    });

    test('an entry with two tags is removed by either one', () async {
      await cache.set('page', 'html', tags: ['pages', 'products']);
      await cache.invalidateTag('products');
      expect(await cache.get<String>('page'), isNull);
    });

    test('invalidateTags removes across several tags in one call', () async {
      await cache.set('a', 1, tags: ['x']);
      await cache.set('b', 2, tags: ['y']);
      await cache.set('c', 3, tags: ['z']);

      await cache.invalidateTags(['x', 'y']);

      expect(await cache.get<int>('a'), isNull);
      expect(await cache.get<int>('b'), isNull);
      expect(await cache.get<int>('c'), 3);
    });

    test('overwriting a key with different tags drops the old associations',
        () async {
      await cache.set('k', 'v1', tags: ['old']);
      await cache.set('k', 'v2', tags: ['new']);

      await cache.invalidateTag('old');
      expect(await cache.get<String>('k'), 'v2',
          reason: 'the old tag must no longer reach this key');

      await cache.invalidateTag('new');
      expect(await cache.get<String>('k'), isNull);
    });

    test('re-tagging a key twice with the same tag does not fail', () async {
      // The (key, tag) primary key would reject a duplicate insert, so the
      // delete-then-insert in set() has to actually clear the way.
      await cache.set('k', 'v1', tags: ['t', 't']);
      await cache.set('k', 'v2', tags: ['t']);
      expect(await cache.get<String>('k'), 'v2');
    });

    test('delete removes the key and its tag rows', () async {
      await cache.set('k', 'v', tags: ['t']);
      await cache.delete('k');

      final rows = await db.fetchAll(
          'SELECT tag FROM ${cache.tagTableName} WHERE key = ?', ['k']);
      expect(rows, isEmpty);
    });

    test('clear empties both tables', () async {
      await cache.set('k', 'v', tags: ['t']);
      await cache.clear();

      expect(await cache.get<String>('k'), isNull);
      final rows =
          await db.fetchAll('SELECT tag FROM ${cache.tagTableName}');
      expect(rows, isEmpty);
    });

    test('invalidating a never-used tag is a no-op', () async {
      await cache.set('k', 'v', tags: ['t']);
      await cache.invalidateTag('never-used');
      expect(await cache.get<String>('k'), 'v');
    });

    test('ttl expiry still works alongside tags', () async {
      // The window has to comfortably exceed a SQLite round trip. A 20ms TTL
      // expired before the first read, because the very first set() also
      // creates both tables.
      await cache.set('k', 'v',
          ttl: const Duration(milliseconds: 400), tags: ['t']);
      expect(await cache.get<String>('k'), 'v');

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(await cache.get<String>('k'), isNull);
    });
  });
}
