# `bloom create`

Scaffolds a new, production-ready Bloom application with complete architecture, routing, configuration, and native scaffolding.

---

## 💻 Synopsis

```bash
bloom create <project_name> [options]
```

---

## ⚙️ Options & Flags

| Flag | Abbreviation | Default | Description |
| :--- | :--- | :--- | :--- |
| `--org` | `-o` | `dev.bloom` | Organization reverse domain prefix for Android package and iOS bundle identifier (e.g. `com.example`). |
| `--description`| `-d` | `"A modern application built with the Bloom Framework."` | Description string placed in `pubspec.yaml` and `bloom.yaml`. |
| `--framework-path` | | `null` | Path to a local `bloom_framework` directory. When provided, configures a path dependency rather than pub dependency (ideal for monorepo development). |
| `--help` | `-h` | | Print usage information. |

---

## 🚀 Examples

### Standard App Creation
```bash
bloom create storefront --org com.mycompany
```

### Monorepo / Local Framework Linking
```bash
bloom create internal_tool --framework-path /root/dev/Bloom/packages/bloom_framework
```

---

## 🚪 Exit Codes

| Code | Meaning |
| :---: | :--- |
| **`0`** | Project successfully generated and ready for development. |
| **`1`** | Failure: missing project name, target directory already exists, or invalid project name format. |
