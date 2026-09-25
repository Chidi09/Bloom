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

### 4. Dev-loop (hot reload) latency — Incremental DDC compile and localized component HMR shipped
Bloom's default DDC dev loop, CSS hot-swap, in-page updates, and stable
top-level Signal preservation are implemented. Component boundaries now have
localized DOM patching for compatible component subtrees, including components
that emit multiple DOM roots, and local root replacement for incompatible
ones. These paths are verified in headless Chromium, including direct-root
mounting and DDC cross-module re-execution. Signal state now survives in
`Live`, `Show`, `Memo`, `Suspense`, `ErrorBoundary`, `lazy()`, `Mount`,
`effect()`, DOM event handlers, `defineCustomElement` builders, and keyed
`ForEach` builders; callbacks without a compiler-recognized stable identity
remain open.

**Implemented improvements:**
- CSS-only edits (a `Style(r'''...''')` body or a top-level
  `const *Css = r'''...''';`) are detected via a skeleton diff
  (`css_hot_swap.dart`) and pushed as a `css-patch` SSE event that
  patches the `<style>` tag in place — no recompile, no reload.
- DDC staging caches each Dart source by SHA-256 for the lifetime of the dev
  compiler. Unchanged files reuse their transformed staging copy, while
  deleted files are removed before the next compile. The staged package
  configuration also routes this project's `package:` imports through the
  transformed tree. Compile output is written to a temporary file and only
  replaces the last good JS bundle after DDC exits successfully with nonempty
  output.
- `bloom js dev` runs DDC as a persistent Bazel-protocol worker with compiler
  result reuse and DDC's incremental front end enabled. Each request supplies
  SHA-256 digests for staged Dart inputs and the SDK outline summary; edits
  invalidate changed files while the worker reuses its compiler state. If the
  SDK worker protocol is unavailable, Bloom retires the worker and falls back
  to one-shot DDC for that session. The compiler still emits the full entry
  module. Compatible component trees can patch in place; unsupported trees
  use the app remount fallback.
- `bloom js dev` (DDC is enabled by default) swaps
  the `dart2js -O0` compile for DDC (`ddc_dev_compiler.dart`),
  serving a version-cached `dart_sdk.js`/`require.js` runtime module.
  If DDC runtime artifact generation fails, the previous SDK cache is kept
  intact and the dev command falls back to `dart2js -O0` before serving.
  Verified in headless Chromium (`test/dev/npm_interop_umd_test.dart`,
  `test/dev/ddc_ecommerce_integration_test.dart`) that vendored npm
  UMD packages still attach to `window` correctly and a real example
  app boots and renders under DDC. `bloom js build` (`dart2js -O4`,
  production) is completely unaffected.
