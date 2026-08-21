# NPM_INTEROP — Bloom JS Native

Bun is the toolchain backend. Dart orchestrates. No hand-rolled package manager.

## Honest constraint

> Full arbitrary-npm compatibility is impossible without shipping `node_modules`. Guarantee: **any ESM-compatible, browser-safe package works**. Anything needing Node globals, native addons, or `window` at import time needs a typed binding (v2) or the `dart:js_interop` escape hatch.

Document this plainly. Do not over-promise.

## v0 — Import maps (ship in M1)

```dart
// Register dependencies in Dart code — build step emits the import map.
NpmRegistry.register(const NpmDependency('zod', '^3.23.0'));
NpmRegistry.register(const NpmDependency('date-fns', '3.6.0'));

// Emit into index.html (build script or server):
final tag = NpmRegistry.generateImportMapTag();
// <script type="importmap">{"imports":{"zod":"https://esm.sh/zod@^3.23.0", ...}}</script>
```

- Provider defaults to `esm.sh` (browser ESM, version-pinned). Override per-dep: `NpmDependency('pkg','1.0', cdn: 'https://cdn.jsdelivr.net/npm')`.
- Import specifier defaults to package name; override: `importAs: 'lodash-es'`.
- Browser fetches only what's imported; HTTP caching does the rest. `vendor/` not needed for correctness — only for reproducibility (v1).

Usage in Dart (via `dart:js_interop` escape hatch until typed bindings land):

```dart
@JS('zod')
external JSZod get zod; // define minimal interop surface you actually use
```

## v1 — Bun vendoring (M4)

```
bloom js vendor
```

Shells out to `bun add` / offline cache to snapshot exact versions into `vendor/` or `web/vendor/`. Import map then points at local files:

```json
{ "imports": { "zod": "/vendor/zod@3.23.8/index.mjs" } }
```

- Reproducible builds, works behind firewalls.
- Bun is an **implementation detail** — no Dart package manager is shipped. Dart just generates the map and shells out.

## v2 — Typed bindings (later)

Codegen generates typed Dart wrappers for a curated set of popular packages (zod schemas → `bloom_validate` bridges as example). Arbitrary packages keep working via `dart:js_interop`.

```
dart run bloom_js_native:codegen --package zod
# → lib/src/bindings/zod.g.dart with JS interop types
```

## Import map generation API

```dart
NpmRegistry.registerAll([ ... ]);
NpmRegistry.generateImportMapJson(pretty: true); // String
NpmRegistry.generateImportMapTag();               // <script type="importmap">...</script>
NpmRegistry.toMap();                              // Map<String,dynamic>
NpmRegistry.clear();                              // tests
```

## Styling note

npm packages that ship CSS should be imported as real CSS (via `<link>` or `Style(css)` node). No CSS-in-JS interception.

## Phase 12 lesson

XSS escaping in `renderToHtml` is non-negotiable — attribute/text interpolation always escaped. Same discipline applies to generated import maps: values are JSON-encoded, never string-interpolated raw.

## Migration from Jaspr

Study Jaspr, don’t copy it. Our differentiation:

1. npm-native imports via import maps / ESM CDN resolution
2. Batteries included — signals/zustand, bloom_data/tanstack, bloom_validate/zod equivalents built-in
3. Dart-controlled compiler pipeline with tree-shaking reports (“only ship the JS you need” is measurable)
