@TestOn('browser')
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLDivElement container;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.appendChild(container);
  });
  tearDown(() => container.remove());

  test('update-time throw with NO boundary does not escape to caller',
      () {
    final blowUp = signal(false);
    final handle = mountToElement(
      Live(() {
        if (blowUp.value) throw StateError('unbounded boom');
        return Div(text: 'ok');
      }),
      container,
    );
    addTearDown(handle.dispose);

    // No ErrorBoundary anywhere. The throw must be reported, not propagated
    // back into this assignment.
    var reached = false;
    blowUp.value = true;
    reached = true;

    expect(reached, isTrue,
        reason: 'an unbounded render error must not poison the signal write');
  });

  test('a fallback that itself throws does not recurse infinitely', () {
    final blowUp = signal(false);
    final node = ErrorBoundary(
      builder: () => Live(() {
        if (blowUp.value) throw StateError('primary');
        return Div(text: 'ok');
      }),
      fallback: (e, s) => throw StateError('fallback also broke'),
    );
    final handle = mountToElement(node, container);
    addTearDown(handle.dispose);

    var reached = false;
    blowUp.value = true;
    reached = true;

    expect(reached, isTrue, reason: 'must terminate, not stack-overflow');
  });

  test('inner boundary catches; outer one is left alone', () {
    final blowUp = signal(false);
    final node = ErrorBoundary(
      builder: () => Div(attrs: {'data-outer': '1'}, children: [
        ErrorBoundary(
          builder: () => Live(() {
            if (blowUp.value) throw StateError('inner boom');
            return Div(text: 'ok');
          }),
          fallback: (e, s) => Div(attrs: {'data-inner-fb': '1'}, text: 'inner'),
        ),
      ]),
      fallback: (e, s) => Div(attrs: {'data-outer-fb': '1'}, text: 'outer'),
    );
    final handle = mountToElement(node, container);
    addTearDown(handle.dispose);

    blowUp.value = true;

    expect(container.querySelectorAll('[data-inner-fb]').length, 1,
        reason: 'nearest boundary handles it');
    expect(container.querySelectorAll('[data-outer-fb]').length, 0,
        reason: 'outer boundary must NOT be triggered');
    expect(container.querySelectorAll('[data-outer]').length, 1,
        reason: 'outer content must survive intact');
  });

  test('Suspense with NO errorBuilder falls through to the boundary',
      () async {
    final node = ErrorBoundary(
      builder: () => Suspense<String>(
        resource: () => Future<String>.error(StateError('load failed')),
        builder: (data) => Div(text: data),
        fallback: Div(attrs: {'data-spinner': '1'}, text: 'loading'),
      ),
      fallback: (e, s) => Div(attrs: {'data-fb': '1'}, text: 'caught'),
    );
    final handle = mountToElement(node, container);
    addTearDown(handle.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(container.querySelectorAll('[data-fb]').length, 1,
        reason: 'boundary should catch a rejected resource with no errorBuilder');
  });

  test('a throw while rendering RESOLVED Suspense data is caught',
      () async {
    final node = ErrorBoundary(
      builder: () => Suspense<String>(
        resource: () async => 'data',
        builder: (d) => throw StateError('builder broke'),
        fallback: Div(text: 'loading'),
      ),
      fallback: (e, s) => Div(attrs: {'data-fb': '1'}, text: 'caught'),
    );
    final handle = mountToElement(node, container);
    addTearDown(handle.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(container.querySelectorAll('[data-fb]').length, 1);
  });

  test('a throw inside a keyed ForEach item builder is caught', () {
    final items = signal([
      {'id': 'a'}
    ]);
    final boom = signal(false);
    final node = ErrorBoundary(
      builder: () => Div(children: [
        ForEach<Map<String, String>>(
          () => items.value,
          (item) {
            if (boom.value) throw StateError('item boom');
            return Div(attrs: {'data-id': item['id']!}, text: item['id']!);
          },
          key: (item) => item['id']!,
        ),
      ]),
      fallback: (e, s) => Div(attrs: {'data-fb': '1'}, text: 'caught'),
    );
    final handle = mountToElement(node, container);
    addTearDown(handle.dispose);

    var reached = false;
    boom.value = true;
    reached = true;

    expect(reached, isTrue, reason: 'must not escape the signal write');
    expect(container.querySelectorAll('[data-fb]').length, 1,
        reason: 'ForEach builder throw should reach the boundary');
  });

  test('ErrorBoundary renders its fallback for an update-time throw', () {
    final blowUp = signal(false);

    final node = ErrorBoundary(
      builder: () => Live(() {
        if (blowUp.value) throw StateError('render exploded');
        return Div(text: 'ok');
      }),
      fallback: (e, s) => Div(attrs: {'data-fallback': '1'}, text: 'caught'),
    );

    final handle = mountToElement(node, container);
    addTearDown(handle.dispose);
    expect(container.textContent, contains('ok'));

    blowUp.value = true;

    expect(container.querySelectorAll('[data-fallback]').length, 1);
  });

  test('Suspense renders errorBuilder for a rejected resource', () async {
    final node = Suspense<String>(
      resource: () => Future<String>.error(StateError('load failed')),
      builder: (data) => Div(text: data),
      fallback: Div(attrs: {'data-spinner': '1'}, text: 'loading'),
      errorBuilder: (e, s) => Div(attrs: {'data-err': '1'}, text: 'failed'),
    );

    final handle = mountToElement(node, container);
    addTearDown(handle.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(container.querySelectorAll('[data-spinner]').length, 0);
    expect(container.querySelectorAll('[data-err]').length, 1);
  });

  test('bloomStyleNonce is applied to injected style elements', () {
    bloomStyleNonce = 'test-nonce-123';
    addTearDown(() => bloomStyleNonce = null);

    final handle = mountToElement(Style('.x{color:red}'), container);
    addTearDown(handle.dispose);

    final styleEl = container.querySelector('style');
    expect(styleEl, isNotNull);
    expect(styleEl!.getAttribute('nonce'), 'test-nonce-123');
  });
}
