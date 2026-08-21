# 05 — Server-Side Rendering (SSR) & Static Generation (SSG)

Bloom JS Native provides sub-millisecond Server-Side Rendering directly from Dart. The same component tree that runs in the browser compiles to pure-Dart strings on the server with **zero Chromium, Puppeteer, or Node.js runtime dependencies**.

---

## 1. The `renderToHtml()` Engine

The `renderToHtml(BloomNode)` function walks the AST descriptor tree and produces a minified, XSS-escaped HTML string in `<0.4ms`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  final app = Div(
    className: 'hero-card',
    children: [
      H1(text: 'Sub-Millisecond SSR'),
      P(text: 'Zero JavaScript required for first contentful paint.'),
    ],
  );

  final html = renderToHtml(app);
  print(html);
  // <div class="hero-card"><h1>Sub-Millisecond SSR</h1><p>Zero JavaScript required for first contentful paint.</p></div>
}
```

---

## 2. Server Integration via `BloomApiRouter.ssr()`

In full-stack Bloom apps (`apps/server/bin/server.dart`), register SSR endpoints with a single method call:

```dart
import 'package:bloom_framework/bloom.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';

void main() {
  final router = BloomApiRouter();

  // Unified SSR Route (<1ms response time)
  router.ssr(
    '/',
    (req) => Div(
      className: 'min-h-screen bg-black text-white p-8',
      children: [
        H1(className: 'text-4xl font-extrabold', text: 'Bloom Edge SSR'),
        P(className: 'text-zinc-400 mt-2', text: 'Rendered instantly on the server.'),
      ],
    ),
    head: (req) => HeadManager(
      initialTitle: 'Bloom — Fast SSR & Edge Delivery',
      meta: {
        'description': 'Pure Dart server-side rendered landing page.',
        'og:title': 'Bloom Web Platform',
        'twitter:card': 'summary_large_image',
      },
    ),
  );

  router.listen(port: 8080);
}
```

---

## 3. SEO & Structured Data (`package:bloom_seo`)

Bloom provides complete, reactive SEO primitives in `package:bloom_seo`:

### Dynamic Head Management
```dart
final head = HeadManager(
  initialTitle: 'Product Details — Bloom',
  meta: {
    'description': 'High-performance engineering tools.',
    'keywords': 'dart, web, framework, signals',
  },
  links: {
    'canonical': 'https://bloom.dev/products/123',
  },
);

// Mutate titles dynamically on client or server
head.title.value = 'Updated Product Name';
```

### JSON-LD Structured Data
```dart
final jsonLd = JsonLd.softwareApp(
  name: 'Bloom Framework',
  operatingSystem: 'All',
  applicationCategory: 'DeveloperApplication',
  offers: {'price': '0', 'priceCurrency': 'USD'},
);

// Emits valid <script type="application/ld+json">...</script>
print(jsonLd.toScriptTag());
```

### Automated Sitemap Generation
```dart
final sitemap = SitemapBuilder(baseUrl: 'https://bloom.dev');
sitemap.addRoute('/', priority: 1.0, changeFreq: 'daily');
sitemap.addRoute('/docs', priority: 0.8, changeFreq: 'weekly');
sitemap.addRoute('/blog', priority: 0.6, changeFreq: 'weekly');

final xml = sitemap.toXml();
```
