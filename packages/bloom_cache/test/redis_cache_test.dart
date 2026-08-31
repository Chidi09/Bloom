import 'package:bloom_cache/bloom_cache.dart';
import 'package:test/test.dart';

void main() {
  group('RedisCache (real Redis instance)', () {
    late RedisCache cache;
    late RedisCache unprefixedCache;
    bool redisAvailable = false;

    setUpAll(() async {
      try {
        final probe = RedisCache.fromUrl('redis://127.0.0.1:6379/15',
            prefix: 'probe_test');
        await probe.set('probe_key', 'ok');
        final res = await probe.get<String>('probe_key');
        await probe.delete('probe_key');
        await probe.close();
        redisAvailable = (res == 'ok');
      } catch (_) {
        redisAvailable = false;
      }
    });

    setUp(() async {
      if (!redisAvailable) return;
      cache =
          RedisCache.fromUrl('redis://127.0.0.1:6379/15', prefix: 'test_bloom');
      unprefixedCache =
          RedisCache(host: '127.0.0.1', port: 6379, db: 15, prefix: '');
      // Clear test namespace
      await cache.clear();
    });

    tearDown(() async {
      if (redisAvailable) {
        await cache.clear();
        await cache.close();
        await unprefixedCache.close();
      }
    });

    test('round-trips basic values without tags', () async {
      if (!redisAvailable) return;

      await cache.set('str_key', 'hello redis');
      await cache.set('map_key', {'name': 'Bloom', 'version': 1});

      expect(await cache.get<String>('str_key'), 'hello redis');
      final map = await cache.get<Map<String, dynamic>>('map_key');
      expect(map?['name'], 'Bloom');
      expect(map?['version'], 1);
    });

    test('atomic tag invalidation removes only tagged entries', () async {
      if (!redisAvailable) return;

      await cache.set('item:1', {'name': 'Item 1'}, tags: ['items', 'cat_a']);
      await cache.set('item:2', {'name': 'Item 2'}, tags: ['items', 'cat_b']);
      await cache.set('user:1', {'name': 'Alice'}, tags: ['users']);

      // Invalidate single tag
      await cache.invalidateTag('cat_a');

      expect(await cache.get<Map<String, dynamic>>('item:1'), isNull);
      expect(await cache.get<Map<String, dynamic>>('item:2'), isNotNull);
      expect(await cache.get<Map<String, dynamic>>('user:1'), isNotNull);

      // Invalidate multiple tags
      await cache.invalidateTags(['items', 'users']);
      expect(await cache.get<Map<String, dynamic>>('item:2'), isNull);
      expect(await cache.get<Map<String, dynamic>>('user:1'), isNull);
    });

    test('overwriting key with new tags drops old tag associations atomically',
        () async {
      if (!redisAvailable) return;

      await cache.set('doc:1', 'v1', tags: ['drafts']);
      await cache.set('doc:1', 'v2', tags: ['published']);

      // Invalidating old tag must NOT remove doc:1
      await cache.invalidateTag('drafts');
      expect(await cache.get<String>('doc:1'), 'v2');

      // Invalidating new tag must remove doc:1
      await cache.invalidateTag('published');
      expect(await cache.get<String>('doc:1'), isNull);
    });

    test('delete removes entry and cleans up tag associations', () async {
      if (!redisAvailable) return;

      await cache.set('doc:99', 'test', tags: ['cleanup_tag']);
      await cache.delete('doc:99');

      expect(await cache.get<String>('doc:99'), isNull);

      // Invalidate tag should be safe no-op
      await cache.invalidateTag('cleanup_tag');
    });

    test('ttl expiration works as expected', () async {
      if (!redisAvailable) return;

      await cache.set('temp', 'fleeting',
          ttl: const Duration(milliseconds: 100));
      expect(await cache.get<String>('temp'), 'fleeting');

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(await cache.get<String>('temp'), isNull);
    });

    test(
        'prefixed clear uses SCAN and removes only prefixed keys without FLUSHDB',
        () async {
      if (!redisAvailable) return;

      final otherAppCache = RedisCache.fromUrl(
        'redis://127.0.0.1:6379/15',
        prefix: 'other_isolated_app',
      );
      await otherAppCache.set('keep_me', 'preserved');

      await cache.set('k1', 'val1', tags: ['t1']);
      await cache.set('k2', 'val2', tags: ['t2']);

      await cache.clear();

      expect(await cache.get<String>('k1'), isNull);
      expect(await cache.get<String>('k2'), isNull);

      // Other app's data was NOT wiped (FLUSHDB was NOT called)
      expect(await otherAppCache.get<String>('keep_me'), 'preserved');
      await otherAppCache.delete('keep_me');
      await otherAppCache.close();
    });

    test(
        'clearing unprefixed cache throws StateError unless allowEmptyPrefixClear is true',
        () async {
      if (!redisAvailable) return;

      // By default, unprefixed clear is rejected
      expect(
        () => unprefixedCache.clear(),
        throwsStateError,
      );

      // When explicitly opted in
      final safeOptIn = RedisCache(
        host: '127.0.0.1',
        port: 6379,
        db: 15,
        prefix: '',
        allowEmptyPrefixClear: true,
      );
      await safeOptIn.set('opt_in_key', 'val');
      expect(await safeOptIn.get<String>('opt_in_key'), 'val');
      await safeOptIn.clear();
      expect(await safeOptIn.get<String>('opt_in_key'), isNull);
      await safeOptIn.close();
    });
  });
}
