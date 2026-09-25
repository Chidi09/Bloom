@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:bloom_js_native/src/_signals_browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('Reflect.deleteProperty')
external bool _reflectDelete(JSAny target, String key);

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

void main() {
  late web.HTMLDivElement container;

  setUp(() {
    disposePreviousBrowserHotEffects();
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body?.appendChild(container);
    bloomHotReloadTrackingEnabled = false;
    _reflectDelete(web.window as JSAny, '__bloom_signal_registry__');
    _reflectDelete(web.window as JSAny, '__bloom_signal_scope_registry__');
    _reflectDelete(web.window as JSAny, '__bloom_signal_active_scopes__');
    _reflectDelete(web.window as JSAny, '__bloom_signal_scope_transition__');
    _reflectDelete(web.window as JSAny, '__bloom_hot_effect_registry__');
    _reflectDelete(web.window as JSAny, '__bloomDisposeHotEffects');
    _reflectDelete(web.window as JSAny, '__bloomPrepareHotEffects');
    _reflectDelete(web.window as JSAny, '__bloomDisposePreviousHotEffects');
    _reflectDelete(web.window as JSAny, '__bloomDisposeActiveMount');
    _reflectDelete(web.window as JSAny, '__bloomTryHotReplaceActiveMount');
    _reflectDelete(web.window as JSAny, '__bloomReportUnhandledError');
  });

  tearDown(() {
    bloomDisposeActiveMount();
    disposeBrowserHotEffects();
    bloomHotReloadTrackingEnabled = false;
    _reflectDelete(web.window as JSAny, '__bloom_signal_registry__');
    _reflectDelete(web.window as JSAny, '__bloom_signal_scope_registry__');
    _reflectDelete(web.window as JSAny, '__bloom_signal_active_scopes__');
    _reflectDelete(web.window as JSAny, '__bloom_signal_scope_transition__');
    _reflectDelete(web.window as JSAny, '__bloom_hot_effect_registry__');
    _reflectDelete(web.window as JSAny, '__bloomDisposeHotEffects');
    _reflectDelete(web.window as JSAny, '__bloomPrepareHotEffects');
    _reflectDelete(web.window as JSAny, '__bloomDisposePreviousHotEffects');
    _reflectDelete(web.window as JSAny, '__bloomDisposeActiveMount');
    _reflectDelete(web.window as JSAny, '__bloomTryHotReplaceActiveMount');
    _reflectDelete(web.window as JSAny, '__bloomReportUnhandledError');
    container.remove();
  });

  group('Signal Hot Reload State Carryover', () {
    test('signals created inside a Live builder keep their HMR scope', () {
      bloomHotReloadTrackingEnabled = true;
      BloomNode page() => Live(
            () {
              final count = signal(0, key: 'live-builder-count');
              return Button(
                text: 'Live count: ${count.value}',
                on: {'click': (_) => count.value++},
              );
            },
            hotReloadScopeId: 'live-builder-test',
          );

      final firstHandle = mountToElement(page(), container);
      final button = container.querySelector('button')!;
      button.dispatchEvent(web.MouseEvent('click'));
      expect(container.querySelector('button')?.textContent, 'Live count: 1');

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Live count: 1');
    });

    test('signals created inside a Memo builder keep their HMR scope', () {
      bloomHotReloadTrackingEnabled = true;
      final dependency = signal(0, key: 'memo-dependency');

      BloomNode page() => Memo<int>(
            () => dependency.value,
            (_) {
              final count = signal(0, key: 'memo-builder-count');
              return Button(
                text: 'Memo count: ${count.value}',
                on: {'click': (_) => count.value++},
              );
            },
            hotReloadScopeId: 'memo-builder-test',
          );

      final firstHandle = mountToElement(page(), container);
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Memo count: 1');
    });

    test('signals created inside a Memo dependency retain their HMR scope', () {
      bloomHotReloadTrackingEnabled = true;
      Signal<int>? localState;

      BloomNode page() => Memo<int>(
            () {
              localState = signal(0, key: 'memo-dependency-local');
              return localState!.value;
            },
            (value) => Button(
              text: 'Memo dependency: $value',
              on: {'click': (_) => localState!.value++},
            ),
            hotReloadScopeId: 'memo-dependency-test',
          );

      final firstHandle = mountToElement(page(), container);
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));
      expect(
          container.querySelector('button')?.textContent, 'Memo dependency: 1');

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();

      expect(
          container.querySelector('button')?.textContent, 'Memo dependency: 1');
    });

    test('signals created inside a Show predicate retain their HMR scope', () {
      bloomHotReloadTrackingEnabled = true;
      Signal<int>? localState;

      BloomNode page() => Show(
            () {
              localState = signal(0, key: 'show-predicate-local');
              return localState!.value > 0;
            },
            child: Live(
              () => Button(
                text: 'Shown: ${localState!.value}',
                on: {'click': (_) => localState!.value++},
              ),
            ),
            fallback: Button(
              text: 'Show it',
              on: {'click': (_) => localState!.value++},
            ),
            hotReloadScopeId: 'show-predicate-test',
          );

      final firstHandle = mountToElement(page(), container);
      expect(container.querySelector('button')?.textContent, 'Show it');
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));
      expect(container.querySelector('button')?.textContent, 'Shown: 1');

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Shown: 1');
    });

    test('event callbacks re-enter their keyed item signal scope', () {
      bloomHotReloadTrackingEnabled = true;
      final localStates = <int, Signal<int>>{};

      BloomNode page() => ForEach<int>(
            () => [1, 2],
            (item) => Button(
              className: 'item-$item',
              text: 'Item $item',
              on: {
                'click': (_) {
                  final count = signal(0, key: 'event-callback-count');
                  count.value++;
                  localStates[item] = count;
                },
              },
            ),
            key: (item) => item.toString(),
            hotReloadScopeId: 'event-callback-list',
          );

      final firstHandle = mountToElement(page(), container);
      container
          .querySelector('.item-1')!
          .dispatchEvent(web.MouseEvent('click'));
      expect(localStates[1]!.value, 1);

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      localStates.clear();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();

      container
          .querySelector('.item-1')!
          .dispatchEvent(web.MouseEvent('click'));
      container
          .querySelector('.item-2')!
          .dispatchEvent(web.MouseEvent('click'));
      expect(localStates[1]!.value, 2);
      expect(localStates[2]!.value, 1);
    });

    test('custom element event callbacks retain keyed item state', () async {
      bloomHotReloadTrackingEnabled = true;
      final localStates = <int, Signal<int>>{};

      BloomNode page() => ForEach<int>(
            () => [1, 2],
            (item) => customElement(
              'bloom-event-scope-test',
              waitForUpgrade: false,
              events: {
                'bloom-count': (_) {
                  final count = signal(0, key: 'custom-element-event-count');
                  count.value++;
                  localStates[item] = count;
                },
              },
            ),
            key: (item) => item.toString(),
            hotReloadScopeId: 'custom-element-event-list',
          );

      final firstHandle = mountToElement(page(), container);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final firstItems = container.querySelectorAll('bloom-event-scope-test');
      expect(firstItems.length, 2);
      firstItems.item(0)!.dispatchEvent(web.CustomEvent('bloom-count'));
      firstItems.item(0)!.dispatchEvent(web.CustomEvent('bloom-count'));
      firstItems.item(1)!.dispatchEvent(web.CustomEvent('bloom-count'));
      expect(localStates[1]!.value, 2);
      expect(localStates[2]!.value, 1);

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      localStates.clear();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final nextItems = container.querySelectorAll('bloom-event-scope-test');
      nextItems.item(0)!.dispatchEvent(web.CustomEvent('bloom-count'));
      nextItems.item(1)!.dispatchEvent(web.CustomEvent('bloom-count'));
      expect(localStates[1]!.value, 3);
      expect(localStates[2]!.value, 2);
    });

    test('hydrated Show predicates retain their HMR scope', () {
      bloomHotReloadTrackingEnabled = true;
      Signal<int>? localState;

      BloomNode page() => Show(
            () {
              localState = signal(0, key: 'hydrated-show-predicate-local');
              return localState!.value > 0;
            },
            child: Live(() => Button(
                  text: 'Shown: ${localState!.value}',
                  on: {'click': (_) => localState!.value++},
                )),
            fallback: Button(
              text: 'Show it',
              on: {'click': (_) => localState!.value++},
            ),
            hotReloadScopeId: 'hydrated-show-predicate-test',
          );

      container.innerHTML = renderToHtml(page()).toJS;
      final firstHandle = hydrateElement(page(), container);
      expect(container.querySelector('button')?.textContent, 'Show it');
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));
      expect(container.querySelector('button')?.textContent, 'Shown: 1');

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      container.innerHTML = renderToHtml(page()).toJS;
      final nextHandle = hydrateElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Shown: 1');
    });

    test('signals created inside keyed ForEach items retain their HMR scope',
        () {
      bloomHotReloadTrackingEnabled = true;
      Signal<int>? localState;

      BloomNode page() => ForEach<int>(
            () {
              localState = signal(0, key: 'foreach-items-local');
              final value = localState!.value;
              return [value, value + 1];
            },
            (item) => Button(
              text: '$item',
              on: {'click': (_) => localState!.value++},
            ),
            key: (item) => item.toString(),
            hotReloadScopeId: 'foreach-items-test',
          );

      final firstHandle = mountToElement(page(), container);
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));
      final buttonsAfterUpdate = container.querySelectorAll('button');
      expect(
        List.generate(
          buttonsAfterUpdate.length,
          (index) => buttonsAfterUpdate.item(index)?.textContent,
        ),
        ['1', '2'],
      );

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();

      final buttonsAfterRemount = container.querySelectorAll('button');
      expect(
        List.generate(
          buttonsAfterRemount.length,
          (index) => buttonsAfterRemount.item(index)?.textContent,
        ),
        ['1', '2'],
      );
    });

    test('async Suspense resolved builder retains its captured HMR scope',
        () async {
      bloomHotReloadTrackingEnabled = true;
      final resource = Completer<int>();

      BloomNode page() => Suspense<int>(
            resource: () => resource.future,
            fallback: P(text: 'Loading'),
            builder: (_) {
              final count = signal(0, key: 'suspense-resolved-count');
              return Button(
                text: 'Resolved: ${count.value}',
                on: {'click': (_) => count.value++},
              );
            },
            hotReloadScopeId: 'suspense-builder-test',
          );

      final firstHandle = mountToElement(page(), container);
      resource.complete(42);
      await Future<void>.delayed(Duration.zero);
      expect(container.querySelector('button')?.textContent, 'Resolved: 0');
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      await Future<void>.delayed(Duration.zero);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Resolved: 1');
    });

    test('lazy loader retains its captured HMR scope across remount', () async {
      bloomHotReloadTrackingEnabled = true;

      BloomNode page() => lazy(
            () async {
              final count = signal(0, key: 'lazy-loader-count');
              return Button(
                text: 'Lazy: ${count.value}',
                on: {'click': (_) => count.value++},
              );
            },
            fallback: P(text: 'Loading'),
            hotReloadScopeId: 'lazy-loader-test',
          );

      final firstHandle = mountToElement(page(), container);
      await Future<void>.delayed(Duration.zero);
      expect(container.querySelector('button')?.textContent, 'Lazy: 0');
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      await Future<void>.delayed(Duration.zero);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Lazy: 1');
    });

    test('async Suspense error builder retains its separate HMR scope',
        () async {
      bloomHotReloadTrackingEnabled = true;
      final resource = Completer<int>();

      BloomNode page() => Suspense<int>(
            resource: () => resource.future,
            fallback: P(text: 'Loading'),
            builder: (_) => P(text: 'Unexpected success'),
            errorBuilder: (error, stack) {
              final count = signal(0, key: 'suspense-error-count');
              return Button(
                text: 'Error: ${count.value}',
                on: {'click': (_) => count.value++},
              );
            },
            hotReloadScopeId: 'suspense-builder-test',
          );

      final firstHandle = mountToElement(page(), container);
      resource.completeError(StateError('failed'), StackTrace.current);
      await Future<void>.delayed(Duration.zero);
      expect(container.querySelector('button')?.textContent, 'Error: 0');
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      await Future<void>.delayed(Duration.zero);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Error: 1');
    });

    test('ErrorBoundary fallback retains its captured HMR scope', () {
      bloomHotReloadTrackingEnabled = true;
      BloomNode page() => ErrorBoundary(
            builder: () => throw StateError('broken'),
            fallback: (error, stack) {
              final count = signal(0, key: 'error-boundary-fallback-count');
              return Button(
                text: 'Recovered: ${count.value}',
                on: {'click': (_) => count.value++},
              );
            },
            hotReloadScopeId: 'error-boundary-test',
          );

      final firstHandle = mountToElement(page(), container);
      expect(container.querySelector('button')?.textContent, 'Recovered: 0');
      container.querySelector('button')!.dispatchEvent(web.MouseEvent('click'));

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      disposePreviousBrowserHotEffects();

      expect(container.querySelector('button')?.textContent, 'Recovered: 1');
    });

    test('Mount onMount signals retain their captured HMR scope', () async {
      bloomHotReloadTrackingEnabled = true;
      dynamic localSignal;

      BloomNode page() => Mount(
            P(text: 'mounted'),
            onMount: () {
              localSignal = signal(0, key: 'mount-on-mount-count');
            },
            hotReloadScopeId: 'mount-lifecycle-test',
          );

      final firstHandle = mountToElement(page(), container);
      await Future<void>.delayed(Duration.zero);
      localSignal.value = 7;

      prepareBrowserHotReloadEffects();
      firstHandle.dispose();
      final nextHandle = mountToElement(page(), container);
      addTearDown(nextHandle.dispose);
      await Future<void>.delayed(Duration.zero);
      disposePreviousBrowserHotEffects();

      expect(localSignal.value, 7);
    });

    test('effect callback signals retain their captured HMR scope', () {
      bloomHotReloadTrackingEnabled = true;
      dynamic localSignal;

      void installEffect() {
        effect(
          () {
            localSignal = signal(0, key: 'effect-local-count');
          },
          hotReloadScopeId: 'effect-callback-test',
        );
      }

      installEffect();
      localSignal.value = 9;
      prepareBrowserHotReloadEffects();
      installEffect();
      disposePreviousBrowserHotEffects();

      expect(localSignal.value, 9);
    });

    test('component boundaries patch in place and preserve sibling DOM', () {
      bloomHotReloadTrackingEnabled = true;

      final firstHandle = mountToElement(
        Div(children: [
          bloomHmrComponent('stable-card', () => Div(text: 'Before')),
          H1(text: 'Outside'),
        ]),
        container,
      );
      final appRoot = container.children.item(0)!;
      final cardRoot = appRoot.children.item(0)!;
      final outside = appRoot.children.item(1)!;

      final nextHandle = mountToElement(
        Div(children: [
          bloomHmrComponent('stable-card', () => Div(text: 'After')),
          H1(text: 'Outside'),
        ]),
        container,
      );

      expect(identical(nextHandle, firstHandle), isTrue);
      expect(identical(container.children.item(0), appRoot), isTrue);
      expect(identical(appRoot.children.item(0), cardRoot), isTrue);
      expect(identical(appRoot.children.item(1), outside), isTrue);
      expect(cardRoot.textContent, 'After');
      expect(outside.textContent, 'Outside');
    });

    test('incompatible component root is replaced without remounting siblings',
        () {
      bloomHotReloadTrackingEnabled = true;

      final handle = mountToElement(
        Div(children: [
          bloomHmrComponent('replace-root', () => Div(text: 'Before')),
          H1(text: 'Outside'),
        ]),
        container,
      );
      final appRoot = container.children.item(0)!;
      final oldCard = appRoot.children.item(0)!;
      final outside = appRoot.children.item(1)!;

      final updatedHandle = mountToElement(
        Div(children: [
          bloomHmrComponent('replace-root', () => El('section', text: 'After')),
          H1(text: 'Outside'),
        ]),
        container,
      );

      expect(identical(updatedHandle, handle), isTrue);
      expect(identical(appRoot.children.item(0), oldCard), isFalse);
      expect(appRoot.children.item(0)?.textContent, 'After');
      expect(identical(appRoot.children.item(1), outside), isTrue);
    });

    test('multi-root component updates within its boundary', () {
      bloomHotReloadTrackingEnabled = true;

      final firstHandle = mountToElement(
        Div(children: [
          bloomHmrComponent(
            'multi-root-card',
            () => Fragment(children: [
              P(text: 'Before one'),
              P(text: 'Before two'),
            ]),
          ),
          H1(text: 'Outside'),
        ]),
        container,
      );
      final appRoot = container.children.item(0)!;
      final outside = appRoot.querySelector('h1');
      final before = appRoot.querySelectorAll('p');
      expect(before.length, 2);

      final nextHandle = mountToElement(
        Div(children: [
          bloomHmrComponent(
            'multi-root-card',
            () => Fragment(children: [
              P(text: 'After one'),
              P(text: 'After two'),
              P(text: 'After three'),
            ]),
          ),
          H1(text: 'Outside'),
        ]),
        container,
      );

      final after = appRoot.querySelectorAll('p');
      expect(identical(nextHandle, firstHandle), isTrue);
      expect(after.length, 3);
      expect(after.item(0)?.textContent, 'After one');
      expect(after.item(1)?.textContent, 'After two');
      expect(after.item(2)?.textContent, 'After three');
      expect(identical(appRoot.querySelector('h1'), outside), isTrue);

      final singleRootHandle = mountToElement(
        Div(children: [
          bloomHmrComponent(
            'multi-root-card',
            () => El('section', text: 'Single root'),
          ),
          H1(text: 'Outside'),
        ]),
        container,
      );
      expect(identical(singleRootHandle, firstHandle), isTrue);
      expect(appRoot.querySelectorAll('p').length, 0);
      expect(appRoot.querySelector('section')?.textContent, 'Single root');
      expect(identical(appRoot.querySelector('h1'), outside), isTrue);
    });

    test('multi-root component mounted directly can hot update', () {
      bloomHotReloadTrackingEnabled = true;

      final firstHandle = mountToElement(
        bloomHmrComponent(
          'root-multi-component',
          () => Fragment(children: [P(text: 'Root one'), P(text: 'Root two')]),
        ),
        container,
      );
      final nextHandle = mountToElement(
        bloomHmrComponent(
          'root-multi-component',
          () => Fragment(children: [
            P(text: 'Updated one'),
            P(text: 'Updated two'),
            P(text: 'Updated three'),
          ]),
        ),
        container,
      );

      expect(identical(nextHandle, firstHandle), isTrue);
      expect(container.querySelectorAll('p').length, 3);
      expect(container.textContent, 'Updated oneUpdated twoUpdated three');
    });

    test('reactive component tree remounts locally and cleans old effects', () {
      bloomHotReloadTrackingEnabled = true;

      final oldValue = signal(1);
      final firstHandle = mountToElement(
        Div(children: [
          bloomHmrComponent(
            'reactive-card',
            () => Div(
                children: [Live(() => P(text: 'Value: ${oldValue.value}'))]),
          ),
          H1(text: 'Outside'),
        ]),
        container,
      );
      final appRoot = container.children.item(0)!;
      final oldCard = appRoot.children.item(0)!;
      final outside = appRoot.children.item(1)!;
      expect(container.querySelector('p')?.textContent, 'Value: 1');

      final newValue = signal(8);
      final nextHandle = mountToElement(
        Div(children: [
          bloomHmrComponent(
            'reactive-card',
            () => Div(
                children: [Live(() => P(text: 'Value: ${newValue.value}'))]),
          ),
          H1(text: 'Outside'),
        ]),
        container,
      );

      expect(firstHandle.isDisposed, isFalse);
      expect(identical(nextHandle, firstHandle), isTrue);
      expect(identical(appRoot.children.item(0), oldCard), isFalse);
      expect(identical(appRoot.children.item(1), outside), isTrue);
      expect(container.querySelector('p')?.textContent, 'Value: 8');
      oldValue.value = 2;
      expect(container.querySelector('p')?.textContent, 'Value: 8');
      newValue.value = 9;
      expect(container.querySelector('p')?.textContent, 'Value: 9');
    });

    test('hot remount disposal stops top-level effects observing old signals',
        () {
      bloomHotReloadTrackingEnabled = true;

      final source = signal(0);
      final seenValues = <int>[];
      final cleanup = effect(() => seenValues.add(source.value));

      expect(seenValues, [0]);
      expect(_reflectGet(web.window as JSAny, '__bloomDisposeHotEffects'),
          isNotNull);

      disposeBrowserHotEffects();
      source.value = 1;
      expect(seenValues, [0],
          reason: 'The previous module effect must stop before remount');

      // The cleanup returned to the caller remains safe after hot disposal.
      expect(cleanup, returnsNormally);
      cleanup();
    });

    test('postponed cleanup disposes old effects but keeps new module effects',
        () {
      bloomHotReloadTrackingEnabled = true;

      final oldSource = signal(0);
      final newSource = signal(10);
      final oldValues = <int>[];
      final newValues = <int>[];
      effect(() => oldValues.add(oldSource.value));
      prepareBrowserHotReloadEffects();
      effect(() => newValues.add(newSource.value));
      disposePreviousBrowserHotEffects();

      oldSource.value = 1;
      newSource.value = 11;
      expect(oldValues, [0]);
      expect(newValues, [10, 11]);
    });

    test(
        'with explicit key, signal value survives bloomDisposeActiveMount and remount',
        () {
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
      expect(identical(count1, count2), isFalse,
          reason: 'Must create a fresh Signal instance');
      expect(count2.value, equals(42),
          reason: 'Value should be restored from registry');

      final app2 = Div(children: [
        H1(text: 'Counter App (Remounted)'),
        Live(() => P(text: 'Count: ${count2.value}')),
      ]);
      final handle2 = mountToElement(app2, container);
      addTearDown(handle2.dispose);

      expect(container.querySelector('h1')?.textContent,
          'Counter App (Remounted)');
      expect(container.querySelector('p')?.textContent, 'Count: 42');
    });

    test(
        'with auto-injected key format, signal value survives remount across new instances',
        () {
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

    test(
        'safely falls back to fresh initialValue when type mismatch occurs at same key',
        () {
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

    test(
        'with tracking disabled (default/production), signal values are not carried over',
        () {
      bloomHotReloadTrackingEnabled = false;

      const key = 'production-key';

      final sig1 = signal(5, key: key);
      sig1.value = 50;

      bloomDisposeActiveMount();

      final sig2 = signal(5, key: key);
      expect(sig2.value, equals(5),
          reason: 'Without hot-reload tracking, signal resets to initialValue');
    });
  });

  group('Signal Registry Eviction', () {
    test(
        'registry is bounded: least-recently-used keys are evicted past the cap',
        () {
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
        reason:
            'the least-recently-used key must have been evicted from the registry',
      );
      expect(
        signal<int>(-1, key: 'evict-key-0').value,
        1000,
        reason: 'recently written keys must survive eviction',
      );
    });
  });

  test('removed keyed rows release their scoped hot-reload signal state', () {
    bloomHotReloadTrackingEnabled = true;
    final items = signal<List<int>>([1]);
    BloomNode page() => Div(children: [
          ForEach<int>(
            () => items.value,
            (item) {
              final count = signal(0, key: 'row-count');
              return Button(
                attrs: {'data-row': '$item'},
                text: '$item: ${count.value}',
                on: {'click': (_) => count.value++},
              );
            },
            key: (item) => '$item',
            hotReloadScopeId: 'removed-row-list',
          ),
        ]);

    final handle = mountToElement(page(), container);
    addTearDown(handle.dispose);
    final row = container.querySelector('button[data-row="1"]')!;
    row.dispatchEvent(web.MouseEvent('click'));
    expect(row.textContent, '1: 1');

    items.value = [];
    expect(container.querySelector('button[data-row="1"]'), isNull);
    items.value = [1];

    expect(
        container.querySelector('button[data-row="1"]')?.textContent, '1: 0');
  });
}
