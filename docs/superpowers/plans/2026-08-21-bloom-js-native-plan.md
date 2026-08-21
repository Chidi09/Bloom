# Bloom JS Native (M1–M3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a zero-Flutter, signal-driven Dart-to-DOM web runtime (`bloom_js_native`) with pure-Dart descriptor trees, fast SSR rendering, fine-grained DOM mounting, npm import maps, an isomorphic router, a dedicated SEO package (`bloom_seo`), and a rich dark-mode demo app.

**Architecture:** Pure Dart AST descriptors (`BloomNode` / `ElNode` / `LiveNode`) decoupling UI declarations from the DOM. One backend compiles to HTML via `renderToHtml()` on the Dart VM for SSR and testing; the other backend mounts to the browser DOM via `package:web` and fine-grained `signals` effects in `package:bloom_js_native/browser.dart`.

**Tech Stack:** Dart 3.4+, `signals: ^5.5.0`, `package:web: ^1.1.0`, `meta: ^1.15.0`, `test: ^1.25.0`.

**Spec:** `docs/superpowers/specs/2026-08-21-bloom-js-native-design.md`

## Global Constraints
- `package:bloom_js_native/bloom_js_native.dart` MUST NOT import `package:web` or `dart:js_interop`.
- All element constructors (`Div`, `Span`, `Button`, `H1`-`H6`, `Input`, `Live`, `Show`, `ForEach`, `Fragment`) MUST be `const` classes extending `ElNode` or `BloomNode` to ensure 0 `non_constant_identifier_names` lint warnings.
- `dart analyze packages/bloom_js_native packages/bloom_seo` MUST pass with 0 errors and 0 warnings.
- All VM unit tests MUST pass via `dart test` without requiring a browser.

---

### Task 1: Decouple VM Core Entry Point & Fix AST Class Hierarchy

**Files:**
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/lib/browser.dart`
- Test: `packages/bloom_js_native/test/framework_test.dart`

**Interfaces:**
- Consumes: `BloomNode`, `BloomEvent`
- Produces: `Div`, `Span`, `Button`, `Input`, `H1`–`H6`, `Ul`, `Ol`, `Li`, `Form`, `Label`, `Header`, `Footer`, `Main`, `Nav`, `Section`, `Article`, `Aside`, `Strong`, `Em`, `Code`, `Pre`, `Img`, `Textarea`, `Live`, `Show`, `ForEach`, `Text`, `Fragment`, `Style`, `Raw`

- [ ] **Step 1: Write/Update unit test for class-based AST descriptors**

Update `test/framework_test.dart`:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Descriptor tree', () {
    test('El subclasses produce valid tags and can be const', () {
      const div = Div(className: 'container', children: [
        H1(text: 'Title'),
        Span(text: 'Subtitle'),
        Button(text: 'Click'),
      ]);
      expect(div.tag, 'div');
      expect(div.className, 'container');
      expect(div.children.length, 3);
      expect((div.children[0] as ElNode).tag, 'h1');
      expect((div.children[1] as ElNode).tag, 'span');
      expect((div.children[2] as ElNode).tag, 'button');
    });

    test('Live, Show, ForEach descriptors', () {
      final count = signal(10);
      final live = Live(() => Text('Count: ${count.value}'));
      expect(live.builder(), isA<TextNode>());

      final show = Show(() => count.value > 5, child: const Text('high'), fallback: const Text('low'));
      expect(show.when(), isTrue);

      final forEach = ForEach<int>(() => [1, 2, 3], (x) => Li(text: '$x'));
      expect(forEach.items(), [1, 2, 3]);
      expect((forEach.builder(99) as ElNode).text, '99');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails on pure VM without web errors**

Run: `cd packages/bloom_js_native && dart test test/framework_test.dart`
Expected: FAIL (or load error if `mount.dart` is still exported).

- [ ] **Step 3: Refactor framework.dart to use const classes and isolate mount.dart**

In `lib/bloom_js_native.dart`, remove `export 'src/mount.dart';`.
In `lib/src/framework.dart`, convert element helper functions into `class ... extends ElNode` with `const` constructors.
In `lib/browser.dart`, export `src/mount.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_js_native && dart test test/framework_test.dart`
Expected: PASS with 0 errors.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_js_native/
git commit -m "feat(bloom_js_native): decouple VM core from web mount and add const AST classes"
```

