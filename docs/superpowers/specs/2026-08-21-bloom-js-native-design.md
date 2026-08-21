# Bloom JS Native & Bloom SEO Architecture Specification (M1–M3)

## 1. Product Definition & Core Philosophy
- **One-Liner**: React wrapped JavaScript; Bloom JS Native wraps Dart around HTML/JS — Dart owns reactivity, compilation, and tooling; the browser owns native DOM rendering; npm is consumed surgically via standard ESM import maps.
- **Strict Non-Goals**:
  - No Flutter Web runtime (no CanvasKit/Skia, no widget rendering engine).
  - No Virtual DOM diffing (direct fine-grained signal effect attachments only).
  - No custom package manager (Bun/ESM native import maps).
- **Core Insight**: Pure Dart AST descriptor tree (`BloomNode`) with zero DOM dependencies at compile/test time. Two distinct backends consume it:
  1. `renderToHtml()`: Pure Dart VM-compatible SSR / SSG / SEO renderer (<1ms execution).
  2. `mount()`: Browser-only (`package:bloom_js_native/browser.dart`) using `package:web` and `dart:js_interop`.

## 2. Platform Isolation & Entry Point Contract
- **`package:bloom_js_native/bloom_js_native.dart`**:
  - 100% VM compatible, zero `dart:js_interop` or `package:web` dependencies.
  - Exports:
    - Descriptors: `BloomNode`, `TextNode`, `ElNode`, `FragmentNode`, `LiveNode`, `ShowNode`, `ForEachNode`, `StyleNode`, `RawHtmlNode`.
    - `const` DSL Constructors: `Div`, `Span`, `Button`, `Input`, `Form`, `Label`, `Header`, `Footer`, `Main`, `Nav`, `Section`, `Article`, `Aside`, `Strong`, `Em`, `Code`, `Pre`, `Ul`, `Ol`, `Li`, `H1`, `H2`, `H3`, `H4`, `H5`, `H6`, `Img`, `Textarea`, `Text`, `Fragment`, `Live`, `Show`, `ForEach`, `Style`, `Raw`.
    - SSR: `renderToHtml()`, `escapeHtml()`.
    - Events: `BloomEvent`, `BloomEventHandler`, test fakes (`BloomEvent.fakeClick()`, `fakeInput()`, etc.).
    - NPM: `NpmDependency`, `NpmImportMap`, `buildImportMap()`.
    - Router: `BloomRouter`, `BloomRoute`, `Link`, `RouteMatch`.
    - Signals: re-exports `signal`, `computed`, `effect`, `batch`, `Signal`, `ReadonlySignal`.
- **`package:bloom_js_native/browser.dart`**:
  - Web only. Imports `package:web` and `dart:js_interop`.
  - Exports: `mount(node, selector)`, `mountToElement(node, element)`, and `BloomMountHandle`.

## 3. AST Class Hierarchy & Zero-Lint Construction
All element builders are concrete `const` subclasses of `ElNode` or `BloomNode` to achieve 0 linter errors and enable compile-time const evaluation:
- `class Div extends ElNode { const Div(...) : super('div', ...); }`
- `class Button extends ElNode { const Button(...) : super('button', ...); }`
- `class Live extends LiveNode { const Live(super.builder); }`
- `class Show extends ShowNode { const Show(super.when, {required super.child, super.fallback}); }`
- `class ForEach<T> extends ForEachNode<T> { const ForEach(super.items, super.builder, {super.keyFn}); }`

## 4. Reactive Region Management & Leak Prevention
- `BrowserMount` binds reactive nodes (`Live`, `Show`, `ForEach`) via scoped `_Region` instances.
- Re-executing an effect cleans up and disposes all nested child effects before rendering new DOM children, preventing memory leaks and zombie listener subscriptions.
- `BloomMountHandle.unmount()` disposes every root and nested effect recursively and clears the root element.

## 5. Client Router & bloom_seo Package
- **Router**:
  - Isomorphic path matching supporting route parameters (`/todos/:id`).
  - Hash and HTML5 History navigation with reactive active route signal.
  - `Link` component preventing default navigation on internal route changes.
- **bloom_seo**:
  - `HeadManager`: Signal-driven document title, `<meta>`, OpenGraph, Twitter Cards, and canonical URL updater.
  - `JsonLd`: Generates valid Schema.org structured data script tags.
  - `prerenderRoute()`: SSG generator executing `renderToHtml()` with embedded SEO meta tags.
  - `SitemapBuilder`: Generates XML sitemaps for multi-route sites.

## 6. Testing & Quality Standards
- `dart analyze` passes with **0 errors and 0 warnings** across `bloom_js_native`, `bloom_seo`, and `example/`.
- 100% of descriptor tests, HTML tests, event tests, router tests, and SEO tests pass directly on the native Dart VM CLI (`dart test`).
- Example application in `example/` demonstrating Counter + Todo + Dark Aesthetic with a build script compiling via `dart compile js`.
