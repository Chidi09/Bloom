# bloom_js_native

> React-wrapped JavaScript. Bloom JS Native wraps Dart around HTML/JS — Dart owns reactivity, compilation, and tooling; the browser owns rendering; npm is consumed surgically, never wholesale.

**No Flutter on web. No VDOM. No hand-rolled package manager. Real DOM, real CSS, fine-grained signals.**

## One-liner mental model

```
Dart component code
      ↓ builds
Descriptor tree (BloomNode: El / Text / Live / Fragment)   ← pure Dart, VM-testable
      ↓ backend 1                    ↓ backend 2
BrowserMount (package:web)      renderToHtml() → String
real DOM + signal effects       SSR / SSG / SEO / prerendering
```

## Quickstart

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  final count = signal(0);

  final app = Fragment(children: [
    H1(text: 'Counter'),
    Live(() => P(text: 'Count: ${count.value}')), // reactive — closes over signals
    Button(text: '+1', onClick: (_) => count.value++),
    Show(() => count.value > 9,
      child: P(text: 'Double digits!'),
      fallback: P(text: 'Keep clicking')),
    ForEach(() => todos.value, (t) => Li(children: [Text(t.title)])),
  ]);

  mount(app, '#app'); // real DOM, effects auto-disposed on unmount
}
```

```bash
# Build (T0 — plain dart compile js)
dart compile js -O4 -o main.js main.dart
# or demo
cd example && bash build.sh
```

## Comparison

| JS concept | Bloom equivalent |
|---|---|
| `useState` / zustand | `signal()` / `computed()` / `effect()` (package:signals) |
| `useReducer` | `BloomReducer` / `useReducer(reducerFn, initial)` |
| React Context | `createContext()` / `useContext()` / `BloomContext.provide()` |
| `{expr}` in JSX | `Live(() => P(text: '${count.value}'))` |
| `{cond && <A/>}` | `Show(() => cond, child: A)` |
| `items.map(...)` | `ForEach(() => items.value, (x) => ...)` |
| React Router `loader`/nested routes | `BloomRoute(loader:, dataBuilder:, layout:, guards:)` |
| React.lazy + Suspense | `lazy(loader, fallback:)` (pairs with Dart `deferred as`) |
| `renderToPipeableStream` | `renderToStreamWithSuspense(node)` |
| `hydrateRoot` | `hydrate(node, '#app')` (full-remount v1; DOM-reuse hydration planned) |
| React/Vite error overlay | `renderDevErrorOverlay()`, auto-shown via `bloomDevErrorOverlayEnabled` |
| React Testing Library | `bloom_test` — `renderForTest()` + `fireEvent` |
| React DevTools (inspector) | `BloomJsDevTools.snapshotTree()` / `.eventLog` |
| tanstack query | `BloomQuery` (native) / `bloom_data` (shared core) |
| tanstack mutation | `BloomMutation` (optimistic updates, rollback, invalidation) |
| `ng generate` / CRA templates | `bloom js create <Name> [--page\|--guard]` |
| zod | `bloom_validate` / `NpmDependency('zod', ...)` bridge |

## Honest npm compatibility statement

> Full arbitrary-npm compatibility is impossible without shipping `node_modules`. Guarantee: **any ESM-compatible, browser-safe package works via import maps** (v0) / Bun vendor (v1). Anything needing Node globals, native addons, or `window` at import time needs a typed binding (v2) or the `dart:js_interop` escape hatch.

## API

- **Elements:** `Div`, `Span`, `P`, `H1`-`H4`, `Button`, `Input`, `A`, `Img`, `Ul`/`Ol`/`Li`, `Form`, `Header`/`Footer`/`Main`/`Nav`/`Section`, plus generic `El('custom-tag', ...)`
- **Props:** `text`, `className`, `style`, `attrs: {k:v}`, `on: {event: handler}`, sugar `onClick`/`onInput`/`onChange`/`onSubmit`, `children`
- **Reactivity:** `Live(() => ...)`, `Show(() => bool, child:, fallback:)`, `ForEach<T>(() => List<T>, (T) => BloomNode)`
- **State management:** `signal()`/`computed()`/`effect()`/`batch()` (useState/useMemo/useEffect), `BloomReducer`/`useReducer` (useReducer), `BloomController` (Zustand-style store with lifecycle), `createContext()`/`useContext()`/`BloomContext.provide()` (Context)
- **Events:** handlers receive `BloomEvent` with `.value`, `.checked`, `.preventDefault()`, `.stopPropagation()` — VM-testable via `BloomEvent.fake*()`
- **Mount:** `mount(node, '#app')` → `BloomMountHandle` with `unmount()` / `dispose()`; `hydrate(node, '#app')` for hydrating server-rendered markup
- **Lazy loading:** `lazy(() async { ...; return Component(); }, fallback: ...)` — Suspense-backed, pairs with Dart's `deferred as` for real JS code-splitting (React.lazy equivalent)
- **SSR:** `renderToHtml(node)` → `String` (XSS-escaped, void elements handled); `renderToStream(node)` for simple chunked output; `renderToStreamWithSuspense(node)` for true out-of-order streaming SSR (React `renderToPipeableStream` equivalent) — flushes every Suspense fallback immediately (root, nested, or discovered inside resolved async content), streams resolved content as each boundary lands, independent of nesting depth
- **Data & mutations:** `BloomQuery` (cached, deduplicated, auto-revalidating fetches — tanstack query equivalent), `BloomMutation` (optimistic updates, rollback, cache invalidation)
- **Router:** `BloomRouter` + `BloomRoute` (nested layouts via `BloomRoute.shell`, `guards: [BloomRouteGuard]`, `loader`/`dataBuilder`/`loadingFallback` for React Router `loader`-style data APIs — auto-revalidates via `BloomQuery`+`BloomMutation.invalidateKeys`) + `Link(href: ...)`
- **Testing:** `bloom_test` — `renderForTest(node)` with `getByTestId`/`getByText`/`getByTag` queries and `fireEvent.click/input/change/submit` (Testing Library equivalent), operates on the descriptor tree with no browser required
- **DevTools:** `BloomJsDevTools.snapshotTree(node)` (serializable component tree), `.eventLog`/`.notify()` (bounded diagnostics event log)
- **Dev error overlay:** `renderDevErrorOverlay(error, stackTrace)` — full-screen HTML error overlay (React/Vite red-screen equivalent), wired into `mount()`'s error path via `bloomDevErrorOverlayEnabled`
- **npm:** `NpmRegistry.register(NpmDependency('zod','^3.23.0'))` → `generateImportMapTag()`
- **CLI:** `bloom js dev`/`build`/`vendor`, plus `bloom js create <Name>` (component), `--page` (route/page + BloomRoute snippet), `--guard` (BloomRouteGuard)

## Styling

Real DOM = real CSS:

- Plain `index.html` `<link>` files
- Tailwind via `className:` (it's a real class attribute)
- Scoped: `Style('a{color:red}')` + generated class names (phase 5 artifact)
- Theme tokens: mirror `GEMINI.md` carbon/indigo palette

## Testing

~90% VM-testable without a browser:

```bash
dart test              # framework descriptors + renderToHtml goldens + npm + router
dart test -p chrome    # mount/events against real DOM (phase M1 stretch)
```

## Complete Documentation Suite

- [01 — Thinking in Signals & Pure Dart AST](../../docs/js-native/01_thinking_in_signals.md)
- [02 — Describing the UI (Elements, Fragments & Keyed Lists)](../../docs/js-native/02_describing_the_ui.md)
- [03 — Reactivity & State Deep Dive (Signals, Computed, Batching)](../../docs/js-native/03_reactivity_and_state.md)
- [04 — Interactivity, Events & Forms](../../docs/js-native/04_interactivity_and_forms.md)
- [05 — Server-Side Rendering (SSR) & Static Generation (SSG)](../../docs/js-native/05_server_side_rendering_and_ssg.md)
- [06 — NPM Ecosystem & JavaScript Interop](../../docs/js-native/06_npm_and_js_interop.md)
- [07 — Developer Tooling & CLI Suite (Zero-Python Dev Server)](../../docs/js-native/07_developer_tooling_and_cli.md)
- [08 — Complete API Reference](../../docs/js-native/08_api_reference.md)

## Status

Core rendering engine (SSR/SSG, streaming SSR, hydration), fine-grained
signals-based reactivity (state, reducer, context, controller stores),
routing (nested layouts, guards, data loaders with revalidation),
component testing utilities, lazy loading, a DevTools inspector, a dev
error overlay, and CLI scaffolding (`bloom js create`) are implemented.
Tracked follow-up: true node-reuse hydration (currently a correct but
non-optimal full remount). Progressive streaming now covers Suspense
boundaries at any nesting depth, including boundaries discovered inside
another boundary's resolved content.
See root `GEMINI.md` § Bloom JS Native.
