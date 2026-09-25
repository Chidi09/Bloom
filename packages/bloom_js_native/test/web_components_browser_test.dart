@TestOn('browser')
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('defineCustomElement registers and mounts with a script nonce', () {
    bloomScriptNonce = 'registration-test-nonce';
    addTearDown(() => bloomScriptNonce = null);

    defineCustomElement(
      'bloom-csp-registration-test',
      (_) => Span(text: 'registered'),
      useShadowDom: false,
      observedAttributes: const ['data-label'],
    );

    expect(web.window.customElements.get('bloom-csp-registration-test'),
        isNotNull);
    final element = web.document.createElement('bloom-csp-registration-test');
    web.document.body!.appendChild(element);
    addTearDown(() => element.remove());
    expect(element.textContent, 'registered');
  });

  test('defineCustomElement rejects invalid tag names before registration', () {
    expect(
      () => defineCustomElement('bad-tag\');alert(1)//', (_) => Div()),
      throwsArgumentError,
    );
  });

  test('distinct tag names retain separate lifecycle bridges', () {
    defineCustomElement('bloom-bridge-a-b', (_) => Span(text: 'first'),
        useShadowDom: false);
    defineCustomElement('bloom-bridge-a_b', (_) => Span(text: 'second'),
        useShadowDom: false);

    final first = web.document.createElement('bloom-bridge-a-b');
    final second = web.document.createElement('bloom-bridge-a_b');
    web.document.body!.appendChild(first);
    web.document.body!.appendChild(second);
    addTearDown(() {
      first.remove();
      second.remove();
    });

    expect(first.textContent, 'first');
    expect(second.textContent, 'second');
  });

  test('custom elements reuse their shadow root after reconnecting', () {
    defineCustomElement(
      'bloom-reconnect-shadow-test',
      (_) => Span(text: 'connected'),
    );

    final element = web.document.createElement('bloom-reconnect-shadow-test');
    web.document.body!.appendChild(element);
    final shadowRoot = element.shadowRoot!;
    expect(shadowRoot.textContent, 'connected');

    element.remove();
    web.document.body!.appendChild(element);

    expect(identical(element.shadowRoot, shadowRoot), isTrue);
    expect(shadowRoot.textContent, 'connected');
    expect(shadowRoot.querySelectorAll('[data-bloom-shadow-root]').length, 1);
    addTearDown(() => element.remove());
  });

  test('custom element registrations refresh their builder during HMR', () {
    bloomHotReloadTrackingEnabled = true;
    final tagName = 'bloom-hmr-builder-test';
    defineCustomElement(tagName, (_) => Span(text: 'Version 1'));
    final element = web.document.createElement(tagName);
    web.document.body!.appendChild(element);

    try {
      expect(element.shadowRoot?.textContent, 'Version 1');
      defineCustomElement(tagName, (_) => Span(text: 'Version 2'));
      expect(element.shadowRoot?.textContent, 'Version 2');
    } finally {
      element.remove();
      bloomDisposeActiveMount();
      bloomHotReloadTrackingEnabled = false;
    }
  });

  test('duplicate registration does not replace the original bridge', () {
    defineCustomElement('bloom-bridge-duplicate', (_) => Span(text: 'first'),
        useShadowDom: false);
    defineCustomElement('bloom-bridge-duplicate', (_) => Span(text: 'second'),
        useShadowDom: false);

    final element = web.document.createElement('bloom-bridge-duplicate');
    web.document.body!.appendChild(element);
    addTearDown(() => element.remove());
    expect(element.textContent, 'first');
  });
}
