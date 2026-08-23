import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('SSR name validation', () {
    test('rejects an attribute name that breaks out of the attribute', () {
      expect(
        () => renderToHtml(El('div', attrs: {'x" onload="alert(1)': 'y'})),
        throwsArgumentError,
      );
    });

    test('rejects a tag name carrying injected markup', () {
      expect(
        () => renderToHtml(El('div onload=alert(1)')),
        throwsArgumentError,
      );
      expect(() => renderToHtml(El('div><script>')), throwsArgumentError);
    });

    test('rejects an empty tag or attribute name', () {
      expect(() => renderToHtml(El('')), throwsArgumentError);
      expect(() => renderToHtml(El('div', attrs: {'': 'v'})), throwsArgumentError);
    });

    test('still allows legitimate SVG camelCase names and namespaced attrs', () {
      final html = renderToHtml(
        El('linearGradient', attrs: {
          'viewBox': '0 0 10 10',
          'stroke-width': '2',
          'xlink:href': '#a',
        }),
      );
      expect(html, contains('<linearGradient'));
      expect(html, contains('viewBox="0 0 10 10"'),
          reason: 'camelCase must be preserved, not lowercased');
      expect(html, contains('stroke-width="2"'));
      expect(html, contains('xlink:href="#a"'));
    });

    test('still allows custom elements, data-* and aria-*', () {
      final html = renderToHtml(
        El('my-widget', attrs: {'data-id': '1', 'aria-label': 'x'}),
      );
      expect(html, contains('<my-widget'));
      expect(html, contains('data-id="1"'));
      expect(html, contains('aria-label="x"'));
    });

    test('attribute VALUES are still escaped, not rejected', () {
      final html = renderToHtml(El('div', attrs: {'title': 'a"b<c'}));
      expect(html, contains('&quot;'));
      expect(html, contains('&lt;'));
    });
  });
}
