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

```
bloom js vendor      # bun add + offline cache → vendor/
bloom js install     # hydrate vendor/ on CI
```

- `NpmRegistry` Dart declarations drive `bun add <pkg>@<version>` under the hood.
- Import map flips from `esm.sh` URLs to `/vendor/...` local files.
- Reproducible builds; works behind firewalls.

## T4 — Wasm target evaluation (deferred)

- Evaluate `dart2wasm` + DOM interop once `package:web` wasm interop stabilizes.
- Explicitly **deferred** — not on the M1–M6 critical path.
- Success criteria: wasm payload + JS glue < dart2js payload for hello-world, with equivalent perf.

## Non-goals

- Hand-rolled package manager — Bun is the toolchain, Dart orchestrates.
- Custom JS bundler/minifier — `dart compile js -O4` already does it.
- Forking Dart SDK — upstream `dart2js`/`dart2wasm` are the compilers.
