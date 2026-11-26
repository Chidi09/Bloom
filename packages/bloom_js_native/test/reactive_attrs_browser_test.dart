@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLDivElement container;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body?.appendChild(container);
  });

  tearDown(() => container.remove());

  test('updates reactive attrs and classes in place and keeps focus', () {
    final open = signal(false);
    final value = signal('before');
    final handle = mountToElement(
      Input.raw(
        className: 'field',
        reactiveAttrs: {
          'aria-expanded': () => open.value,
          'disabled': () => open.value,
          'value': () => value.value,
        },
        classIf: {'is-open': () => open.value},
      ),
      container,
    );
    addTearDown(handle.dispose);

    final input = container.firstElementChild as web.HTMLInputElement;
    expect(input.getAttribute('aria-expanded'), 'false');
    expect(input.value, 'before');
    input.focus();
    open.value = true;
    value.value = 'after';

    expect(container.firstElementChild, equals(input));
    expect(input.className, 'field is-open');
    expect(input.getAttribute('aria-expanded'), 'true');
    expect(input.hasAttribute('disabled'), isTrue);
    expect(input.value, 'after');
    expect(web.document.activeElement, equals(input));

    handle.dispose();
    expect(() => open.value = false, returnsNormally);
  });

  test('reactive fields inside Live update in place without rebuilding it', () {
    final active = signal(false);
    var builds = 0;
    final handle = mountToElement(
      Live(() {
        builds++;
        return Div(
          className: 'tab',
          classIf: {'active': () => active.value},
          reactiveAttrs: {'aria-selected': () => active.value},
        );
      }),
      container,
    );
    addTearDown(handle.dispose);

    final tab = container.querySelector('.tab')!;
    active.value = true;

    expect(builds, 1);
    expect(container.querySelector('.tab'), equals(tab));
    expect(tab.className, 'tab active');
    expect(tab.getAttribute('aria-selected'), 'true');
  });

  test('mountApp mounts empty containers and hydrates rendered content', () {
    final empty = web.document.createElement('div') as web.HTMLDivElement;
    empty.id = 'empty-app';
    web.document.body?.appendChild(empty);
    addTearDown(() => empty.remove());
    final mounted = mountApp(Div(text: 'mounted'), '#empty-app');
    expect(empty.textContent, 'mounted');
    mounted.dispose();
  });

  test('mountApp hydrates server rendered content without duplication', () {
    final span = web.document.createElement('span');
    span.textContent = 'hello';
    container.appendChild(span);
    final handle = mountApp(Span(text: 'hello'), 'div');
    addTearDown(handle.dispose);
    expect(container.children.length, 1);
    expect(container.textContent, 'hello');
  });

  test('hydration binds reactive attributes to adopted SSR elements', () {
    final open = signal(false);
    final tree = Button(
      text: 'Menu',
      reactiveAttrs: {'aria-expanded': () => open.value},
      classIf: {'is-open': () => open.value},
    );
    container.innerHTML = renderToHtml(tree).toJS;
    final before = container.querySelector('button');
    final handle = hydrateElement(tree, container);
    addTearDown(handle.dispose);

    open.value = true;
    expect(container.querySelector('button'), equals(before));
    expect(before!.getAttribute('aria-expanded'), 'true');
    expect(before.className, 'is-open');
  });

  test('reactive nodes mounted in svg retain their namespace after updates',
      () {
    final n = signal(1);
    final handle = mountToElement(
      Svg(children: [
        Live(() => El('path', attrs: {'d': 'M0 0L${n.value} 1'})),
      ]),
      container,
    );
    addTearDown(handle.dispose);
    n.value = 2;
    final path = container.querySelector('path')!;
    expect(path.namespaceURI, 'http://www.w3.org/2000/svg');
  });
}
