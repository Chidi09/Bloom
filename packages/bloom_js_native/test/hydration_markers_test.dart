import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('SSR hydration marker contract', () {
    test('Live wraps output in live markers', () {
      final html = renderToHtml(Live(() => P(text: 'x')));
      expect(html, '<!--bloom:live--><p>x</p><!--/bloom:live-->');
    });

    test('Memo wraps output in memo markers', () {
      final html = renderToHtml(Memo(() => 1, (v) => P(text: 'v$v')));
      expect(html, '<!--bloom:memo--><p>v1</p><!--/bloom:memo-->');
    });

    test('Show wraps the active branch in show markers', () {
      final html = renderToHtml(
          Show(() => true, child: P(text: 'y'), fallback: P(text: 'n')));
      expect(html, '<!--bloom:show--><p>y</p><!--/bloom:show-->');
    });

    test('keyed ForEach tags each item with its key', () {
      final node = ForEach<String>(
        () => ['a', 'b'],
        (t) => Li(text: t),
        key: (t) => 'user-$t',
      );
      expect(
        renderToHtml(node),
        '<!--bloom:foreach-->'
        '<!--bloom:key=user-a--><li>a</li><!--/bloom:key-->'
        '<!--bloom:key=user-b--><li>b</li><!--/bloom:key-->'
        '<!--/bloom:foreach-->',
      );
    });

    test('keyed ForEach rejects duplicate keys during SSR', () {
      final node = ForEach<int>(
        () => [1, 2],
        (item) => Li(text: '$item'),
        key: (_) => 'duplicate',
      );

      expect(
        () => renderToHtml(node),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Duplicate ForEach key "duplicate"'),
          ),
        ),
      );
    });

    test('unkeyed ForEach emits only the container boundary', () {
      final html =
          renderToHtml(ForEach(() => ['a'], (String t) => Li(text: t)));
      expect(html, '<!--bloom:foreach--><li>a</li><!--/bloom:foreach-->');
    });

    test('markers nest without breaking the outer span', () {
      final html = renderToHtml(Live(() => Div(children: [
            Show(() => true, child: P(text: 'in')),
          ])));
      expect(
        html,
        '<!--bloom:live--><div>'
        '<!--bloom:show--><p>in</p><!--/bloom:show-->'
        '</div><!--/bloom:live-->',
      );
    });

    test('static trees emit no markers', () {
      final html = renderToHtml(Div(children: [P(text: 'a'), P(text: 'b')]));
      expect(html, '<div><p>a</p><p>b</p></div>');
      expect(html, isNot(contains('bloom:')));
    });

    test('Mount and Ref stay transparent in SSR', () {
      final ref = Ref<Object>();
      final html = renderToHtml(
          Mount(RefNode(ref, P(text: 'hi')), onMount: () {}, onUnmount: () {}));
      expect(html, '<p>hi</p>');
    });

    test('streaming shell keeps its div-id contract', () async {
      final node = Suspense<String>(
        resource: () => Future.value('done'),
        builder: (data) => Div(text: data),
        fallback: Div(text: 'loading'),
      );
      final chunks = await renderToStreamWithSuspense(node).toList();
      expect(chunks.first, contains('id="bloom-suspense-0"'));
      expect(suspenseStreamId(0), 'bloom-suspense-0');
    });
  });

  group('hydration key escaping', () {
    test('simple keys pass through verbatim', () {
      expect(escapeHydrationKey('user-1'), 'user-1');
      expect(unescapeHydrationKey('user-1'), 'user-1');
    });

    test('unsafe keys round-trip through b64 encoding', () {
      for (final key in [
        'a b',
        'x--y',
        '<b>',
        'ünï',
        'a/b?c=d&e',
        '日本',
        '😀'
      ]) {
        final escaped = escapeHydrationKey(key);
        expect(escaped, isNot(contains('--')));
        expect(escaped, isNot(contains('<')));
        expect(unescapeHydrationKey(escaped), key);
      }
    });

    test('key markers parse back to the original key', () {
      const key = 'order 42/x';
      final open = ssrKeyOpenMarker(key);
      final data = open.substring(4, open.length - 3);
      expect(parseKeyMarker(data), key);
      expect(isKeyMarkerClose('/bloom:key'), isTrue);
    });

    test('corrupted base64 key markers are rejected without throwing', () {
      expect(parseKeyMarker('bloom:key=b64:%%%'), isNull);
      expect(parseKeyMarker('bloom:key=b64:_w'), isNull,
          reason:
              'invalid base64 must become a recoverable hydration mismatch');
    });

    test('marker matching ignores mount-style whitespace', () {
      expect(isMarkerOpen('bloom:live', 'bloom:live'), isTrue);
      expect(isMarkerOpen(' bloom:live ', 'bloom:live'), isTrue);
      expect(isMarkerClose(' /bloom:live ', 'bloom:live'), isTrue);
      expect(isMarkerOpen('bloom:show', 'bloom:live'), isFalse);
    });
  });

  group('hydration mismatch diagnostics', () {
    test('formats a single-line diagnostic', () {
      const mismatch = HydrationMismatch(
        path: 'Div[0]/Live[0]',
        boundary: 'bloom:live',
        expected: 'element <p>',
        actual: 'element <div>',
        recovery: 'remounted boundary',
      );
      expect(
        formatHydrationMismatch(mismatch),
        'Bloom hydration mismatch at Div[0]/Live[0] '
        '[boundary bloom:live]: expected element <p>, '
        'found element <div> — remounted boundary.',
      );
      expect(mismatch.toString(), formatHydrationMismatch(mismatch));
    });
  });
}
