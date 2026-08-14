# 01. Architecture & Design Principles

## 1. Core Product Principles

### 1.1 Convention Over Configuration
A developer should not have to repeatedly decide:
* Where should routes live? (`lib/routes/`)
* Where should controllers and state live? (`lib/features/...` or `lib/controllers/`)
* How do dependencies get registered and injected? (`inject<T>()`)
* How should state be exposed and observed? (`signal()`, `computed()`)
* How should environment variables be loaded? (`.env`, `bloom.yaml`)
* How should pages, components, and services be structured?

Bloom answers these questions with standard, battle-tested conventions by default.

---

### 1.2 Progressive Complexity
A simple application should feel simple. An enterprise-scale application should have the necessary primitives without hitting architectural ceilings.

```text
Small Application (Quick Prototype)
       ↓
Bloom Conventions (Minimal code, inline signals)
       ↓
No Unnecessary Architecture Boilerplate
       ↓
More Complexity Only When Needed (Controllers → Repositories → Domain Services)
```

---

### 1.3 Keep Escape Hatches
Every abstraction in Bloom must provide a frictionless escape hatch. Bloom must never lock developers out of the broader Flutter/Dart ecosystem.

Developers can freely use:
* Direct Flutter widget APIs
* Riverpod or Bloc alongside Bloom state
* Raw `go_router` or custom Navigator delegates
* Native Swift / Kotlin platform channels & FFI
* Any transport: REST, GraphQL, gRPC, Serverpod, Supabase, Firebase
* Custom build scripts and native projects

Bloom makes the common path delightful without making alternative choices impossible.

---

## 2. Ecosystem Division of Ownership

Bloom explicitly categorizes responsibilities into three distinct buckets:

```text
┌─────────────────────────────────────────────────────────────┐
│                       Bloom-Owned                           │
│  CLI UX • Project Conventions • Config Spec (bloom.yaml)   │
│  Filesystem Routing Conventions • State API Contract       │
│  Bloom Data / Query Engine • Plugin Contracts & Dev UX     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  Bloom Orchestration Layer                  │
│   Compiles filesystem routes to GoRouter                    │
│   Integrates Signals with Flutter Lifecycle & DI            │
│   Wraps Platform Plugins with Declarative YAML Manifest     │
│   Orchestrates Flutter CLI, Analyzer & DevTools             │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                      Ecosystem-Owned                        │
│   Flutter Engine & Rendering Pipeline (Impeller / Skia)    │
│   Dart Analyzer & VM / JIT / AOT Toolchain                  │
│   go_router Routing Core • signals Reactive Primitives      │
│   Shorebird OTA Infrastructure • Native Android/iOS SDKs    │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Package & Monorepo Strategy

To avoid premature package fragmentation and brittle version-coupling, Bloom does **not** launch with 14 separate pub packages.

### Initial Package Layout (v0.1)

```text
bloom_cli/                  # The global CLI entry point (`bloom`)
bloom_framework/            # Single runtime package (internally modularized)
├── lib/
│   ├── bloom.dart          # Public umbrella exports
│   └── src/
│       ├── core/           # Boot sequence, logging, environment
│       ├── config/         # bloom.yaml loader and schema
│       ├── di/             # Thin DI abstraction (inject, register)
│       ├── lifecycle/      # App & widget lifecycle observers
│       ├── state/          # Signals wrapper & controller base
│       ├── router/         # Filesystem router annotations & runtime bridge
│       ├── generator/      # Code generation templates & AST utilities
│       ├── data/           # Query, mutation, and cache primitives (v0.2)
│       ├── native/         # Declarative native plugin bridge (v0.3)
│       └── testing/        # Testing harnesses and mock overrides
```

### Long-Term Modularization (Post-Stabilization)
Once internal APIs stabilize across production usage, sub-modules will be cleanly extracted into independent packages:
* `bloom_core`
* `bloom_router`
* `bloom_state`
* `bloom_data`
* `bloom_native`

---

## 4. Package Naming & Identity

* **Framework Brand:** **Bloom**
* **CLI Command:** `bloom` (e.g. `bloom create`, `bloom dev`)
* **Pub.dev Runtime Package:** `bloom_framework` (reserving against existing widget packages)
* **Pub.dev CLI Package:** `bloom_cli`

The public developer brand is **Bloom**, regardless of the exact root package namespace on pub.dev.
