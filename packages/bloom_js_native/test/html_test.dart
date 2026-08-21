import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('renderToHtml', () {
    test('renders simple element', () {
      final html = renderToHtml(Div(className: 'foo', text: 'hello'));
      expect(html, '<div class="foo">hello</div>');
    });

    test('escapes text XSS', () {
      final html = renderToHtml(P(text: '<script>alert(1)</script>'));
      expect(html, '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>');
      expect(html, isNot(contains('<script>')));
    });

    test('escapes attribute XSS', () {
      final html = renderToHtml(Div(attrs: {'title': 'a"b&c'}));
      expect(html, contains('&quot;'));
      expect(html, contains('&amp;'));
    });

    test('void element without closing tag', () {
      final html = renderToHtml(Input(placeholder: 'hi'));
      expect(html, contains('<input'));
      expect(html, isNot(contains('</input>')));
    });

    test('nested children', () {
      final html = renderToHtml(Ul(children: [Li(text: 'a'), Li(text: 'b')]));
      expect(html, '<ul><li>a</li><li>b</li></ul>');
    });

    test('Fragment renders children without wrapper', () {
      final html = renderToHtml(Fragment(children: [P(text: 'a'), P(text: 'b')]));
      expect(html, '<p>a</p><p>b</p>');
    });

    test('Live evaluates builder', () {
      final count = signal(3);
      final node = Live(() => P(text: 'Count: ${count.value}'));
      expect(renderToHtml(node), '<p>Count: 3</p>');
      count.value = 7;
      expect(renderToHtml(node), '<p>Count: 7</p>');
    });

    test('Show renders child or fallback', () {
      final flag = signal(true);
      final node = Show(() => flag.value, child: P(text: 'yes'), fallback: P(text: 'no'));
      expect(renderToHtml(node), '<p>yes</p>');
      flag.value = false;
      expect(renderToHtml(node), '<p>no</p>');
    });

    test('Show without fallback renders empty when false', () {
      final node = Show(() => false, child: P(text: 'x'));
      expect(renderToHtml(node), '');
    });

    test('ForEach renders each item', () {
      final todos = signal(['a', 'b']);
      final node = ForEach(() => todos.value, (String t) => Li(text: t));
      expect(renderToHtml(node), '<li>a</li><li>b</li>');
    });

    test('ForEach empty list renders empty', () {
      final node = ForEach(() => <String>[], (String t) => Li(text: t));
      expect(renderToHtml(node), '');
    });

    test('Style node escapes css', () {
      final html = renderToHtml(Style('a{color:red}'));
      expect(html, '<style>a{color:red}</style>');
    });

    test('style attribute and className emitted', () {
      final html = renderToHtml(Div(className: 'foo', style: 'color:red', text: 'x'));
      expect(html, '<div class="foo" style="color:red">x</div>');
    });

    test('complex nested with Live + Show + ForEach', () {
      final count = signal(0);
      final items = signal([1, 2]);
      final tree = Fragment(children: [
        H1(text: 'Counter'),
        Live(() => P(text: 'Count: ${count.value}')),
        Show(() => count.value > 1, child: P(text: 'big'), fallback: P(text: 'small')),
        Ul(children: [
          ForEach(() => items.value, (int x) => Li(text: 'Item $x')),
        ]),
      ]);
      final html = renderToHtml(tree);
      expect(html, contains('<h1>Counter</h1>'));
      expect(html, contains('<p>Count: 0</p>'));
      expect(html, contains('<p>small</p>'));
      expect(html, contains('<li>Item 1</li>'));
    });

    test('escapeHtml handles all special chars', () {
      expect(escapeHtml('&<>"\'/'), '&amp;&lt;&gt;&quot;&#x27;/');
    });

    test('renderToHtmlAll concatenates', () {
      final html = renderToHtmlAll([P(text: 'a'), P(text: 'b')]);
      expect(html, '<p>a</p><p>b</p>');
    });
  });
}