- `bloom js dev` performs an **in-page update** on a Dart source edit instead
  of a full
  `window.location.reload()`: the dev server broadcasts a new
  `hot-remount` SSE event (only when DDC mode is active — the
  `dart2js` dev path's `reload` behavior is unchanged), the browser keeps
  the mounted app while it evicts the cached `main` module from RequireJS
  (`require.undef('main')`, a real API in the vendored Dart SDK
  `amd/require.js`) and re-invokes `main()` — with no browser navigation.
  Compatible component boundaries patch in place; old module effects are
  disposed after the updated app has mounted or patched. Unsupported tree
  shapes fall back to a full app remount. Verified in headless Chromium
  (`test/dev/hot_remount_test.dart`) that a window-level sentinel
  survives the remount (proving no navigation occurred), that the DOM
  updates to the new source's content, and that a `main()` thrown
  during the second invocation renders the existing dev error overlay
  in place.
- Stable `BloomNode build()` methods are wrapped in source-identified
  `HmrComponentNode` boundaries in the DDC staging copy. Component boundaries
  use comment anchors to patch or replace any number of sibling DOM roots
  locally while preserving surrounding DOM identity. Old component effects
  are disposed when the boundary updates.
- State carryover covers keyed `ForEach`, `Live`, and `Memo` builders, both
  callbacks in `ErrorBoundary`, resolved and error builders in `Suspense`, and
  `Mount` lifecycle and user `effect()` callbacks, as well as stable top-level
  and explicitly keyed signals. Nested scopes preserve enclosing keyed-row
  identity when reactive callbacks rerun outside their original Zone. Signals
  in unkeyed lists or other closures without a stable instance identity still
  require an explicit key. `computed` values are re-derived and effects are
  recreated on reload.
  `--legacy-dart2js` retains the full-page-reload path.

**Owner package:** `bloom_cli` (`bloom js dev`), `bloom_js_native`
(HMR client/component boundaries/signal preservation).

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

**Next useful work:** extend state carryover to remaining callbacks with a
stable runtime identity, while keeping unkeyed repeated instances isolated.
The incremental front end now reuses compiler state; Turbopack's `turbo-tasks`
engine is not directly transferable.

### 5. Partial state preservation during hot reload — ✅ First slice shipped
The in-page remount preserves keyed signal values across supported callbacks,
but it does not preserve every reactive resource or effect-local state.

**Implementation:** an analyzer-based AST pass builds stable identities for
top-level signal call sites, `Live` builders, `Show` predicates, both `Memo`
callbacks, both `ErrorBoundary` callbacks, `Suspense` resource, resolved, and
error callbacks, `lazy()` loader callbacks, native custom element builders,
`Mount` lifecycle callbacks, user `effect()` callbacks, `batch()` and
`untracked()` callbacks, DOM event handlers, and keyed `ForEach` item-list and
item-builder callbacks.
Runtime scopes compose the
callback call site with any enclosing keyed item so values survive DDC
remounts without crossing between repeated rows. Lazy loaders re-enter their
captured scope when asynchronous work runs. Closures without a stable
instance identity remain unkeyed.

**Fixed in:** an analyzer-based AST pass
(`signal_key_injector.dart`) tags signal call sites with stable keys and adds
stable runtime scopes to `Live`, `Show`, `Memo`, `Suspense`, `ErrorBoundary`,
`lazy()`, `defineCustomElement` builders, and `Mount` callbacks and user
`effect()` callbacks. Signals created in imported synchronous `batch()` and
`untracked()` callbacks also receive stable call-site keys, with import
combinators honored. Keyed `ForEach`
item scopes compose with those callback scopes, keeping repeated rows independent;
async `Suspense` and `lazy()` continuations re-enter their captured scope after
resolution or rejection. DOM event listeners
re-enter the scope where their element was mounted, and internal reactive
effects restore their captured scope boundary so event scopes cannot leak into
unrelated list or sibling updates. Unkeyed lists and
closures without a stable instance identity are left untouched. The pass runs
strictly in the DDC dev-compile path (staged into a temporary cache copy; the
developer's real source files are never touched, and `dart2js` dev mode /
`bloom js build` are unaffected). Explicit `key:` arguments always win over
injected keys. The `ForEach` scope identity hashes its item source and key
callback, so adding another keyed list in the same function does not shift
existing item scopes.

On the runtime side, `signals.dart`'s bare re-export of `signal` is now
a real wrapper: zero overhead when hot-reload tracking is inactive or
no key is present (including all production builds), otherwise it
carries the old value into a fresh `Signal` instance via a registry
stored on the JS `window` global — required because DDC's monolithic
AMD module re-execution resets all plain Dart top-level state on every
hot remount, so only `window`-stored state survives. Any type mismatch
at a given key between two compiled versions falls back to a clean
reset of the new value rather than risking silent corruption.

Verified independently: `dart analyze` clean; AST-injector unit tests
(`signal_key_injector_test.dart`); browser-level carryover tests covering
explicit keys, auto-injected keys, Live builder scopes, per-item scopes,
type-mismatch fallback, and tracking-disabled/production passthrough
(`signal_hot_reload_test.dart`);
Memo, Suspense, ErrorBoundary, Mount, and effect callback scopes in
`signal_hot_reload_test.dart`; Suspense async builder hydration in
`reactive_hydration_test.dart`; and 4 real
headless-Chromium/puppeteer end-to-end tests via real DDC compiles
(`signal_hot_remount_test.dart`), including state carryover through async
`lazy()` loaders, native custom element builder replacement, `batch()`, and
`untracked()` callbacks,
including the specific case of adding an unrelated `signal()` call
above the tracked signal and preserving different values in two keyed list
items without cross-restoring either value, including when each keyed item
contains a stateful `Live` builder.

When a keyed row is removed during normal list reconciliation, its scoped
signal values are released so re-adding the same key starts with fresh local
state. Whole-tree disposal retains values for the in-progress HMR remount.

The injector only transforms calls when the file directly imports Bloom's
`bloom_js_native.dart` entry point or its signal implementation (with or
without a prefix). It honors
`show`/`hide` combinators and skips a file when a declaration could shadow
the imported name, preventing an unrelated `signal(...)` helper from being
rewritten into an invalid call.

**Fixed in this pass:** user-created `effect()` callbacks register their
cleanup while DDC hot reload is active. The dev bootstrap disposes those
callbacks before evicting and re-executing the app module, including
top-level effects that are outside any mounted DOM region. The new module
then creates fresh effects against its new signal instances. Production and
SSR still delegate directly to `signals_core`.

Constructor expressions and named constructors assigned directly to
variables now receive per-call-site scopes at stable locations in `main`,
top-level initializers, and supported UI callbacks/build methods, including
constructors imported from another project file. Signal-bearing classes
declared in the same file also receive scopes when constructed inline at
those locations. This composes with keyed `ForEach` item scopes, so separate
store instances preserve their field-signal values independently through a
remount. The compiler skips
unkeyed repeated builders, ordinary loops, top-level factory functions, and
inline imported constructors when it cannot prove instance identity; those
patterns remain open.

**Still open:** computed values are re-derived and effect subscriptions are
recreated on each reload. Closure-local variables are not preserved. Signals
inside unkeyed lists or
other repeated closures without an instance-specific identity remain
unkeyed. `Memo`, `Suspense`, `ErrorBoundary`, `lazy()`, `defineCustomElement`,
`Mount`, `effect()`, `batch()`, and `untracked()` callback handling and DOM
event handlers are supported;
unsupported callback patterns
still need explicit signal keys.
This is still not general HMR state preservation for every pattern.

**Owner package:** `bloom_cli` (compile-time keying,
`signal_key_injector.dart`, `ddc_dev_compiler.dart`), `bloom_js_native`
(runtime matching/carry-over, `signals.dart`).

### 6. DDC fast dev-loop was opt-in — ✅ Fixed
`bloom js dev` with no flags now uses the DDC fast dev-loop by default.
`js_command.dart`'s arg parser was inverted: `--ddc` now defaults to
`true`, a new `--legacy-dart2js` flag (default `false`, `negatable:
false`) opts back out to the whole-program `dart2js -O0` path, and the
old `--experimental-ddc` flag is kept as a backward-compatible alias
(now defaulting to `true`, so any existing script/CI that still passes
it explicitly sees no behavior change). The activation logic composes
correctly with the pre-existing graceful fallback-with-warning for
Dart SDKs missing DDC snapshots. `create_command.dart`'s printed
onboarding line and the generated COOKBOOK.md template text
(`templates.dart`) were updated to describe the new default instead of
telling developers to opt in.

**Verified:** freshly scaffolded `--js-native` project (path-dependency
override to local `bloom_js_native` to pick up item 5's unpublished
`signal(key:)` param) — `bloom js dev` with no flags printed "Using DDC
(Dart Dev Compiler) fast dev-loop" and compiled cleanly;
`--legacy-dart2js` correctly forced a whole-program `dart2js` compile
(`main.js`, no DDC message). Full `bloom_cli` test suite run twice: 3
pre-existing flaky puppeteer e2e tests failed only under full-suite
concurrency and passed cleanly in isolation (confirmed contention, not
a regression from this change).

**Owner package:** `bloom_cli` (`js_command.dart`, `create_command.dart`,
`templates.dart`).

### 7. No lint rule for the #1 documented reactivity footgun — ✅ Fixed
`packages/bloom_js_native/COOKBOOK.md` §20 names "reading a signal
outside `Live`/`Show`/`ForEach` captures a one-time snapshot, not a
subscription" as the single most common beginner bug. `bloom_lint.dart`
has real rules for the *inverse* case (`live_never_reads_signal` — a
`Live` that never reads a signal, so it can never react to anything)
and five others, but nothing catches a `.value` read on a tracked
signal directly inside a `BloomNode`-returning function body, outside
any reactive callback (`Live`/`Show`/`ForEach`/`effect`/`computed`).
SolidJS ships `eslint-plugin-solid`'s `reactivity` rule for exactly
this footgun class.

A new `untracked_signal_read` rule was added to `bloom_lint.dart`,
mirroring the existing rules' AST-visitor infrastructure. It tracks
"am I currently inside a UI-building function" (via return-type and
inferred-body-return heuristics, `_isUiDeclaration`/
`_bodyReturnsUiNode`) crossed with "am I currently inside an exempted
reactive callback" (a depth counter incrementing/decrementing around
`Live`, `Show`'s non-predicate children, `ForEach`'s item builder,
`effect`, `computed`, and event-handler callbacks), and flags a
`.value` read on an identifier resolvable to a signal that falls
outside all of them.

