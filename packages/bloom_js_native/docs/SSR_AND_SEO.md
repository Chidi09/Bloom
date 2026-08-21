# SSR_AND_SEO — Bloom JS Native

Same descriptor tree, two backends. SSR is not a feature — it’s the other interpreter.

## renderToHtml (SSR backend)

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

String html = renderToHtml(Fragment(children: [
  H1(text: 'Hello'),
  Live(() => P(text: 'Count ${count.value}')), // evaluated once, no effect
]));
```

- `Live`, `Show`, `ForEach` closures are evaluated **once** (no reactivity server-side).
- All text/attrs escaped via `escapeHtml` (XSS-safe).
- Void elements (`input`, `img`, `br`, …) emitted without closing tags.

## Server integration (BloomApiRouter)

Already documented in `GEMINI.md` §3 — the Bloom server on `:8080`:

- `/` → native SSR HTML landing page (<1ms, 0kB JS baseline, dynamic DB interpolation)
- `/api/*` → REST & WebSocket APIs
- `/app` → interactive client SPA

Bloom JS Native plugs in as:

```dart
// apps/server/bin/server.dart or lib/src/server/api_router.dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';

router.get('/', (req) async {
  final count = await db.countTodos();
  final html = renderToHtml(Fragment(children: [
    H1(text: 'Todos: $count'),
  ]));
  return Response.html(html);
});

// Or with bloom_seo prerender:
router.get('/about', (req) async {
  final head = HeadManager(initialTitle: 'About — Bloom', initialDescription: '...');
  final html = prerenderRoute(body: AboutPage(), head: head);
  return Response.html(html);
});
```

Sub-millisecond because it’s string concatenation of a pure-Dart tree — no browser, no isolate spawn per request.

## bloom_seo package

Standalone and router-integrated:

```dart
import 'package:bloom_seo/bloom_seo.dart';

// Head
final head = HeadManager(initialTitle: 'Home');
head.title.value = 'New title'; // reactive — route changes update head
head.update(description: 'New desc', canonical: 'https://example.com/');
final headHtml = head.renderToHtml(); // inject into <head>

// JSON-LD
final ld = JsonLd.article(headline: 'Hello', author: 'Bloom');
final scriptTag = ld.toScriptTag(); // <script type="application/ld+json">

// Prerender (SSG)
final html = prerenderRoute(body: MyPage(), head: head);
final pages = prerenderRoutes({'/': Home(), '/about': About()});

// Sitemap
final s = SitemapBuilder();
s.add('https://example.com/', priority: 1.0, changefreq: 'daily');
s.add('https://example.com/about', priority: 0.8);
final xml = s.buildXml();
```

## Hydration

- v1 ships `renderToHtml` + **full client re-mount** (acceptable gap). Server sends HTML, client discards and re-renders via `mount()`.
- Stretch goal: event-delegation hydration (re-attach listeners without rebuild). Deferred to M5.

## Security

- `renderToHtml` escapes `& < > " '` in both text and attributes.
- `HeadManager` escapes all injected meta content.
- `JsonLd` escapes `</script>` inside JSON payload.
- `SitemapBuilder` escapes XML entities.

Same discipline as the phase12 sanitize fix — never interpolate raw user content into HTML/XML.
