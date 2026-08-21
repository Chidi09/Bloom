import 'dart:convert';
import 'package:bloom_framework/bloom.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BloomApiRouter SSR', () {
    test('renders BloomNode tree to sub-millisecond HTML response', () async {
      final router = BloomApiRouter();
      router.ssr(
        '/',
        (req) => Div(
          className: 'hero',
          children: [H1(text: 'Welcome to Bloom SSR')],
        ),
        head: (req) => HeadManager(initialTitle: 'Bloom Server App'),
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = await router.handle(req);

      expect(res.statusCode, 200);
      expect(res.headers['content-type'], contains('text/html'));
      final bodyStr = utf8.decode(res.body);
      expect(bodyStr, contains('<title>Bloom Server App</title>'));
      expect(bodyStr, contains('<h1>Welcome to Bloom SSR</h1>'));
    });
  });
}
