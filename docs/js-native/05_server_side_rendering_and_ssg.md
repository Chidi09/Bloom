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

### Boundary markers

SSR wraps reactive subtrees in HTML comment markers so hydration can find
them again without disturbing layout:

```html
<!--bloom:live--><p>Count: 0</p><!--/bloom:live-->
<!--bloom:foreach-->
<!--bloom:key=user-1--><li>Alice</li><!--/bloom:key-->
<!--bloom:key=user-2--><li>Bob</li><!--/bloom:key-->
<!--/bloom:foreach-->
```

`Live`, `Memo`, `Show`, `ForEach` (keyed items carry their keys),
`ErrorBoundary`, and synchronous `Suspense` fallbacks all emit markers;
streaming Suspense keeps its `<div id="bloom-suspense-N">` shell.
`Context.provide`, `Mount`, and `Ref` are transparent wrappers with no
markers, `Animated` keeps its wrapper `<div>`, and `Portal` keeps its
`<template>`. Marker matching ignores comment whitespace, so mount
sentinels (`<!-- bloom:live -->`) and SSR markers adopt identically.

### What hydrates in place

Static nodes (`Text`, elements, `Fragment`, `Raw`, `Style`) reuse their DOM
nodes, attach listeners, and patch differing text/attributes. Reactive
boundaries adopt the nodes between their markers and bind the same sentinel
regions and effects a fresh mount would create, so later signal updates
patch the adopted nodes. Keyed lists reconcile by key after hydration —
reordering reuses nodes, preserving input state and focus.

Pre-hydration user state is preserved: hydration never overwrites
`value`/`checked` on form controls, keeps the focused element and text
selection, and reports conflicts as diagnostics instead of clobbering them.

```dart
// Static shell with a reactive island — nodes reused, listeners attached:
hydrate(Div(children: [
  H1(text: 'Welcome'),
  Live(() => P(text: 'Count: ${count.value}')),
]), '#app');
```

### Mismatch recovery and diagnostics

Each mismatch recovers at the smallest marker-delimited boundary — that
region alone remounts while siblings keep their nodes — and is reported as
a `HydrationMismatch` (path, boundary, expected, actual, recovery) through
an optional `onMismatch` callback, the `bloomHydrationMismatchHandler`
global, and DevTools:

```dart
hydrateElement(app, container, onMismatch: (m) => print(m));
// Bloom hydration mismatch at Div[1]/Live[0] [boundary bloom:live]:
// expected element <p>, found element <div> — remounted boundary.
```

Only a root-level structural mismatch clears the target and does a clean
full mount. Portal `<template>` content remounts into its target by design
(surrounding DOM is kept); Suspense content that resolved before hydration
remounts as a live Suspense region, resolving instantly from the dehydrated
query cache.

### Suspense streaming vs hydration timing

- **Resolves before hydration:** the patch is already in the DOM; hydration
  recovers through the nearest delimited parent into a live Suspense region.
- **Resolves during hydration:** hydration claims the shell synchronously,
  so ordering stays strict — there is no interleaving to race.
- **Resolves after hydration:** hydration moves the shell's `id` to a
  `data-bloom-ssr-suspense` attribute, so the late server patch script finds
  no element and safely no-ops; the client region re-runs its own `resource`
  and patches itself on resolve.

### Delayed islands and interaction activation

Islands with `visible`, `idle`, `media`, or `never` strategies hydrate only
when their trigger fires; the triggering interaction hydrates the island
without replaying into the fresh content — the first click wakes the island,
the second click interacts with it:

```dart
registerIsland('cart', (props) => Cart(count: props['count']),
    defaultStrategy: HydrationStrategy.interaction);
orchestrateIslands(); // pointerdown hydrates; later events interact
```

### Browser verification

Reactive hydration is covered by `test/reactive_hydration_test.dart` (DOM
identity, inputs, focus/selection, keyed reordering, events, cleanup,
Suspense timing, island activation). Run it with the release verification
workflow across engines:

```bash
dart test -p chrome test/reactive_hydration_test.dart
dart test -p firefox test/reactive_hydration_test.dart
dart test -p safari test/reactive_hydration_test.dart
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
