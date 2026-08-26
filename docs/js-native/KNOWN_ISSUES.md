# Bloom JS Native — Known Issues & Tracked Work

Findings from a full-stack production build against `bloom_js_native`,
recorded here for follow-up. Ratings/verdicts are from that review, not
from the framework's own benchmarks.

## Bugs

### 1. `bloom format` corrupts CSS inside raw Dart strings
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

## Friction points / feature requests

### 2. Tailwind JIT has no static-extraction production path
`@tailwindcss/browser`'s runtime DOM scanning is good for scaffolding
but stumbles on complex arbitrary values (e.g. opacity slashes on CSS
variables like `border-[var(--success)]/40`) and adds a small layout
shift before script evaluation.

**Fix direction:** Add a `bloom css build` step (or Tailwind
CLI/Vite-style integration) that pre-scans and emits a minified,
static `dist/app.css` for production builds instead of relying on
runtime JIT scanning.

**Owner package:** `bloom_cli`, `bloom_js_native`.

### 3. No lint rule for the dual-entry-point boundary
Accidentally importing `package:bloom_js_native/browser.dart` into
shared business logic or an SSR route causes silent build or test
crashes, with no static warning at the import site.

**Fix direction:** Add a `bloom lint` rule
(`forbidden_browser_import_in_shared_code`) that flags any import of
`browser.dart` outside `lib/main.dart` or `web/`.

**Owner package:** `bloom_cli` (`bloom lint` command).

### 4. Dev-loop (hot reload) latency
Each save currently costs ~4.5s–7.0s: a whole-program `dart2js`
compile, Bun asset assembly, then an SSE-triggered full
`window.location.reload()`. Comparable web tooling (Vite, Turbopack,
SolidStart) achieves sub-150ms HMR.

**Fix direction (two independent levers):**
- Compile with DDC (Dart Dev Compiler) or incremental Wasm in dev mode
  instead of a whole-program `dart2js` batch compile on every save.
- Since Bloom state lives in isolated `Signal<T>` cells, patch DOM
  subtrees and preserve signal values across an edit instead of forcing
  a full page reload (fine-grained HMR).

**Owner package:** `bloom_cli` (`bloom js dev`), `bloom_js_native`
(HMR client/signal preservation).

## Review summary (for context)

| Dimension | Rating | Note |
|---|---|---|
| Architecture & API Design | 9/10 | Clean, declarative, elegant signal reactivity |
| Bundle Efficiency & SSR | 9.5/10 | Very fast SSR, small footprint |
| Fullstack Integration (`bloom_db`/`bloom_server`) | 8.5/10 | Ergonomic ORM, seamless same-origin dev proxy |
| Hot Reload & Dev Loop Speed | 6/10 | Functional, but ~5s cycles need incremental compilation |
| CLI Tooling & Formatters | 7/10 | Promising, needs CSS-safe formatting in raw strings |
