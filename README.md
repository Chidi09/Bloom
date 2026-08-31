<p align="center">
  <img src="assets/bloom_logo.svg" alt="Bloom logo" width="120" height="120" />
</p>

<p align="center">
  <h1 align="center">Bloom</h1>
  <p align="center"><strong>Full-stack Dart framework for web applications.</strong></p>
  <p align="center">
    <em>"Next.js did it for React. Rails did it for Ruby. Bloom does it for Flutter and Dart."</em>
  </p>
  <p align="center">
    <a href="https://pub.dev/packages/bloom_framework"><img src="https://img.shields.io/pub/v/bloom_framework.svg" alt="bloom_framework on pub.dev" /></a>
    <a href="https://pub.dev/packages/bloom_cli"><img src="https://img.shields.io/pub/v/bloom_cli.svg" alt="bloom_cli on pub.dev" /></a>
    <a href="https://pub.dev/packages/bloom_server"><img src="https://img.shields.io/pub/v/bloom_server.svg" alt="bloom_server on pub.dev" /></a>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-purple.svg" alt="License: MIT" /></a>
  </p>
</p>

---

## 🚀 Overview

**Bloom is a full-stack Dart framework for web applications: SSR · SSG · ISR · reactive UI · server APIs.** `bloom_js_native` compiles Dart components to the browser's real DOM, while `bloom_server` runs the HTTP, API, rendering, and backend side on Dart. Together they let Dart span browser and server without a JavaScript application layer.

Bloom is **not** Flutter rendered into a browser. Bloom JS Native is a Dart-to-DOM web framework with fine-grained signals, real CSS, SSR/SSG/ISR-friendly rendering, and targeted npm interop. Bloom also includes an opinionated Flutter client framework (`bloom_framework`) for native applications, but the web platform stands on its own.

The platform is batteries-included: a growing suite of independent backend packages (`bloom_server`, `bloom_db`, `bloom_auth_server`, `bloom_rest`, `bloom_admin`, and more) forms a Django/Rails-style server usable with or without the Flutter side.

With Bloom, you get:

**Client (Flutter)**
* 🗂️ **Filesystem-based Routing** — File-based page declarations compiled to strongly-typed `go_router` instances with nested `_layout.dart` shell routes and loader annotations.
* ⚡ **Fine-Grained Signals Reactivity** — Zero-boilerplate reactive state powered by `signals_flutter` (`signal`, `computed`, `effect`, `batch`, `Watch`, `SignalBuilder`).
* 💾 **Bloom Data & Offline Engine** — Server-state query caching (`BloomData.query`), optimistic mutations (`BloomData.mutation`), TTL garbage collection, and persistent `OfflineMutationQueue`.
* 📱 **Declarative Native Prebuild** — Configure permissions, camera, notifications, secure storage, and deep links in `bloom.yaml` without manually touching platform XML/plist files.
* 📲 **Dev Server & Live Launcher** — LAN UDP broadcast discovery on port `5354`, optical QR device pairing, request replay, and interactive DevTools overlay.

**Web (Dart, no Flutter runtime)**
* 🌐 **Bloom JS Native** — Dart components compiled to real DOM and CSS with fine-grained signals, SSR, SSG, ISR-friendly rendering, SEO, and browser-native interop.

**Server (Dart, Flutter-free)**
* 🌐 **HTTP Server & Router** (`bloom_server`) — API routing with path/wildcard params, middleware pipelines, and SSR.
* 🗄️ **Database & Migrations** (`bloom_db`, `bloom_migrate`) — Postgres/SQLite executor, query builder, and schema migrations.
* 🔐 **Auth & Security** (`bloom_auth_server`, `bloom_security`) — JWT sessions, Google/GitHub OAuth2 login, CVE and secret scanning.
* 📨 **Mail & Background Jobs** (`bloom_mail`, `bloom_jobs`) — SMTP delivery with HTML/text templating, and a `BloomTaskQueue` with in-memory, Redis, and database-backed persistent implementations.
* 🖥️ **Admin & REST** (`bloom_admin`, `bloom_rest`) — Django-style auto-generated SSR admin panel and REST ViewSets.
* 🌍 **i18n, Storage, Realtime, Cache** (`bloom_i18n`, `bloom_storage`, `bloom_realtime`, `bloom_cache`) — Locale-aware responses, pluggable file storage backends, WebSocket channels, and caching.
* 🔒 **Errors & Validation** (`bloom_errors`, `bloom_validate`) — Structured exception-to-response mapping and input validation.

