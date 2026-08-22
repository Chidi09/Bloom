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

### `useReducer<S, A>(BloomReducerFn<S, A> reducerFn, S initialState)`
Returns a `BloomReducer<S, A>` — React `useReducer` equivalent, signal-backed.
- `.state`: `ReadonlySignal<S>` — the current state.
- `.dispatch(A action)`: applies `reducerFn(state, action)` synchronously.
- `.history`: read-only, oldest-first `List<A>` of dispatched actions.

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

### `BloomMountHandle hydrate(BloomNode root, String selector)`
Hydrates server-rendered markup at `selector`. Reuses existing DOM nodes in
place (attaching listeners, patching only what differs) for purely static
trees; falls back to a full `mount()` remount for any tree containing a
reactive node or a structural mismatch against the actual DOM. See
[05 — SSR & SSG §3](05_server_side_rendering_and_ssg.md#3-hydration--hydrate--hydrateelement).

### `bool bloomDevErrorOverlayEnabled`
When `true`, an uncaught mount-time error renders as a full-screen dev error
overlay instead of propagating. Dev-only — never set in a production build.

---

## 3a. SSR Streaming (`package:bloom_js_native/bloom_js_native.dart`)

### `Stream<String> renderToStreamWithSuspense(BloomNode node)`
True out-of-order streaming SSR (`renderToPipeableStream` equivalent).
Flushes the shell (including every `Suspense` fallback, at any nesting
depth) as the first chunk, then streams a `<script>` replacement per
boundary as its `resource` resolves. See
[05 — SSR & SSG §2](05_server_side_rendering_and_ssg.md#2-out-of-order-streaming-ssr--rendertostreamwithsuspense).

### `Stream<String> renderToStream(BloomNode node)`
Simple chunked output — fully renders the tree synchronously, then yields
the resulting string in fixed-size chunks. No progressive/out-of-order
behavior; prefer `renderToStreamWithSuspense` when the tree has `Suspense`
boundaries worth streaming independently.

---

## 3b. Lazy Loading & Data Loaders

### `BloomNode lazy(Future<BloomNode> Function() loader, {required BloomNode fallback})`
React.lazy equivalent — returns a `Suspense`-backed node that renders
`fallback` until `loader` resolves, then renders the loaded node. The
loader's `Future` is cached (`BloomLazyComponent`), so it runs at most once
even across re-renders. Pairs with Dart's `deferred as` import mechanism for
real JS code-splitting; see
[09 §5](09_testing_devtools_and_resilience.md#5-code-splitting--lazy).

### `BloomRoute({..., loader, dataBuilder, loadingFallback})`
`loader: Future<dynamic> Function(Map<String,String> params)?` — when set,
wraps the matched route in a `Suspense` automatically. See
[09 §6](09_testing_devtools_and_resilience.md#6-route-data-loaders--bloomrouteloader).

---

## 3c. Testing, DevTools & Error Overlay

### `bloom_test` — `renderForTest(BloomNode node)`
Returns a result object with `getByTestId`/`queryByTestId`,
`getByText`/`queryByText`, `getByTag`/`queryByTag`, and `toHtml()`. Operates
on the descriptor tree — no browser required.

### `fireEvent`
`.click(node)`, `.input(node, value)`, `.change(node, value)`,
`.submit(node)`, `.custom(node, type, {...})` — dispatches a synthetic
`BloomEvent` directly to the matched node's handler.

### `BloomJsDevTools`
`.snapshotTree(BloomNode)`, `.eventLog` / `.notify(type, data)` /
`.clearEventLog()` (bounded ring buffer, 200 entries), `.activeRegionCount`.

### `renderDevErrorOverlay(Object error, StackTrace stackTrace, {String? componentName, String? sourceHint})`
Returns an HTML fragment rendering a full-screen dev error overlay.
`renderDevErrorOverlayJson(...)` returns the same information as structured
JSON instead.

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
