# COMPILER_ROADMAP — Bloom JS Native

Bun is the toolchain backend; `bloom js` verbs are convenience wrappers.

## T0 — Plain dart compile js (M1)

No custom compiler. Just `dart compile js`.

```bash
dart compile js -O4 -o main.js main.dart
```

Document baseline: target `<50KB gzipped` for hello-world. Measure from M1, optimize from there.

## T1 — bloom js dev (M4)

```
bloom js dev
```

- `dart2js --watch` (or `dart compile js` in watch mode) + static file server + live reload.
- Serves `example/index.html` + import map, reloads on `.dart` change.
- No custom bundler — reuses existing Dart toolchain.

## T2 — Tree-shaking report (M4+)

```
bloom js build --analyze
# → bytes-per-dependency report: "only ship the JS you need" is measurable
```

- Parse `dart2js`/`dart compile js` output + source maps to attribute bytes to packages.
- Output JSON + pretty CLI table. Gate: fail if reported JS exceeds budget.
- Foundation for “only ship the JS you need” being a **number**, not a slogan.

## T3 — Bun orchestration (M4)

```bash
bloom js vendor      # bun add + offline cache → web/vendor/
bloom add npm:<pkg>  # declare in bloom.yaml, vendor, and generate typed bindings
```

- `NpmRegistry` Dart declarations drive `bun add <pkg>@<version>` under the hood.
- Import map points at `/vendor/...` local files.
- Reproducible builds; works behind firewalls.

## T4 — Wasm target (`dart2wasm`)

- Supported via `bloom js build --wasm` (`dart compile wasm -O4`), verified against headless Chrome (`dart test -p chrome -c dart2wasm`) and the 50 KiB combined `.wasm` + `.mjs` gzip budget on `example/main.dart` (~36.8 KiB gzipped: 33.6 KiB `.wasm` + 3.2 KiB `.mjs`).
- When comparing `package:web` DOM node references in `dart2wasm`, use `==`/`!=` (or `equals()` in tests) rather than `identical()`/`same()`, because JS DOM objects are boxed in `JSValue`.

## Non-goals

- Hand-rolled package manager — Bun is the toolchain, Dart orchestrates.
- Custom JS bundler/minifier — `dart compile js -O4` already does it.
- Forking Dart SDK — upstream `dart2js`/`dart2wasm` are the compilers.