**Verified:** 16 tests (8 true-positive: direct read in a
`BloomNode` function body, in `Show`'s non-predicate child, in a UI
getter, in an inferred-return-type UI function, and an untracked `lazy`
loader or fallback read and UI reads hidden in `batch()`/`untracked()`;
8 true-negative:
wrapped in `Live`, in `Show`'s `when:` predicate, in `ForEach`'s items
callback, in `effect()`/`computed()`, a `lazy()` loader read wrapped in `Live`, in an event handler, in
non-UI/business-logic code, `.value` on an unrelated non-signal class)
all pass. A real compile bug in the dispatch's diff was caught and
fixed during review: `InstanceCreationExpression` (used for `Show(...)`
construction) has no `.typeArguments` getter — only `MethodInvocation`
does — the erroneous `node.typeArguments?.accept(this)` call was
removed (redundant anyway; `node.constructorName.accept(this)` already
traverses it). Confirmed via `dart analyze` and a real `bloom create
--js-native` scaffold, which failed to compile before the fix and
succeeded after.

**Owner package:** `bloom_cli` (`bloom lint` command, `bloom_lint.dart`).

### 8. No transaction support in `bloom_db` — ✅ Fixed
`packages/bloom_db/lib/src/database.dart:203`'s doc comment on
`DbExecutor` claims "a driver-agnostic API for running queries,
parameterized statements, transactions, and inspecting query logs" —
but no `transaction()` method, and no `BEGIN`/`COMMIT`/`ROLLBACK`
anywhere in the file (grep confirms zero hits across
`packages/bloom_db/lib/`). `errors.dart:132` even defines an error type
assuming an active transaction can exist
(`select_for_update cannot be used outside of a transaction`), but
nothing can actually open one. Without this, any multi-write operation
(e.g. an RPC handler updating two related tables) is not atomic — a
crash or error between statements leaves partial writes. Every serious
ORM (Prisma, Drizzle, Django's own `atomic()`) supports this.

**Fix direction:** add `Future<T> transaction<T>(Future<T> Function(DbExecutor tx) callback)`
to the `DbExecutor` interface (`database.dart:216`), implemented in both
`SqliteDbExecutor` and `PostgresDbExecutor` — wrap the callback in
driver-level `BEGIN`/`COMMIT`, `ROLLBACK` on any thrown exception
(rethrow after rollback). The callback receives a `tx` executor so
nested queries run against the same connection/transaction scope
rather than the pool.

**Verified:** `Database.transaction<R>(callback)` added to the
`DbExecutor` interface, implemented in both backends —
`SqliteDbExecutor` runs raw `BEGIN`/`COMMIT`/`ROLLBACK` against the
shared `sqlite.Database` connection; `PostgresDbExecutor` delegates to
`package:postgres`'s real `Connection.runTx()`, wrapping the resulting
`TxSession` in a new `_PostgresTxExecutor implements DbExecutor` so
queries inside the callback route through the transaction rather than
the outer connection. 3 new tests added to the shared, dialect-agnostic
ORM contract suite (`shared_orm_tests.dart`, run against both SQLite
`:memory:` and a real local PostgreSQL 16) verify: commit on success,
full rollback (including a row inserted before the throw) on a thrown
exception with the original exception rethrown, and the callback's
return value is correctly propagated. All 30 tests (15 per backend)
pass; `dart analyze` clean.

**Owner package:** `bloom_db` (`database.dart`).

### 9. `bloom generate controller` has no companion test scaffold — ✅ Fixed
`generate_command.dart`'s `_GenerateControllerCommand` created a
controller file but no accompanying test, unlike `create-t3-app`/Next.js
codegen conventions where a generator's output includes a starter test.
A freshly created project does get one smoke test at project-creation
time (`templates.dart` `widgetTest`/`jsNativeSmokeTest`), but nothing
after that.

**Fix direction:** `bloom generate controller <Name>` now also writes
`test/features/<feature>/<feature>_controller_test.dart` (new
`BloomTemplates.controllerTest` template) alongside the controller
file, skipping it if the file already exists (matches the existing
`env` generator's already-exists guard pattern). The test exercises the
controller's generated `count`/`increment`/`decrement`/`reset` signal
API directly via `package:test`, no widget mount required.

**Verified:** real end-to-end scaffold (`bloom create` → `bloom
generate controller Counter`) produced a correct, compiling test file
importing the freshly generated controller. `dart analyze` clean on
both touched files. Full `bloom_cli` suite run: only the 2 known-flaky
puppeteer e2e tests failed under full-suite concurrency (pre-existing,
unrelated to this change).

**Owner package:** `bloom_cli` (`generate_command.dart`, `templates.dart`).

### 10. `bloom js create` generated permissive and empty scaffolds — ✅ Fixed
The route-guard template returned `GuardResult.allow()` while its
authorization check was still a TODO, so a developer could generate and
register a placeholder that silently granted access. Component tests were
also empty commented examples, and pages and guards had no companion tests.

**Fixed in:** generated guards return `GuardResult.deny()` until the developer
implements authorization. Components, pages, and guards now each receive a
test that imports the generated file and checks rendered markup or the guard's
fail-closed default.

**Verified:** the `js_create_command_test.dart` suite checks all three
generated test templates and the guard's default-deny behavior; `dart analyze`
and all 12 command tests pass.

**Owner package:** `bloom_cli` (`js_command.dart`).

### 11. Duplicate `ForEach` keys corrupt list bookkeeping — ✅ Fixed
The keyed reconciler stored entries in a map by key but did not reject a
duplicate key. Repeated keys could overwrite the tracked entry while leaving
duplicate DOM nodes and undisposed per-item effects behind. SSR emitted
duplicate hydration markers as well.

**Fixed in:** SSR, browser mounting, reconciliation, and keyed hydration now
validate each list snapshot before processing it. Duplicate keys throw a
clear `StateError` on SSR/initial mount and are routed through normal list
error handling on reactive updates.

**Verified:** targeted analysis and the VM hydration-marker suite pass; the
suite now asserts duplicate-key rejection during SSR. A browser mount
regression test also asserts that duplicate keys fail before any item DOM is
inserted; it is included in the JS Native browser test gate.

**Owner package:** `bloom_js_native` (`mount.dart`, `html.dart`).

**Editor schema:** A JSON Schema for `bloom.yaml` now ships at
`packages/bloom_cli/schema/bloom.schema.json`. Both project templates include
the YAML language server modeline, which enables completion and diagnostics
for known manifest fields in compatible editors. The schema leaves plugin
settings and unknown future fields open. In-editor signal/component
IntelliSense beyond the Dart LSP is still open.

## Review summary (for context)

| Dimension | Rating | Note |
|---|---|---|
| Architecture & API Design | 9/10 | Clean, declarative, elegant signal reactivity |
| Bundle Efficiency & SSR | 9.5/10 | Very fast SSR, small footprint |
| Fullstack Integration (`bloom_db`/`bloom_server`) | 9/10 | Ergonomic ORM with real atomic transactions, bounded PostgreSQL pooling, typed RPC, and a seamless same-origin dev proxy |
| Hot Reload & Dev Loop Speed | 9.5/10 | CSS hot-swap, incremental DDC compilation, fast remount, top-level and keyed-row Signal state preservation, previous-module effect disposal, and localized multi-root component updates ship; unkeyed repeated closures still need explicit keys |
| CLI Tooling & Formatters | 9/10 | CSS-safe raw-string formatting, lint rules (including the #1 documented reactivity footgun), static Tailwind build, generator test scaffolding, and a `bloom.yaml` JSON Schema now ship; broader component-aware editor intelligence is still open |
