# Bloom JS Native — Known Issues & Tracked Work

Findings from a full-stack production build against `bloom_js_native`,
recorded here for follow-up. Ratings/verdicts are from that review, not
from the framework's own benchmarks.

## Bugs

### 1. `bloom format` corrupts CSS inside raw Dart strings — ✅ Fixed
**Severity:** High — silently drops CSS rules in the browser.

`bloom format` tokenizes multiline CSS embedded in `r'''...'''` raw
strings and inserts whitespace between function names and their
parentheses (e.g. `rgba (...)`, `blur (...)`, `var (...)`,
`translateY (...)`). This is invalid CSS syntax; browsers silently drop
the malformed rules rather than erroring.

**Fix direction:** Treat `r'''...'''` raw strings as immutable literal
content in `bloom format` (skip tokenization entirely), or pipe them
through a strict, standards-compliant CSS formatter (e.g. an embedded
Prettier-equivalent) instead of the general Dart formatter's tokenizer.

**Owner package:** `bloom_cli` (`bloom format` command).
**Fixed in:** `_needsSpaceBetween()` no longer inserts a space between
a bare identifier and an immediately-following parenthesized token,
except for at-rule keywords (`@media (...)`, `@supports (...)`).

## Friction points / feature requests

### 2. Tailwind JIT has no static-extraction production path — ✅ Fixed
`@tailwindcss/browser`'s runtime DOM scanning is good for scaffolding
but stumbles on complex arbitrary values (e.g. opacity slashes on CSS
variables like `border-[var(--success)]/40`) and adds a small layout
shift before script evaluation.

**Fix direction:** Add a `bloom css build` step (or Tailwind
CLI/Vite-style integration) that pre-scans and emits a minified,
static `dist/app.css` for production builds instead of relying on
runtime JIT scanning.

**Owner package:** `bloom_cli`, `bloom_js_native`.
**Fixed in:** `bloom build web_dom` now uses a dedicated production
output directory (`build/web/`), cleanly copying static assets from
the source `web/` directory and compiling `build/web/main.dart.js`.
When `@tailwindcss/browser` is declared in `bloom.yaml`,
`TailwindStaticBuild` invokes `@tailwindcss/cli` via Bun to scan `.dart`
sources and emit an optimized, minified `build/web/dist/app.css`
(55.7 kB on `bloom_js_ecommerce`). The production copy at
`build/web/index.html` is transformed via `TailwindStaticBuild.transformIndexHtml()`
to replace the dev-mode `@tailwindcss/browser` `<script>` tag with
`<link rel="stylesheet" href="dist/app.css">`, leaving the source
`web/index.html` untouched for subsequent `bloom js dev` runs.

