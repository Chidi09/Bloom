@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.deleteProperty')
external bool _reflectDelete(JSAny target, String key);

void main() {
  late web.HTMLDivElement container;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body?.appendChild(container);
    bloomHotReloadTrackingEnabled = false;
    _reflectDelete(web.window as JSAny, '__bloomDisposeActiveMount');
    _reflectDelete(web.window as JSAny, '__bloomReportUnhandledError');
  });

  tearDown(() {
    bloomDisposeActiveMount();
    bloomHotReloadTrackingEnabled = false;
    _reflectDelete(web.window as JSAny, '__bloomDisposeActiveMount');
    _reflectDelete(web.window as JSAny, '__bloomReportUnhandledError');
    container.remove();
  });

  group('Hot Reload Active Mount Tracking', () {
    test('with bloomHotReloadTrackingEnabled = false (default), does NOT install window.__bloomDisposeActiveMount', () {
      final node = Div(text: 'Initial App');
      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      expect(container.textContent, 'Initial App');
      final hook = _reflectGet(web.window as JSAny, '__bloomDisposeActiveMount');
      expect(hook, isNull);
    });

    test('with bloomHotReloadTrackingEnabled = true, mounting installs hook and calling it disposes active handle', () {
      bloomHotReloadTrackingEnabled = true;

      final count = signal(10);
      final node = Div(children: [
        H1(text: 'Hot App'),
        Live(() => P(text: 'Count: ${count.value}')),
      ]);

      final handle = mountToElement(node, container);
      expect(container.querySelector('h1')?.textContent, 'Hot App');
      expect(container.querySelector('p')?.textContent, 'Count: 10');

      // Hook was installed on window
      final hook = _reflectGet(web.window as JSAny, '__bloomDisposeActiveMount');
      expect(hook, isNotNull);

      // Mutating signal updates DOM
      count.value = 20;
      expect(container.querySelector('p')?.textContent, 'Count: 20');

      // Disposing via bloomDisposeActiveMount tears down DOM and marks handle disposed
      bloomDisposeActiveMount();
      expect(handle.isDisposed, isTrue);
      expect(container.textContent, '');

      // Further signal changes do not affect disposed tree
      count.value = 30;
      expect(container.textContent, '');
    });

    test('mounting a second app after disposing the first correctly replaces active handle without errors', () {
      bloomHotReloadTrackingEnabled = true;

      // App 1
      final count1 = signal(1);
      final app1 = Div(children: [
        Span(text: 'App1'),
        Live(() => P(text: 'Val1: ${count1.value}')),
      ]);

      final handle1 = mountToElement(app1, container);
      expect(container.querySelector('span')?.textContent, 'App1');
      expect(handle1.isDisposed, isFalse);

      // Dispose active mount
      bloomDisposeActiveMount();
      expect(handle1.isDisposed, isTrue);
      expect(container.textContent, '');

      // App 2
      final count2 = signal(100);
      final app2 = Div(children: [
        Span(text: 'App2'),
        Live(() => P(text: 'Val2: ${count2.value}')),
      ]);

      final handle2 = mountToElement(app2, container);
      expect(container.querySelector('span')?.textContent, 'App2');
      expect(container.querySelector('p')?.textContent, 'Val2: 100');
      expect(handle2.isDisposed, isFalse);

      // Disposing again disposes App 2 cleanly
      bloomDisposeActiveMount();
      expect(handle2.isDisposed, isTrue);
      expect(container.textContent, '');

      // Calling dispose again is a safe no-op
      expect(() => bloomDisposeActiveMount(), returnsNormally);
    });
  });
}
