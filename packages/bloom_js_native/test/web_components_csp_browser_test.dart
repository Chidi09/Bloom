@TestOn('browser')
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('defineCustomElement works under nonce-only script CSP', () {
    const nonce = 'bloom-custom-element-csp-test';
    final policy = web.document.createElement('meta') as web.HTMLMetaElement;
    policy.httpEquiv = 'Content-Security-Policy';
    policy.content = "script-src 'self' 'nonce-$nonce'; object-src 'none'";
    web.document.head!.appendChild(policy);

    bloomScriptNonce = nonce;
    addTearDown(() => bloomScriptNonce = null);
    defineCustomElement(
      'bloom-nonce-policy-test',
      (_) => Span(text: 'CSP accepted'),
      useShadowDom: false,
    );

    final element = web.document.createElement('bloom-nonce-policy-test');
    web.document.body!.appendChild(element);
    addTearDown(() => element.remove());
    expect(element.textContent, 'CSP accepted');
  });
}
