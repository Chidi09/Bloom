# 07 — Developer Tooling & CLI Suite

Bloom provides a dedicated command-line suite for developing, building, analyzing, and deploying JS Native applications without third-party web servers or Node/Python dependencies.

---

## 1. Native Dev Server (`bloom js dev`)

Starts the pure-Dart development server with instant static file serving, SPA routing fallback, and automatic file-watching recompilation:

```bash
bloom js dev -p 8080
```

### Options
- `-p, --port <port>`: Port to bind (default: `8080`).
- `-e, --entry <file>`: Custom entry point Dart file.
- `--host <host>`: Host interface to bind (default: `0.0.0.0`).

### Features
1. **Zero External Runtime Needed**: Runs 100% native asynchronous Dart `HttpServer` (no `python -m http.server` or `npm run dev` required).
2. **Auto-Recompile on Save**: Watches `lib/` for `.dart` changes and rebuilds `web/main.js` with debounced sub-second compilation.
3. **MIME & SPA Engine**: Serves HTML, JS, CSS, WASM, SVG, and handles SPA client-side route fallbacks.

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
