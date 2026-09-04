@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:bloom_js_native/src/_signals_browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('Reflect.deleteProperty')
external bool _reflectDelete(JSAny target, String key);

void main() {
  late web.HTMLDivElement container;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body?.appendChild(container);
    bloomHotReloadTrackingEnabled = false;
    _reflectDelete(web.window as JSAny, '__bloom_signal_registry__');
    _reflectDelete(web.window as JSAny, '__bloomDisposeActiveMount');
    _reflectDelete(web.window as JSAny, '__bloomReportUnhandledError');
  });

  tearDown(() {
    bloomDisposeActiveMount();
    bloomHotReloadTrackingEnabled = false;
    _reflectDelete(web.window as JSAny, '__bloom_signal_registry__');
    _reflectDelete(web.window as JSAny, '__bloomDisposeActiveMount');
    _reflectDelete(web.window as JSAny, '__bloomReportUnhandledError');
    container.remove();
  });

  group('Signal Hot Reload State Carryover', () {
    test('with explicit key, signal value survives bloomDisposeActiveMount and remount', () {
      bloomHotReloadTrackingEnabled = true;

      // Mount version 1
      final count1 = signal(0, key: 'explicit-test-key');
      final app1 = Div(children: [
        H1(text: 'Counter App'),
        Live(() => P(text: 'Count: ${count1.value}')),
      ]);
      final handle1 = mountToElement(app1, container);

      expect(container.querySelector('p')?.textContent, 'Count: 0');

      // Increment count
      count1.value = 42;
      expect(container.querySelector('p')?.textContent, 'Count: 42');

      // Simulate hot remount: dispose active mount
      bloomDisposeActiveMount();
      expect(handle1.isDisposed, isTrue);
      expect(container.textContent, '');

      // Mount version 2 with a NEW signal instance using the same key
      final count2 = signal(0, key: 'explicit-test-key');
      expect(identical(count1, count2), isFalse, reason: 'Must create a fresh Signal instance');
      expect(count2.value, equals(42), reason: 'Value should be restored from registry');

      final app2 = Div(children: [
        H1(text: 'Counter App (Remounted)'),
        Live(() => P(text: 'Count: ${count2.value}')),
      ]);
      final handle2 = mountToElement(app2, container);
      addTearDown(handle2.dispose);

      expect(container.querySelector('h1')?.textContent, 'Counter App (Remounted)');
      expect(container.querySelector('p')?.textContent, 'Count: 42');
    });

    test('with auto-injected key format, signal value survives remount across new instances', () {
      bloomHotReloadTrackingEnabled = true;

      const autoKey = 'lib/main.dart#count#0';

      // First mount
      final count1 = signal(10, key: autoKey);
      final handle1 = mountToElement(
        Live(() => Span(text: 'Val: ${count1.value}')),
        container,
      );

      expect(container.textContent, 'Val: 10');

      // Mutate
      count1.value = 99;
      expect(container.textContent, 'Val: 99');

      // Teardown
      bloomDisposeActiveMount();
      expect(handle1.isDisposed, isTrue);

      // Second mount with fresh signal instance
      final count2 = signal(10, key: autoKey);
      expect(count2.value, equals(99));

      final handle2 = mountToElement(
        Live(() => Span(text: 'Val: ${count2.value}')),
        container,
      );
      addTearDown(handle2.dispose);

      expect(container.textContent, 'Val: 99');
    });

    test('safely falls back to fresh initialValue when type mismatch occurs at same key', () {
      bloomHotReloadTrackingEnabled = true;

      const key = 'lib/main.dart#typedField#0';

      // Version 1: int signal
      final numSignal = signal<int>(100, key: key);
      numSignal.value = 250;

      // Hot reload
      bloomDisposeActiveMount();

      // Version 2: developer edited the signal type to String at the same call site
      final strSignal = signal<String>('fresh-string-value', key: key);

      // Should not throw and should retain the new type's default value
      expect(strSignal.value, equals('fresh-string-value'));

      // New changes to string signal update registry
      strSignal.value = 'mutated-string';
      expect(strSignal.value, equals('mutated-string'));
    });

    test('with tracking disabled (default/production), signal values are not carried over', () {
      bloomHotReloadTrackingEnabled = false;

      const key = 'production-key';

      final sig1 = signal(5, key: key);
      sig1.value = 50;

      bloomDisposeActiveMount();

      final sig2 = signal(5, key: key);
      expect(sig2.value, equals(5), reason: 'Without hot-reload tracking, signal resets to initialValue');
    });
  });

  group('Signal Registry Eviction', () {
    test('registry is bounded: least-recently-used keys are evicted past the cap', () {
      bloomHotReloadTrackingEnabled = true;

      final cap = kMaxSignalRegistryEntries;

      // Fill the registry to the cap with distinct keys; each write stores
      // into the window-global registry.
      for (var i = 0; i < cap; i++) {
        signal(-1, key: 'evict-key-$i').value = i;
      }

      // Re-writing an existing key refreshes its recency instead of growing
      // the map, making 'evict-key-0' the most recently used entry.
      signal<int>(-1, key: 'evict-key-0').value = 1000;

      // One more store beyond the cap evicts the least-recently-used entry:
      // 'evict-key-1' ('evict-key-0' was just refreshed and must survive).
      signal(-1, key: 'evict-key-overflow').value = 0;

      expect(
        signal<int>(-1, key: 'evict-key-1').value,
        -1,
        reason: 'the least-recently-used key must have been evicted from the registry',
      );
      expect(
        signal<int>(-1, key: 'evict-key-0').value,
        1000,
        reason: 'recently written keys must survive eviction',
      );
    });
  });
}
