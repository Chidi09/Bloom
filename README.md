<p align="center">
  <h1 align="center">🌸 Bloom</h1>
  <p align="center"><strong>The Opinionated Application Framework for Flutter & Dart.</strong></p>
  <p align="center">
    <em>"Next.js did it for React. Rails did it for Ruby. Bloom does it for Flutter."</em>
  </p>
  <p align="center">
    <a href="https://pub.dev/packages/bloom_framework"><img src="https://img.shields.io/pub/v/bloom_framework.svg" alt="bloom_framework on pub.dev" /></a>
    <a href="https://pub.dev/packages/bloom_cli"><img src="https://img.shields.io/pub/v/bloom_cli.svg" alt="bloom_cli on pub.dev" /></a>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-purple.svg" alt="License: MIT" /></a>
  </p>
</p>

---

## 🚀 Overview

**Bloom** is a full-stack, batteries-included application framework and developer platform built on top of Flutter and Dart. It turns Flutter's raw UI rendering engine into an opinionated, productive, enterprise-ready application platform.

With Bloom, you get:
* 🗂️ **Filesystem-based Routing** — File-based page declarations compiled to strongly-typed `go_router` instances with nested `_layout.dart` shell routes and loader annotations.
* ⚡ **Fine-Grained Signals Reactivity** — Zero-boilerplate reactive state powered by `signals_flutter` (`signal`, `computed`, `effect`, `batch`, `Watch`, `SignalBuilder`).
* 💾 **Bloom Data & Offline Engine** — Server-state query caching (`BloomData.query`), optimistic mutations (`BloomData.mutation`), TTL garbage collection, and persistent `OfflineMutationQueue`.
* 📱 **Declarative Native Prebuild** — Configure permissions, camera, notifications, secure storage, and deep links in `bloom.yaml` without manually touching platform XML/plist files.
* 🌐 **Full-Stack Server & SSR Engine** — Dart API routes (`routes/api/*`), HTTP middleware pipelines, and Static Site / Server-Side Rendering.
* 🔍 **Observability & Error Telemetry** — Automatic uncaught crash capture, breadcrumb logging timeline, release fingerprinting, and source map / dSYM symbol uploaders.
* 🔒 **Security & Secret Scanner** — Built-in CVE vulnerability audits and regex entropy scanning for hardcoded secrets.
* 🚀 **Automated Migration Engine** — AST-powered codebase migrations (`bloom upgrade`) and deprecation diagnostics (`bloom doctor --upgrade`).
* 📲 **Dev Server & Live Launcher** — LAN UDP broadcast discovery on port `5354`, optical QR device pairing, request replay, and interactive DevTools overlay.
* 🔌 **Official Full-Stack Adapters** — First-class adapters for Supabase (`supabase_flutter`) and Serverpod.

---

## 📦 Monorepo Workspace Structure

```text
Bloom/
├── packages/
│   ├── bloom_framework/      # Core framework runtime, DI, routing, state, data, native plugins, server, adapters
│   └── bloom_cli/            # Complete CLI tooling (create, dev, doctor, upgrade, explain, graph, registry, module, assets)
├── apps/
│   └── bloom_go/             # Universal native mobile development client for iOS and Android
├── examples/
│   ├── bloom_ecommerce/      # E-Commerce reference app (catalog, reactive cart, offline checkout queue)
│   ├── bloom_social_feed/    # Social timeline reference app (optimistic likes, compose view, media permissions)
│   ├── bloom_fullstack_api/  # Full-Stack API & SSR reference app (API routes /api/users, /api/health, SSR)
│   └── bloom_counter/        # Reference counter application demonstrating full Bloom architecture
└── docs/                     # Comprehensive architectural documentation & 17-phase hardening specs
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
# 1. Framework Test Suite (102 tests)
cd packages/bloom_framework && flutter test && flutter analyze

# 2. CLI Tooling Test Suite (62 tests)
cd ../bloom_cli && dart test && dart analyze

# 3. Official Sample Applications
cd ../../examples/bloom_ecommerce && flutter test && flutter analyze
cd ../bloom_social_feed && flutter test && flutter analyze
cd ../bloom_fullstack_api && flutter test && flutter analyze
```

---

## 📄 License
MIT © Bloom Framework Authors.
