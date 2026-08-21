# 08 — Complete API Reference

Complete reference for all types, functions, and element constructors exported by `package:bloom_js_native`, `package:bloom_seo`, and `package:bloom_framework`.

---

## 1. Reactivity Primitives

### `signal<T>(T initialValue)`
Creates a mutable reactive signal cell.
- `.value`: Getter/setter for the wrapped value.
- `.peek()`: Reads value without creating a reactive subscription.

### `computed<T>(T Function() fn)`
Creates a derived memoized computation signal.
- Re-evaluates lazily only when dependencies change.

### `effect(void Function() fn)`
Registers a reactive side-effect function.
- Returns a `void Function()` disposer.

### `batch(void Function() fn)`
Batches multiple signal writes into a single downstream notification cycle.

### `untracked<T>(T Function() fn)`
Executes `fn` and returns its result without subscribing to signals read within.

---

## 2. Core Descriptors (`package:bloom_js_native/bloom_js_native.dart`)

### `Div`, `Span`, `Button`, `Input`, `Form`, `H1`–`H6`, `P`, `A`, `Img`, `Nav`, `Header`, `Footer`, `Main`, `Section`, `Article`, `Aside`, `Ul`, `Ol`, `Li`, `Pre`, `Code`, `Textarea`, `Select`, `Option`, `Label`, `Svg`, `Raw`
Constructor arguments:
- `text`: String content (automatically XSS escaped).
- `className`: CSS class string.
- `style`: Inline CSS style string.
- `attrs`: Map of additional HTML attributes (`{'id': '...', 'aria-label': '...'}`).
- `children`: List of child `BloomNode` instances.
- `onClick`: Event handler `void Function(BloomEvent)`.
- `onInput`: Event handler `void Function(BloomEvent)`.
- `onChange`: Event handler `void Function(BloomEvent)`.
- `onSubmit`: Event handler `void Function(BloomEvent)`.

### `Live(BloomNode Function() builder)`
Reactive node wrapper that re-evaluates its subtree when enclosed signals mutate.

### `Show(bool Function() when, {required BloomNode child, BloomNode? fallback})`
Reactive conditional branch node with automatic cleanup of unmounted regions.

### `ForEach<T>(List<T> Function() items, BloomNode Function(T) builder, {String Function(T)? key})`
Keyed collection renderer with fine-grained in-place DOM reconciliation.

### `Fragment.fromList(List<BloomNode> children)`
Groups sibling nodes without emitting a wrapper DOM container.

---

## 3. Browser Mounting (`package:bloom_js_native/browser.dart`)

### `BloomMountHandle mount(BloomNode root, String selector)`
Mounts an AST descriptor tree onto the target DOM selector (e.g. `'#app'`).
- `handle.unmount()`: Cleans up DOM and disposes all active reactive effect subscriptions.

---

## 4. Server & SEO Primitives (`package:bloom_seo/bloom_seo.dart`)

### `renderToHtml(BloomNode root)`
Renders an AST descriptor tree to an XSS-escaped HTML string in `<0.4ms`.

### `HeadManager`
Manages reactive `<title>`, `<meta>`, and `<link>` tags.

### `JsonLd`
Constructs Schema.org compliant structured data scripts.

### `SitemapBuilder`
Generates XML sitemaps for search engine indexing.