---

### Task 2: Pure Dart Event Abstraction & SSR HTML Sanitized Renderer

**Files:**
- Modify: `packages/bloom_js_native/lib/src/events.dart`
- Modify: `packages/bloom_js_native/lib/src/html.dart`
- Test: `packages/bloom_js_native/test/events_test.dart`
- Test: `packages/bloom_js_native/test/html_test.dart`

**Interfaces:**
- Consumes: `BloomNode`, `ElNode`, `TextNode`, `LiveNode`, `ShowNode`, `ForEachNode`, `RawHtmlNode`
- Produces: `renderToHtml(BloomNode node) -> String`, `escapeHtml(String text) -> String`, `BloomEvent`

- [ ] **Step 1: Write the failing tests for SSR HTML generation and XSS escaping**

In `test/html_test.dart`:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('renderToHtml', () {
    test('renders nested elements with attributes and escapes HTML', () {
      final app = Div(
        className: 'card',
        attrs: {'data-id': '123'},
        children: [
          H1(text: '<script>alert("xss")</script>'),
          Input(attrs: {'placeholder': 'Search "quoted" & safe'}),
          Raw('<span>trusted</span>'),
        ],
      );
      final html = renderToHtml(app);
      expect(html, contains('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'));
      expect(html, contains('Search &quot;quoted&quot; &amp; safe'));
      expect(html, contains('<span>trusted</span>'));
    });

    test('evaluates reactive nodes statically for SSR', () {
      final count = signal(42);
      final app = Div(children: [
        Live(() => Span(text: 'Value: ${count.value}')),
        Show(() => count.value > 0, child: const Text('Positive')),
        ForEach<String>(() => ['A', 'B'], (s) => Li(text: s)),
      ]);
      final html = renderToHtml(app);
      expect(html, contains('Value: 42'));
      expect(html, contains('Positive'));
      expect(html, contains('<li>A</li><li>B</li>'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it passes or fails**

Run: `cd packages/bloom_js_native && dart test test/html_test.dart`

- [ ] **Step 3: Implement renderToHtml with void elements, XSS escaping, and SSR evaluation**

Ensure void elements (`<input>`, `<img>`, `<hr>`, `<br>`, `<meta>`, `<link>`) render without closing tags, attributes are safely encoded, and `RawHtmlNode` passes verbatim.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/bloom_js_native && dart test test/html_test.dart test/events_test.dart`
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_js_native/
git commit -m "feat(bloom_js_native): robust SSR html renderer with XSS protection and event abstraction"
```

---

### Task 3: NPM Import Maps Generator & Browser DOM Mount Backend

**Files:**
- Modify: `packages/bloom_js_native/lib/src/npm.dart`
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Test: `packages/bloom_js_native/test/npm_test.dart`

**Interfaces:**
- Consumes: `BloomNode`, `NpmDependency`, `NpmImportMap`
- Produces: `buildImportMap()`, `mount()`, `mountToElement()`, `BloomMountHandle`

- [ ] **Step 1: Write test for NPM Import Map generation**

In `test/npm_test.dart`:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('npm import maps', () {
    test('generates pinned ESM CDN importmap script tag', () {
      final map = NpmImportMap(dependencies: [
        const NpmDependency('canvas-confetti', '^1.9.3'),
        const NpmDependency('dayjs', '^1.11.10', cdn: NpmCdn.jsdelivr),
      ]);
      final scriptTag = map.toScriptTag();
      expect(scriptTag, contains('<script type="importmap">'));
      expect(scriptTag, contains('"canvas-confetti": "https://esm.sh/canvas-confetti@^1.9.3"'));
      expect(scriptTag, contains('"dayjs": "https://cdn.jsdelivr.net/npm/dayjs@^1.11.10/+esm"'));
    });
  });
}
```

- [ ] **Step 2: Run test and verify pass**

Run: `cd packages/bloom_js_native && dart test test/npm_test.dart`

- [ ] **Step 3: Refine mount.dart in browser backend**

Refine `lib/src/mount.dart` with robust `_Region` teardown, DOM event wrapping, and value/checked extraction.

- [ ] **Step 4: Commit**

```bash
git add packages/bloom_js_native/
git commit -m "feat(bloom_js_native): npm import map builder and browser mount lifecycle"
```

---

### Task 4: Isomorphic Client Router & Navigation Primitives

**Files:**
- Modify: `packages/bloom_js_native/lib/src/router.dart`
- Test: `packages/bloom_js_native/test/router_test.dart`

**Interfaces:**
- Consumes: `BloomNode`, `signals`
- Produces: `BloomRouter`, `BloomRoute`, `Link`, `RouteMatch`, `useRouter()`

- [ ] **Step 1: Write failing tests for router pattern matching & param extraction**

In `test/router_test.dart`:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('BloomRouter', () {
    test('matches static and parameterized routes', () {
      final router = BloomRouter(
        routes: [
          BloomRoute(path: '/', builder: (_) => const H1(text: 'Home')),
          BloomRoute(path: '/todos/:id', builder: (match) => H1(text: 'Todo ${match.params['id']}')),
        ],
        initialPath: '/todos/42',
      );

      expect(router.currentPath.value, '/todos/42');
      final match = router.currentMatch;
      expect(match, isNotNull);
      expect(match!.params['id'], '42');

      final rendered = renderToHtml(router.outlet());
      expect(rendered, contains('Todo 42'));

      router.navigate('/');
      expect(router.currentPath.value, '/');
      expect(renderToHtml(router.outlet()), contains('Home'));
    });

    test('Link renders anchor descriptor with correct href and attributes', () {
      const link = Link(to: '/about', className: 'nav-link', child: Text('About'));
      expect(link.tag, 'a');
      expect(link.attrs!['href'], '/about');
      expect(link.className, 'nav-link');
    });
  });
}
```

- [ ] **Step 2: Run test to verify behavior**

Run: `cd packages/bloom_js_native && dart test test/router_test.dart`

- [ ] **Step 3: Implement BloomRouter and Link with const constructors**

Convert `Link` to `class Link extends ElNode` with `const` constructor, ensuring 0 lint warnings.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_js_native && dart test test/router_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_js_native/
git commit -m "feat(bloom_js_native): isomorphic client router with reactive path signals and const Link"
```

---

### Task 5: Bloom SEO Package (`packages/bloom_seo`)

**Files:**
- Modify: `packages/bloom_seo/lib/bloom_seo.dart`
- Modify: `packages/bloom_seo/lib/src/head.dart`
- Modify: `packages/bloom_seo/lib/src/json_ld.dart`
- Modify: `packages/bloom_seo/lib/src/prerender.dart`
- Modify: `packages/bloom_seo/lib/src/sitemap.dart`
- Test: `packages/bloom_seo/test/seo_test.dart`

**Interfaces:**
- Consumes: `package:bloom_js_native/bloom_js_native.dart`
- Produces: `HeadManager`, `SeoMeta`, `JsonLd`, `prerenderRoute()`, `SitemapBuilder`

- [ ] **Step 1: Write test for SEO head metadata and pre-rendering**

In `packages/bloom_seo/test/seo_test.dart`:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';
import 'package:test/test.dart';

void main() {
  group('bloom_seo', () {
    test('generates complete meta tags, OG, and Twitter tags', () {
      final seo = SeoMeta(
        title: 'Bloom JS Native',
        description: 'Fine-grained Dart-to-DOM web framework.',
        canonicalUrl: 'https://bloom.dev/js',
        ogImageUrl: 'https://bloom.dev/og.png',
        twitterCard: 'summary_large_image',
      );
      final headHtml = seo.toHtml();
      expect(headHtml, contains('<title>Bloom JS Native</title>'));
      expect(headHtml, contains('<meta name="description" content="Fine-grained Dart-to-DOM web framework.">'));
      expect(headHtml, contains('<meta property="og:image" content="https://bloom.dev/og.png">'));
      expect(headHtml, contains('<link rel="canonical" href="https://bloom.dev/js">'));
    });

    test('prerenderRoute produces full standalone HTML document', () {
      final html = prerenderRoute(
        title: 'My Page',
        description: 'Test Description',
        body: const Div(className: 'app', children: [H1(text: 'Hello World')]),
      );
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<title>My Page</title>'));
      expect(html, contains('<h1>Hello World</h1>'));
    });

    test('SitemapBuilder creates valid XML sitemap', () {
      final builder = SitemapBuilder(baseUrl: 'https://bloom.dev');
      builder.addRoute('/', priority: 1.0, changefreq: 'daily');
      builder.addRoute('/docs', priority: 0.8);
      final xml = builder.buildXml();
      expect(xml, contains('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'));
      expect(xml, contains('<loc>https://bloom.dev/</loc>'));
      expect(xml, contains('<priority>1.0</priority>'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it passes/fails**

Run: `cd packages/bloom_seo && dart test`

- [ ] **Step 3: Fix analysis issues in bloom_seo (remove unnecessary library directive)**

Update `packages/bloom_seo/lib/bloom_seo.dart` to clean standard library directives.

- [ ] **Step 4: Run dart analyze and dart test**

Run: `cd packages/bloom_seo && dart analyze && dart test`
Expected: 0 issues, ALL TESTS PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_seo/
git commit -m "feat(bloom_seo): SEO metadata, JSON-LD, sitemap builder and static pre-renderer"
```

---

### Task 6: Modern Dark Linear/Vercel Example Demo & Build Script

**Files:**
- Modify: `packages/bloom_js_native/example/main.dart`
- Modify: `packages/bloom_js_native/example/index.html`
- Modify: `packages/bloom_js_native/example/build.sh`
- Modify: `packages/bloom_js_native/README.md`

**Interfaces:**
- Consumes: `package:bloom_js_native/bloom_js_native.dart`, `package:bloom_js_native/browser.dart`
- Produces: Compiled JS bundle `example/build/main.dart.js`, interactive UI demo.

- [ ] **Step 1: Write interactive dark Linear/Vercel style Counter & Todo demo**

In `example/main.dart`:
Demonstrate `signal`, `computed`, `Live`, `Show`, `ForEach`, `Input`, `Button`, styled with the carbon dark aesthetic (`#09090B`, `#14141A`, `#1E1E24`, `#6366F1`), clean Material vector/SVG icons, and responsive task filter states.

- [ ] **Step 2: Update example/index.html and example/build.sh**

Configure `index.html` with modern Inter font, reset CSS, and import map. Ensure `build.sh` runs `dart compile js -O4 web/main.dart -o build/main.dart.js`.

- [ ] **Step 3: Compile and test example**

Run: `cd packages/bloom_js_native/example && bash build.sh`
Expected: Successful compilation to JS.

- [ ] **Step 4: Commit**

```bash
git add packages/bloom_js_native/example/
git commit -m "feat(bloom_js_native): dark Linear-style interactive demo app with build script"
```

---

### Task 7: Full Monorepo Quality Gate & Test Verification

**Files:**
- Modify: `packages/bloom_js_native/analysis_options.yaml`
- Modify: `packages/bloom_seo/analysis_options.yaml`

- [ ] **Step 1: Run dart analyze on both packages**

Run: `dart analyze packages/bloom_js_native packages/bloom_seo`
Expected: 0 errors, 0 warnings.

- [ ] **Step 2: Run dart test on both packages**

Run: `cd packages/bloom_js_native && dart test`
Run: `cd packages/bloom_seo && dart test`
Expected: All tests pass.

- [ ] **Step 3: Final Commit & Summary**

```bash
git add .
git commit -m "chore: verify zero analysis warnings and green test suite for bloom_js_native and bloom_seo"
```
