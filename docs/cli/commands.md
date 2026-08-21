# Bloom CLI Master Command Index & Architecture Manual

The **Bloom CLI (`bloom`)** is the unified developer toolchain for scaffolding, developing, analyzing, testing, and deploying full-stack Bloom applications across **Mobile**, **Desktop**, **JS Native Web**, and **Multi-Isolate Backend Servers**.

---

## 1. Global Syntax & Environment Flags

```bash
bloom <command> [subcommand] [arguments...] [options...]
```

### Global Options

| Flag | Description |
| :--- | :--- |
| `-v, --verbose` | Enables verbose diagnostic logging, stack traces, and internal process telemetry. |
| `--version` | Displays the current Bloom toolchain and CLI engine version. |
| `-h, --help` | Prints contextual help and syntax for the specified command or subcommand. |

### Global Environment Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `BLOOM_ENV` | Active environment runtime profile (`development`, `staging`, `production`). | `development` |
| `BLOOM_PORT` | Default HTTP port for dev servers and backend runtimes. | `8080` |
| `BLOOM_PACKAGES_PATH` | Explicit path override for local `bloom_*` framework packages in monorepos. | Auto-discovered |
| `BLOOM_NO_COLOR` | Disables ANSI color output when running inside automated CI/CD runners. | `false` |

---

## 2. Complete Command Matrix (31 Toolchain Commands)

### 🚀 Application Development & Lifecycle

| Command | Subcommands | Description |
| :--- | :--- | :--- |
| [**`bloom dev`**](file:///root/dev/Bloom/docs/cli/dev.md) | — | Starts the interactive full-stack dev server with dashboard, QR pairing, and TUI shortcuts. |
| [**`bloom js`**](file:///root/dev/Bloom/docs/cli/js.md) | `dev`, `build`, `vendor` | Develop, compile (-O4), and vendor fine-grained Bloom JS Native web applications. |
| [**`bloom server`**](file:///root/dev/Bloom/docs/cli/server.md) | `run`, `create`, `startapp` | Scaffold, run, and hot-restart multi-isolate Bloom Server backend runtimes. |
| [**`bloom run`**](file:///root/dev/Bloom/docs/cli/dev.md) | — | Launches the native Flutter mobile/desktop client with VM hot reload. |
| [**`bloom build`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-build) | `apk`, `appbundle`, `ipa`, `web`, `server` | Compiles optimized, signed production release binaries. |
| [**`bloom deploy`**](file:///root/dev/Bloom/docs/cli/deploy.md) | — | Orchestrates Over-The-Air (OTA) code-push patches via Shorebird. |

---

### 📦 Project Scaffolding & Code Generation

| Command | Subcommands | Description |
| :--- | :--- | :--- |
| [**`bloom create`**](file:///root/dev/Bloom/docs/cli/create.md) | — | Scaffolds a new Bloom application from curated production templates. |
| [**`bloom create module`**](file:///root/dev/Bloom/docs/cli/module.md) | — | Scaffolds a standalone `@BloomModule` with Swift/Kotlin native bindings. |
| [**`bloom generate`**](file:///root/dev/Bloom/docs/cli/generate.md) | `route`, `controller`, `model`, `service` | Generates type-safe boilerplate and synchronizes filesystem routes (`routes.g.dart`). |
| [**`bloom templates`**](file:///root/dev/Bloom/docs/cli/create.md) | `list`, `info` | Lists official and community application scaffolding templates. |

---

### 🎨 UI & Package Management

| Command | Subcommands | Description |
| :--- | :--- | :--- |
| [**`bloom ui`**](file:///root/dev/Bloom/docs/cli/ui.md) | `add`, `list`, `diff` | Copies zero-dependency, dark-themed Shadcn-inspired UI components directly into `lib/ui/`. |
| [**`bloom add`**](file:///root/dev/Bloom/docs/cli/npm.md) | `npm:<pkg>`, `<pkg>` | Adds pub.dev dependencies or vendors NPM packages directly. |
| [**`bloom remove`**](file:///root/dev/Bloom/docs/cli/npm.md) | — | Safely uninstalls dependencies and updates `bloom.yaml` / `pubspec.yaml`. |
| [**`bloom npm`**](file:///root/dev/Bloom/docs/cli/npm.md) | `sync`, `list`, `vendor` | Manages NPM packages, Bun bundling, and ESM importmaps. |

---

### 🔧 Toolchain Diagnostics, Auditing & Quality Gates

| Command | Subcommands | Description |
| :--- | :--- | :--- |
| [**`bloom doctor`**](file:///root/dev/Bloom/docs/cli/doctor.md) | — | Validates local SDKs (Dart, Flutter, Java, Android, Xcode, Shorebird, Bun). |
| [**`bloom prebuild`**](file:///root/dev/Bloom/docs/cli/prebuild.md) | — | Idempotently synchronizes native Android manifests, iOS `Info.plist`, and entitlements. |
| [**`bloom analyze`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-analyze) | — | Runs strict static analysis enforcing the zero-warning quality gate. |
| [**`bloom test`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-test) | — | Executes unit, widget, store, and server integration test suites. |
| [**`bloom audit`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-audit) | — | Performs cryptographic dependency auditing and permission vulnerability scanning. |
| [**`bloom security`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-security) | — | Scans project source files for leaked secrets, tokens, and unsafe eval calls. |
| [**`bloom upgrade`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-upgrade) | — | Automatically migrates project files and dependencies across Bloom version releases. |

---

### 🌐 Dependency Graphs & Monorepo Introspection

| Command | Subcommands | Description |
| :--- | :--- | :--- |
| [**`bloom autolink`**](file:///root/dev/Bloom/docs/cli/module.md) | — | Automatically links native Swift/Kotlin plugins into host Android and iOS projects. |
| [**`bloom deps`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-deps) | — | Visualizes the full-stack dependency graph across local monorepo packages. |
| [**`bloom why <pkg>`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-why) | — | Explains why a specific package or transitive dependency is required. |
| [**`bloom graph`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-graph) | — | Generates interactive Graphviz / Mermaid dependency flow diagrams. |
| [**`bloom explain <topic>`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-explain) | — | Interactive architectural documentation assistant embedded directly in the CLI. |
| [**`bloom workspace`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-workspace) | `list`, `run` | Dispatches synchronized commands across all monorepo workspace members. |
| [**`bloom symbols`**](file:///root/dev/Bloom/docs/cli/commands.md#bloom-symbols) | — | Inspects exported public API symbols to prevent accidental breaking changes. |