**Tooling**
* 🚀 **CLI** (`bloom_cli`) — `bloom create`, `bloom dev`, `bloom doctor`, `bloom server create/startapp/run`, `bloom format`, `bloom lint`, and automated AST migrations (`bloom upgrade`).
* 🔍 **Observability** — Automatic uncaught crash capture, breadcrumb logging timeline, and source map / dSYM symbol uploaders.

---

## 📦 Monorepo Workspace Structure

```text
Bloom/
├── packages/
│   ├── bloom_framework/      # Flutter client framework: DI, routing, state, data, native plugins, adapters
│   ├── bloom_server/         # Flutter-free HTTP server & API router (the backend runtime)
│   ├── bloom_db/             # Database executor, query builder (bloom_db_generator: codegen)
│   ├── bloom_migrate/        # Schema migration engine
│   ├── bloom_auth_server/    # JWT sessions + OAuth2 (Google, GitHub) login
│   ├── bloom_security/       # CVE + secret scanning
│   ├── bloom_mail/           # SMTP mail delivery with HTML/text templating
│   ├── bloom_jobs/           # Background task queue (in-memory, Redis, database-backed)
│   ├── bloom_admin/          # Auto-generated SSR admin panel
│   ├── bloom_rest/           # REST ViewSets & serializers
│   ├── bloom_i18n/           # Locale detection & translation
│   ├── bloom_storage/        # Pluggable file storage backends
│   ├── bloom_realtime/       # WebSocket channel hub
│   ├── bloom_cache/          # Caching layer
│   ├── bloom_errors/         # Structured exception → response mapping
│   ├── bloom_validate/       # Input validation
│   ├── bloom_seo/            # SEO metadata tooling
│   ├── bloom_js_native/      # JS/npm interop for Bloom web projects
│   ├── bloom_ui/             # Shared UI primitives
│   └── bloom_cli/            # CLI tooling (create, dev, doctor, server, format, lint, upgrade, ...)
├── apps/
│   └── bloom_go/             # Universal native mobile development client for iOS and Android
├── examples/
│   ├── bloom_fullstack_todo/ # Reference app exercising all 15 backend packages against real PostgreSQL
│   ├── bloom_fullstack_api/  # Full-Stack API & SSR reference app
│   ├── bloom_ecommerce/      # E-Commerce reference app (catalog, reactive cart, offline checkout queue)
│   ├── bloom_social_feed/    # Social timeline reference app (optimistic likes, compose view, media permissions)
│   ├── bloom_js_ecommerce/   # JS-target e-commerce reference app
│   ├── bloom_portfolio/      # Portfolio/SSR site reference app
│   ├── bloom_showcase_web/   # Web showcase reference app
│   └── bloom_counter/        # Minimal reference app demonstrating core Bloom architecture
├── cloud-dashboard/           # Cloud dashboard frontend
├── cloud-backend/             # Cloud dashboard backend
├── bloom-website/             # bloom.dev marketing site
└── docs/                      # Architectural documentation & phased hardening specs
```

---

## ⚡ Quickstart

### 1. Install Bloom CLI
```bash
dart pub global activate bloom_cli
```

### 2. Create a New Application
```bash
# Standard project
bloom create my_app

# Or use an official reference template
bloom create my_store --template ecommerce
cd my_app
```

### 3. Run Interactive Development Server
```bash
bloom dev
```
Scan the terminal QR code or auto-discover over LAN using **Bloom Go** on your device to launch the app wirelessly!

### 4. Health & Security Verification
```bash
# Verify local environment and deprecations
bloom doctor

# Strict CI pipeline health check (fails on CVEs, secrets, or autolink conflicts)
bloom doctor --ci
```

---

## 🛠️ CLI Commands Master Catalog

