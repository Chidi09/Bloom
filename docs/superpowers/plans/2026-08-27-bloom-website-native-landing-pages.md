# Bloom JS Native Website Landing Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pure Bloom JS Native static website for the Bloom platform landing pages (`/`, `/bloom`, `/build`, `/ship`, `/server`) with SSG generation, marketplace-grade UI primitives, and fine-grained client interactivity.

**Architecture:** A static site generator in pure Dart that compiles AST descriptor trees (`BloomNode`) to static HTML in `dist/` via `renderToHtml()` and attaches client-side reactive islands (Command Palette, Toast system, Telemetry Ticker) via `web/main.dart` with `signals`.

**Tech Stack:** Dart 3.x, `package:bloom_js_native`, `package:bloom_seo`, `package:web`, Tailwind CSS utilities.

**Spec:** [docs/superpowers/specs/2026-08-27-bloom-website-native-landing-pages-design.md](file:///root/dev/Bloom/docs/superpowers/specs/2026-08-27-bloom-website-native-landing-pages-design.md)

## Global Constraints

* **Strict Aesthetics**: Dark carbon palette (`#09090B`), elevated surfaces (`#14141A`), borders (`#1E1E24`), indigo accent (`#6366F1`).
* **Zero Toy Emojis**: Always use pure SVG HugeIcons with 1.5px stroke.
* **Entry Point Isolation**: Never import `package:bloom_js_native/browser.dart` into SSG or test code; use it only in `web/main.dart`.
* **Zero Linter Warnings**: `dart analyze` must pass with 0 errors and 0 warnings.

---

### Task 1: Package Scaffolding & Configuration

**Files:**
- Create: `apps/bloom_website_native/pubspec.yaml`
- Create: `apps/bloom_website_native/bloom.yaml`
- Create: `apps/bloom_website_native/web/index.html`
- Create: `apps/bloom_website_native/web/styles/main.css`
- Test: `apps/bloom_website_native/test/scaffold_test.dart`

**Interfaces:**
- Produces: Project dependencies configured with local path references to `../../packages/bloom_js_native` and `../../packages/bloom_seo`.

- [ ] **Step 1: Write the failing scaffold test**

```dart
// test/scaffold_test.dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  test('Bloom JS Native core import operates in VM environment', () {
    const node = Div(className: 'test-node', text: 'Scaffold OK');
    final html = renderToHtml(node);
    expect(html, contains('class="test-node"'));
    expect(html, contains('Scaffold OK'));
  });
}
```

- [ ] **Step 2: Create `pubspec.yaml` and `bloom.yaml`**

```yaml
# apps/bloom_website_native/pubspec.yaml
name: bloom_website_native
description: Official Bloom marketing website built with Bloom JS Native SSG.
version: 1.0.0
publish_to: none

environment:
  sdk: ^3.5.0

dependencies:
  bloom_js_native:
    path: ../../packages/bloom_js_native
  bloom_seo:
    path: ../../packages/bloom_seo
  web: ^1.0.0

dev_dependencies:
  lints: ^4.0.0
  test: ^1.25.0
```

```yaml
# apps/bloom_website_native/bloom.yaml
name: bloom_website_native
target: web_dom
```

- [ ] **Step 3: Create `web/index.html` and `web/styles/main.css`**

```html
<!-- apps/bloom_website_native/web/index.html -->
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="/styles/main.css">
  <script src="https://cdn.tailwindcss.com"></script>
  <script>
    tailwind.config = {
      darkMode: 'class',
      theme: {
        extend: {
          colors: {
            carbon: '#09090B',
            surface: '#14141A',
            elevated: '#18181B',
            borderSubtle: '#1E1E24',
            borderProminent: '#27272A',
            brand: '#6366F1'
          }
        }
      }
    }
  </script>
</head>
<body class="bg-[#09090B] text-zinc-100 min-h-screen antialiased selection:bg-indigo-600 selection:text-white font-sans">
  <div id="app"></div>
  <div id="bloom-palette"></div>
  <div id="bloom-toast"></div>
  <script type="module" src="/main.js"></script>
</body>
</html>
```

```css
/* apps/bloom_website_native/web/styles/main.css */
:root {
  --bg: #09090B;
  --surface: #14141A;
  --border: #1E1E24;
  --text: #F4F4F5;
  --text-muted: #A1A1AA;
  --brand: #6366F1;
}

body {
  background-color: #09090B;
  color: #F4F4F5;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
}
```

- [ ] **Step 4: Run `dart pub get` and verify test passes**

Run: `cd /root/dev/Bloom/apps/bloom_website_native && dart pub get && dart test`
Expected: 1 test passed.

- [ ] **Step 5: Commit**

```bash
git add apps/bloom_website_native/
git commit -m "feat(website): scaffold bloom_website_native package"
```

---

### Task 2: Design Tokens & Marketplace UI Primitives

**Files:**
- Create: `apps/bloom_website_native/lib/design/tokens.dart`
- Create: `apps/bloom_website_native/lib/components/cn.dart`
- Create: `apps/bloom_website_native/lib/components/button_variants.dart`
- Create: `apps/bloom_website_native/lib/components/huge_icons.dart`
- Create: `apps/bloom_website_native/lib/components/ui.dart`
- Test: `apps/bloom_website_native/test/ui_components_test.dart`

**Interfaces:**
- Produces: `cn(List<String?> classes)`, `button(label: ..., variant: ...)`, `hugeIcon(name, className: ...)`, `badge(label: ..., variant: ...)`, `card(children: ...)`, `codeBlock(code, language: ...)`.

- [ ] **Step 1: Write the failing UI components test**

```dart
// test/ui_components_test.dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_website_native/components/ui.dart';
import 'package:bloom_website_native/components/huge_icons.dart';

void main() {
  test('hugeIcon renders inline SVG without emojis', () {
    final icon = hugeIcon('terminal', className: 'w-4 h-4 text-indigo-400');
    final html = renderToHtml(icon);
    expect(html, contains('<svg'));
    expect(html, contains('viewBox="0 0 24 24"'));
    expect(html, isNot(contains('🔥')));
  });

  test('bloomButton generates correct class names', () {
    final btn = bloomButton(label: 'Get Started', variant: 'brand');
    final html = renderToHtml(btn);
    expect(html, contains('Get Started'));
    expect(html, contains('bg-[#6366F1]'));
  });

  test('bloomBadge renders semantic variants', () {
    final b = bloomBadge(label: 'v1.0 Ready', variant: 'brand');
    final html = renderToHtml(b);
    expect(html, contains('v1.0 Ready'));
    expect(html, contains('rounded-full'));
  });
}
```

- [ ] **Step 2: Implement `tokens.dart`, `cn.dart`, `huge_icons.dart`, `button_variants.dart`, and `ui.dart`**

Implement tokens with Linear/Vercel palette, clean HugeIcon SVGs (`terminal`, `zap`, `layers`, `server`, `rocket`, `check`, `copy`, `search`, `code`, `github`, `chevron-right`, `arrow-right`, `command`, `cpu`), and UI components modeled after `benchmarks/marketplace/bloom`.

- [ ] **Step 3: Run tests and verify they pass**

Run: `cd /root/dev/Bloom/apps/bloom_website_native && dart test test/ui_components_test.dart`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add apps/bloom_website_native/lib/ apps/bloom_website_native/test/
git commit -m "feat(website): implement design tokens, hugeicons, and ui primitives"
```

---

### Task 3: Common Layout, Sticky Navbar & Footer

**Files:**
- Create: `apps/bloom_website_native/lib/components/navbar.dart`
- Create: `apps/bloom_website_native/lib/components/footer.dart`
- Create: `apps/bloom_website_native/lib/components/tech_marquee.dart`
- Create: `apps/bloom_website_native/lib/pages/page_layout.dart`
- Test: `apps/bloom_website_native/test/layout_test.dart`

**Interfaces:**
- Consumes: `hugeIcon`, `bloomButton`, `cn` from Task 2.
- Produces: `pageLayout(currentPath: ..., title: ..., description: ..., child: ...) -> BloomNode`.

- [ ] **Step 1: Write failing layout test**

```dart
// test/layout_test.dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_website_native/pages/page_layout.dart';

void main() {
  test('pageLayout encapsulates navbar, main content, and footer', () {
    final layout = pageLayout(
      currentPath: '/',
      title: 'Bloom Platform',
      description: 'The Application Platform for Dart & Flutter',
      child: Div(className: 'content-test', text: 'Hello World'),
    );
    final html = renderToHtml(layout);
    expect(html, contains('<nav'));
    expect(html, contains('content-test'));
    expect(html, contains('Hello World'));
    expect(html, contains('<footer'));
  });
}
```

- [ ] **Step 2: Implement Navbar, Footer, TechMarquee, and PageLayout**

Include sticky header with backdrop blur (`backdrop-blur-md bg-[#09090B]/80`), links to `/` (Home), `/bloom` (Runtime), `/build` (Build), `/ship` (Ship), `/server` (Server), `/docs` (Docs), and GitHub button.

- [ ] **Step 3: Run test to verify it passes**

Run: `cd /root/dev/Bloom/apps/bloom_website_native && dart test test/layout_test.dart`
Expected: 1 test passed.

- [ ] **Step 4: Commit**

```bash
git add apps/bloom_website_native/lib/ apps/bloom_website_native/test/
git commit -m "feat(website): implement navbar, footer, tech marquee, and page layout"
```

---

### Task 4: Platform Home Page & Live Telemetry Benchmark

**Files:**
- Create: `apps/bloom_website_native/lib/components/telemetry_panel.dart`
- Create: `apps/bloom_website_native/lib/pages/home_page.dart`
- Test: `apps/bloom_website_native/test/home_page_test.dart`

**Interfaces:**
- Consumes: `pageLayout`, `bloomCard`, `bloomBadge`, `bloomButton`, `codeBlock`, `hugeIcon`.
- Produces: `homePage() -> BloomNode`.

- [ ] **Step 1: Write failing home page test**

```dart
// test/home_page_test.dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_website_native/pages/home_page.dart';

void main() {
  test('homePage renders complete hero, pillars, telemetry, and features', () {
    final page = homePage();
    final html = renderToHtml(page);
    expect(html, contains('The Application Platform for Dart &amp; Flutter'));
    expect(html, contains('bloom create'));
    expect(html, contains('Fine-Grained Signals vs VDOM Diffing'));
  });
}
```

- [ ] **Step 2: Implement `telemetry_panel.dart` and `home_page.dart`**

Implement:
- Hero: Headline, eyebrow badge, action buttons, copyable CLI box `bloom create my_app`.
- 3 Product Pillar Cards: Build, Ship, Bloom.
- Benchmark Telemetry Panel: Live stress ticker displaying fine-grained signals vs VDOM diffing.
- Feature Grid: Sub-ms SSR, OTA patches, multi-isolate server.

- [ ] **Step 3: Run test to verify it passes**

Run: `cd /root/dev/Bloom/apps/bloom_website_native && dart test test/home_page_test.dart`
Expected: 1 test passed.

- [ ] **Step 4: Commit**

```bash
git add apps/bloom_website_native/lib/ apps/bloom_website_native/test/
git commit -m "feat(website): implement platform home page and telemetry panel"
```

---

### Task 5: Platform Pillar Pages (Runtime, Build, Ship, Server)

**Files:**
- Create: `apps/bloom_website_native/lib/pages/bloom_page.dart`
- Create: `apps/bloom_website_native/lib/pages/build_page.dart`
- Create: `apps/bloom_website_native/lib/pages/ship_page.dart`
- Create: `apps/bloom_website_native/lib/pages/server_page.dart`
- Test: `apps/bloom_website_native/test/pillar_pages_test.dart`

**Interfaces:**
- Produces: `bloomPage() -> BloomNode`, `buildPage() -> BloomNode`, `shipPage() -> BloomNode`, `serverPage() -> BloomNode`.

- [ ] **Step 1: Write failing pillar pages test**

```dart
// test/pillar_pages_test.dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_website_native/pages/bloom_page.dart';
import 'package:bloom_website_native/pages/build_page.dart';
import 'package:bloom_website_native/pages/ship_page.dart';
import 'package:bloom_website_native/pages/server_page.dart';

void main() {
  test('bloomPage renders Signals & AST architecture', () {
    final html = renderToHtml(bloomPage());
    expect(html, contains('Signals Engine'));
  });

  test('buildPage renders CLI & fast compilation details', () {
    final html = renderToHtml(buildPage());
    expect(html, contains('Incremental Compilation'));
  });

  test('shipPage renders OTA release pipeline', () {
    final html = renderToHtml(shipPage());
    expect(html, contains('Over-The-Air'));
  });

  test('serverPage renders multi-isolate runtime and OpenAPI', () {
    final html = renderToHtml(serverPage());
    expect(html, contains('Multi-Isolate Server'));
  });
}
```

- [ ] **Step 2: Implement all 4 pillar pages**

Port the visual content from `bloom-website/src/pages/bloom.astro`, `build.astro`, `ship.astro`, and `server.astro` into clean Bloom JS Native AST components.

- [ ] **Step 3: Run test to verify it passes**

Run: `cd /root/dev/Bloom/apps/bloom_website_native && dart test test/pillar_pages_test.dart`
Expected: 4 tests passed.

- [ ] **Step 4: Commit**

```bash
git add apps/bloom_website_native/lib/pages/ apps/bloom_website_native/test/
git commit -m "feat(website): implement runtime, build, ship, and server landing pages"
```

---

### Task 6: Static Site Generator (SSG) Builder & SEO Pipeline

**Files:**
- Create: `apps/bloom_website_native/bin/ssg.dart`
- Test: `apps/bloom_website_native/test/ssg_render_test.dart`

**Interfaces:**
- Consumes: All pages from Tasks 4 and 5, `package:bloom_seo`.
- Produces: `dist/index.html`, `dist/bloom/index.html`, `dist/build/index.html`, `dist/ship/index.html`, `dist/server/index.html`, `dist/sitemap.xml`, `dist/llms.txt`.

- [ ] **Step 1: Write failing SSG test**

```dart
// test/ssg_render_test.dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('SSG compiler generates complete static distribution directory', () async {
    final result = await Process.run('dart', ['run', 'bin/ssg.dart']);
    expect(result.exitCode, equals(0), reason: result.stderr.toString());

    expect(File('dist/index.html').existsSync(), isTrue);
    expect(File('dist/bloom/index.html').existsSync(), isTrue);
    expect(File('dist/build/index.html').existsSync(), isTrue);
    expect(File('dist/ship/index.html').existsSync(), isTrue);
    expect(File('dist/server/index.html').existsSync(), isTrue);
    expect(File('dist/sitemap.xml').existsSync(), isTrue);
    expect(File('dist/llms.txt').existsSync(), isTrue);
  });
}
```

- [ ] **Step 2: Implement `bin/ssg.dart`**

Write the SSG runner that executes `renderToHtml()` for every page, writes files into `dist/`, builds `sitemap.xml` with `SitemapBuilder`, generates `llms.txt`, and copies static assets.

- [ ] **Step 3: Run SSG test and verify generation**

Run: `cd /root/dev/Bloom/apps/bloom_website_native && dart test test/ssg_render_test.dart`
Expected: 1 test passed, `dist/` contains all static assets.

- [ ] **Step 4: Commit**

```bash
git add apps/bloom_website_native/bin/ apps/bloom_website_native/test/
git commit -m "feat(website): implement static site generator ssg builder and sitemap"
```

---

### Task 7: Client Reactivity Islands & Web JS Bundle

**Files:**
- Create: `apps/bloom_website_native/lib/components/command_palette.dart`
- Create: `apps/bloom_website_native/lib/components/toast_system.dart`
- Create: `apps/bloom_website_native/web/main.dart`
- Test: Verify compilation via `dart compile js web/main.dart -o dist/main.js`

**Interfaces:**
- Consumes: `package:bloom_js_native/browser.dart`, `package:web`.
- Produces: `dist/main.js` mounting reactive islands for Command Palette (`Ctrl+K`), Toast messages, and real-time stress ticker.

- [ ] **Step 1: Implement `command_palette.dart`, `toast_system.dart`, and `web/main.dart`**

Implement keyboard shortcuts (`Ctrl+K` / `Cmd+K`), fast search modal with quick route navigation, clipboard copy toast triggers, and live stress ticker timer in `web/main.dart`.

- [ ] **Step 2: Verify `dart compile js` builds without errors**

Run: `cd /root/dev/Bloom/apps/bloom_website_native && dart compile js web/main.dart -o dist/main.js -O2`
Expected: Exit code 0, `dist/main.js` generated.

- [ ] **Step 3: Run complete static analysis**

Run: `cd /root/dev/Bloom/apps/bloom_website_native && dart analyze . && dart test`
Expected: 0 errors, 0 warnings, all unit tests pass.

- [ ] **Step 4: Commit**

```bash
git add apps/bloom_website_native/
git commit -m "feat(website): add client interactivity islands, command palette, and compiled main.js"
```
