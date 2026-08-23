# Changelog

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
