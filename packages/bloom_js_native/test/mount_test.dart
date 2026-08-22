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
    web.document.body?.appendChild(container);
  });

  tearDown(() {
    container.remove();
  });

  group('mountToElement DOM rendering', () {
    test('plain ElNode renders the right tag, class, style, attrs, text', () {
      final node = ElNode(
        'button',
        text: 'Click me',
        className: 'btn primary',
        style: 'color: red;',
        attrs: {'data-id': '123', 'type': 'submit'},
      );

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      expect(container.children.length, 1);
      final el = container.firstElementChild as web.HTMLButtonElement;
      expect(el.tagName.toLowerCase(), 'button');
      expect(el.className, 'btn primary');
      expect(el.getAttribute('style'), 'color: red;');
      expect(el.getAttribute('data-id'), '123');
      expect(el.getAttribute('type'), 'submit');
      expect(el.textContent, 'Click me');
    });

    test('nested children render in order', () {
      final node = Div(children: [
        H1(text: 'Title'),
        P(text: 'Paragraph 1'),
        Span(text: 'Span 1'),
      ]);

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final div = container.firstElementChild as web.HTMLElement;
      expect(div.tagName.toLowerCase(), 'div');
      expect(div.children.length, 3);
      expect((div.children.item(0)! as web.HTMLElement).tagName.toLowerCase(), 'h1');
      expect(div.children.item(0)!.textContent, 'Title');
      expect((div.children.item(1)! as web.HTMLElement).tagName.toLowerCase(), 'p');
      expect(div.children.item(1)!.textContent, 'Paragraph 1');
      expect((div.children.item(2)! as web.HTMLElement).tagName.toLowerCase(), 'span');
      expect(div.children.item(2)!.textContent, 'Span 1');
    });

    test('Fragment renders children without a wrapper element', () {
      final node = Fragment(children: [
        Span(text: 'A'),
        Span(text: 'B'),
        Span(text: 'C'),
      ]);

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      expect(container.children.length, 3);
      expect(container.children.item(0)!.textContent, 'A');
      expect(container.children.item(1)!.textContent, 'B');
      expect(container.children.item(2)!.textContent, 'C');
    });

    test('Live region updates its DOM when its signal changes', () {
      final count = signal(0);
      final node = Live(() => P(text: 'Count: ${count.value}'));

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final p = container.querySelector('p')!;
      expect(p.textContent, 'Count: 0');

      count.value = 42;
      final updatedP = container.querySelector('p')!;
      expect(updatedP.textContent, 'Count: 42');
    });

    test('Show node swaps between child and fallback', () {
      final condition = signal(true);
      final node = Show(
        () => condition.value,
        child: Div(className: 'active', text: 'Online'),
        fallback: Div(className: 'inactive', text: 'Offline'),
      );

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      var div = container.querySelector('div')!;
      expect(div.className, 'active');
      expect(div.textContent, 'Online');

      condition.value = false;
      div = container.querySelector('div')!;
      expect(div.className, 'inactive');
      expect(div.textContent, 'Offline');

      condition.value = true;
      div = container.querySelector('div')!;
      expect(div.className, 'active');
      expect(div.textContent, 'Online');
    });

    test('keyed ForEach: items reorder, insert, and delete correctly', () {
      final items = signal([
        {'id': '1', 'name': 'Item 1'},
        {'id': '2', 'name': 'Item 2'},
        {'id': '3', 'name': 'Item 3'},
      ]);

      final node = Ul(children: [
        ForEach<Map<String, String>>(
          () => items.value,
          (item) => Li(attrs: {'data-id': item['id']!}, text: item['name']!),
          key: (item) => item['id']!,
        ),
      ]);

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final ul = container.querySelector('ul')!;
      var lis = ul.querySelectorAll('li');
      expect(lis.length, 3);
      expect(lis.item(0)!.textContent, 'Item 1');
      expect(lis.item(1)!.textContent, 'Item 2');
      expect(lis.item(2)!.textContent, 'Item 3');

      // Reorder & Delete: 3, 1 (remove 2)
      items.value = [
        {'id': '3', 'name': 'Item 3'},
        {'id': '1', 'name': 'Item 1'},
      ];

      lis = ul.querySelectorAll('li');
      expect(lis.length, 2);
      expect((lis.item(0)! as web.Element).getAttribute('data-id'), '3');
      expect((lis.item(1)! as web.Element).getAttribute('data-id'), '1');

      // Insert 4 in middle: 3, 4, 1
      items.value = [
        {'id': '3', 'name': 'Item 3'},
        {'id': '4', 'name': 'Item 4'},
        {'id': '1', 'name': 'Item 1'},
      ];

      lis = ul.querySelectorAll('li');
      expect(lis.length, 3);
      expect((lis.item(0)! as web.Element).getAttribute('data-id'), '3');
      expect((lis.item(1)! as web.Element).getAttribute('data-id'), '4');
      expect((lis.item(2)! as web.Element).getAttribute('data-id'), '1');
    });

    test('REGRESSION TEST FOR STAGE 1: on a keyed ForEach reorder/update where key is unchanged, retains exact DOM element instance', () {
      final items = signal([
        {'id': 'a', 'title': 'Alpha'},
        {'id': 'b', 'title': 'Beta'},
      ]);

      final node = Div(children: [
        ForEach<Map<String, String>>(
          () => items.value,
          (item) => Div(attrs: {'data-id': item['id']!}, text: item['title']!),
          key: (item) => item['id']!,
        ),
      ]);

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final initialDivA = container.querySelector('[data-id="a"]') as web.HTMLDivElement;
      final initialDivB = container.querySelector('[data-id="b"]') as web.HTMLDivElement;
      expect(initialDivA, isNotNull);
      expect(initialDivB, isNotNull);

      // Reorder items and update text of 'a' and 'b'
      items.value = [
        {'id': 'b', 'title': 'Beta Updated'},
        {'id': 'a', 'title': 'Alpha Updated'},
      ];

      final afterDivA = container.querySelector('[data-id="a"]') as web.HTMLDivElement;
      final afterDivB = container.querySelector('[data-id="b"]') as web.HTMLDivElement;

      // Identity equality check: the DOM element instances MUST be identical
      expect(identical(afterDivA, initialDivA), isTrue);
      expect(identical(afterDivB, initialDivB), isTrue);

      // Content was patched in place
      expect(afterDivA.textContent, 'Alpha Updated');
      expect(afterDivB.textContent, 'Beta Updated');

      // Order was updated
      final divChildren = container.querySelector('div')!.querySelectorAll('[data-id]');
      expect((divChildren.item(0)! as web.Element).getAttribute('data-id'), 'b');
      expect((divChildren.item(1)! as web.Element).getAttribute('data-id'), 'a');
    });

    test('REGRESSION TEST: focus is retained in a text input across a reactive update of the region containing it', () {
      final textValue = signal('hello');
      final otherSignal = signal(0);

      final node = Live(() {
        final _ = otherSignal.value;
        return Div(children: [
          Input(attrs: {'id': 'my-input', 'value': textValue.value}),
          Span(text: 'Other: ${otherSignal.value}'),
        ]);
      });

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final input = container.querySelector('#my-input') as web.HTMLInputElement;
      input.focus();
      input.setSelectionRange(2, 4);

      expect(web.document.activeElement, equals(input));

      // Trigger rebuild
      otherSignal.value = 1;

      final activeEl = web.document.activeElement;
      expect(activeEl, isNotNull);
      expect(activeEl!.getAttribute('id'), 'my-input');
    });

    test('Stage 2 Memo: only re-evaluates when dependency value changes', () {
      var builderCallCount = 0;
      final dep = signal(1);
      final unrelated = signal('foo');

      final node = Memo(
        () => dep.value,
        (val) {
          builderCallCount++;
          final _ = unrelated.value;
          return Div(className: 'memo-box', text: 'Val: $val');
        },
      );

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      expect(builderCallCount, 1);
      final div = container.querySelector('.memo-box')!;
      expect(div.textContent, 'Val: 1');

      // Changing dependency triggers builder and updates DOM
      dep.value = 2;
      expect(builderCallCount, 2);
      expect(div.textContent, 'Val: 2');

      final initialDiv = container.querySelector('.memo-box')!;

      // Updating dependency again to 3
      dep.value = 3;
      expect(builderCallCount, 3);
      final updatedDiv = container.querySelector('.memo-box')!;
      expect(identical(updatedDiv, initialDiv), isTrue);
      expect(updatedDiv.textContent, 'Val: 3');
    });

    test('patching an element containing a nested Live does not duplicate DOM', () {
      final items = signal([
        {'id': 'a', 'title': 'Alpha'},
      ]);
      final counter = signal(0);

      final node = Div(children: [
        ForEach<Map<String, String>>(
          () => items.value,
          (item) => Div(attrs: {'data-id': item['id']!}, children: [
            Span(text: item['title']!),
            Live(() => Span(attrs: {'data-c': '1'}, text: '${counter.value}')),
          ]),
          key: (item) => item['id']!,
        ),
      ]);

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      expect(container.querySelectorAll('[data-c]').length, 1,
          reason: 'baseline: exactly one live span');

      // Patch the outer Div (key unchanged, title changed). A reactive child
      // mounts to a sentinel comment pair plus content — several DOM nodes for
      // one descriptor — so index-aligned child patching must NOT be attempted
      // here, or the old region is orphaned and its nodes duplicated.
      items.value = [
        {'id': 'a', 'title': 'Alpha Updated'},
      ];

      expect(container.querySelectorAll('[data-c]').length, 1,
          reason: 'after patch there must still be exactly ONE live span');

      // The live region must still be reactive — its effect not leaked.
      counter.value = 42;
      final live = container.querySelectorAll('[data-c]');
      expect(live.length, 1);
      expect((live.item(0)! as web.Element).textContent, '42',
          reason: 'nested Live still reacts after its parent was patched');
    });

    test('keyed item WITH an event handler retains its DOM element', () {
      final items = signal([
        {'id': 'a', 'title': 'Alpha'},
      ]);

      final node = Div(children: [
        ForEach<Map<String, String>>(
          () => items.value,
          // A fresh closure every build — the realistic case for any
          // interactive list.
          (item) => Div(
            attrs: {'data-id': item['id']!},
            text: item['title']!,
            on: {'click': (e) {}},
          ),
          key: (item) => item['id']!,
        ),
      ]);

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final before = container.querySelector('[data-id="a"]')!;
      items.value = [
        {'id': 'a', 'title': 'Alpha Updated'},
      ];
      final after = container.querySelector('[data-id="a"]')!;

      expect(after.textContent, 'Alpha Updated');
      expect(identical(after, before), isTrue);
    });

    test('patched element fires only the NEWEST handler, exactly once', () {
      final items = signal([
        {'id': 'a', 'n': '1'},
      ]);
      final fired = <String>[];

      final node = Div(children: [
        ForEach<Map<String, String>>(
          () => items.value,
          (item) => Div(
            attrs: {'data-id': item['id']!},
            text: 'n=${item['n']}',
            // Fresh closure each build, capturing that build's value.
            on: {'click': (e) => fired.add(item['n']!)},
          ),
          key: (item) => item['id']!,
        ),
      ]);

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      // Re-render twice; the element is patched in place each time.
      items.value = [
        {'id': 'a', 'n': '2'},
      ];
      items.value = [
        {'id': 'a', 'n': '3'},
      ];

      (container.querySelector('[data-id="a"]')! as web.HTMLElement).click();

      expect(fired, ['3'],
          reason: 'stale handlers must not fire, and the live one exactly once');
    });

    test('a typed Suspense<T> resolves in the browser', () async {
      final node = Suspense<String>(
        resource: () async => 'loaded',
        builder: (data) => Div(attrs: {'data-loaded': '1'}, text: data),
        fallback: Div(attrs: {'data-spinner': '1'}, text: 'loading'),
      );

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      expect(container.querySelectorAll('[data-spinner]').length, 1);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Regression: reading `resource`/`builder` off a `case SuspenseNode():`
      // match casts them to `Function(dynamic)`, which throws for any concrete
      // `T` — function parameters are contravariant. This threw a TypeError
      // for every typed Suspense before the erased-view accessors landed.
      final loaded = container.querySelectorAll('[data-loaded]');
      expect(loaded.length, 1);
      expect((loaded.item(0)! as web.Element).textContent, 'loaded');
    });

    test('an event dropped from the descriptor stops firing after a patch', () {
      final withHandler = signal(true);
      final fired = <String>[];

      final node = Div(children: [
        ForEach<Map<String, String>>(
          () => [
            {'id': 'a'}
          ],
          (item) => Div(
            attrs: {'data-id': item['id']!},
            text: withHandler.value ? 'on' : 'off',
            on: withHandler.value ? {'click': (e) => fired.add('hit')} : null,
          ),
          key: (item) => item['id']!,
        ),
      ]);

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final el = container.querySelector('[data-id="a"]')! as web.HTMLElement;
      el.click();
      expect(fired, ['hit'], reason: 'baseline: handler is wired');

      withHandler.value = false;
      (container.querySelector('[data-id="a"]')! as web.HTMLElement).click();

      expect(fired, ['hit'],
          reason: 'removed handler must not fire after the patch');
    });
  });
}
