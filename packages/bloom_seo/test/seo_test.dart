import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';
import 'package:test/test.dart';

void main() {
  group('HeadManager', () {
    test('renders title + description + canonical', () {
      final head = HeadManager(
        initialTitle: 'Hello',
        initialDescription: 'Desc',
        initialCanonical: 'https://example.com',
      );
      final html = head.renderToHtml();
      expect(html, contains('<title>Hello</title>'));
      expect(html, contains('name="description"'));
      expect(html, contains('rel="canonical"'));
    });

    test('escapes XSS in title', () {
      final head = HeadManager(initialTitle: '<script>alert(1)</script>');
      final html = head.renderToHtml();
      expect(html, contains('&lt;script&gt;'));
      expect(html, isNot(contains('<script>alert')));
    });

    test('update batches signals', () {
      final head = HeadManager(initialTitle: 'A');
      head.update(title: 'B', description: 'new');
      expect(head.title.value, 'B');
      expect(head.description.value, 'new');
    });

    test('reactive — changing title reflects in next render', () {
      final head = HeadManager(initialTitle: 'T1');
      head.title.value = 'T2';
      expect(head.renderToHtml(), contains('T2'));
    });

    test('wrapDocument produces full html', () {
      final head = HeadManager(initialTitle: 'Home');
      final doc = head.wrapDocument('<h1>Hi</h1>');
      expect(doc, startsWith('<!DOCTYPE html>'));
      expect(doc, contains('<title>Home</title>'));
      expect(doc, contains('<h1>Hi</h1>'));
    });

    test('og tags default from title/desc', () {
      final head = HeadManager(initialTitle: 'My Page', initialDescription: 'Desc');
      final html = head.renderToHtml();
      expect(html, contains('og:title'));
      expect(html, contains('My Page'));
    });
  });

  group('JsonLd', () {
    test('article factory emits correct type', () {
      final ld = JsonLd.article(headline: 'Hello', author: 'Bloom');
      final tag = ld.toScriptTag();
      expect(tag, contains('Article'));
      expect(tag, contains('Hello'));
      expect(tag, contains('Bloom'));
    });

    test('escapes closing script tag', () {
      final ld = JsonLd({'x': '</script>'});
      expect(ld.toScriptTag(), contains('<\\/script>'));
      expect(ld.toScriptTag(), isNot(contains('</script><script>')));
    });

    test('breadcrumb factory', () {
      final ld = JsonLd.breadcrumb([
        {'name': 'Home', 'url': '/'},
        {'name': 'About', 'url': '/about'},
      ]);
      expect(ld.toScriptTag(), contains('BreadcrumbList'));
      expect(ld.data['itemListElement'], isA<List<dynamic>>());
    });
  });

  group('SitemapBuilder', () {
    test('builds valid xml', () {
      final s = SitemapBuilder();
      s.add('https://example.com/', lastmod: '2026-08-21', changefreq: 'daily', priority: 1.0);
      s.add('https://example.com/about', priority: 0.8);
      final xml = s.buildXml();
      expect(xml, contains('<urlset'));
      expect(xml, contains('<loc>https://example.com/</loc>'));
      expect(xml, contains('<lastmod>2026-08-21</lastmod>'));
      expect(xml, contains('<priority>1.0</priority>'));
    });

    test('escapes xml chars', () {
      final s = SitemapBuilder();
      s.add('https://example.com/?a=1&b=2');
      expect(s.buildXml(), contains('&amp;'));
    });

    test('buildIndex', () {
      final xml = SitemapBuilder.buildIndex(['https://example.com/sitemap.xml']);
      expect(xml, contains('<sitemapindex'));
      expect(xml, contains('<loc>https://example.com/sitemap.xml</loc>'));
    });
  });

  group('prerenderRoute', () {
    test('prerenders body to html document', () {
      final html = prerenderRoute(body: H1(text: 'Hello'));
      expect(html, contains('<h1>Hello</h1>'));
      expect(html, startsWith('<!DOCTYPE html>'));
    });

    test('prerender with head manager', () {
      final head = HeadManager(initialTitle: 'SSR Page');
      final html = prerenderRoute(body: P(text: 'content'), head: head);
      expect(html, contains('<title>SSR Page</title>'));
      expect(html, contains('<p>content</p>'));
    });

    test('prerenderRoutes builds map', () {
      final routes = {
        '/': H1(text: 'Home'),
        '/about': H1(text: 'About'),
      };
      final out = prerenderRoutes(routes);
      expect(out['/'], contains('Home'));
      expect(out['/about'], contains('About'));
    });

    test('Live/Show/ForEach prerender correctly', () {
      final count = signal(5);
      final node = Fragment(children: [
        Live(() => P(text: 'Count ${count.value}')),
        Show(() => count.value > 3, child: Text('big'), fallback: Text('small')),
      ]);
      final html = prerenderRoute(body: node);
      expect(html, contains('Count 5'));
      expect(html, contains('big'));
    });
  });
}
