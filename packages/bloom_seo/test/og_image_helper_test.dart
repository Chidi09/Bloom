import 'package:bloom_seo/bloom_seo.dart';
import 'package:test/test.dart';

void main() {
  group('ogImagePath', () {
    test('builds standard OG image path with default base', () {
      expect(ogImagePath(slug: 'home'), equals('/generated/og/home.png'));
      expect(ogImagePath(slug: 'about'), equals('/generated/og/about.png'));
    });

    test('handles leading slash in slug and trailing slash in base', () {
      expect(ogImagePath(slug: '/pricing'), equals('/generated/og/pricing.png'));
      expect(
        ogImagePath(slug: 'docs/quickstart', base: '/static/og/'),
        equals('/static/og/docs/quickstart.png'),
      );
    });

    test('supports custom base path', () {
      expect(
        ogImagePath(slug: 'post-1', base: 'https://example.com/og'),
        equals('https://example.com/og/post-1.png'),
      );
    });
  });
}
