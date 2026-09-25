# 07 — Developer Tooling & CLI Suite

Bloom provides a dedicated command-line suite for developing, building, analyzing, and deploying JS Native applications without third-party web servers or Node/Python dependencies.

---

## 1. Native Hot Live-Reload Server (`bloom js dev`)

Starts the pure-Dart development server with instant static file serving, SPA routing fallback, Server-Sent Events (SSE) live reload, and automatic file-watching recompilation:

```bash
bloom js dev -p 8080
```

### Options
- `-p, --port <port>`: Port to bind (default: `8080`).
- `-e, --entry <file>`: Custom entry point Dart file.
- `--host <host>`: Host interface to bind (default: `127.0.0.1`; use `0.0.0.0` for LAN access).

### Features
1. **Zero-Config Hot Reload**: Automatically establishes an SSE broadcast stream at `/_bloom_hr` and injects a 0.5kB receiver script into served `index.html` on the fly.
2. **Fast Development Compilation**: Uses DDC by default and falls back to `dart2js -O0` when the SDK lacks DDC snapshots or Bloom cannot build the DDC runtime; `--legacy-dart2js` explicitly selects the fallback.
3. **Incremental DDC Worker**: Keeps a DDC worker alive across edits and sends content digests for Dart inputs, allowing the compiler front end to reuse unchanged compiler state. If the installed SDK cannot run worker mode, the CLI falls back to one-shot DDC.
4. **Smart Debounced Watcher**: Monitors `lib/` and `web/` with a 150ms debounce window to prevent edit thrashing.
5. **Zero External Runtime Needed**: Runs 100% native asynchronous Dart `HttpServer` (no `python -m http.server` or `npm run dev` required).
6. **MIME & SPA Engine**: Serves HTML, JS, CSS, WASM, SVG, and handles SPA client-side route fallbacks.
7. **Component-aware DDC updates**: Instruments `BloomNode build()` methods with stable development identities and patches or replaces anchored component ranges locally, including components that emit multiple DOM roots. Unsupported reactive structures fall back to an app remount.
8. **Scoped signal carryover**: Automatically keys stable signal call sites, preserves values in supported reactive callbacks and keyed list rows, and isolates stateful objects assigned to variables at stable constructor call sites, including imported classes. Ambiguous unkeyed repetition and arbitrary factories remain explicit-identity cases.

---

## 2. Production Optimized Build (`bloom js build`)

Compiles an optimized production JavaScript bundle using the Dart `-O4` whole-program tree-shaking compiler:

```bash
bloom js build
```

### Performance & Budget Analysis (`--analyze`)
Pass `--analyze` to generate a detailed per-asset size breakdown and gzip estimate:

```bash
bloom js build --analyze
```

#### Sample Analysis Output:
```text
🏗  Compiling Bloom JS Native production bundle (O4)...
✓ Build completed in 3.65s: web/main.js (134.1 kB)

📊 Bloom JS Native — Bundle Analysis Report
┌────────────────────────────────────────┬──────────────┬──────────────┐
│ Asset                                  │ Raw Size     │ Gzip (est)   │
├────────────────────────────────────────┼──────────────┼──────────────┤
│ main.js                                │ 134.1 kB     │ 33.5 kB      │
│ vendor/three.min.js                    │ 128.4 kB     │ 36.0 kB      │
│ vendor/chart.min.js                    │ 68.2 kB      │ 19.1 kB      │
│ vendor/canvas-confetti.min.js          │ 12.0 kB      │ 3.4 kB       │
└────────────────────────────────────────┴──────────────┴──────────────┘
```

---

## 3. NPM Vendoring (`bloom js vendor`)

Synchronizes and snapshots NPM libraries declared in `bloom.yaml` into `web/vendor/`:

```bash
bloom js vendor
```

---

## 4. Code Scaffolding (`bloom js create`)

Generates a new component, page, or route guard from a template, matching the
role Angular's `ng generate`/`create-react-app` templates play — but scoped to
a single file (plus a matching test) instead of a whole project.

```bash
bloom js create <Name> [--page | --guard]
```

Must be run from inside a Bloom project (i.e. somewhere `BloomProject.find()`
can locate the project root). `--page` and `--guard` are mutually exclusive;
passing neither scaffolds a plain component.

### Component (default)

```bash
bloom js create UserCard
```

Writes `lib/components/user_card.dart` (a `BloomNode UserCard(...)` function
skeleton) and a matching `test/user_card_test.dart` using `bloom_test`'s
`renderForTest`. The generated test imports the component and checks that it
renders its expected markup.

### Page (`--page` / `-p`)

```bash
bloom js create Dashboard --page
```

Writes `lib/pages/dashboard.dart` with a `BloomNode Dashboard(Map<String,
String> params)` signature (matching `BloomRoute.builder`'s shape) and a doc
comment showing both a plain `BloomRoute` registration and a
`loader`/`dataBuilder` registration for data-driven pages. A test file is
scaffolded alongside it and verifies that the page renders.

### Route guard (`--guard` / `-g`)

```bash
bloom js create Auth --guard
```

Writes `lib/guards/auth_guard.dart` with a `class AuthGuard extends
BloomRouteGuard` skeleton (`canActivate` returns `GuardResult.deny()` until
you implement authorization). This default fails closed, so a generated
placeholder cannot silently grant access. A companion test verifies the
default denial. The name is auto-suffixed with `Guard` unless it already ends
in one (`Auth` → `AuthGuard`, but `AuthGuard` stays `AuthGuard`).

Name validation is shared across all three variants: the name must be
non-empty and start with a letter (`snake_case`/`PascalCase` are both
accepted as input; the CLI derives both the Dart class name and the
`snake_case` file name from whatever's given). Running against a name whose
target file already exists is an error — it will not silently overwrite.
