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

## 2. Out-of-Order Streaming SSR — `renderToStreamWithSuspense()`

`renderToHtml()` (above) and `renderToStream()` (simple chunked output of an
already-fully-rendered string) both wait for the *entire* tree, including any
slow data-dependent sections, before the response starts sending. For a page
with a fast static shell and one or two slow sections, that means the fast
part waits on the slow part for no reason.

`renderToStreamWithSuspense(BloomNode node)` — analogous to React's
`renderToPipeableStream` / `renderToReadableStream` — fixes this: it flushes
the shell (including every `Suspense` boundary's `fallback`) as the *first*
chunk, then streams a small `<script>` snippet replacing each boundary's
placeholder as its `resource` resolves, **in resolution order, not source
order**:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final page = Div(children: [
  H1(text: 'Dashboard'),
  Suspense<List<Order>>(
    resource: () => api.fetchRecentOrders(),
    builder: (orders) => OrdersTable(orders: orders),
    fallback: P(text: 'Loading orders…'),
  ),
]);

await for (final chunk in renderToStreamWithSuspense(page)) {
  response.write(chunk); // flush each chunk to the client as it arrives
}
```

The first chunk the client receives already contains `<h1>Dashboard</h1>` and
the `Loading orders…` fallback wrapped in a `<div id="bloom-suspense-0">` —
so first paint isn't blocked on `fetchRecentOrders()`. A second chunk arrives
once that future resolves:

```html
<script>(function(){var e=document.getElementById("bloom-suspense-0");
if(e){e.outerHTML="<table>...</table>";}})();</script>
```

**Boundaries at any nesting depth stream.** Unlike an earlier version of this
function (which only handled the root node or direct children of a root
`Fragment`), a `Suspense` nested arbitrarily deep inside `Div`/`Fragment`
children — or nested inside *another* boundary's resolved content — still
gets its own progressive chunk. This is implemented by threading an optional
hook through the same recursive walk `renderToHtml()` uses internally, so no
rendering logic is duplicated between the synchronous and streaming
entrypoints; when the hook is absent, the walk's behavior is byte-identical
to plain `renderToHtml()`.

A rejected `resource` simply leaves that boundary's fallback as the final
content (no error chunk, no hung stream) — pair `Suspense` with an
`ErrorBoundary` above it if you need to render an error state instead of a
frozen loading state.

---

## 3. Hydration — `hydrate()` / `hydrateElement()`

Once server-rendered HTML reaches the browser, `hydrate(node, selector)`
attaches the same descriptor tree's reactivity (signals, event listeners) to
that markup — the browser equivalent of React's `hydrateRoot`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  hydrate(app, '#app'); // app is the *same* descriptor tree used for SSR
}
```

**True DOM-reuse for static trees.** When the tree passed to `hydrate()`
contains only static node types — `Text`, elements (`Div`, `Span`, …),
`Fragment`, `Raw`, `Style` — hydration walks the existing server-rendered DOM
in lockstep with the descriptor tree and reuses each node in place: it
attaches event listeners and patches any text/attribute that doesn't already
match, but never tears down or recreates a node that's already correct. This
matters for large static shells (marketing content, SSG pages, the static
frame around a few dynamic islands) where a full remount would otherwise
throw away and rebuild DOM the browser already parsed.

**Reactive trees fall back to a full remount — correctly, not silently.**
Once any `Live`, `Show`, `ForEach`, `Suspense`, `ErrorBoundary`, `Portal`,
`Mount`, `Ref`, `Animated`, or `Context.provide` node appears anywhere in the
tree, `hydrate()` clears the target element and mounts fresh via the normal
`mount()` path instead of attempting partial reuse. This isn't a missing
feature so much as a structural fact about the two renderers: `renderToHtml`
emits a reactive node's *current* content inline with no marker correlating
it back to the pair of comment nodes `mount()` brackets that region with, so
there is no safe way to splice a live region into an arbitrary DOM position
without risking corrupted or duplicated sibling content. The same fallback
also triggers if the static walk ever finds a structural mismatch against
the actual DOM (hand-edited markup, a stale build) — the walk never mutates
destructively until a full match is confirmed, so falling back is always
safe.

```dart
// Fully static — real node reuse, listeners attached in place:
hydrate(Div(children: [H1(text: 'Welcome'), P(text: 'Static content.')]), '#app');

// Contains a Live(...) region — falls back to a correct full remount:
hydrate(Div(children: [Live(() => P(text: 'Count: ${count.value}'))]), '#app');
```

---

## 4. Server Integration via `BloomApiRouter.ssr()`

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

## 5. SEO & Structured Data (`package:bloom_seo`)

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
