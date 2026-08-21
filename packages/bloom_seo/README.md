# bloom_seo

Standalone SEO toolkit for Bloom JS Native — and for any Dart SSR setup.

- **HeadManager** — reactive `title`/`meta`/`canonical`/`OG`/`Twitter` tags driven by signals
- **JsonLd** — typed `Article`/`Breadcrumb`/`Organization`/`WebSite` structured data + `toScriptTag()`
- **SitemapBuilder** — `sitemaps.org` XML + index generation with XML escaping
- **prerenderRoute()** — static HTML via `renderToHtml` (SSG), single-route or multi-route

## Usage

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';

// Head (reactive)
final head = HeadManager(initialTitle: 'Home', initialDescription: 'Welcome');
head.title.value = 'New title'; // route change → head updates
final headTags = head.renderToHtml(); // inject into <head>

// JSON-LD
final ld = JsonLd.article(headline: 'Hello World', author: 'Bloom');
final script = ld.toScriptTag();

// Sitemap
final s = SitemapBuilder();
s.add('https://example.com/', changefreq: 'daily', priority: 1.0);
s.add('https://example.com/about', priority: 0.8);
final xml = s.buildXml();

// Prerender (SSG) — same descriptor tree as client
final html = prerenderRoute(body: Fragment(children: [H1(text: 'Hi')]), head: head);
final pages = prerenderRoutes({'/': Home(), '/about': About()});
```

Server integration (BloomApiRouter):

```dart
router.get('/about', (req) async {
  final head = HeadManager(initialTitle: 'About — Bloom');
  return Response.html(prerenderRoute(body: AboutPage(), head: head));
});
```

See `bloom_js_native/docs/SSR_AND_SEO.md` for full SSR + hydration story.
