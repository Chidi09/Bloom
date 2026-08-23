@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

web.HTMLDivElement _host() {
  final d = web.document.createElement('div') as web.HTMLDivElement;
  web.document.body!.appendChild(d);
  return d;
}

void main() {
  group('islands orchestration (item 9)', () {
    late web.HTMLDivElement root;
    setUp(() {
      root = _host();
      BloomIslandRegistry.instance.clear();
    });
    tearDown(() => root.remove());

    test('an immediate island hydrates and becomes interactive', () async {
      root.innerHTML = '<div $bloomIslandAttribute="counter">'
              '<button>0</button></div>'
          .toJS;

      final clicks = signal(0);
      registerIsland('counter', (props) {
        return Button(
          onClick: (_) => clicks.value++,
          text: 'count',
        );
      });

      final orch = orchestrateIslands(rootElement: root);
      addTearDown(orch.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final btn = root.querySelector('button');
      expect(btn, isNotNull);
      (btn as web.HTMLElement).click();
      expect(clicks.value, 1,
          reason: 'the island must be genuinely hydrated, not just present');
    });

    test('props reach the builder decoded', () async {
      root.innerHTML = '<div $bloomIslandAttribute="p" '
              '$bloomPropsAttribute=\'{"n":7,"s":"hi"}\'></div>'
          .toJS;

      Map<String, dynamic>? seen;
      registerIsland('p', (props) {
        seen = props;
        return Div(text: 'ok');
      });

      final orch = orchestrateIslands(rootElement: root);
      addTearDown(orch.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(seen, isNotNull);
      expect(seen!['n'], 7);
      expect(seen!['s'], 'hi');
    });

    test('malformed props do not take down the page', () async {
      root.innerHTML = '<div $bloomIslandAttribute="bad" '
              '$bloomPropsAttribute="{not json"></div>'
              '<div $bloomIslandAttribute="good"></div>'
          .toJS;

      var goodRan = false;
      registerIsland('bad', (props) => Div(text: 'bad'));
      registerIsland('good', (props) {
        goodRan = true;
        return Div(text: 'good');
      });

      final orch = orchestrateIslands(rootElement: root);
      addTearDown(orch.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(goodRan, isTrue,
          reason: 'a malformed payload must not stop other islands');
    });

    test('one island throwing does not block the others', () async {
      root.innerHTML = '<div $bloomIslandAttribute="boom"></div>'
              '<div $bloomIslandAttribute="fine"></div>'
          .toJS;

      var fineRan = false;
      registerIsland('boom', (props) => throw StateError('island boom'));
      registerIsland('fine', (props) {
        fineRan = true;
        return Div(text: 'fine');
      });

      final orch = orchestrateIslands(rootElement: root);
      addTearDown(orch.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(fineRan, isTrue, reason: 'failures must be isolated per island');
    });

    test('a "never" island is left as static markup', () async {
      root.innerHTML =
          '<div $bloomIslandAttribute="static" $bloomStrategyAttribute="never">'
                  '<span>server html</span></div>'
              .toJS;

      var built = false;
      registerIsland('static', (props) {
        built = true;
        return Div(text: 'client');
      });

      final orch = orchestrateIslands(rootElement: root);
      addTearDown(orch.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(built, isFalse, reason: 'strategy "never" must not hydrate');
      expect(root.textContent, contains('server html'));
    });

    test('an unregistered island is skipped without throwing', () async {
      root.innerHTML =
          '<div $bloomIslandAttribute="nobody-registered"></div>'.toJS;
      final orch = orchestrateIslands(rootElement: root);
      addTearDown(orch.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(true, isTrue);
    });

    test('an island hydrates at most once', () async {
      root.innerHTML = '<div $bloomIslandAttribute="once"></div>'.toJS;
      var builds = 0;
      registerIsland('once', (props) {
        builds++;
        return Div(text: 'x');
      });

      final orch = orchestrateIslands(rootElement: root);
      addTearDown(orch.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      orch.scan();
      orch.scan();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(builds, 1, reason: 'repeated scans must not re-hydrate');
    });
  });

  group('web components interop (item 11)', () {
    late web.HTMLDivElement root;
    setUp(() => root = _host());
    tearDown(() => root.remove());

    test('renders a custom tag and sets rich properties on the instance',
        () async {
      final handle = mountToElement(
        customElement(
          'test-widget',
          properties: {
            'items': [1, 2, 3],
            'config': {'a': 1},
          },
          attrs: {'label': 'hello'},
          waitForUpgrade: false,
        ),
        root,
      );
      addTearDown(handle.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final el = root.querySelector('test-widget');
      expect(el, isNotNull);
      expect(el!.getAttribute('label'), 'hello',
          reason: 'plain attributes still go on as attributes');

      // A rich value must be a real JS property, not a stringified attribute.
      expect(el.hasAttribute('items'), isFalse,
          reason: 'arrays must not be serialised into an attribute');
      final items = (el as JSObject).getProperty('items'.toJS);
      expect(items, isNotNull,
          reason: 'the array must be assigned as a JS property');
    });

    test('a reactive property is re-assigned when its signal changes',
        () async {
      final count = signal(1);
      final handle = mountToElement(
        customElement(
          'reactive-widget',
          properties: {'value': count},
          waitForUpgrade: false,
        ),
        root,
      );
      addTearDown(handle.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final el = root.querySelector('reactive-widget')! as JSObject;
      expect((el.getProperty('value'.toJS) as JSNumber?)?.toDartInt, 1);

      count.value = 42;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect((el.getProperty('value'.toJS) as JSNumber?)?.toDartInt, 42,
          reason: 'the live element must be updated without being recreated');
    });

    test('custom events deliver a decoded detail payload', () async {
      Object? received;
      final handle = mountToElement(
        customElement(
          'evt-widget',
          events: {
            'thing-changed': (e) => received = e.detail,
          },
          waitForUpgrade: false,
        ),
        root,
      );
      addTearDown(handle.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final el = root.querySelector('evt-widget')!;
      final init = web.CustomEventInit(detail: {'id': 7}.jsify());
      el.dispatchEvent(web.CustomEvent('thing-changed', init));

      expect(received, isNotNull);
      expect((received as Map)['id'], 7,
          reason: 'detail must arrive as usable Dart, not an opaque JS value');
    });

    test('SSR renders the tag with attributes and no properties', () {
      final html = renderToHtml(
        customElement(
          'ssr-widget',
          attrs: {'label': 'x'},
          properties: {'rich': [1, 2]},
        ),
      );
      expect(html, contains('<ssr-widget'));
      expect(html, contains('label="x"'));
      expect(html, isNot(contains('rich=')),
          reason: 'properties cannot exist in server-rendered HTML');
    });
  });
}
