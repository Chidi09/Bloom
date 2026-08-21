import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Suspense', () {
    test('SSR renders fallback shell synchronously', () {
      final app = Suspense<String>(
        resource: () => Future.value('Loaded Data'),
        builder: (data) => P(text: data),
        fallback: P(text: 'Loading...'),
      );
      final html = renderToHtml(app);
      expect(html, '<p>Loading...</p>');
    });
  });
}
