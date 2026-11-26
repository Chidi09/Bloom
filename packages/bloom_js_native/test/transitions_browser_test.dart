@TestOn('browser')
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

const _transition = BloomAnimation(
  name: 'bloom-show-transition-test',
  duration: Duration(seconds: 1),
  keyframes: [
    BloomKeyframe(offset: 0, styles: {'opacity': '0'}),
    BloomKeyframe(offset: 1, styles: {'opacity': '1'}),
  ],
);

void main() {
  late web.HTMLDivElement container;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body?.appendChild(container);
  });

  tearDown(() {
    container.remove();
  });

  test('Show retains the exiting child until animationend', () {
    final visible = signal(true);
    final handle = mountToElement(
      Show(
        () => visible.value,
        child: Div(attrs: {'id': 'shown'}),
        exit: _transition,
      ),
      container,
    );
    addTearDown(handle.dispose);

    visible.value = false;
    final element = container.querySelector('#shown')!;
    expect(
        element.getAttribute('style'), contains('bloom-show-transition-test'));
    expect(element.parentNode, isNotNull);
    element.dispatchEvent(web.Event('animationend'));
    expect(container.querySelector('#shown'), isNull);
  });

  test('Show cancels exit removal when it becomes visible again', () {
    final visible = signal(true);
    final handle = mountToElement(
      Show(
        () => visible.value,
        child: Div(attrs: {'id': 'shown'}),
        exit: _transition,
      ),
      container,
    );
    addTearDown(handle.dispose);

    visible.value = false;
    final original = container.querySelector('#shown')!;
    visible.value = true;
    expect(container.querySelector('#shown'), equals(original));
    expect(original.getAttribute('style'), isNull);
  });

  test('Show plays enter animation on a subsequent show', () {
    final visible = signal(false);
    final handle = mountToElement(
      Show(
        () => visible.value,
        child: Div(attrs: {'id': 'shown'}),
        enter: _transition,
      ),
      container,
    );
    addTearDown(handle.dispose);

    visible.value = true;
    expect(
      container.querySelector('#shown')!.getAttribute('style'),
      contains('bloom-show-transition-test'),
    );
  });

  test('Show does not play enter animation on initial render', () {
    final handle = mountToElement(
      Show(
        () => true,
        child: Div(attrs: {'id': 'shown'}),
        enter: _transition,
      ),
      container,
    );
    addTearDown(handle.dispose);
    expect(container.querySelector('#shown')!.getAttribute('style'), isNull);
  });

  test('Reveal starts hidden and is cleaned up on unmount', () {
    final handle = mountToElement(
      Reveal(child: Div(attrs: {'id': 'reveal'})),
      container,
    );
    final element = container.querySelector('#reveal')!.parentElement!;
    expect(element.classList.contains('bloom-reveal'), isTrue);
    handle.dispose();
    expect(container.children.length, 0);
  });

  test('Reveal adds the visible class once the child is in the viewport',
      () async {
    final handle = mountToElement(
      Reveal(child: Div(attrs: {'id': 'in-view'}, text: 'Hello')),
      container,
    );
    addTearDown(handle.dispose);

    final wrapper = container.firstElementChild!;
    for (var i = 0; i < 40 && !wrapper.classList.contains('is-visible'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(wrapper.classList.contains('is-visible'), isTrue);
  });
}
