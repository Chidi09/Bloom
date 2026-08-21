# Bloom JS Native (M4–M6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Milestones M4–M6 for Bloom JS Native: Bun-first vendoring CLI tooling, fast SSR endpoints on `BloomApiRouter`, pure-Dart SSG pre-rendering in `BloomPrerenderEngine`, full JS-interop plugin integration in `examples/bloom_todo/apps/web`, and comprehensive documentation.

**Architecture:** Augment existing CLI modules (`NpmVendorAssembler`) to detect and use Bun for offline ESM bundling with CDN fallback; extend `BloomApiRouter` with native `.ssr()` endpoint executing `renderToHtml()` in <1ms; upgrade `BloomPrerenderEngine` to perform instant pure-Dart SSG; wire existing web plugins and views in `examples/bloom_todo/apps/web`.

**Tech Stack:** Dart 3.4+, Bun CLI, `bloom_js_native`, `bloom_seo`, `bloom_framework`, `bloom_cli`.

**Spec:** `docs/superpowers/specs/2026-08-21-bloom-js-native-m4-m6-design.md`

## Global Constraints
- Maximize reuse of existing files in `packages/bloom_cli/lib/src/npm/`, `packages/bloom_framework/lib/src/server/`, and `examples/bloom_todo/apps/web/`.
- Do not create redundant copies of existing plugin bindings or view components.
- Zero errors and zero warnings across `dart analyze`.
- All tests must pass cleanly via `dart test`.

---

### Task 1: Bun-First Vendoring Toolchain in `bloom_cli`

**Files:**
- Modify: `packages/bloom_cli/lib/src/npm/npm_vendor_assembler.dart`
- Modify: `packages/bloom_cli/lib/src/commands/npm_command.dart`
- Test: `packages/bloom_cli/test/bloom_npm_vendor_test.dart`

**Interfaces:**
- Consumes: `BloomProject`, `NpmManifest`, `NpmResolver`
- Produces: `NpmVendorAssembler.assemble({bool forceBun = false})`

- [ ] **Step 1: Write test for Bun-first detection and vendoring assembler**

In `packages/bloom_cli/test/bloom_npm_vendor_test.dart`:
```dart
import 'dart:io';
import 'package:bloom_cli/src/npm/npm_manifest.dart';
import 'package:bloom_cli/src/npm/npm_vendor_assembler.dart';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:test/test.dart';

void main() {
  group('NpmVendorAssembler', () {
    test('detects local vendor dependencies and builds import map', () async {
      final tempDir = Directory.systemTemp.createTempSync('bloom_vendor_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      File('${tempDir.path}/bloom.yaml').writeAsStringSync('''
name: test_app
target: web_dom
npm_dependencies:
  canvas-confetti: ^1.9.3
  lucide: ^0.460.0
''');

      Directory('${tempDir.path}/web').createSync(recursive: true);
      File('${tempDir.path}/web/index.html').writeAsStringSync('<html><head></head><body></body></html>');

      final project = BloomProject(rootDir: tempDir);
      final assembler = NpmVendorAssembler(project);
      expect(assembler, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it loads**

Run: `cd packages/bloom_cli && dart test test/bloom_npm_vendor_test.dart`

- [ ] **Step 3: Augment NpmVendorAssembler with Bun detection & snapshot logic**

Update `packages/bloom_cli/lib/src/npm/npm_vendor_assembler.dart` to check `which bun` / `Process.run('bun', ['--version'])`, run `bun add` if available, or fetch via CDN, generating local `./vendor/<pkg>.min.js` import maps and updating `web/index.html`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_cli && dart test test/bloom_npm_vendor_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_cli/
git commit -m "feat(bloom_cli): add Bun-first ESM vendoring with CDN fallback"
```

---

### Task 2: Server-Side SSR Endpoint on `BloomApiRouter`

**Files:**
- Modify: `packages/bloom_framework/lib/src/server/api_router.dart`
- Modify: `packages/bloom_framework/pubspec.yaml`
- Test: `packages/bloom_framework/test/ssr_router_test.dart`

**Interfaces:**
- Consumes: `BloomNode` from `bloom_js_native`, `HeadManager` from `bloom_seo`
- Produces: `BloomApiRouter.ssr(String path, BloomNode Function(BloomRequest) builder, ...)`

- [ ] **Step 1: Write test for BloomApiRouter SSR endpoint**

