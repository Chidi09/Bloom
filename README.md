<p align="center">
  <h1 align="center">🌸 Bloom</h1>
  <p align="center"><strong>The Opinionated Application Framework for Flutter & Dart.</strong></p>
  <p align="center">
    <em>"Next.js did it for React. Rails did it for Ruby. Bloom does it for Flutter."</em>
  </p>
</p>

---

## 🚀 Overview

**Bloom** is a full-stack, batteries-included application framework built on top of Flutter and Dart. It turns Flutter's raw UI rendering engine into an opinionated, productive, enterprise-ready application platform.

With Bloom, you get:
* 🗂️ **Filesystem-based Routing** — File-based page declarations compiled to strongly-typed `go_router` instances.
* ⚡ **Fine-Grained Signals Reactivity** — Zero boilerplate reactive state powered by `signals_flutter`.
* 💾 **Bloom Data Engine** — Server-state queries, optimistic mutations, TTL-based caching, and automated offline sync.
* 📱 **Declarative Native Prebuild** — Configure permissions, camera, notifications, secure storage, and deep links in `bloom.yaml` without editing XML/plist files.
* 📲 **Bloom Go Shell & Terminal QR Hosting** — Expo-like wireless development on physical devices with QR pairing and live VM DevTools.
* 🚀 **Over-The-Air (OTA) Deployments** — Native Shorebird code-push integration for instant zero-downtime updates.
* 🔌 **Official Full-Stack Adapters** — First-class adapters for Supabase (`supabase_flutter`) and Serverpod.

---

## 📦 Monorepo Workspace Structure

```text
Bloom/
├── packages/
│   ├── bloom_framework/      # Core framework runtime, DI, routing, state, data, native plugins, adapters
│   └── bloom_cli/            # Command-line interface (create, dev, generate, doctor, prebuild, deploy)
├── apps/
│   └── bloom_go/             # Universal native mobile development client for iOS and Android
├── examples/
│   └── bloom_counter/        # Reference counter application demonstrating full Bloom architecture
└── docs/                     # Comprehensive architectural documentation & guides
```

---

## ⚡ Quickstart

### 1. Install Bloom CLI
```bash
dart pub global activate --source path packages/bloom_cli
```

### 2. Create a New Application
```bash
bloom create my_app
cd my_app
```

### 3. Run Interactive Development Server
```bash
bloom dev
```
Scan the terminal QR code using **Bloom Go** on your device to launch the app wirelessly!

### 4. Deploy Over-The-Air Patches
```bash
# Validate planned deployment
bloom deploy --dry-run --target=android --channel=production

# Publish live OTA patch
bloom deploy --target=android --channel=production
```

---

## 📚 Architectural Documentation

Explore the detailed architecture guides in [`docs/`](file:///root/dev/Bloom/docs):

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

---

## 🧪 Testing

Run the full workspace test and static analysis matrix:
```bash
# Framework
cd packages/bloom_framework && flutter test && flutter analyze

# CLI
cd ../bloom_cli && dart test && dart analyze

# Bloom Go Mobile Client
cd ../../apps/bloom_go && flutter test && flutter analyze

# Example App
cd ../../examples/bloom_counter && flutter test && flutter analyze
```

---

## 📄 License
MIT © Bloom Framework Authors.
