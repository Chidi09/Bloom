import 'dart:async';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('BloomRevalidateConfig', () {
    test('generates expected Cache-Control headers for ssr, ssg, and isr', () {
      expect(const BloomRevalidateConfig.ssr().toCacheControlHeader(),
          'no-store');
      expect(const BloomRevalidateConfig.ssg().toCacheControlHeader(),
          'public, max-age=31536000, immutable');
      expect(
        const BloomRevalidateConfig.isr(revalidate: Duration(seconds: 60))
            .toCacheControlHeader(),
        'public, s-maxage=60, stale-while-revalidate=60',
      );
    });

    test('cacheKeyFor normalizes path and canonicalizes vary params/headers',
        () {
      const config = BloomRevalidateConfig.isr(
        revalidate: Duration(seconds: 30),
        varyQueryParams: ['b', 'a'],
        varyHeaders: ['Accept-Language', 'X-Tenant'],
      );
      final key1 = config.cacheKeyFor(
        '/products/',
        query: {'a': '1', 'b': '2', 'ignored': '9'},
        headers: {'x-tenant': 'acme', 'accept-language': 'en-US'},
      );
      final key2 = config.cacheKeyFor(
        'products',
        query: {'b': '2', 'a': '1'},
        headers: {'Accept-Language': 'en-US', 'X-Tenant': 'acme'},
      );
      expect(key1, equals(key2));
      expect(key1, '/products|q:a=1&b=2|h:accept-language=en-US&x-tenant=acme');
    });

    test('isCacheableRequest rejects Cookie and Authorization unless allowed',
        () {
      const config = BloomRevalidateConfig.isr(
        revalidate: Duration(seconds: 60),
      );
      expect(config.isCacheableRequest(), isTrue);
      expect(config.isCacheableRequest(headers: {'Cookie': 'sid=123'}),
          isFalse);
      expect(
          config.isCacheableRequest(headers: {'authorization': 'Bearer tok'}),
          isFalse);

      const personalized = BloomRevalidateConfig.isr(
        revalidate: Duration(seconds: 60),
        allowPersonalized: true,
      );
      expect(personalized.isCacheableRequest(headers: {'Cookie': 'sid=123'}),
          isTrue);
      expect(const BloomRevalidateConfig.ssr().isCacheableRequest(), isFalse);
    });
  });

  group('MemoryBloomIsrStore', () {
    test('evicts least-recently used entry when exceeding maxEntries', () {
      final store = MemoryBloomIsrStore(maxEntries: 2);
      final now = DateTime(2026, 1, 1);
      store.put('/a', BloomIsrEntry(html: 'a', generatedAt: now));
      store.put('/b', BloomIsrEntry(html: 'b', generatedAt: now));
      // Touch /a so /b becomes least-recently used.
      expect(store.get('/a')?.html, 'a');
      store.put('/c', BloomIsrEntry(html: 'c', generatedAt: now));

      expect(store.length, 2);
      expect(store.get('/b'), isNull);
      expect(store.get('/a')?.html, 'a');
      expect(store.get('/c')?.html, 'c');
    });

    test('deleteByTag removes matching entries only', () {
      final store = MemoryBloomIsrStore();
      final now = DateTime(2026, 1, 1);
      store.put('/p1',
          BloomIsrEntry(html: '1', generatedAt: now, tags: ['products', 'p1']));
      store.put('/p2',
          BloomIsrEntry(html: '2', generatedAt: now, tags: ['products', 'p2']));
      store.put('/about',
          BloomIsrEntry(html: 'about', generatedAt: now, tags: ['static']));

      expect(store.deleteByTag('products'), 2);
      expect(store.get('/p1'), isNull);
      expect(store.get('/p2'), isNull);
      expect(store.get('/about')?.html, 'about');
    });
  });

  group('BloomIsrRenderer', () {
    test('handles miss -> hit -> stale-while-revalidate -> updated hit',
        () async {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      var version = 0;
      final renderer = BloomIsrRenderer(clock: () => now);
      const config = BloomRevalidateConfig.isr(
        revalidate: Duration(seconds: 60),
        tags: ['home'],
      );

      // 1. Miss
      final r1 = await renderer.render(
        path: '/',
        config: config,
        renderHtml: () => '<h1>v${++version}</h1>',
      );
      expect(r1.cacheStatus, BloomIsrCacheStatus.miss);
      expect(r1.html, '<h1>v1</h1>');

      // 2. Hit (within 60s)
      now = now.add(const Duration(seconds: 30));
      final r2 = await renderer.render(
        path: '/',
        config: config,
        renderHtml: () => '<h1>v${++version}</h1>',
      );
      expect(r2.cacheStatus, BloomIsrCacheStatus.hit);
      expect(r2.html, '<h1>v1</h1>');
      expect(version, 1);

      // 3. Stale (after 60s): returns v1 immediately, triggers 1 background refresh
      now = now.add(const Duration(seconds: 40));
      final regenGate = Completer<void>();
      final r3 = await renderer.render(
        path: '/',
        config: config,
        renderHtml: () async {
          await regenGate.future;
          return '<h1>v${++version}</h1>';
        },
      );
      final r4 = await renderer.render(
        path: '/',
        config: config,
        renderHtml: () => '<h1>should-dedupe</h1>',
      );
      expect(r3.cacheStatus, BloomIsrCacheStatus.stale);
      expect(r3.html, '<h1>v1</h1>');
      expect(r4.cacheStatus, BloomIsrCacheStatus.stale);
      expect(r4.html, '<h1>v1</h1>');

      regenGate.complete();
      await renderer.drainPending();
      expect(version, 2);

      // 4. Subsequent request is a fresh hit with v2
      final r5 = await renderer.render(
        path: '/',
        config: config,
        renderHtml: () => '<h1>v${++version}</h1>',
      );
      expect(r5.cacheStatus, BloomIsrCacheStatus.hit);
      expect(r5.html, '<h1>v2</h1>');
    });

    test('keeps serving stale entry if background regeneration throws',
        () async {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final renderer = BloomIsrRenderer(clock: () => now);
      const config = BloomRevalidateConfig.isr(
        revalidate: Duration(seconds: 10),
      );

      await renderer.render(
        path: '/post',
        config: config,
        renderHtml: () => '<p>good</p>',
      );

      now = now.add(const Duration(seconds: 20));
      final staleRes = await renderer.render(
        path: '/post',
        config: config,
        renderHtml: () => throw StateError('backend down'),
      );
      expect(staleRes.cacheStatus, BloomIsrCacheStatus.stale);
      expect(staleRes.html, '<p>good</p>');

      await renderer.drainPending();
      final stillCached = await renderer.render(
        path: '/post',
        config: config,
        renderHtml: () => '<p>recovered</p>',
      );
      expect(stillCached.html, '<p>good</p>');
    });

    test('bypasses cache for personalized requests and supports invalidation',
        () async {
      var count = 0;
      final renderer = BloomIsrRenderer();
      const config = BloomRevalidateConfig.isr(
        revalidate: Duration(seconds: 60),
        tags: ['catalog'],
      );

      final bypass = await renderer.render(
        path: '/catalog',
        config: config,
        headers: {'Cookie': 'session=abc'},
        renderHtml: () => '<div>private-${++count}</div>',
      );
      expect(bypass.cacheStatus, BloomIsrCacheStatus.bypass);
      expect(bypass.cacheControl, 'private, no-store');

      final miss1 = await renderer.render(
        path: '/catalog',
        config: config,
        renderHtml: () => '<div>public-${++count}</div>',
      );
      expect(miss1.cacheStatus, BloomIsrCacheStatus.miss);

      expect(await renderer.revalidateTag('catalog'), 1);
      final miss2 = await renderer.render(
        path: '/catalog',
        config: config,
        renderHtml: () => '<div>public-${++count}</div>',
      );
      expect(miss2.cacheStatus, BloomIsrCacheStatus.miss);
      expect(miss2.html, '<div>public-3</div>');
    });

    test('BloomRoute carries optional revalidate metadata', () {
      final route = BloomRoute(
        '/blog/:slug',
        (params) => Div(text: params['slug']),
        revalidate: const BloomRevalidateConfig.isr(
          revalidate: Duration(minutes: 5),
          tags: ['blog'],
        ),
      );
      expect(route.revalidate?.mode, BloomRenderMode.isr);
      expect(route.revalidate?.revalidate, const Duration(minutes: 5));
      expect(route.revalidate?.tags, ['blog']);
    });
  });
}
