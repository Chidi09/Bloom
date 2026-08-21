import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('BloomRoute.shell', () {
    test('matches nested route and wraps with shell layout', () {
      final router = BloomRouter([
        BloomRoute.shell(
          layout: (child, params) => Div(className: 'app-shell', children: [child]),
          routes: [
            BloomRoute('/admin/users', (_) => P(text: 'Users Table')),
            BloomRoute('/admin/settings', (_) => P(text: 'Settings Form')),
          ],
        ),
      ]);

      final match = router.match('/admin/users');
      expect(match, isNotNull);
      final rendered = renderToHtml(match!.build());
      expect(rendered, '<div class="app-shell"><p>Users Table</p></div>');
    });
  });
}