**Behavior change:** `bloom deploy` for `web_dom` projects now targets
`build/web` (matching Flutter web's existing convention) instead of the
source `web/` directory directly — a `bloom build web_dom` run is now
required before deploying, where previously deploy could point straight
at source.

### 3. No lint rule for the dual-entry-point boundary — ✅ Fixed
Accidentally importing `package:bloom_js_native/browser.dart` into
shared business logic or an SSR route causes silent build or test
crashes, with no static warning at the import site.

**Fix direction:** Add a `bloom lint` rule
(`forbidden_browser_import_in_shared_code`) that flags any import of
`browser.dart` outside `lib/main.dart` or `web/`.

**Owner package:** `bloom_cli` (`bloom lint` command).
**Fixed in:** new `forbidden_browser_import_in_shared_code` rule in
`bloom_lint.dart`, independent of the existing `browser_import_in_test`
rule (both fire on a `test/` file importing `browser.dart`).

### 4. Dev-loop (hot reload) latency — Partially fixed (in-page fast remount shipped; full Signal-state preservation deferred)
Each save currently costs ~4.5s–7.0s: a whole-program `dart2js`
compile, Bun asset assembly, then an SSE-triggered full
`window.location.reload()`. Comparable web tooling (Vite, Turbopack,
SolidStart) achieves sub-150ms HMR.

**Fixed in:** both of the two independent levers below are now
implemented in `bloom js dev`:
- CSS-only edits (a `Style(r'''...''')` body or a top-level
  `const *Css = r'''...''';`) are detected via a skeleton diff
  (`css_hot_swap.dart`) and pushed as a `css-patch` SSE event that
  patches the `<style>` tag in place — no recompile, no reload.
- `bloom js dev --experimental-ddc` (opt-in, off by default) swaps
  the `dart2js -O0` compile for DDC (`ddc_dev_compiler.dart`),
  serving a version-cached `dart_sdk.js`/`require.js` runtime module.
  Verified in headless Chromium (`test/dev/npm_interop_umd_test.dart`,
  `test/dev/ddc_ecommerce_integration_test.dart`) that vendored npm
  UMD packages still attach to `window` correctly and a real example
  app boots and renders under DDC. `bloom js build` (`dart2js -O4`,
  production) is completely unaffected.
- `bloom js dev --experimental-ddc` now performs an **in-page fast
  remount** on a Dart source edit instead of a full
  `window.location.reload()`: the dev server broadcasts a new
  `hot-remount` SSE event (only when DDC mode is active — the
  `dart2js` dev path's `reload` behavior is unchanged), the browser
  disposes the currently-mounted app via a new
  `bloomDisposeActiveMount()` hook (installed by `mount.dart` only
  when hot-reload tracking is active, so this adds zero overhead to
  production builds), evicts the cached `main` module from RequireJS
  (`require.undef('main')`, a real API in the vendored Dart SDK
  `amd/require.js`), and re-requires/re-invokes `main()` — with no
  browser navigation. Verified in headless Chromium
  (`test/dev/hot_remount_test.dart`) that a window-level sentinel
  survives the remount (proving no navigation occurred), that the DOM
  updates to the new source's content, and that a `main()` thrown
  during the second invocation renders the existing dev error overlay
  in place.
- Still open: this is a fast *remount*, not state-preserving hot
  reload — every `Signal<T>` legitimately resets to its initial value
  on each hot reload, same as before, just without a full page
  reload/navigation (scroll position, DevTools console history, and
  network tab survive; component state does not). Full Signal-value
  preservation across a hot reload was investigated and explicitly
  **not attempted**: an external technical review found the
  naive "just re-execute the changed module" premise false for
  Bloom's DDC output (it compiles to a single monolithic AMD module,
  not a fine-grained module graph), and all three candidate
  Signal-matching strategies (declaration-order key, explicit opt-in
  key, top-level-only scoping) carry a real risk of silently binding a
  stale value to the wrong Signal — worse for developer trust than a
  clean reset. The recommended path to real state preservation is
  compiler-level (AST/macro-based stable keying of each `signal(...)`
  call site), which is a separate, larger, not-yet-started body of
  work.

**Fix direction (two independent levers):**
- Compile with DDC (Dart Dev Compiler) or incremental Wasm in dev mode
  instead of a whole-program `dart2js` batch compile on every save.
- Since Bloom state lives in isolated `Signal<T>` cells, patch DOM
  subtrees and preserve signal values across an edit instead of forcing
  a full page reload (fine-grained HMR).

**Owner package:** `bloom_cli` (`bloom js dev`), `bloom_js_native`
(HMR client/signal preservation).

**Reference: how Next.js/Turbopack gets sub-150ms HMR** (from reading
the real Next.js/Turbopack source, for context on what's actually
transferable to a `dart2js` + Bun dev server):
- Server watches the filesystem and computes only the affected
  compilation tasks, then pushes a targeted diff (changed
  chunks/modules only) to the browser over a persistent WebSocket —
  never a full rebuild artifact.
- Browser re-executes just the changed module(s) in place via the
  module registry, instead of reloading the page; falls back to a full
  reload only when an update can't be applied incrementally.
- CSS updates bypass JS module re-execution entirely — the runtime
  just swaps a `<style>` tag's content (or re-points a `<link>` href
  with a cache-busting query), independent of any bundler-level
  incremental compilation. This is why CSS HMR is near-instant even in
  plain webpack setups.
- The incremental compilation itself (`turbo-tasks`: memoized, pure
  compilation "tasks" keyed by content-hashed inputs, invalidated only
  when their specific inputs change) is a bespoke Rust engine — not
  something to reimplement for Bloom.

**What's actually adoptable here, in order of leverage/cost:**
1. **WebSocket push of a targeted diff instead of
   `window.location.reload()`** — highest leverage, fully transferable
   without any compiler changes: the dev server already knows *what*
   changed (a CSS-only edit inside a `Style(r'''...''')` raw string vs.
   a Dart source edit) and could push a typed message instead of
   always forcing a full reload.
2. **CSS hot-swap via `<style>` textContent replacement** — directly
   implementable today: on a CSS-only edit, re-run `formatCss`/the CSS
   extraction step and push the new CSS text over the existing SSE/WS
   channel to patch a `<style>` tag in place, skipping `dart2js`
   entirely for that class of edit.
3. **DDC or incremental Wasm compilation in dev mode** — the actual
   fix for JS/Dart source edits (not CSS), replacing the whole-program
   `dart2js` batch compile; larger, riskier change, worth its own
   dispatch/implementation pass separate from (1) and (2).
4. Turbopack's `turbo-tasks` incremental-computation engine is **not**
   transferable directly — only the general shape (cache results keyed
   by content hash, invalidate only affected units) is worth keeping
   in mind if Bloom ever moves off whole-program `dart2js` in dev mode.

## Review summary (for context)

| Dimension | Rating | Note |
|---|---|---|
| Architecture & API Design | 9/10 | Clean, declarative, elegant signal reactivity |
| Bundle Efficiency & SSR | 9.5/10 | Very fast SSR, small footprint |
| Fullstack Integration (`bloom_db`/`bloom_server`) | 8.5/10 | Ergonomic ORM, seamless same-origin dev proxy |
| Hot Reload & Dev Loop Speed | 6/10 | Functional, but ~5s cycles need incremental compilation |
| CLI Tooling & Formatters | 7/10 | Promising, needs CSS-safe formatting in raw strings |
