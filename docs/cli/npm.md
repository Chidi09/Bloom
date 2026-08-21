# `bloom npm` & `bloom add` CLI Reference Manual

Bloom includes an integrated NPM package management and vendoring pipeline. It allows Bloom JS Native web applications to seamlessly leverage any NPM package without requiring `package.json` or Node.js runtime environments.

---

## 1. `bloom add` — Add Dependencies

Adds either pub.dev Dart packages or NPM JavaScript libraries to your project manifest (`pubspec.yaml` or `bloom.yaml`).

```bash
# Add a pub.dev Dart package
bloom add equatable
bloom add http:^1.2.0

# Add an NPM JavaScript library
bloom add npm:canvas-confetti
bloom add npm:lucide@^1.33.0
bloom add npm:three
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `-d, --dev` | Adds dependency as a dev dependency. | `false` |
| `--no-sync` | Skips immediate bundle download/vendoring. | `false` |

---

## 2. `bloom npm sync` — Vendor & Bundle NPM Packages

Inspects all NPM packages declared in `bloom.yaml`, bundles them into self-contained minified ESM modules via Bun, and places them into `web/vendor/`.

```bash
bloom npm sync
```

### Manifest Declaration (`bloom.yaml`)
```yaml
name: my_bloom_dashboard
target: web_dom

npm:
  canvas-confetti: ^1.9.4
  lucide: ^1.33.0
  chart.js: ^4.4.1
  fuse.js: ^7.5.0
```

### Generated Output
```
web/
├── index.html       # Automatically updated with importmap
└── vendor/
    ├── canvas-confetti.min.js
    ├── lucide.min.js
    ├── chart.js.min.js
    └── fuse.js.min.js
```

---

## 3. `bloom remove` — Uninstall Dependency

Removes a Dart or NPM package and cleans up its vendored bundle and manifest entries.

```bash
bloom remove equatable
bloom remove npm:canvas-confetti
```
