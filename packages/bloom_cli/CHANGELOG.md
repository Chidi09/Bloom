# Changelog

## 0.7.2 - 2026-08-26

### Added
* **`bloom js dev`** now uses the DDC (Dart Dev Compiler) fast dev-loop by default — no flag required. `--legacy-dart2js` opts out to the whole-program `dart2js -O0` dev path; `--experimental-ddc` remains as a backward-compatible alias.
* **`untracked_signal_read` lint rule**: `bloom lint` now flags a `.value` read on a signal directly inside UI-building code, outside `Live`/`Show`/`ForEach`/`effect`/`computed` — the #1 documented reactivity footgun in `bloom_js_native`'s COOKBOOK.md.
* **`bloom generate controller`** now also scaffolds a companion `test/features/<feature>/<feature>_controller_test.dart` exercising the generated controller's signal API.

## 0.7.1 - 2026-08-26

### Added
* **`bloom build web_dom`**: pure-Dart web apps now build into a dedicated `build/web/` output directory (matching Flutter web's convention) instead of in place inside the source `web/` directory. `TailwindStaticBuild` wraps the real `@tailwindcss/cli` v4 via `bunx` to emit a minified, static `build/web/dist/app.css` for production, swapping the dev-mode `@tailwindcss/browser` `<script>` tag for a production `<link rel="stylesheet">` in the built copy of `index.html` only. `bloom deploy` for `web_dom` projects now targets `build/web`, matching every other web target — a `bloom build web_dom` run is required before deploying (previously deploy could point straight at source).
* **`bloom js dev --experimental-ddc`**: on a Dart source edit, the dev server now performs an in-page fast remount (dispose the active mount, evict the cached RequireJS module, re-invoke `main()`) instead of a full `window.location.reload()` — no browser navigation. The `dart2js` dev path's reload behavior is unchanged.

### Fixed
* CSS hot-swap (`css_hot_swap.dart`) no longer misidentifies certain brace boundaries during its skeleton diff.

## 0.7.0 - 2026-08-25

### Added
* **`bloom format`**: AST-aware formatter for `bloom_js_native` projects. Runs the official `dart_style` (tall-style) formatter, then a `package:analyzer`-based pre-pass that wraps long named-argument string literals (e.g. `className: '...'`) into adjacent string literals split at word boundaries — the one thing `dart_style` structurally cannot do for any Dart code, since splitting a literal could change its meaning. Also normalizes embedded raw CSS strings (`const fooCss = r'''...''';` and `Style(r'''...''')` blocks) — reindents selectors/declarations/at-rules without ever rewriting property or value tokens. `--check` mode matches `dart format --set-exit-if-changed` semantics for CI. Automatically skips generated `lib/src/plugins/` bindings from `bloom add npm:<pkg>`.
* **`bloom lint`**: AST-based static analysis for Bloom-specific footguns, grounded in COOKBOOK.md's "Best Practices & Common Pitfalls" section: force-unwrapping nullable `BloomEvent.value`/`.checked`, `ForEach<T>(...)` missing a `key:` extractor, importing `browser.dart` in test files, `Live(...)` builders that never read a signal (so can never react to anything), in-place mutation of a signal's List/Map (`signal.value.add(...)` instead of reassigning `.value`), and hand-authored `<style>`/`<link rel="stylesheet">` tags in `web/index.html` for `target: web_dom` projects.

## 0.6.2 - 2026-08-24

### Added
* `bloom add npm:@tailwindcss/browser` now works correctly: writes a dedicated self-executing `<script type="module">` (Tailwind's browser build has no JS API to bind, so no Dart interop binding is generated for it), fixed a regex collision that could delete this script when a second package was later added.
* `.d.ts`-driven `@JS()` binding generator (`bloom add npm:<package>`) now parses a package's real exported member names instead of emitting a single guessed member.
* `bloom create --js-native`'s generated `bloom.yaml` now sets `target: web_dom`, which several CLI subsystems (`bloom add`, `bloom build`, `bloom dev`) key off of — without it, `bloom add npm:<package>` misrouted js-native projects through native mobile plugin handling instead of npm.
* `bloom create --js-native`'s generated `AGENTS.md` and COOKBOOK.md now document the real `bloom add`/Tailwind/design-token/font workflows in full.

## 0.6.1 - 2026-08-24

### Added
* `bloom create --js-native`'s generated `AGENTS.md` now includes a full best-practices checklist (reactivity, nullable event fields, the two-entry-point rule, SSR gotchas, disposal, styling, testing) mirroring COOKBOOK.md's new Section 20.

## 0.6.0 - 2026-08-24

### Added
* **`bloom create <name> --js-native`**: scaffolds a Flutter-free Bloom JS Native project (pubspec.yaml with no `flutter` dependency, `bloom.yaml`, `web/index.html`, `lib/main.dart` correctly importing `browser.dart` for `mount()`, a smoke test, and a generated `AGENTS.md`) instead of shelling out to `flutter create`.

### Fixed
* `bloom --version` / `bloom -v` printed a stale hardcoded `0.1.0` regardless of the installed release; now kept in sync with `pubspec.yaml`.

## 0.5.0 - 2026-08-24

### Added
* **`bloom typegen`**: compile-checked, typed route builder generation from route annotations.
* **`bloom insights`**: live dev-server request log (`GET /__insights` on the dev server; `--url`/`--json`/`--limit` flags, with port auto-discovery when `--url` is omitted).
* **`bloom doctor`**: new System Information section (OS/CPU/CLI process memory) and a best-effort Version Check against pub.dev.
* **Open in editor**: dev error overlay entries now have an "Open `file:line`" button that launches `$VISUAL`/`$EDITOR` (or `code --goto`) at the exact error location, with path-containment and shell-injection guards.
* **`bloom fonts optimize`**: self-hosts Google Fonts `.woff2` files at build time and generates `fonts.g.css` with a CLS-mitigation fallback face.
* **`bloom og generate`**: build-time Open Graph social card PNG generator (1200x630).
* Server-side image optimizer for responsive variants.
* Production deployment for web targets.

## 0.4.0 - 2026-08-23

- Bun vendoring, SSR router endpoint, and SSG prerendering delivered end to end.
- Module authoring/scaffolding improvements.
- Scaffolded projects now resolve `bloom_js_native` and `bloom_seo` from pub.dev
  rather than from sibling paths.

## 0.3.1

### Added
* **Live SSE Hot Reload Dev Server**: Introduced `BloomLiveReloadServer` with automatic script injection and Server-Sent Events on `/_bloom_hr`.
* **Debounced Recursive Source Watcher**: Added `BloomSourceWatcher` with 150ms debouncing and multi-directory inotify tracking for `.dart`, `.html`, `.css`, and `.yaml` files.
* **Server Hot Restart**: Integrated sub-80ms isolate hot restart in `bloom server run --watch`.
* **Fast JS Dev Compiler**: Upgraded `bloom js dev` with `-O0` fast development compiler and live browser reload.

## 0.3.0

### Breaking

* **`bloom add` and `bloom remove` now validate plugin names**: an unrecognized name prints the supported plugin ids and exits with code `1`, writing nothing to `bloom.yaml` and skipping prebuild. Previously any string was accepted and written straight to `bloom.yaml`, so a typo such as `bloom add camrea` reported success while silently configuring nothing.
* Plugin names are canonicalized (trimmed, lowercased, `-` converted to `_`), so `secure-storage`, `secure_storage` and `Secure-Storage` all resolve to the single canonical id `secure_storage`, and that canonical id is what gets written to `bloom.yaml`.

### Added

* **Incremental Static Regeneration (ISR) for SSR**: Wires up the `revalidate: Duration(...)` parameter in `@BloomLoader` annotations to enable stale-while-revalidate full-page HTML caching in `bloom build web --server`. Routes with `revalidate` serve cached HTML within the duration, serve stale HTML immediately while regenerating in the background once stale, and populate cache on demand on first hit.
* **Real headless-browser prerendering for SSG/SSR**: `bloom build web --static`/`--server` now compile the real Flutter web app (`flutter build web --release`) and drive a real headless Chromium instance (via `puppeteer`) to capture the genuine rendered DOM for each route, replacing the previous static placeholder-shell HTML. Falls back gracefully to the old shell template whenever Chromium is unavailable or a route fails to render, so a build never fails or hangs because of prerendering. `bloom_framework`'s `BloomApp` now signals readiness (and force-enables the Flutter semantics/accessibility tree, which is what produces real descriptive DOM content) after its first frame, on web only.
* **Real Bloom-branded PWA icons**: `bloom build web --static`/`--server` now generate genuine `Icon-192.png`/`Icon-512.png`/maskable/apple-touch-icon/favicon assets from the real Bloom five-petal gradient mark (rasterized via the same headless Chromium pipeline), instead of a `manifest.json` that pointed at files which never actually existed. Falls back to leaving any pre-existing icons untouched when Chromium is unavailable.

### Fixed

* **Documented plugins received no prebuild transformations**: the prebuild engines only recognized `camera`, `notifications` and `location`, so `background_tasks` never had `WAKE_LOCK` injected and the hyphenated spellings shown in the docs matched nothing at all. Plugin metadata now lives in a single shared `BloomPluginCatalog` read by both the Android and iOS prebuild engines and by `bloom add` / `bloom remove`, so the CLI and the platform manifests can no longer drift apart.

## 0.1.0

* **Project Creation & Templates**: `bloom create <app>` with official and community starter templates (`--template`).
* **Interactive Dev Server**: `bloom dev` with wireless LAN pairing and TUI shortcuts.
* **Diagnostics & Continuous CI Health**: `bloom doctor` and strict `bloom doctor --ci`.
* **Zero-Config Native Autolinking**: `bloom add`, `bloom deps`, `bloom why`, and `bloom workspace`.
* **Native Module Authoring & Sandbox**: `bloom create module`, `bloom module dev`, and `bloom module test`.
* **Asset Optimization Pipeline**: `bloom assets optimize`, `bloom assets analyze`, `bloom assets generate`.
* **Security & Vulnerability Auditing**: `bloom audit` and `bloom security scan`.
* **Architectural Explanation**: `bloom explain route <path>` and `bloom graph`.
* **Ecosystem Package Registry**: `bloom registry search` and `bloom registry info`.
* **Automated Upgrades & Migrations**: `bloom upgrade` and `bloom doctor --upgrade`.
