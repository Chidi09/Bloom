# Bloom Documentation

> **"Flutter gives you the engine. Bloom gives you the application framework."**

Welcome to the comprehensive technical documentation and engineering specification for **Bloom** — an opinionated application framework and developer platform built on Dart and Flutter.

---

## 📚 Table of Contents

| Document | Topic | Key Contents |
| :--- | :--- | :--- |
| [**00. Overview & Vision**](file:///root/dev/Bloom/docs/00_overview.md) | Executive Strategy & Thesis | Strategic direction, ecosystem relationship, core thesis, the "80/20" approach. |
| [**01. Architecture & Design Principles**](file:///root/dev/Bloom/docs/01_architecture_and_design_principles.md) | Architectural Foundation | Core principles, package structure (`bloom_framework`), namespace identity, escape hatches. |
| [**02. CLI & Developer Workflows**](file:///root/dev/Bloom/docs/02_cli_and_developer_tooling.md) | Tooling & Scaffolding | `bloom create`, `bloom dev`, `bloom generate`, `bloom doctor`, `bloom.yaml` spec, generator rules. |
| [**03. Boot, Lifecycle & DI**](file:///root/dev/Bloom/docs/03_boot_lifecycle_and_di.md) | Core Runtime Services | `Bloom.boot()`, environment loading, logging, DI container abstraction (`inject<T>()`). |
| [**04. State Management & Controllers**](file:///root/dev/Bloom/docs/04_state_management_and_controllers.md) | Reactive State Layer | Signals integration (`signal`, `computed`, `effect`), Controller conventions, Riverpod/Bloc adapters. |
| [**05. Filesystem Routing & Navigation**](file:///root/dev/Bloom/docs/05_filesystem_routing_and_navigation.md) | Declarative Routing | Filesystem router convention, GoRouter generation, typed routes, route guards, tabs & deep links. |
| [**06. Bloom Data & Offline Architecture**](file:///root/dev/Bloom/docs/06_bloom_data_and_offline.md) | Server State & Persistence | Differentiated query engine, mutations, cache invalidation, offline sync queue, repositories. |
| [**07. Native Architecture & Plugins**](file:///root/dev/Bloom/docs/07_native_architecture_and_plugins.md) | Platform Capabilities | Managed vs Bare modes, `bloom.yaml` plugin config, native prebuilds, reference modules (Storage, Notifications, Camera). |
| [**08. Dev Experience, Bloom Go & OTA**](file:///root/dev/Bloom/docs/08_development_experience_and_bloom_go.md) | Interactive DX & Distribution | Terminal DX, wireless dev, QR distribution, Dev Client, Bloom Go architecture, Shorebird OTA integration. |
| [**09. Testing, CI & DevTools**](file:///root/dev/Bloom/docs/09_testing_ci_and_devtools.md) | Quality & Tooling | Testing conventions, dependency overrides, CI recipes (GitHub Actions/Codemagic), `bloom inspect`. |
| [**10. Phased Roadmap & Implementation**](file:///root/dev/Bloom/docs/10_phased_implementation_roadmap.md) | Execution Plan & Milestones | Phase-by-phase execution plan (Phases 0 through 8), verification criteria, success metrics & real-world benchmarks. |

---

## 🎯 High-Level Architecture

```text
                                  BLOOM
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                     Bloom CLI            Bloom Runtime
                         │                     │
                ┌────────┼────────┐      ┌─────┼──────┐
                │        │        │      │     │      │
            Generate    Dev     Doctor   DI  State  Config
                │                           │
                │                        signals
                │                           │
                └───────────┬───────────────┘
                            │
                      Bloom Router
                            │
                         go_router
                            │
                      Bloom Data
                            │
                 queries / mutations / cache
                            │
                      Bloom Native
                            │
                 Flutter plugin ecosystem
                            │
                          Flutter
                            │
               Android / iOS / Web / Desktop
```

---

## ⚡ The Golden Path

```bash
# 1. Activate Bloom CLI
dart pub global activate bloom_cli

# 2. Create a new full-stack app
bloom create shop
cd shop

# 3. Scaffold architecture
bloom generate page home
bloom generate model Product
bloom generate service ProductService
bloom generate route products

# 4. Add native capabilities
bloom add auth
bloom add notifications
bloom add secure-storage

# 5. Launch interactive development experience
bloom dev
```
