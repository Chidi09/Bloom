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
- `--host <host>`: Host interface to bind (default: `0.0.0.0`).

### Features
1. **Zero-Config Hot Reload**: Automatically establishes an SSE broadcast stream at `/_bloom_hr` and injects a 0.5kB receiver script into served `index.html` on the fly.
2. **Sub-Second Recompilation**: Uses the `-O0` fast development compiler to build updated bundles upon file modifications.
3. **Smart Debounced Watcher**: Monitors `lib/` and `web/` with a 150ms debounce window to prevent edit thrashing.
4. **Zero External Runtime Needed**: Runs 100% native asynchronous Dart `HttpServer` (no `python -m http.server` or `npm run dev` required).
5. **MIME & SPA Engine**: Serves HTML, JS, CSS, WASM, SVG, and handles SPA client-side route fallbacks.

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
`renderForTest`.

### Page (`--page` / `-p`)

```bash
bloom js create Dashboard --page
```

Writes `lib/pages/dashboard.dart` with a `BloomNode Dashboard(Map<String,
String> params)` signature (matching `BloomRoute.builder`'s shape) and a doc
comment showing both a plain `BloomRoute` registration and a
`loader`/`dataBuilder` registration for data-driven pages. No test file is
required to be added manually — one is scaffolded alongside it, same as the
component case.

### Route guard (`--guard` / `-g`)

```bash
bloom js create Auth --guard
```

Writes `lib/guards/auth_guard.dart` with a `class AuthGuard extends
BloomRouteGuard` skeleton (`canActivate` stub returning a `GuardResult`). The
name is auto-suffixed with `Guard` unless it already ends in one (`Auth` →
`AuthGuard`, but `AuthGuard` stays `AuthGuard`). No test file is scaffolded
for guards — a guard's `canActivate` behavior is typically exercised via the
router's own test suite rather than in isolation.

Name validation is shared across all three variants: the name must be
non-empty and start with a letter (`snake_case`/`PascalCase` are both
accepted as input; the CLI derives both the Dart class name and the
`snake_case` file name from whatever's given). Running against a name whose
target file already exists is an error — it will not silently overwrite.
