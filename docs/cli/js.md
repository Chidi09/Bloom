# `bloom js` CLI Reference Manual

The `bloom js` command suite is the dedicated toolchain for developing, compiling, analyzing, and vendoring **Bloom JS Native** fine-grained reactive web applications.

---

## 1. `bloom js dev` — Hot Live-Reloading Dev Server

Starts a native asynchronous Dart HTTP development server with automatic file watching, incremental compilation, Server-Sent Events (SSE) live reload, and dynamic script auto-injection.

```bash
bloom js dev [options]
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `-p, --port <port>` | Port to bind the dev server. | `8080` |
| `-e, --entry <file>` | Custom entrypoint Dart file. | `lib/main.dart` or `example/main.dart` |
| `--host <host>` | Host network interface to bind. | `0.0.0.0` |

### Architecture & Lifecycle
1. **NPM Auto-Sync**: Automatically verifies and bundles any NPM dependencies declared in `bloom.yaml` via Bun.
2. **Fast Initial Build**: Compiles `lib/main.dart` to `web/main.js` using `-O0` fast development optimization flags.
3. **Zero-Config Script Auto-Injection**: Injects a 0.5kB live receiver into served `index.html` before `</body>` on the fly.
4. **Debounced File Watcher (`150ms`)**: Monitors `lib/` and `web/` recursively.
5. **SSE Broadcast Stream (`/_bloom_hr`)**: When a `.dart` file changes, re-compiles `main.js` and immediately pushes `event: reload` to all connected browser tabs.

---

## 2. `bloom js build` — Production AOT Optimizer

Compiles the Bloom JS application for production using Dart whole-program tree-shaking, symbol minification, and dead-code elimination.

```bash
bloom js build [options]
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `-o, --output <path>` | Target output JavaScript bundle path. | `web/main.js` |
| `-e, --entry <path>` | Entrypoint Dart file. | `lib/main.dart` |
| `--analyze` | Generates a detailed size and gzip breakdown report. | `false` |

### Bundle Analysis Output (`--analyze`)
```text
🌸 Building Bloom JS Native Web Application for Production...
› Entry  : lib/main.dart
› Output : web/main.js
› Mode   : -O4 Whole-Program Optimization & Tree-Shaking

✓ Production build succeeded in 4.12s!
  • Output Bundle : web/main.js (134.2 kB)

📊 Bloom JS Native — Bundle Analysis Report
┌────────────────────────────────────────┬──────────────┬──────────────┐
│ Asset                                  │ Raw Size     │ Gzip (est)   │
├────────────────────────────────────────┼──────────────┼──────────────┤
│ main.js                                │ 134.2 kB     │ 33.5 kB      │
│ vendor/lucide.min.js                   │ 42.1 kB      │ 11.2 kB      │
│ vendor/canvas-confetti.min.js          │ 12.0 kB      │ 3.4 kB       │
└────────────────────────────────────────┴──────────────┴──────────────┘
```

---

## 3. `bloom js vendor` — NPM Package Bundler

Downloads, snapshots, and bundles NPM dependencies declared in `bloom.yaml` into self-contained ESM bundles in `web/vendor/`.

```bash
bloom js vendor
```

* **Preferred Bundler**: Uses local `bun` for lightning-fast bundling.
* **Fallback Resolver**: Automatically falls back to ESM CDN HTTP resolvers if Bun is not installed.
* **Importmap Generator**: Updates `web/index.html` with accurate ESM module resolution paths.
