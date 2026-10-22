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

    test('head descriptors render no body HTML', () {
      expect(
        renderToHtml(Fragment(children: const [
          Title('Page title'),
          Meta(name: 'description', content: 'A page'),
          HeadLink(rel: 'icon', href: '/favicon.ico'),
        ])),
        isEmpty,
      );
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

    test('serializes reactive classes and attributes', () {
      final html = renderToHtml(ElNode(
        'button',
        className: 'base same',
        attrs: {'title': 'static', 'data-live': 'old'},
        reactiveClass: () => 'extra same',
        classIf: {'active': () => true, 'hidden': () => false},
        reactiveAttrs: {
          'aria-expanded': () => false,
          'disabled': () => true,
          'hidden': () => false,
          'title': () => null,
          'data-live': () => 'new',
        },
      ));
      expect(
          html,
          '<button class="base same extra active" '
          'data-live="new" aria-expanded="false" disabled=""></button>');
    });

    test('rejects unsafe reactive URL attributes', () {
      expect(
        () => renderToHtml(A(reactiveAttrs: {
          'href': () => 'javascript:alert(1)',
        })),
        throwsArgumentError,
      );
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

    test('typed common attributes merge with attrs', () {
      final html = renderToHtml(Div(
        id: 'typed-id',
        role: 'button',
        data: {'user-id': '7'},
        hidden: true,
        title: 'Help',
        tabIndex: 2,
        aria: {'label': 'Close', 'expanded': false, 'ignored': null},
        attrs: {
          'id': 'attrs-id',
          'role': 'link',
          'title': 'Override',
          'data-user-id': '8',
          'aria-label': 'Dismiss',
        },
      ));
      expect(
        html,
        '<div id="attrs-id" role="link" hidden="" title="Override" '
        'tabindex="2" data-user-id="8" aria-label="Dismiss" '
        'aria-expanded="false"></div>',
      );
      expect(
        () => renderToHtml(Div(data: {'bad name': 'x'})),
        throwsArgumentError,
      );
    });

    test('form descriptors render typed attributes', () {
      final input = renderToHtml(Input(
        type: InputType.email,
        required: true,
        readOnly: true,
        autofocus: true,
        multiple: true,
        min: 1,
        max: '2030-01-01',
        step: 0.5,
        minLength: 2,
        maxLength: 12,
        pattern: '.+',
        autocomplete: 'email',
        accept: 'image/*',
        inputMode: 'email',
      ));
      for (final attribute in [
        'type="email"',
        'required="required"',
        'readonly="readonly"',
        'autofocus="autofocus"',
        'multiple="multiple"',
        'min="1"',
        'max="2030-01-01"',
        'step="0.5"',
        'minlength="2"',
        'maxlength="12"',
        'pattern=".+"',
        'autocomplete="email"',
        'accept="image/*"',
        'inputmode="email"',
      ]) {
        expect(input, contains(attribute));
      }

      final textarea = renderToHtml(Textarea(
        required: true,
        readOnly: true,
        autofocus: true,
        minLength: 3,
        maxLength: 20,
        rows: 4,
        cols: 30,
        placeholder: 'Notes',
        name: 'notes',
      ));
      for (final attribute in [
        'required="required"',
        'readonly="readonly"',
        'autofocus="autofocus"',
        'minlength="3"',
        'maxlength="20"',
        'rows="4"',
        'cols="30"',
        'placeholder="Notes"',
        'name="notes"',
      ]) {
        expect(textarea, contains(attribute));
      }

      expect(
        renderToHtml(Select(
            name: 'roles', required: true, multiple: true, disabled: true)),
        contains('name="roles"'),
      );
      expect(renderToHtml(Select(required: true)),
          contains('required="required"'));
      expect(renderToHtml(Select(multiple: true)),
          contains('multiple="multiple"'));
      expect(renderToHtml(Select(disabled: true)),
          contains('disabled="disabled"'));
      expect(renderToHtml(Button(type: ButtonType.reset, disabled: true)),
          '<button type="reset" disabled="disabled"></button>');
      expect(InputType.datetimeLocal, 'datetime-local');
      expect(ButtonType.button, 'button');
    });

    test('image and anchor descriptors render typed attributes', () {
      final image = renderToHtml(Img(
        src: '/image.png',
        alt: 'An image',
        width: 32,
        height: 16,
        loading: ImageLoading.lazy,
        decoding: ImageDecoding.async,
        fetchPriority: FetchPriority.high,
        srcset: '/image-2x.png 2x',
        sizes: '32px',
      ));
      for (final attribute in [
        'loading="lazy"',
        'decoding="async"',
        'fetchpriority="high"',
        'width="32"',
        'height="16"',
        'srcset="/image-2x.png 2x"',
        'sizes="32px"',
      ]) {
        expect(image, contains(attribute));
      }
      expect(renderToHtml(A(href: '/download', download: true)),
          contains('download="download"'));
    });

    test('description list descriptors render', () {
      expect(
        renderToHtml(Dl(children: [Dt(text: 'Term'), Dd(text: 'Meaning')])),
        '<dl><dt>Term</dt><dd>Meaning</dd></dl>',
      );
    });

    test('SVG presentation shorthands accept numeric stroke widths', () {
      expect(
        renderToHtml(SvgCircle(
          cx: 2,
          cy: 3,
          r: 4,
          fill: 'red',
          stroke: 'black',
          strokeWidth: 2,
          opacity: 0.5,
          transform: 'scale(2)',
        )),
        contains('stroke-width="2"'),
      );
      expect(
        renderToHtml(SvgRect(
          width: 10,
          height: 8,
          strokeWidth: 4,
          opacity: 0.6,
          transform: 'rotate(2)',
        )),
        allOf(
          contains('stroke-width="4"'),
          contains('opacity="0.6"'),
          contains('transform="rotate(2)"'),
        ),
      );
      expect(
          renderToHtml(SvgLine(
              x1: 0,
              y1: 1,
              x2: 2,
              y2: 3,
              strokeWidth: 3,
              opacity: 0.7,
              transform: 'translate(1)')),
          allOf(contains('stroke-width="3"'), contains('opacity="0.7"'),
              contains('transform="translate(1)"')));
      expect(
        renderToHtml(Svg(
          width: 24,
          strokeWidth: 5,
          opacity: 0.8,
          transform: 'scale(1.5)',
        )),
        allOf(
          contains('<svg width="24"'),
          contains('stroke-width="5"'),
          contains('opacity="0.8"'),
          contains('transform="scale(1.5)"'),
        ),
      );
      expect(renderToHtml(Svg(width: '100%')), contains('<svg width="100%">'));
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

    test('hoists stylesheet links from the body and includes media', () {
      final html = renderToDocument(
        Fragment(children: const [
          StylesheetLink('/css/site.css'),
          StylesheetLink('/css/print.css', media: 'print'),
        ]),
      );
      expect(html, contains('<link rel="stylesheet" href="/css/site.css">'));
      expect(
        html,
        contains(
          '<link rel="stylesheet" href="/css/print.css" media="print">',
        ),
      );
      expect(
        RegExp('<link rel="stylesheet" href="/css/site.css"')
            .allMatches(html)
            .length,
        1,
      );
      final body = html.substring(html.indexOf('<body>'));
      expect(body, isNot(contains('/css/site.css')));
    });

    test('hoists and deduplicates title, metadata, and links safely', () {
      final html = renderToDocument(
        Fragment(children: [
          const Title('Old'),
          const Meta(name: 'description', content: 'old'),
          const Meta(property: 'og:title', content: 'Old metadata title'),
          const Meta(httpEquiv: 'refresh', content: '1;url=/old'),
          const HeadLink(rel: 'icon', href: '/icon?a=1&b=2'),
          Live(() => Fragment(children: [
                const Title('New <title>'),
                const Meta(name: 'description', content: 'last & best'),
                const Meta(property: 'og:title', content: 'New & title'),
                const Meta(httpEquiv: 'refresh', content: '5;url=/new'),
                const HeadLink(rel: 'icon', href: '/icon?a=1&b=2'),
              ])),
        ]),
        title: 'Parameter title',
      );

      expect(html, contains('<title>New &lt;title&gt;</title>'));
      expect(html, isNot(contains('<title>Old</title>')));
      expect(html, isNot(contains('Parameter title')));
      expect(
        html,
        contains('<meta name="description" content="last &amp; best">'),
      );
      expect(
        html,
        contains('<meta property="og:title" content="New &amp; title">'),
      );
      expect(
        html,
        contains('<meta http-equiv="refresh" content="5;url=/new">'),
      );
      expect(html, contains('<link rel="icon" href="/icon?a=1&amp;b=2">'));
      expect(RegExp('<meta name="description"').allMatches(html).length, 1);
      expect(RegExp('<meta property="og:title"').allMatches(html).length, 1);
      expect(RegExp('<meta http-equiv="refresh"').allMatches(html).length, 1);
      expect(RegExp('<link rel="icon"').allMatches(html).length, 1);
      final body = html.substring(html.indexOf('<body>'));
      expect(body, isNot(contains('New')));
    });

    test('validates head descriptor attributes before rendering', () {
      expect(
        () => renderToDocument(
          const HeadLink(rel: 'stylesheet', href: 'javascript:alert(1)'),
        ),
        throwsArgumentError,
      );
      expect(
        () => renderToDocument(
          const HeadLink(
            rel: 'stylesheet',
            href: '/safe.css',
            attrs: {'onload': 'alert(1)'},
          ),
        ),
        throwsArgumentError,
      );
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

    test('orders explicit and legacy scripts after head nodes', () {
      final html = renderToDocument(
        Div(),
        head: [ElNode('title', text: 'head node')],
        scriptTags: const [
          DocumentScript('/bootstrap.js', module: true),
          DocumentScript('/classic.js', defer: false, async: true),
        ],
        scripts: ['/main.js'],
      );
      final headNodeIndex = html.indexOf('<title>head node</title>');
      final moduleIndex =
          html.indexOf('<script type="module" src="/bootstrap.js"></script>');
      final classicIndex =
          html.indexOf('<script async src="/classic.js"></script>');
      final legacyIndex =
          html.indexOf('<script defer src="/main.js"></script>');
      expect(headNodeIndex, lessThan(moduleIndex));
      expect(moduleIndex, lessThan(classicIndex));
      expect(classicIndex, lessThan(legacyIndex));
      expect(legacyIndex, lessThan(html.indexOf('</head>')));
    });

    test('rejects executable URLs in descriptor script tags', () {
      expect(
        () => renderToDocument(Div(), scriptTags: const [
          DocumentScript('javascript:run()'),
        ]),
        throwsArgumentError,
      );
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
