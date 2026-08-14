# 00. Executive Strategy & Vision

## 1. Executive Direction

Bloom should **not** attempt to replace the Flutter ecosystem.

The initial versions must avoid reinventing:
* Flutter rendering pipeline
* Low-level routing engines
* Reactive primitive engines from scratch
* Complex native build systems
* Dart code-generation infrastructure
* Proprietary OTA patching systems
* Backend application servers

Instead, Bloom's explicit differentiation is:

> **"Make the good parts of the Dart/Flutter ecosystem feel like one framework."**

Bloom owns the **developer experience and architectural conventions** while deliberately delegating mature low-level capabilities to proven infrastructure.

---

## 2. The Core Problem in Flutter Today

Production Flutter applications frequently suffer from severe ecosystem fragmentation. To build a standard mobile/web app today, an engineer must manually evaluate, configure, wire, and maintain separate packages for:

1. **State Management:** Riverpod, Bloc, Signals, Provider, MobX
2. **Routing:** go_router, auto_route, beamer, native Navigator 2.0
3. **Dependency Injection:** get_it, injectable, provider
4. **Networking:** dio, http, chopper
5. **Data & Caching:** ferry, graphql_flutter, custom caching layers
6. **Persistence:** hive, isar, sqflite, shared_preferences
7. **Environment & Config:** flutter_dotenv, envied
8. **Native Integration:** flutter_launcher_icons, flutter_native_splash, permission_handler

Every team solves this puzzle differently, leading to inconsistent architectures, excessive boilerplate, high onboarding overhead, and fragile maintenance.

---

## 3. The Implementation Philosophy

The revised Bloom strategy changes the engineering approach from:

```text
Build Everything (Heavy Monolith)
```

to:

```text
Standardize
     ↓
   Wrap
     ↓
 Generate
     ↓
Orchestrate
     ↓
Replace ONLY where the ecosystem has a genuine gap
```

---

## 4. What Bloom Actually Is

Bloom is:

> **An opinionated application framework and developer platform built on Dart and Flutter.**

### Separation of Concerns

```text
                  BLOOM
       Developer / Application Layer
                    │
       ┌────────────┼────────────┐
       │            │            │
    Routing       State         Data
       │            │            │
       └────────────┼────────────┘
                    │
              Bloom Runtime
                    │
              Bloom CLI
                    │
                 Flutter
                    │
        Android / iOS / Web / Desktop
```

| Bloom Responsibilities | Flutter Responsibilities |
| :--- | :--- |
| Application Architecture | Rendering Engine |
| CLI Tooling & Workflows | Widget Tree & Primitives |
| Project Structure Conventions | Layout & Painting |
| Synchronous Reactive State API | Animations & Gestures |
| Filesystem-based Routing Conventions | Accessibility (Semantics) |
| Dependency Injection & Lifecycle | Platform Renderers (Impeller / Skia) |
| Data / Query / Cache Architecture | Target Compilation (AOT / JIT) |
| Native Configuration Orchestration | Platform Channel Plumbing |

---

## 5. The "80/20" Strategy

The first **80%** of the developer experience improvement requires approximately **20%** of the eventual infrastructure.

### Priority Focus for v0.1:
* `bloom create` (Standardized boilerplate & boot)
* `bloom dev` (Unified terminal DX)
* `bloom generate` (Deterministic scaffolding)
* `bloom doctor` (Environment & configuration health checks)
* `bloom.yaml` (Centralized manifest)
* Dependency Injection wrapper (`inject<T>()`)
* Reactivity wrapper over Signals
* Filesystem routing compiled to `go_router`

### Defer to Later Phases:
* Proprietary Bloom Go native client (Phase 7)
* Custom Cloud hosting & builds (Phase 8)
* Custom DevTools visual debugger (Phase 6/7)
* Custom Native AST transformers (Phase 5)
* Custom OTA engine (Integrate with Shorebird instead)

---

## 6. Product Positioning

> **"Flutter gives you the engine. Bloom gives you the application framework."**

Bloom makes Flutter feel like modern web frameworks (e.g., Next.js, Nuxt, Expo) while retaining 100% of Flutter's cross-platform rendering power and Dart's strict type safety.
