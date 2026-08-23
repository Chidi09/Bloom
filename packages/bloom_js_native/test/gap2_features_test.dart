import 'dart:async';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('scheduler actually yields (item 8)', () {
    tearDown(BloomScheduler.resetHost);

    test('a long queue yields to the host instead of running in one go',
        () async {
      // The old startTransition used scheduleMicrotask, which never yields.
      // A real scheduler must hand control back to the host between slices.
      // It does that by re-queueing through scheduleWork (a real macrotask),
      // so more than one scheduleWork turn proves the work was sliced.
      var turns = 0;
      BloomScheduler.setHost(_CountingHost(() {}, onScheduleWork: () => turns++));

      for (var i = 0; i < 200; i++) {
        BloomScheduler.schedule<void>(() {
          // Burn enough time that the slice budget is exceeded.
          final end = DateTime.now().add(const Duration(milliseconds: 2));
          while (DateTime.now().isBefore(end)) {}
        }, priority: TaskPriority.normal);
      }
      await BloomScheduler.flush();

      expect(turns, greaterThan(1),
          reason: 'THE POINT: work must be sliced across host turns, '
              'not run to completion in a single microtask');
    });

    test('higher priority work runs before lower priority work', () async {
      final order = <String>[];
      BloomScheduler.schedule<void>(() => order.add('idle'),
          priority: TaskPriority.idle);
      BloomScheduler.schedule<void>(() => order.add('low'),
          priority: TaskPriority.low);
      BloomScheduler.schedule<void>(() => order.add('urgent'),
          priority: TaskPriority.userBlocking);
      await BloomScheduler.flush();

      expect(order.first, 'urgent');
      expect(order.last, 'idle');
    });

    test('same-priority work keeps submission order', () async {
      final order = <int>[];
      for (var i = 0; i < 5; i++) {
        BloomScheduler.schedule<void>(() => order.add(i),
            priority: TaskPriority.normal);
      }
      await BloomScheduler.flush();
      expect(order, [0, 1, 2, 3, 4]);
    });

    test('a cancelled task never runs', () async {
      var ran = false;
      final task = BloomScheduler.schedule<void>(() => ran = true,
          priority: TaskPriority.low);
      task.cancel();
      await BloomScheduler.flush();

      expect(ran, isFalse);
      expect(task.isCancelled, isTrue);
    });

    test('a task that throws does not stop the queue', () async {
      var reached = false;
      final bad = BloomScheduler.schedule<void>(
          () => throw StateError('boom'),
          priority: TaskPriority.normal);
      bad.future.catchError((Object _) {});
      BloomScheduler.schedule<void>(() => reached = true,
          priority: TaskPriority.normal);
      await BloomScheduler.flush();

      expect(reached, isTrue,
          reason: 'one bad task must not wedge the scheduler');
    });

    test('isTransitionPending spans the whole transition', () async {
      expect(isTransitionPending.value, isFalse);
      startTransition(() {});
      expect(isTransitionPending.value, isTrue,
          reason: 'must be true immediately, before the work runs');
      await BloomScheduler.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(isTransitionPending.value, isFalse);
    });

    test('the sync host runs work promptly, for SSR', () async {
      BloomScheduler.setHost(SyncSchedulerHost());
      var ran = false;
      BloomScheduler.schedule<void>(() => ran = true,
          priority: TaskPriority.low);
      await BloomScheduler.flush();
      expect(ran, isTrue,
          reason: 'an SSR render cannot wait on animation frames');
    });
  });

  group('scoped css (item 10)', () {
    test('the same input always produces the same hash', () {
      const css = '.title { color: red; }';
      expect(scopedCss(css).hash, scopedCss(css).hash,
          reason: 'SSR and client must agree on generated class names');
      expect(scopedCss(css).hash, isNot(scopedCss('.other { color: red; }').hash));
    });

    test('class selectors are scoped and mapped', () {
      final s = scopedCss('.title { color: red; } .body { margin: 0; }');
      expect(s.classes.containsKey('title'), isTrue);
      expect(s.classes['title'], isNot('title'));
      expect(s.css, contains(s.classes['title']!));
      expect(s('title'), s.classes['title'],
          reason: 'the call shorthand must resolve a class name');
    });

    test('element, id and :root selectors are left alone', () {
      final s = scopedCss('div { margin: 0; } #app { padding: 0; } '
          ':root { --x: 1px; }');
      expect(s.css, contains('div'));
      expect(s.css, contains('#app'));
      expect(s.css, contains(':root'));
      expect(s.classes, isEmpty);
    });

    test('pseudo-classes and pseudo-elements survive', () {
      final s = scopedCss('.btn:hover { color: red; } .btn::before '
          '{ content: "x"; }');
      final scoped = s.classes['btn']!;
      expect(s.css, contains('$scoped:hover'));
      expect(s.css, contains('$scoped::before'));
    });

    test('rules nested in @media are scoped', () {
      final s = scopedCss(
          '@media (min-width: 600px) { .wide { display: flex; } }');
      expect(s.classes.containsKey('wide'), isTrue);
      expect(s.css, contains('@media'));
      expect(s.css, contains(s.classes['wide']!));
    });

    test('keyframe stops are NOT treated as selectors', () {
      final s = scopedCss('@keyframes spin { from { opacity: 0; } '
          'to { opacity: 1; } } .spinner { animation: spin 1s; }');
      expect(s.css, contains('from'));
      expect(s.css, contains('to'));
      expect(s.classes.containsKey('spinner'), isTrue);
      expect(s.classes.containsKey('from'), isFalse,
          reason: 'from/to are keyframe stops, not classes');
    });

    test('comma-separated selectors each get scoped', () {
      final s = scopedCss('.a, .b { color: red; }');
      expect(s.classes.containsKey('a'), isTrue);
      expect(s.classes.containsKey('b'), isTrue);
    });

    test('the produced node is a StyleNode carrying the rewritten css', () {
      final s = scopedCss('.x { color: red; }');
      final html = renderToHtml(s.node);
      expect(html, contains('<style'));
      expect(html, contains(s.classes['x']!));
    });
  });

  group('i18n (item 13)', () {
    late BloomI18n i18n;
    setUp(() {
      i18n = BloomI18n();
      i18n.addMessages('en', {
        'greeting': 'Hello, {name}!',
        'items': '{count, plural, =0{no items} one{# item} other{# items}}',
        'role': '{kind, select, admin{Administrator} other{Member}}',
      });
      i18n.addMessages('fr', {'greeting': 'Bonjour, {name} !'});
      i18n.setLocale('en');
    });

    test('interpolates named arguments', () {
      expect(i18n.translate('greeting', args: {'name': 'Ada'}), 'Hello, Ada!');
    });

    test('handles ICU plural including the zero case', () {
      expect(i18n.translate('items', args: {'count': 0}), 'no items');
      expect(i18n.translate('items', args: {'count': 1}), contains('1'));
      expect(i18n.translate('items', args: {'count': 5}), contains('5'));
      expect(i18n.translate('items', args: {'count': 5}), contains('items'));
    });

    test('handles ICU select', () {
      expect(i18n.translate('role', args: {'kind': 'admin'}), 'Administrator');
      expect(i18n.translate('role', args: {'kind': 'other'}), 'Member');
    });

    test('changing locale is reactive', () {
      var ticks = 0;
      final d = effect(() {
        i18n.locale.value;
        ticks++;
      });
      addTearDown(d.call);
      final before = ticks;

      i18n.setLocale('fr');
      expect(ticks, greaterThan(before),
          reason: 'a Live reading the locale must re-render on change');
      expect(i18n.translate('greeting', args: {'name': 'Ada'}),
          'Bonjour, Ada !');
    });

    test('a missing key is detectable, not silently blank', () {
      final out = i18n.translate('does.not.exist');
      expect(out, isNotEmpty,
          reason: 'must fall back to something visible, not empty string');
      expect(out, contains('does.not.exist'));
    });

    test('rtl detection and dir attribute', () {
      expect(isRtl('ar'), isTrue);
      expect(isRtl('he'), isTrue);
      expect(isRtl('en'), isFalse);
      expect(dirAttribute('ar')['dir'], 'rtl');
      expect(dirAttribute('en')['dir'], 'ltr');
    });

    test('locale resolution picks the best available match', () {
      final picked =
          resolveLocale(['fr-CA', 'fr', 'en'], supported: ['en', 'fr']);
      expect(picked, 'fr');
    });
  });

  group('image (item 14)', () {
    test('builds a srcset from widths', () {
      final srcset = buildSrcSet('/hero.jpg', const [400, 800, 1200]);
      expect(srcset, contains('400w'));
      expect(srcset, contains('1200w'));
    });

    test('lazy and async by default, eager when priority', () {
      final lazy = renderToHtml(bloomImage(src: '/a.jpg', alt: 'a'));
      expect(lazy, contains('loading="lazy"'));
      expect(lazy, contains('decoding="async"'));

      final hero = renderToHtml(
          bloomImage(src: '/hero.jpg', alt: 'hero', priority: true));
      expect(hero, contains('loading="eager"'),
          reason: 'lazy-loading the LCP image defeats the purpose');
      expect(hero, contains('fetchpriority="high"'));
    });

    test('a decorative image gets empty alt and aria-hidden', () {
      final html = renderToHtml(bloomImage(src: '/deco.png', decorative: true));
      expect(html, contains('alt=""'));
      expect(html, contains('aria-hidden="true"'));
    });

    test('width and height are emitted for layout stability', () {
      final html =
          renderToHtml(bloomImage(src: '/a.jpg', alt: 'a', width: 800, height: 600));
      expect(html, contains('width="800"'));
      expect(html, contains('height="600"'));
    });

    test('picture emits sources before the fallback img', () {
      final html = renderToHtml(bloomPicture(
        sources: [
          PictureSource(srcset: '/a.avif', type: 'image/avif'),
          PictureSource(srcset: '/a.webp', type: 'image/webp'),
        ],
        fallbackSrc: '/a.jpg',
        alt: 'a',
      ));
      expect(html, contains('<picture'));
      expect(html.indexOf('image/avif'), lessThan(html.indexOf('<img')));
      expect(html, contains('/a.jpg'));
    });
  });

  group('islands: the SSR half must work on a server (item 9)', () {
    // island_node.dart is deliberately pure Dart. If this group compiles and
    // runs on the VM, a server can emit island placeholders without pulling in
    // package:web — which is the whole point of the feature.
    test('emits a placeholder carrying name, strategy and props', () {
      final html = renderToHtml(bloomIsland(
        name: 'shopping-cart',
        strategy: HydrationStrategy.visible,
        props: {'itemCount': 3},
        child: Div(text: 'Cart (3)'),
      ));

      expect(html, contains('$bloomIslandAttribute="shopping-cart"'));
      expect(html, contains('$bloomStrategyAttribute="visible"'));
      expect(html, contains('itemCount'));
      expect(html, contains('Cart (3)'),
          reason: 'server-rendered content must be present for no-JS visitors');
    });

    test('props are JSON-escaped so they cannot break out of the attribute',
        () {
      final html = renderToHtml(bloomIsland(
        name: 'x',
        props: {'evil': '"><script>alert(1)</script>'},
        child: Div(text: 'x'),
      ));
      expect(html.contains('"><script>alert(1)'), isFalse,
          reason: 'props must not break out of the attribute');
    });

    test('an island with no props still emits a valid placeholder', () {
      final html =
          renderToHtml(bloomIsland(name: 'plain', child: Div(text: 'hi')));
      expect(html, contains('$bloomIslandAttribute="plain"'));
    });
  });

  group('typed rpc (item 12)', () {
    test('interpolates and encodes path parameters', () {
      final c = BloomRpcContract<void, Map<String, dynamic>>.get(
          '/users/:id/posts');
      final uri = c.resolvePath(pathParams: {'id': 'a b/c'});
      expect(uri, contains('a%20b%2Fc'),
          reason: 'path params must be percent-encoded');
      expect(uri, isNot(contains(':id')));
    });

    test('a missing path parameter fails loudly and names it', () {
      final c =
          BloomRpcContract<void, Map<String, dynamic>>.get('/users/:id');
      expect(
        () => c.resolvePath(pathParams: const {}),
        throwsA(predicate((Object e) => e.toString().contains('id'))),
        reason: 'must not silently produce a URL containing ":id"',
      );
    });

    test('a contract produces a stable cache key', () {
      final c = BloomRpcContract<int, String>.get('/thing');
      final a = c.cacheKey(1);
      final b = c.cacheKey(1);
      expect(BloomData.normalizeKey(a), BloomData.normalizeKey(b));
      expect(BloomData.normalizeKey(a),
          isNot(BloomData.normalizeKey(c.cacheKey(2))));
    });
  });
}

/// A [SchedulerHost] that records how many times the scheduler yielded.
class _CountingHost implements SchedulerHost {
  _CountingHost(this.onYield, {this.onScheduleWork});
  final void Function() onYield;
  final void Function()? onScheduleWork;

  @override
  bool get isSynchronous => false;

  @override
  void scheduleWork(void Function() work) {
    onScheduleWork?.call();
    Timer.run(work);
  }

  @override
  Future<void> yieldToHost() {
    onYield();
    return Future<void>.delayed(Duration.zero);
  }
}
