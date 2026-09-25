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

    test('rejects inline event-handler attributes', () {
      expect(
        () => renderToHtml(Div(attrs: {'onerror': 'alert(1)'})),
        throwsArgumentError,
      );
      expect(
        () => renderToHtml(Div(attrs: {'ONLOAD': 'alert(1)'})),
        throwsArgumentError,
      );
    });

    test('rejects executable URL schemes, including entity obfuscation', () {
      for (final value in [
        'javascript:alert(1)',
        ' java\nscript:alert(1)',
        'jav&#x61;script:alert(1)',
        'java&Tab;script&colon;alert(1)',
      ]) {
        expect(
          () => renderToHtml(A(attrs: {'href': value})),
          throwsArgumentError,
          reason: 'must reject $value',
        );
      }
      expect(
        () => renderToHtml(
            IFrame.raw(attrs: {'srcdoc': '<script>alert(1)</script>'})),
        throwsArgumentError,
      );
      expect(
        () =>
            renderToHtml(ElNode('object', attrs: {'data': 'javascript:run()'})),
        throwsArgumentError,
      );
    });

    test('allows normal URLs and base64 raster data images', () {
      expect(
        renderToHtml(A(attrs: {'href': 'https://example.com'})),
        '<a href="https://example.com"></a>',
      );
      expect(
        renderToHtml(Img(src: 'data:image/png;base64,AAAA')),
        '<img src="data:image/png;base64,AAAA">',
      );
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
      final html =
          renderToHtml(Fragment(children: [P(text: 'a'), P(text: 'b')]));
      expect(html, '<p>a</p><p>b</p>');
    });

    test('Live evaluates builder', () {
      final count = signal(3);
      final node = Live(() => P(text: 'Count: ${count.value}'));
      expect(renderToHtml(node),
          '<!--bloom:live--><p>Count: 3</p><!--/bloom:live-->');
      count.value = 7;
      expect(renderToHtml(node),
          '<!--bloom:live--><p>Count: 7</p><!--/bloom:live-->');
    });

    test('Show renders child or fallback', () {
      final flag = signal(true);
      final node = Show(() => flag.value,
          child: P(text: 'yes'), fallback: P(text: 'no'));
      expect(
          renderToHtml(node), '<!--bloom:show--><p>yes</p><!--/bloom:show-->');
      flag.value = false;
      expect(
          renderToHtml(node), '<!--bloom:show--><p>no</p><!--/bloom:show-->');
    });

    test('Show without fallback renders empty when false', () {
      final node = Show(() => false, child: P(text: 'x'));
      expect(renderToHtml(node), '<!--bloom:show--><!--/bloom:show-->');
    });

    test('ForEach renders each item', () {
      final todos = signal(['a', 'b']);
      final node = ForEach(() => todos.value, (String t) => Li(text: t));
      expect(renderToHtml(node),
          '<!--bloom:foreach--><li>a</li><li>b</li><!--/bloom:foreach-->');
    });

    test('ForEach empty list renders empty', () {
      final node = ForEach(() => <String>[], (String t) => Li(text: t));
      expect(renderToHtml(node), '<!--bloom:foreach--><!--/bloom:foreach-->');
    });

    test('Style node escapes css', () {
      final html = renderToHtml(Style('a{color:red}'));
      expect(html, '<style>a{color:red}</style>');
    });

    test('Style node neutralizes mixed-case HTML closing tags', () {
      final html = renderToHtml(Style('a{color:red}</STYLE><script>alert(1)'));
      expect(html, contains(r'<\/STYLE>'));
      expect(html, isNot(contains('</STYLE>')));
    });

    test('renderToDocument protects raw import-map JSON and script URLs', () {
      final html = renderToDocument(
        Div(text: 'app'),
        importMapJson: '{"evil":"</SCRIPT><script>alert(1)</script>"}',
      );
      expect(html, contains(r'\u003c/SCRIPT>'));
      expect(html, isNot(contains('</SCRIPT><script>alert(1)')));
      expect(
        () => renderToDocument(Div(), scripts: ['javascript:run()']),
        throwsArgumentError,
      );
    });

    test('style attribute and className emitted', () {
      final html =
          renderToHtml(Div(className: 'foo', style: 'color:red', text: 'x'));
      expect(html, '<div class="foo" style="color:red">x</div>');
    });

    test('complex nested with Live + Show + ForEach', () {
      final count = signal(0);
      final items = signal([1, 2]);
      final tree = Fragment(children: [
        H1(text: 'Counter'),
        Live(() => P(text: 'Count: ${count.value}')),
        Show(() => count.value > 1,
            child: P(text: 'big'), fallback: P(text: 'small')),
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

    test('Svg renders with viewBox', () {
      final html = renderToHtml(Svg(viewBox: '0 0 24 24', children: [
        SvgPath(d: 'M12 2L2 7l10 5 10-5-10-5z'),
      ]));
      expect(html,
          '<svg viewBox="0 0 24 24"><path d="M12 2L2 7l10 5 10-5-10-5z"></path></svg>');
    });

    test('SvgCircle renders cx cy r', () {
      final html = renderToHtml(SvgCircle(cx: 12, cy: 12, r: 5));
      expect(html, '<circle cx="12" cy="12" r="5"></circle>');
    });
  });

  group('renderToDocument', () {
    test('wraps body in full HTML shell', () {
      final html = renderToDocument(
        Div(text: 'hello'),
        title: 'My App',
        lang: 'en',
      );
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<html lang="en">'));
      expect(html, contains('<title>My App</title>'));
      expect(html, contains('<div>hello</div>'));
      expect(html, contains('</body>'));
      expect(html, contains('</html>'));
    });

    test('includes import map when provided', () {
      final html = renderToDocument(
        Div(),
        importMapJson: '{"imports":{"zod":"https://esm.sh/zod@3"}}',
      );
      expect(html, contains('<script type="importmap">'));
      expect(html, contains('"zod"'));
    });

    test('includes stylesheets', () {
      final html = renderToDocument(Div(), stylesheets: ['/app.css']);
      expect(html, contains('<link rel="stylesheet" href="/app.css">'));
    });

    test('includes head nodes', () {
      final html = renderToDocument(
        Div(),
        head: [
          ElNode('meta', attrs: {'name': 'description', 'content': 'test'})
        ],
      );
      expect(html, contains('<meta name="description" content="test">'));
    });
  });

  group('renderToStream', () {
    test('emits same content as renderToHtml', () async {
      final node = Div(children: [P(text: 'a'), P(text: 'b')]);
      final streamed = await renderToStream(node).join();
      expect(streamed, renderToHtml(node));
    });
  });
}
