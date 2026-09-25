# Changelog

## Unreleased

### Fixed
* `renderForTest` queries (`getByTestId`, `getByText`, `getByTag`) now traverse `Memo` boundaries, evaluating the builder with the current dependency value, so elements rendered inside a `Memo` can be found and driven with `fireEvent` in VM tests.

## 0.3.8 - 2026-09-25

### Added
* **Request-isolated SSR query caches (#31)**: `BloomData` caches, invalidation and in-flight deduplication are now scoped per SSR request through `BloomQueryScope` (`BloomData.withRequestScope`), so concurrent requests never share private query data. SSR render helpers create and dispose the scope automatically, including for streaming, errors and cancellation.
* **Reactive hydration preserves SSR DOM (#32)**: hydration attaches reactive behavior to the server-rendered DOM through boundary markers (`live`, `memo`, `show`, keyed `foreach`, error boundaries, Suspense) instead of remounting the target. Mismatches are recovered at the smallest delimited boundary and reported as `HydrationMismatch` diagnostics; pre-hydration input values and focus are kept, and streamed Suspense shells are claimed against late server patches.

### Fixed
* Hydration keys are UTF-8 encoded before base64, so keyed `ForEach` items with non-Latin-1 keys (CJK, emoji) match their SSR markers instead of remounting the whole list.
* Rejected executable raw HTML attributes and URL schemes across SSR, browser mounting, reconciliation, and hydration; escaped script-context JSON in import maps, streamed Suspense updates, and cache dehydration; neutralized case-insensitive `</style>` terminators.
* Enforced route guards on direct browser loads and nested shell routes, kept denied or redirected back/forward URLs consistent with the rendered route, and withheld guarded content until initial authorization completes.
* Query and path parameter decoding now handles malformed percent escapes and invalid UTF-8 without throwing during route matching; malformed markers stay literal and invalid byte sequences become U+FFFD.
* Excluded generated `example/main.js` bundles and source maps from the published package archive; they remain reproducible with `example/build.sh`.
* Disposed browser router controllers now ignore queued navigation work and stop in-flight guarded navigations before they can change history or reactive location state.
* **Top-level effects survive DDC remounts as stale subscriptions**: browser dev effects now register their cleanup and the DDC bootstrap stops them before re-executing the app module. Production and SSR behavior still delegates directly to `signals_core`.
* Added the development-only `bloomHmrScope` runtime hook used by Bloom's compiler to isolate signals owned by stateful object instances; it executes without creating a Zone outside active browser hot reload.
* **Duplicate keyed list entries**: SSR, mounting, reconciliation, and hydration now validate each keyed `ForEach` snapshot before processing it, preventing duplicate IDs from overwriting entries and leaking mounted regions.
* `defineCustomElement` registers through a nonce-bearing script instead of `eval()`. Apps with a strict script Content Security Policy can set `bloomScriptNonce` to the response nonce; `unsafe-eval` is no longer required. Tag names are validated and JavaScript literals are JSON-encoded.
* Removed the Chrome test configuration override that prevented `CHROME_EXECUTABLE` from selecting a browser installed outside `/Applications`.
* The DDC signal-key injector no longer assigns the same automatic key to every invocation of an anonymous reactive or list builder. Top-level signals still preserve state; repeated builders require an explicit instance-specific key.
* Number, percent, currency, date, and date-time formatting now use `package:intl` locale data on both the VM and in the browser, with the existing formatter as a fallback for unknown locale tags. Indian digit grouping and Italian month names are covered by regression tests.
* Relative-time formatting now uses pure-Dart locale messages for more than 40 languages on both the VM and in the browser, while preserving existing phrasing for English, French, German, Spanish, Japanese, and Chinese.
* Router focus management now uses `preventScroll`, so focusing the new heading cannot undo navigation scroll restoration.

## 0.3.7 - 2026-09-04

### Fixed
* **Per-render keyframe dedup scope (#16)**: animation `@keyframes` dedup state is now scoped to each top-level SSR render via zones instead of a shared global set, so concurrent `renderToStreamWithSuspense` streams can no longer drop or duplicate each other's `@keyframes` blocks. `renderToStream` renders eagerly (chunking stays lazy) with identical bytes.
* **Guard redirect loop detection (#17)**: new `BloomRouter.resolveRedirects` follows guard redirect chains with visited-set + hop-budget (`maxRedirects`, default 10) protection, throwing `BloomRedirectLoopException` on cycles instead of recursing forever; the browser controller resolves redirects up-front into a single history entry. Also adds `GuardResult.deny()` for blocking without redirecting.
* **Bounded hot-reload signal registry (#19)**: the `window`-global registry backing `signal(initialValue, key: ...)` is now capped at `kMaxSignalRegistryEntries` (512) entries with least-recently-used eviction — every write refreshes its key's recency, so live carryover state survives while stale keys left by renamed or removed call sites are pruned, and an evicted key falls back to the documented clean reset. Covered by a browser eviction test.

### Added
* **Hostile SSR attribute-name regression tests (#19)**: attribute names were already validated against the same identifier rules as tag names; added explicit tests for the hardening audit's hostile names (`onload=alert(1)`, `a>b`) on both the HTML and SVG render paths to lock the behavior in.
* **ForEach keyless tradeoff documented (#19)**: the `ForEach` API docs and COOKBOOK Section 6 now state explicitly that unkeyed lists rebuild the whole list region on every update — dropping per-item reactive regions and effects (input focus, text selection, local DOM state, in-flight CSS animations) — and that `key:` is required for any list that can reorder, insert, or remove items.

## 0.3.6 - 2026-08-31

### Added
* Browser-only `BrowserRealtimeClient` WebSocket transport with channel multiplexing, presence, heartbeat, reconnect, and resubscription.
* Expanded cookbook guidance for font manifests, visual parity, responsive CSS, hydration, and raw HTML/SVG behavior.

## 0.3.5 - 2026-08-26

### Added
* `signal<T>(initialValue, {key})` — an opt-in `key` parameter that, when hot-reload tracking is active (used by `bloom js dev`'s DDC fast dev-loop), preserves a top-level signal's mutated value across an in-page hot remount by carrying it over via a `window`-global registry. Zero overhead when no key is given or tracking is inactive (the default, including all production builds). Falls back to a clean reset on any type mismatch between edits rather than risking silent corruption.
* `isHotReloadTrackingActive()` exposed publicly (was previously a private `mount.dart` helper) for use by the new `signal()` wrapper.

## 0.3.4 - 2026-08-26

### Added
* `mount()`/`mountToElement()` now support an opt-in hot-reload tracking mode (used by `bloom js dev --experimental-ddc`'s in-page fast remount): when active, the currently-mounted `BloomMountHandle` is tracked and disposable via a dev-only `bloomDisposeActiveMount()` hook, with zero overhead when inactive (the default, including all production builds).

## 0.3.3 - 2026-08-24

### Added
* **COOKBOOK.md**: documented the real `bloom add npm:<package>` workflow (vendoring, generated `@JS()` bindings, importmap/bootstrap wiring) and how to use `@tailwindcss/browser` with no CDN and no build step; documented the `lib/design/tokens.dart` + `Style()` pattern for design tokens and `bloom fonts optimize` + `fontStylesheetLink()` for fonts, replacing hand-written `web/index.html` styling/font tags in all guidance.

## 0.3.2 - 2026-08-24

### Added
* **COOKBOOK.md**: new "Best Practices & Common Pitfalls Checklist" section (reactivity, nullable event fields, the two-entry-point rule, SSR/hydration gotchas, disposal, styling, testing) consolidated as a pre-flight reference.

## 0.3.1 - 2026-08-24

### Added
* **COOKBOOK.md**: new "Project Structure & Multi-File Apps" section (recommended `lib/routes/`, `lib/components/`, `lib/state/` layout) and a "UI Component Primitives" section covering all 47+ exports from `lib/src/ui.dart`.

## 0.3.0 - 2026-08-24

### Added
* **UI primitives library**: 45+ reusable, accessible UI components (tier 1 + tier 2 — accordion through toggle group).
* **`fontStylesheetLink()`**: helper for linking the stylesheet generated by `bloom fonts optimize`.
* Backend-for-Frontend support (dev proxy, RPC mount, env split).

### Fixed
* Soft reset no longer permanently poisons regions.

## 0.2.0 - 2026-08-23

### Added
- **Typed RPC** (`rpc.dart`): `BloomRpcContract` with path parameters, typed
  input/output codecs, and stable cache keys.
- **i18n** (`i18n.dart`): ICU message formatting (plural, select, nested
  sub-patterns), locale resolution, and reactive locale switching. Number/date
  formatting is hand-rolled and is not full CLDR.
- **Images** (`image.dart`): responsive `srcset`/`sizes`, `priority` for LCP,
  and decorative-image handling.
- **Scoped CSS** (`scoped_css.dart`): deterministic scoped class generation,
  including `@media` and `@keyframes`.
- **Islands** (`island_node.dart`, `islands.dart`): server-emitted island
  placeholders plus a browser orchestrator with per-island failure isolation.
  The SSR half is pure Dart and safe to import from a server.
- **Web components** (`web_components.dart`): consume custom elements with rich
  JS properties and decoded `CustomEvent` payloads.
- **Cooperative scheduler** (`transition.dart`): real priority-based time
  slicing replacing the previous microtask stub.
- Async form validators, typed form fields, and field arrays.
- Router query strings, fragments, and focus/aria-live route announcements.
- SSR cache dehydration/hydration and infinite queries.

### Fixed
- Route announcements now render into a real `aria-live` region; previously they
  only wrote to a signal that nothing displayed.
- Error boundaries now cover reactive rebuild paths.

### Known limitations at release
- `defineCustomElement` used `eval()` to construct the custom-element class;
  this is addressed in the unreleased changes above.

## 0.1.0 - 2026-08-21

* Initial release of `bloom_js_native`.
* Pure Dart AST descriptor tree (`BloomNode`, `ElNode`, `TextNode`, `LiveNode`, `ShowNode`, `ForEachNode`, `FragmentNode`).
* Fine-grained signals reactivity binding (`signal`, `computed`, `effect`, `batch`).
* Dual-backend architecture:
  * Browser DOM mounting via `package:bloom_js_native/browser.dart` (`package:web`).
  * Instant sub-millisecond SSR via `renderToHtml()` with automatic XSS escaping.
* Built-in NPM vendor manager & ESM importmaps (`NpmRegistry`).
* HTML element subclasses (`Div`, `Span`, `Button`, `Input`, `Form`, `H1`–`H6`, etc.) ensuring 0 analyzer warnings.
