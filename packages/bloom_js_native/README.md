# bloom_js_native

> **Bloom JS Native is the reactive web layer of Bloom: Dart components to real DOM, with SSR · SSG · ISR-friendly rendering, SEO, and browser-native APIs.** It is not Flutter rendered in a browser.

Dart owns reactivity, compilation, and tooling; the browser owns rendering; npm is consumed surgically, never wholesale. Pair it with `bloom_server` for a full-stack Dart web application.

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

Create and run a Flutter-free Bloom web app with the CLI:

```bash
dart pub global activate bloom_cli
bloom create my_web_app --js-native
cd my_web_app
bloom js dev
```

The scaffold includes `web/index.html`, the browser entry point, a smoke test,
and the `bloom_js_native` dependency. Open the local URL printed by the dev
server. Use `bloom js build` for an optimized production bundle.

For a custom `lib/main.dart`, import the pure-Dart API and browser API
separately. `mount()` is browser-only and comes from `browser.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

final todos = signal<List<String>>(['Review the docs', 'Ship the feature']);

void main() {
  final count = signal(0);

  final app = Fragment(children: [
    H1(text: 'Counter'),
    Live(() => P(text: 'Count: ${count.value}')), // reactive — closes over signals
    Button(text: '+1', onClick: (_) => count.value++),
    Show(() => count.value > 9,
      child: P(text: 'Double digits!'),
      fallback: P(text: 'Keep clicking')),
    ForEach<String>(
      () => todos.value,
      (todo) => Li(text: todo),
      key: (todo) => todo,
    ),
  ]);

  mount(app, '#app'); // real DOM, effects auto-disposed on unmount
}
```

Run `bloom js dev` while developing, then run `bloom js build` before
deployment. The generated `web/index.html` already provides the `#app` mount
target and script entry point.

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
| `hydrateRoot` | `hydrate(node, '#app')` (reuses static and reactive SSR nodes; recovers mismatched boundaries locally) |
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
- **Mount:** `mount(node, '#app')` → `BloomMountHandle` with `unmount()` / `dispose()`; `hydrate(node, '#app')` reuses static and reactive server-rendered DOM nodes, attaches listeners and effects, and remounts only the smallest mismatched marker-delimited boundary. A root-level structural mismatch remounts the root.
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

Run the pure Dart tests and the browser DOM tests separately:

```bash
dart test -p vm         # framework descriptors, SSR, data, and router
dart test -p chrome test/reactive_hydration_test.dart
```

Run `bash tool/check.sh` from this package to execute analysis, VM tests, all
browser test files, an optimized example build with a 50 KiB gzip budget, and
a localized entry build with a 100 KiB gzip budget.
It uses Chrome by default; set `CHROME_EXECUTABLE` if Chrome is outside the
default search path. Set `BLOOM_BROWSER=firefox` or `BLOOM_BROWSER=safari`
to run the same DOM suite in another browser. CI can invoke the same script.
The repository's [CircleCI workflow](../../.circleci/config.yml) runs this
gate and the CLI hot remount and ecommerce integration tests when the
repository is connected to CircleCI.

## Complete Documentation Suite

- [01 — Thinking in Signals & Pure Dart AST](../../docs/js-native/01_thinking_in_signals.md)
- [02 — Describing the UI (Elements, Fragments & Keyed Lists)](../../docs/js-native/02_describing_the_ui.md)
- [03 — Reactivity & State Deep Dive (Signals, Computed, Batching)](../../docs/js-native/03_reactivity_and_state.md)
- [04 — Interactivity, Events & Forms](../../docs/js-native/04_interactivity_and_forms.md)
- [05 — Server-Side Rendering (SSR) & Static Generation (SSG)](../../docs/js-native/05_server_side_rendering_and_ssg.md)
- [06 — NPM Ecosystem & JavaScript Interop](../../docs/js-native/06_npm_and_js_interop.md)
- [07 — Developer Tooling & CLI Suite (Zero-Python Dev Server)](../../docs/js-native/07_developer_tooling_and_cli.md)
- [08 — Complete API Reference](../../docs/js-native/08_api_reference.md)
- [09 — Testing, DevTools, Lazy Loading & Resilience](../../docs/js-native/09_testing_devtools_and_resilience.md)
- [Known Issues & Tracked Work](../../docs/js-native/KNOWN_ISSUES.md)

## Current limitations

- `ForEach` without a `key:` rebuilds every item after a list update, losing
  focus and local DOM state. Supply a stable key for changing lists.
- Development hot remount preserves stable top-level keyed signals and scopes
  signals created in `Live`, `Show` predicates, both `Memo` callbacks,
  `Suspense` resource/resolved/error callbacks, and `ErrorBoundary` callbacks,
  `Mount` lifecycle callbacks, user `effect()` callbacks, `lazy()` loaders,
  native custom element builders, event handlers, `batch()` and `untracked()`
  callbacks, and keyed `ForEach` item-list and item-builder callbacks. Event handlers retain
  their enclosing keyed-row scope. The three
  `Suspense` callback kinds use separate scopes, and
  nested callbacks retain their keyed row identity. Signals in unkeyed lists
  and unsupported callbacks need explicit keys. Constructor expressions and
  named constructors assigned directly to variables at stable call sites also
  receive per-instance scopes, including imported classes. Top-level factory
  functions and inline imported constructor expressions still need deliberate
  state identity.
  See the known issues log.
- Relative-time phrases cover more than 40 languages through pure-Dart locale
  messages; unknown languages fall back to English. Number, currency, percent,
  date, and time formatting use CLDR-backed `package:intl`.

For a strict script Content Security Policy, set `bloomScriptNonce` to the
server-issued nonce before calling `defineCustomElement()`. Registration does
not require `unsafe-eval` or `unsafe-inline`.

## Status

Core rendering engine (SSR/SSG, streaming SSR, hydration), fine-grained
signals-based reactivity (state, reducer, context, controller stores),
routing (nested layouts, guards, data loaders with revalidation),
component testing utilities, lazy loading, a DevTools inspector, a dev
error overlay, and CLI scaffolding (`bloom js create`) are implemented.
Hydration reuses server-rendered DOM nodes for static and reactive
subtrees, including `Live`, `Show`, and keyed `ForEach`. It preserves
pre-hydration form values and focus. Marker-delimited mismatches recover
within their boundary; a root-level structural mismatch remounts the
root. Browser tests cover DOM identity, reactive updates, events, and
cleanup. Progressive streaming covers Suspense
boundaries at any nesting depth, including boundaries discovered inside
another boundary's resolved content.
See root `GEMINI.md` § Bloom JS Native.