In `packages/bloom_framework/test/ssr_router_test.dart`:
```dart
import 'package:bloom_framework/bloom_framework.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';
import 'package:test/test.dart';

void main() {
  group('BloomApiRouter SSR', () {
    test('renders BloomNode tree to sub-millisecond HTML response', () async {
      final router = BloomApiRouter();
      router.ssr('/', (req) => Div(
        className: 'hero',
        children: [H1(text: 'Welcome to Bloom SSR')],
      ), head: (req) => HeadManager(initialTitle: 'Bloom Server App'));

      final req = BloomRequest.fake(method: 'GET', uri: Uri.parse('http://localhost/'));
      final res = await router.handle(req);

      expect(res.statusCode, 200);
      expect(res.headers['content-type'], contains('text/html'));
      expect(res.bodyString, contains('<title>Bloom Server App</title>'));
      expect(res.bodyString, contains('<h1>Welcome to Bloom SSR</h1>'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/bloom_framework && dart test test/ssr_router_test.dart`

- [ ] **Step 3: Implement .ssr() on BloomApiRouter**

In `packages/bloom_framework/lib/src/server/api_router.dart`, implement `ssr()` integrating `renderToHtml()` and `HeadManager.wrapDocument()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_framework && dart test test/ssr_router_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_framework/
git commit -m "feat(bloom_framework): add native SSR endpoint on BloomApiRouter"
```

---

### Task 3: Pure-Dart SSG in `BloomPrerenderEngine`

**Files:**
- Modify: `packages/bloom_cli/lib/src/web/prerender_engine.dart`
- Test: `packages/bloom_cli/test/bloom_prerender_test.dart`

**Interfaces:**
- Consumes: `prerenderRoutes()` from `bloom_seo`, `bloom.yaml`
- Produces: `BloomPrerenderEngine.prerenderNativeRoutes()`

- [ ] **Step 1: Write test for pure-Dart SSG execution in prerender engine**

In `packages/bloom_cli/test/bloom_prerender_test.dart`:
```dart
import 'dart:io';
import 'package:bloom_cli/src/web/prerender_engine.dart';
import 'package:test/test.dart';

void main() {
  group('BloomPrerenderEngine', () {
    test('supports instant pure-Dart SSG without browser launch', () async {
      final engine = BloomPrerenderEngine();
      expect(engine.isBrowserRunning, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test and implement pure-Dart SSG route output**

Update `packages/bloom_cli/lib/src/web/prerender_engine.dart` with `prerenderNative()` support.

- [ ] **Step 3: Run test to verify pass**

Run: `cd packages/bloom_cli && dart test test/bloom_prerender_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/bloom_cli/
git commit -m "feat(bloom_cli): add pure-Dart SSG pre-rendering support"
```

---

### Task 4: Connect Existing Web Views & Plugins in `examples/bloom_todo/apps/web`

**Files:**
- Modify: `examples/bloom_todo/apps/web/lib/main.dart`
- Modify: `examples/bloom_todo/apps/web/pubspec.yaml`
- Modify: `examples/bloom_todo/apps/web/web/index.html`

**Interfaces:**
- Consumes: `package:bloom_js_native/bloom_js_native.dart`, `package:bloom_js_native/browser.dart`, `plugins/`, `views/`
- Produces: Full Todo interactive web app using Bloom JS Native

- [ ] **Step 1: Wire existing views to Bloom JS Native in web app entry point**

In `examples/bloom_todo/apps/web/lib/main.dart`, mount the main shell connecting `todo_store.dart`, `sidebar.dart`, `today_view.dart`, `kanban_view.dart`, and JS plugins (`lucide`, `canvas_confetti`, `sonner`).

- [ ] **Step 2: Compile web app**

Run: `cd examples/bloom_todo/apps/web && dart compile js -O4 -o web/main.dart.js lib/main.dart`
Expected: Successful compilation to JS.

- [ ] **Step 3: Commit**

```bash
git add examples/bloom_todo/apps/web/
git commit -m "feat(examples/bloom_todo): wire full web views and JS plugins with bloom_js_native"
```

---

### Task 5: Monorepo Quality Gate & Documentation Finalization

**Files:**
- Modify: `GEMINI.md`
- Modify: `packages/bloom_js_native/docs/SSR_AND_SEO.md`
- Modify: `packages/bloom_js_native/docs/NPM_INTEROP.md`

- [ ] **Step 1: Run dart analyze on all monorepo packages**

Run: `dart analyze packages/bloom_js_native packages/bloom_seo packages/bloom_framework packages/bloom_cli`
Expected: 0 errors, 0 warnings.

- [ ] **Step 2: Run all tests**

Run: `cd packages/bloom_js_native && dart test`
Run: `cd packages/bloom_seo && dart test`
Run: `cd packages/bloom_framework && dart test`
Expected: All tests pass.

- [ ] **Step 3: Update GEMINI.md with Bloom JS Native architectural contract**

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "docs: finalize Bloom JS Native architecture contract and docs in GEMINI.md"
```
