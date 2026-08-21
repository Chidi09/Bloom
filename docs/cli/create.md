# `bloom create` CLI Reference Manual

Scaffolds a new Bloom application or monorepo workspace from curated production templates with dependency wiring and filesystem routing ready out-of-the-box.

---

## 1. Synopsis

```bash
bloom create <project_name> [options]
```

---

## 2. Options & Flags

| Flag | Abbreviation | Default | Description |
| :--- | :--- | :--- | :--- |
| `--org` | | `com.example` | Reverse-domain organization prefix used for Android package names and iOS bundle IDs. |
| `--description` | | `"A new Bloom project."` | Project description injected into `pubspec.yaml` and `bloom.yaml`. |
| `--template` | `-t` | `fullstack` | Template profile to instantiate (`fullstack`, `web_only`, `mobile_only`, `server_only`, `minimal`). |
| `--framework-path` | | Auto-detected | Local directory path to `bloom_framework` for monorepo development. |
| `--no-pub` | | `false` | Skips running `dart pub get` / `flutter pub get` after scaffolding. |
| `--help` | `-h` | | Print usage information. |

---

## 3. Template Profiles

### `fullstack` (Default)
Scaffolds a complete enterprise monorepo:
* `apps/web`: Bloom JS Native web application with fine-grained reactivity and Tailwind tokens.
* `apps/mobile`: Bloom Flutter client targeting iOS and Android.
* `apps/server`: Multi-isolate backend API with OpenAPI generation and SSR landing page.
* `packages/core`: Shared domain entities (`Task`, `User`, `Workspace`), validation schemas, and constants.

### `web_only`
Scaffolds a lightweight Bloom JS Native web application without Flutter mobile dependencies.

### `server_only`
Scaffolds a standalone Django-inspired Bloom Server backend runtime.

---

## 4. Exit Codes

| Code | Meaning |
| :---: | :--- |
| **`0`** | Project successfully scaffolded and initial dependencies installed. |
| **`1`** | Target directory already exists, invalid project name, or network failure during package resolution. |
