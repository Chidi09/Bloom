import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('BloomRouter path matching', () {
    test('static routes', () {
      final r = BloomRouter([
        BloomRoute('/', (_) => Text('home')),
        BloomRoute('/about', (_) => Text('about')),
      ]);
      expect(r.match('/')!.route.path, '/');
      expect(r.match('/about')!.route.path, '/about');
      expect(r.match('/missing'), isNull);
    });

    test('param extraction', () {
      final r = BloomRouter([
        BloomRoute('/users/:id', (_) => Text('user')),
      ]);
      final m = r.match('/users/42')!;
      expect(m.params['id'], '42');
    });

    test('multiple params', () {
      final r = BloomRouter([
        BloomRoute('/posts/:postId/comments/:id', (_) => Text('c')),
      ]);
      final m = r.match('/posts/10/comments/5')!;
      expect(m.params['postId'], '10');
      expect(m.params['id'], '5');
    });

    test('wildcard captures remainder', () {
      final r = BloomRouter([
        BloomRoute('/docs/*', (_) => Text('docs')),
      ]);
      final m = r.match('/docs/a/b/c')!;
      expect(m.params['wildcard'], 'a/b/c');
    });

    test('strips query and hash', () {
      final r = BloomRouter([
        BloomRoute('/about', (_) => Text('a')),
      ]);
      expect(r.match('/about?x=1')!.route.path, '/about');
      expect(r.match('/about#section')!.route.path, '/about');
    });

    test('Link renders anchor', () {
      final node = Link(href: '/about', text: 'About');
      final html = renderToHtml(node);
      expect(html, '<a href="/about">About</a>');
    });
  });
}
