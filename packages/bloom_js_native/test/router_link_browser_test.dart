@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

class _FakeNavigator implements BloomNavigator {
  @override
  final Signal<String> currentPath = signal('/');
  final List<String> navigations = [];
  final List<String> replacements = [];
  final List<String> fragments = [];

  @override
  Future<void> navigate(String path) async => navigations.add(path);

  @override
  Future<void> replace(String path) async => replacements.add(path);

  @override
  Future<void> navigateFragment(String fragment) async =>
      fragments.add(fragment);
}

/// Dispatches a cancelable click on [target] and reports whether Bloom
/// prevented it. The native default is always cancelled afterwards so the
/// test page never navigates away.
bool _click(web.Element target, {bool ctrlKey = false}) {
  var preventedByBloom = false;
  void guard(web.Event event) {
    preventedByBloom = event.defaultPrevented;
    event.preventDefault();
  }

  final listener = guard.toJS;
  web.document.addEventListener('click', listener);
  try {
    target.dispatchEvent(web.MouseEvent(
      'click',
      web.MouseEventInit(
        bubbles: true,
        cancelable: true,
        button: 0,
        ctrlKey: ctrlKey,
      ),
    ));
  } finally {
    web.document.removeEventListener('click', listener);
  }
  return preventedByBloom;
}

void main() {
  late web.HTMLDivElement container;
  late _FakeNavigator navigator;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body?.appendChild(container);
    navigator = _FakeNavigator();
  });

  tearDown(() => container.remove());

  test('left click navigates and prevents the native default', () {
    final handle = mountToElement(
      RouterLink(controller: navigator, href: '/next', text: 'Next'),
      container,
    );
    addTearDown(handle.dispose);
    final prevented = _click(container.querySelector('a')!);

    expect(navigator.navigations, ['/next']);
    expect(prevented, isTrue);
  });

  test('ctrl click is left to the browser', () {
    final handle = mountToElement(
      RouterLink(controller: navigator, href: '/next', text: 'Next'),
      container,
    );
    addTearDown(handle.dispose);
    final prevented = _click(container.querySelector('a')!, ctrlKey: true);

    expect(navigator.navigations, isEmpty);
    expect(prevented, isFalse);
  });

  test('replace and fragment links call their matching navigator methods', () {
    final handle = mountToElement(
      Div(children: [
        RouterLink(
          controller: navigator,
          href: '/replace',
          replace: true,
          text: 'Replace',
        ),
        RouterLink(
          controller: navigator,
          href: '#section',
          text: 'Section',
        ),
      ]),
      container,
    );
    addTearDown(handle.dispose);

    final anchors = container.querySelectorAll('a');
    _click(anchors.item(0)! as web.Element);
    _click(anchors.item(1)! as web.Element);

    expect(navigator.replacements, ['/replace']);
    expect(navigator.fragments, ['section']);
  });

  test('active class updates when the navigator path changes', () {
    final handle = mountToElement(
      RouterLink(
        controller: navigator,
        href: '/docs',
        activeClassName: 'active',
        text: 'Docs',
      ),
      container,
    );
    addTearDown(handle.dispose);
    final anchor = container.querySelector('a')!;

    expect(anchor.classList.contains('active'), isFalse);
    navigator.currentPath.value = '/docs/guide';
    expect(anchor.classList.contains('active'), isTrue);
    expect(anchor.getAttribute('aria-current'), 'page');
  });
}
