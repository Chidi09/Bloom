# ARCHITECTURE — Bloom JS Native

## Core insight (what v1 got wrong)

v1 tried to own rendering (Flutter web canvas/Skia). This time the browser owns rendering. Dart owns reactivity, compilation, and tooling. The descriptor tree is the seam.

```
Dart component code
      ↓ builds
Descriptor tree (BloomNode)   ← pure Dart, VM-testable, no DOM
      ↓                       ↓
 BrowserMount              renderToHtml()
 package:web + signals      String (SSR/SSG/SEO)
```

**Dual-backend gives SSR for free** — same tree, two interpreters. ~90% tests run on VM.

## Why no VDOM

- Fine-grained signals already know exactly which nodes depend on which state.
- VDOM diff is O(n) reconciliation of a tree you just built to discover what already-known signals could tell you.
- Instead: each `Live`/`Show`/`ForEach` registers a `signal effect` that patches only its own DOM region using comment-node sentinels. No tree diff, and `ForEach(..., key:)` performs keyed in-place DOM reconciliation.

## Why no Flutter on web target

- Widgets, Canvas, Skia/CanvasKit are a rendering engine that fights the browser's native CSS/layout/a11y.
- Real DOM gives Tailwind, native form controls, view transitions, and sub-50KB hello-world (dart2js) without a canvas fallback.

## Package layout

```
packages/bloom_js_native/
  lib/bloom_js_native.dart — pure-Dart core entry point (SSR/VM-safe)
  lib/browser.dart         — browser DOM entry point (mountApp, mount, hydrate, router)
  lib/ui.dart              — shadcn-style UI primitives & design tokens
  lib/tags.dart            — concise lowercase HTML builders (`as h`)
  lib/widgets.dart         — optional Flutter-shaped layout helpers
  lib/ssg.dart             — static site generator (`generateStaticSite`, VM-only)
  lib/src/framework.dart   — BloomNode sealed hierarchy + capitalized builders
  lib/src/events.dart      — BloomEvent abstraction (browser impl + test fake)
  lib/src/html.dart        — renderToHtml / renderToDocument / streaming Suspense (SSR)
  lib/src/isr.dart         — BloomRevalidateConfig & BloomIsrRenderer (ISR contract)
  lib/src/mount.dart       — BrowserMount & in-place reactive hydration (package:web + signals)
  lib/src/npm.dart         — NpmDependency registry → import map generation
  lib/src/router.dart      — history/hash routing, guards, nested shells, loaders

packages/bloom_seo/
  HeadManager, JsonLd, SitemapBuilder, prerenderRoute() over renderToHtml
```

## Descriptor nodes

- `TextNode(String)` — leaf
- `ElNode(tag, text?, className?, style?, attrs?, on?, children)` — element
- `FragmentNode(children)` — grouping without wrapper
- `LiveNode(() => BloomNode)` — reactive boundary
- `ShowNode(() => bool, child, fallback?)` — conditional
- `ForEachNode<T>(() => List<T>, (T)=>BloomNode, keyFn?)` — list
- `StyleNode(css)` — `<style>` emission

Builders (`Div`, `Button`, `Input`, …) are capitalized functions returning `ElNode`. Generic escape hatch: `El('custom-tag', ...)`.

## Event model

`BloomEvent` decouples handlers from `web.Event` so they are VM-testable. Browser mount wraps real events; tests use `BloomEvent.fakeClick()` / `fakeInput()`.

## Module boundaries

- `bloom_js_native` must never import `package:flutter/*` (enforced by `pubspec`).
- `bloom_seo` depends only on `bloom_js_native` + `signals`.
- Future `bloom_cli` extensions (`bloom js create/dev/build`) orchestrate Bun but live outside the runtime.

## Anti-goals (locked)

- No Flutter widgets on web target
- No VDOM diffing
- No hand-rolled package manager — Bun is the backend, Dart orchestrates
- Not a Flutter replacement — web-first framework written in Dart
