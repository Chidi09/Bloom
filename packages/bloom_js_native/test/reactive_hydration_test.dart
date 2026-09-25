@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:bloom_js_native/src/_signal_scope.dart';
import 'package:bloom_js_native/src/_signals_browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

web.HTMLDivElement newContainer() {
  final container = web.document.createElement('div') as web.HTMLDivElement;
  web.document.body!.appendChild(container);
  return container;
}

void setSsrHtml(web.HTMLDivElement container, String html) {
  container.innerHTML = html.toJS;
}

void main() {
  late web.HTMLDivElement container;
  final mismatches = <HydrationMismatch>[];

  setUp(() {
    container = newContainer();
    mismatches.clear();
    bloomHotReloadTrackingEnabled = false;
  });

  tearDown(() {
    bloomHotReloadTrackingEnabled = false;
    container.remove();
  });

  HydrationMismatchHandler collect() => (m) => mismatches.add(m);

  group('reactive hydration preserves SSR DOM', () {
    test('Live hydrates in place and stays reactive', () {
      final count = signal(0);
      BloomNode page() => Div(children: [
            H1(text: 'Title'),
            Live(() => P(text: 'Count: ${count.value}')),
          ]);
      setSsrHtml(container, renderToHtml(page()));
      final h1Before = container.querySelector('h1');
      final pBefore = container.querySelector('p');

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);

      expect(mismatches, isEmpty);
      // DOM identity: the same nodes, not remounts.
      expect(container.querySelector('h1'), same(h1Before));
      expect(container.querySelector('p'), same(pBefore));

      count.value = 42;
      expect(container.querySelector('p')!.textContent, 'Count: 42');
      // Static sibling untouched by the reactive update.
      expect(container.querySelector('h1'), same(h1Before));
    });

    test('Show swaps branches without remounting siblings', () {
      final flag = signal(true);
      BloomNode page() => Div(children: [
            Span(text: 'static'),
            Show(() => flag.value,
                child: P(text: 'yes'), fallback: P(text: 'no')),
          ]);
      setSsrHtml(container, renderToHtml(page()));
      final spanBefore = container.querySelector('span');

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);
      expect(mismatches, isEmpty);

      flag.value = false;
      expect(container.querySelector('p')!.textContent, 'no');
      expect(container.querySelector('span'), same(spanBefore));
    });

    test('event listeners attach to SSR nodes exactly once', () {
      var clicks = 0;
      BloomNode page() => Div(children: [
            Button(text: 'go', on: {'click': (_) => clicks++}),
          ]);
      setSsrHtml(container, renderToHtml(page()));

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);

      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));
      expect(clicks, 1);
    });

    test('pre-hydration input values survive with a diagnostic', () {
      BloomNode page() => Div(children: [
            Input(attrs: {'value': 'server', 'type': 'text'})
          ]);
      setSsrHtml(container, renderToHtml(page()));
      final input = container.querySelector('input') as web.HTMLInputElement;
      input.value = 'typed-by-user';

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);

      expect(input.value, 'typed-by-user',
          reason: 'hydration must not clobber user input');
      expect(
          mismatches
              .where((m) => m.recovery == 'preserved pre-hydration input'),
          isNotEmpty);
    });

    test('focus and selection survive hydration', () {
      final count = signal(0);
      BloomNode page() => Div(children: [
            Input(attrs: {'type': 'text', 'id': 'name'}),
            Live(() => P(text: 'n=${count.value}')),
          ]);
      setSsrHtml(container, renderToHtml(page()));
      final input = container.querySelector('input') as web.HTMLInputElement;
      input.value = 'hello world';
      input.focus();
      input.setSelectionRange(6, 11);

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);

      expect(web.document.activeElement, same(input));
      expect(input.selectionStart, 6);
      expect(input.selectionEnd, 11);
      // Reactive updates elsewhere keep working.
      count.value = 1;
      expect(container.querySelector('p')!.textContent, 'n=1');
      expect(web.document.activeElement, same(input));
    });

    test('keyed ForEach hydrates by key and reorders without remount', () {
      final items = signal(['a', 'b']);
      BloomNode page() => Ul(children: [
            ForEach<String>(
              () => items.value,
              (t) => Li(attrs: {'data-k': t}, text: t),
              key: (t) => t,
            ),
          ]);
      setSsrHtml(container, renderToHtml(page()));
      final liA = container.querySelector('li[data-k="a"]')!;
      final liB = container.querySelector('li[data-k="b"]')!;

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);
      expect(mismatches, isEmpty);

      items.value = ['b', 'a'];
      final order = <String>[];
      final lis = container.querySelectorAll('li');
      for (var i = 0; i < lis.length; i++) {
        order.add((lis.item(i)! as web.Element).textContent!);
      }
      expect(order, ['b', 'a']);
      // Same node instances, reordered — not recreated.
      expect(container.querySelector('li[data-k="a"]'), same(liA));
      expect(container.querySelector('li[data-k="b"]'), same(liB));
    });

    test('corrupted keyed marker recovers instead of throwing', () {
      BloomNode page() => Ul(children: [
            ForEach<String>(
              () => ['a'],
              (value) => Li(attrs: {'data-k': value}, text: value),
              key: (value) => value,
            ),
          ]);

      // Simulate a malformed marker in otherwise valid SSR output (for
      // example, after an intermediary has modified the HTML comment).
      final html = renderToHtml(page()).replaceFirst(
        'bloom:key=a',
        'bloom:key=b64:%%%',
      );
      setSsrHtml(container, html);

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);

      expect(container.textContent, 'a');
      expect(container.querySelector('li[data-k="a"]'), isNotNull);
    });

    test('keyed item signal scopes survive rehydration without cross-row state',
        () {
      BloomNode page() => Div(children: [
            ForEach<int>(
              () => [1, 2],
              (item) {
                final count = signal(0, key: 'hydrated-row-count');
                return Button(
                  attrs: {'data-row': '$item'},
                  text: '$item: ${count.value}',
                  on: {'click': (_) => count.value++},
                );
              },
              key: (item) => item.toString(),
              hotReloadScopeId: 'hydration-list',
            ),
          ]);

      setSsrHtml(container, renderToHtml(page()));
      bloomHotReloadTrackingEnabled = true;
      final firstHandle =
          hydrateElement(page(), container, onMismatch: collect());
      expect(mismatches, isEmpty);

      final firstButton = container.querySelector('button[data-row="1"]')!;
      final secondButton = container.querySelector('button[data-row="2"]')!;
      firstButton.dispatchEvent(web.MouseEvent('click'));
      for (var i = 0; i < 3; i++) {
        secondButton.dispatchEvent(web.MouseEvent('click'));
      }
      expect(firstButton.textContent, '1: 1');
      expect(secondButton.textContent, '2: 3');
      beginBloomSignalScopeTransition();
      firstHandle.dispose();

      bloomHotReloadTrackingEnabled = false;
      setSsrHtml(container, renderToHtml(page()));
      bloomHotReloadTrackingEnabled = true;
      final secondHandle =
          hydrateElement(page(), container, onMismatch: collect());
      finishBloomSignalScopeTransition();
      expect(
          container.querySelector('button[data-row="1"]')?.textContent, '1: 1');
      expect(
          container.querySelector('button[data-row="2"]')?.textContent, '2: 3');
      secondHandle.dispose();
    });

    test('dispose stops effects and listeners', () {
      final count = signal(0);
      var clicks = 0;
      BloomNode page() => Div(children: [
            Live(() => P(text: 'n=${count.value}')),
            Button(text: 'b', on: {'click': (_) => clicks++}),
          ]);
      setSsrHtml(container, renderToHtml(page()));
      final handle = hydrateElement(page(), container);

      handle.dispose();
      count.value = 99;
      expect(container.querySelector('p'), isNull,
          reason: 'dispose clears the container');
    });

    test('context, mount, ref wrappers hydrate through', () async {
      final theme = createContext('light');
      var mounted = false;
      final ref = Ref<Object>();
      BloomNode page() => theme.provide(
            'dark',
            Mount(
              RefNode(ref, Live(() => P(text: 't=${useContext(theme)}'))),
              onMount: () => mounted = true,
            ),
          );
      setSsrHtml(container, renderToHtml(page()));

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);

      expect(mismatches, isEmpty);
      expect(container.querySelector('p')!.textContent, 't=dark');
      expect(ref.isMounted, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(mounted, isTrue, reason: 'hydration fires onMount');
    });

    test('boundary mismatch recovers locally with diagnostics', () {
      // SSR and client agree on the outer structure; only the Live
      // boundary's content differs (<p> vs <div>).
      setSsrHtml(
          container,
          renderToHtml(Div(children: [
            Span(text: 'keep'),
            Live(() => P(text: 'old')),
          ])));
      final spanBefore = container.querySelector('span');
      final handle = hydrateElement(
        Div(children: [
          Span(text: 'keep'),
          Live(() => Div(text: 'new')),
        ]),
        container,
        onMismatch: collect(),
      );
      addTearDown(handle.dispose);

      expect(mismatches.where((m) => m.boundary == 'bloom:live'), isNotEmpty,
          reason: 'the Live boundary recovers itself');
      // Untouched sibling keeps its node identity.
      expect(container.querySelector('span'), same(spanBefore));
      expect(container.textContent, contains('keep'));
      expect(container.textContent, contains('new'));
    });

    test('root mismatch falls back to a full remount', () {
      setSsrHtml(container, '<section><p>other app</p></section>');
      final handle =
          hydrateElement(Div(text: 'fresh'), container, onMismatch: collect());
      addTearDown(handle.dispose);

      expect(mismatches.where((m) => m.recovery == 'remounted target'),
          isNotEmpty);
      expect(container.textContent, 'fresh');
    });
  });

  group('suspense hydration timing', () {
    test('late server patch no-ops after the shell is claimed', () async {
      final completer = Completer<String>();
      BloomNode page() => Div(children: [
            Suspense<String>(
              resource: () => completer.future,
              builder: (data) => P(text: 'got $data'),
              fallback: P(text: 'loading'),
            ),
          ]);
      // Simulate the already-flushed streaming shell.
      setSsrHtml(container,
          '<div><div id="bloom-suspense-0"><p>loading</p></div></div>');

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);

      // Claimed synchronously during hydrate: the stale id is gone, so a
      // late server <script> patch finds no element and no-ops.
      expect(web.document.getElementById('bloom-suspense-0'), isNull);
      expect(
          container
              .querySelector('div[$suspenseClaimedAttribute]')!
              .getAttribute(suspenseClaimedAttribute),
          'bloom-suspense-0');

      completer.complete('data');
      await completer.future;
      await Future<void>.delayed(Duration.zero);
      expect(container.textContent, contains('got data'));
    });

    test('async builder signals keep their scope through hydration and HMR',
        () async {
      bloomHotReloadTrackingEnabled = true;
      final completer = Completer<int>();
      BloomNode page() => Div(children: [
            Suspense<int>(
              resource: () => completer.future,
              builder: (_) {
                final count = signal(0, key: 'hydrated-suspense-count');
                return Button(
                  text: 'Resolved ${count.value}',
                  on: {'click': (_) => count.value++},
                );
              },
              fallback: P(text: 'loading'),
              hotReloadScopeId: 'hydrated-suspense',
            ),
          ]);

      setSsrHtml(container,
          '<div><div id="bloom-suspense-0"><p>loading</p></div></div>');
      final firstHandle =
          hydrateElement(page(), container, onMismatch: collect());
      completer.complete(1);
      await completer.future;
      await Future<void>.delayed(Duration.zero);
      expect(container.querySelector('button')?.textContent, 'Resolved 0');
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      setSsrHtml(container,
          '<div><div id="bloom-suspense-0"><p>loading</p></div></div>');
      final nextHandle =
          hydrateElement(page(), container, onMismatch: collect());
      addTearDown(nextHandle.dispose);
      await Future<void>.delayed(Duration.zero);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Resolved 1');
      expect(mismatches, isEmpty);
    });

    test('resolved-before-hydrate recovers through a delimited parent',
        () async {
      BloomNode page() => Div(children: [
            Live(() => Suspense<String>(
                  resource: () => Future.value('fast'),
                  builder: (data) => P(text: 'got $data'),
                  fallback: P(text: 'loading'),
                )),
          ]);
      // Server already patched in the resolved content before hydrate ran:
      // no shell div, no markers around the resolved markup.
      setSsrHtml(container, '<div><p>got fast</p></div>');

      final handle = hydrateElement(page(), container, onMismatch: collect());
      addTearDown(handle.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.textContent, contains('got fast'));
    });
  });

  group('island activation semantics', () {
    test('interaction hydrates without replaying the trigger', () async {
      registerIsland('toggler', (props) {
        final count = signal(0);
        return Live(() => Button(
            text: 'c=${count.value}', on: {'click': (_) => count.value++}));
      });
      addTearDown(() => unregisterIsland('toggler'));

      container.innerHTML =
          ('<div data-bloom-island="toggler" data-bloom-strategy="interaction">'
                  '<button>c=0</button></div>')
              .toJS;
      final orchestrator = BloomIslandOrchestrator(autoScan: true);
      addTearDown(orchestrator.dispose);
      await Future<void>.delayed(Duration.zero);

      final host =
          container.querySelector('[data-bloom-island]') as web.Element;
      // The triggering interaction hydrates only.
      host.dispatchEvent(web.PointerEvent('pointerdown'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final button = container.querySelector('button')!;
      expect(button.textContent, 'c=0',
          reason: 'first interaction hydrates; it is not replayed');
      // Subsequent interactions work normally.
      button.dispatchEvent(web.MouseEvent('click'));
      expect(container.querySelector('button')!.textContent, 'c=1');
    });

    test('idle island hydrates without interaction', () async {
      registerIsland('idl', (_) => Span(text: 'live'));
      addTearDown(() => unregisterIsland('idl'));

      container.innerHTML =
          ('<div data-bloom-island="idl" data-bloom-strategy="idle">'
                  '<span>live</span></div>')
              .toJS;
      final orchestrator = BloomIslandOrchestrator(autoScan: true);
      addTearDown(orchestrator.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      final host =
          container.querySelector('[data-bloom-island]') as web.Element;
      expect(host.getAttribute('data-bloom-hydrated'), 'true');
    });
  });
}