| Command | Purpose |
| :--- | :--- |
| `bloom create <app> [--template <name>]` | Scaffolds a new Bloom application from official or community templates |
| `bloom server create <app>` / `startapp <name>` / `run` | Scaffolds and runs a Flutter-free Bloom backend project on `bloom_server` |
| `bloom format` / `bloom lint` | Formats and lints Bloom JS-native projects |
| `bloom dev` | Launches local development orchestrator with LAN discovery, hot reload, and TUI shortcuts |
| `bloom doctor [--ci] [--upgrade]` | Runs system diagnostics, strict CI health checks, and breaking-change deprecation audits |
| `bloom add <plugin>` / `bloom remove <plugin>` | Adds or removes native plugins with zero-config autolinking |
| `bloom deps` / `bloom why <pkg>` | Inspects the native dependency tree and explains why packages are included |
| `bloom workspace [info\|sync]` | Inspects and syncs monorepo workspace dependencies |
| `bloom create module <name>` | Scaffolds a native module package with typed Dart ↔ Swift/Kotlin DSL bindings |
| `bloom module dev` / `bloom module test` | Runs isolated native module sandbox development and multi-platform test suites |
| `bloom assets optimize\|analyze\|generate` | Optimizes raster/vector assets, analyzes asset disk footprint, generates typed icons |
| `bloom audit` / `bloom security scan` | Audits dependencies for known CVE vulnerabilities and scans for leaked API secrets |
| `bloom explain route <path>` | Explains route hierarchy, dynamic URL parameters, layout nesting, and auth guards |
| `bloom graph` | Generates visual dependency graphs in ASCII or Mermaid markdown formats |
| `bloom registry search\|info` | Queries Bloom ecosystem package registry with CI verification badges |
| `bloom upgrade [--dry-run]` | Upgrades dependencies and automatically executes AST code refactorings |
| `bloom symbols package\|upload` | Packages debug symbol maps and dSYMs and uploads to observability backend |
| `bloom templates list` | Lists all official starter templates (`starter`, `ecommerce`, `social`, `fullstack`) |
| `bloom analyze` | Executes strict framework linting and architectural convention checks |
| `bloom test` | Runs unit, widget, and integration test suites with structured reporting |
| `bloom prebuild` | Generates Android/iOS native platform manifests from `bloom.yaml` |
| `bloom build <target>` | Compiles production-optimized binaries (`apk`, `ipa`, `web`, `desktop`) |
| `bloom deploy` | Deploys Over-The-Air (OTA) patches via Shorebird code-push engine |

---

## 📚 Architectural Documentation

Explore the detailed documentation in [`docs/`](file:///root/dev/Bloom/docs):

* [`00. Overview & Vision`](file:///root/dev/Bloom/docs/00_overview.md)
* [`01. Architecture & Design Principles`](file:///root/dev/Bloom/docs/01_architecture_and_design_principles.md)
* [`02. CLI & Developer Workflows`](file:///root/dev/Bloom/docs/02_cli_and_developer_tooling.md)
* [`03. Boot, Lifecycle & DI`](file:///root/dev/Bloom/docs/03_boot_lifecycle_and_di.md)
* [`04. State Management & Controllers`](file:///root/dev/Bloom/docs/04_state_management_and_controllers.md)
* [`05. Filesystem Routing & Navigation`](file:///root/dev/Bloom/docs/05_filesystem_routing_and_navigation.md)
* [`06. Bloom Data & Offline Architecture`](file:///root/dev/Bloom/docs/06_bloom_data_and_offline.md)
* [`07. Native Architecture & Plugins`](file:///root/dev/Bloom/docs/07_native_architecture_and_plugins.md)
* [`08. Dev Experience, Bloom Go & OTA`](file:///root/dev/Bloom/docs/08_development_experience_and_bloom_go.md)
* [`09. Testing, CI & DevTools`](file:///root/dev/Bloom/docs/09_testing_ci_and_devtools.md)
* [`10. Phased Roadmap & Implementation`](file:///root/dev/Bloom/docs/10_phased_implementation_roadmap.md)
* [**Hardening Roadmap Index (Phases 9–17)**](file:///root/dev/Bloom/docs/hardening-phases/00_hardening_roadmap_overview.md)

---

## 🧪 Testing & Quality Assurance

Run the comprehensive test and analysis matrix across the entire monorepo:
```bash
# 1. Flutter Framework Test Suite
cd packages/bloom_framework && flutter test && flutter analyze

# 2. CLI Tooling Test Suite
cd ../bloom_cli && dart test && dart analyze

# 3. Backend Packages (pure Dart, run per package: bloom_server, bloom_db, bloom_auth_server,
#    bloom_mail, bloom_jobs, bloom_admin, bloom_rest, bloom_i18n, bloom_storage, bloom_realtime,
#    bloom_cache, bloom_errors, bloom_validate, bloom_security, bloom_migrate)
cd ../bloom_server && dart test && dart analyze

# 4. Official Sample Applications
cd ../../examples/bloom_fullstack_todo && dart test && dart analyze
cd ../bloom_ecommerce && flutter test && flutter analyze
cd ../bloom_social_feed && flutter test && flutter analyze
cd ../bloom_fullstack_api && flutter test && flutter analyze
```

---

## 📄 License
MIT © Bloom Framework Authors.
