# 🌸 Bloom Documentation Portal & Technical Index

> **"Flutter gives you the engine. Bloom gives you the application framework."**

Welcome to the comprehensive technical documentation for **Bloom** — an opinionated application framework and developer platform built on Dart and Flutter.

---

## 📚 Master Table of Contents (Sections A – J)

### 🚀 Section A: Getting Started
* [**01. Installation & Environment Setup**](file:///root/dev/Bloom/docs/getting-started/01_installation.md) — SDK requirements, global pub activation, PATH configuration, `bloom doctor` verification.
* [**02. 5-Minute Quickstart**](file:///root/dev/Bloom/docs/getting-started/02_quickstart.md) — `bloom create`, adding routes, state controllers, running the dev server, and hot reload.
* [**03. Project Anatomy & Structure**](file:///root/dev/Bloom/docs/getting-started/03_project_anatomy.md) — Directory breakdown (`lib/app`, `lib/routes`, `lib/features`, `bloom.yaml`, `.env`, `routes.g.dart`).
* [**04. `bloom.yaml` Full Reference**](file:///root/dev/Bloom/docs/getting-started/04_bloom_yaml_reference.md) — Exhaustive schema documentation for every manifest key, defaults, and typing.

---

### 💻 Section B: CLI Reference & Commands
* [**05. `bloom create` Reference**](file:///root/dev/Bloom/docs/cli/create.md) — Project generator flags (`--org`, `--description`, `--framework-path`) and exit codes.
* [**06. `bloom dev` Reference**](file:///root/dev/Bloom/docs/cli/dev.md) — Interactive DX server, device selection, port hosting, QR pairing, and TUI keyboard controls (<kbd>r</kbd>/<kbd>R</kbd>/<kbd>w</kbd>/<kbd>d</kbd>/<kbd>o</kbd>/<kbd>v</kbd>/<kbd>c</kbd>/<kbd>q</kbd>).
* [**07. `bloom generate` Reference**](file:///root/dev/Bloom/docs/cli/generate.md) — Component generator for routes, controllers, models, services, and routing tables.
* [**08. `bloom doctor` Reference**](file:///root/dev/Bloom/docs/cli/doctor.md) — Toolchain diagnostics, Android/Java SDK, Xcode, Shorebird, and network interfaces.
* [**09. `bloom prebuild` Reference**](file:///root/dev/Bloom/docs/cli/prebuild.md) — Managed native transformations on `AndroidManifest.xml`, `Info.plist`, and idempotency rules.
* [**10. `bloom deploy` Reference**](file:///root/dev/Bloom/docs/cli/deploy.md) — Shorebird Over-The-Air code-push patching and base binary release orchestration.
* [**11. Secondary CLI Commands**](file:///root/dev/Bloom/docs/cli/commands.md) — Manual workflows for `bloom add`, `bloom remove`, `bloom build`, `bloom test`, and `bloom analyze`.

---

### 🏛️ Section C: Core Runtime Concepts
* [**12. Framework Boot & Lifecycle**](file:///root/dev/Bloom/docs/runtime/boot_lifecycle.md) — `Bloom.boot()`, 10-step startup sequence, `AppBootstrapper`, and runtime state inspection.
* [**13. Dependency Injection & Scopes**](file:///root/dev/Bloom/docs/runtime/dependency_injection.md) — `BloomContainer`, `provide`, `provideSingleton`, `provideValue`, `inject<T>()`, and `BloomTestScope`.
* [**14. Signals & Controllers**](file:///root/dev/Bloom/docs/runtime/signals_and_controllers.md) — `signal`, `computed`, `effect`, `batch`, `readonly`, `Watch`, `SignalBuilder`, and `BloomController` lifecycle.
* [**15. Filesystem Routing & Navigation**](file:///root/dev/Bloom/docs/runtime/filesystem_routing.md) — File-based routes (`index.dart`, `[id].dart`, `(groups)`, `_layout.dart`), `BloomRouter`, and `BloomAuthGuard`.
* [**16. Config & Environment**](file:///root/dev/Bloom/docs/runtime/config_and_env.md) — Multi-stage `.env` resolution, `BloomEnv` getters, and `BloomConfig` typing.
* [**17. Structured Logging**](file:///root/dev/Bloom/docs/runtime/logging.md) — `BloomLogger`, severity thresholds, contextual child loggers, ANSI formatting, and remote writers.

---

### 💾 Section D: Data Layer (Bloom Data)
* [**18. Asynchronous Server Queries**](file:///root/dev/Bloom/docs/data/queries.md) — `BloomData.query<T>()`, stale/cache timeouts, deduplication, and reactive accessors.
* [**19. Mutations & Optimistic Updates**](file:///root/dev/Bloom/docs/data/mutations.md) — `BloomData.mutation<T, P>()`, optimistic mutations, and automated rollback patterns.
* [**20. Query Cache & Garbage Collection**](file:///root/dev/Bloom/docs/data/cache_and_garbage_collection.md) — Cache key normalization, prefix invalidations, TTL GC, and telemetry inspection.
* [**21. Offline Mutation Queue**](file:///root/dev/Bloom/docs/data/offline_queue.md) — `OfflineMutationQueue`, persistent storage replay, and `ConflictPolicy`.
* [**22. Storage Adapters & TTL Persistence**](file:///root/dev/Bloom/docs/data/storage_adapters.md) — `BloomStorageAdapter`, `BloomSecureStorage`, `InMemoryStorageAdapter`, and `BloomJsonStorage`.
* [**23. HTTP Networking Client**](file:///root/dev/Bloom/docs/data/http_client.md) — `BloomHttpClient`, dynamic token providers, interceptors, and strict base URL error models.
* [**24. Repositories & CRUD Contracts**](file:///root/dev/Bloom/docs/data/repositories.md) — `BloomRepository` base and typed `BloomCrudRepository<T, ID>` interface.
* [**25. Authentication & Session Management**](file:///root/dev/Bloom/docs/data/authentication.md) — `BloomAuth<U>`, session persistence, encrypted token management, and route guards.

---

### 📱 Section E: Native & Platform Architecture
* [**26. Runtime Permission Management**](file:///root/dev/Bloom/docs/native/permissions.md) — `BloomPermissions`, `BloomPermissionStatus`, and settings redirection.
* [**27. Native Modules & Plugins**](file:///root/dev/Bloom/docs/native/plugins.md) — Secure storage, local push notifications, camera capture, background tasks, and deep links.
* [**28. Native Prebuild Engine**](file:///root/dev/Bloom/docs/native/prebuild_engine.md) — Android manifest XML AST parser, iOS Info.plist synchronizer, and `.well-known` generation.
* [**29. Multi-Environment Build Flavors**](file:///root/dev/Bloom/docs/native/flavors.md) — Multi-flavor builds, `BLOOM_FLAVOR` dart-define propagation, and flavor configs.
* [**30. Deep Links, App Links & Universal Links**](file:///root/dev/Bloom/docs/native/deep_links.md) — Custom schemes (`bloom://`), domain verification, and cold-start route buffering.

---

### 📲 Section F: Developer Experience & Tooling
* [**31. Bloom Go Mobile Shell**](file:///root/dev/Bloom/docs/dev-experience/bloom_go.md) — Companion mobile app, optical QR pairing, UDP auto-discovery, and in-app DevTools overlay.
* [**32. Bloom Dev Server & Endpoints**](file:///root/dev/Bloom/docs/dev-experience/dev_server.md) — Endpoints (`/manifest.json`, `/health`, `/qr`, `/devices/pair`), CORS, and LAN routing.
* [**33. DevTools & VM Service Extensions**](file:///root/dev/Bloom/docs/dev-experience/devtools_extensions.md) — Custom VM RPC methods (`ext.bloom.*`), `BloomDevOverlay`, and live cache inspection.
* [**34. Over-The-Air (OTA) Updates**](file:///root/dev/Bloom/docs/dev-experience/ota_deployments.md) — `BloomOTA` runtime lifecycle, patch checking, engine staging, and Shorebird code-push.

---

### 🧪 Section G: Testing
* [**35. Standardized Testing Harness**](file:///root/dev/Bloom/docs/testing/bloom_testing_harness.md) — `bloom_testing.dart`, `pumpBloomApp`, test scope isolation, and `BloomMock`.
* [**36. Testing Recipes & Best Practices**](file:///root/dev/Bloom/docs/testing/test_recipes.md) — Unit testing controllers, query caching tests, mutation rollbacks, and DI overrides.

---

### 🔌 Section H: Full-Stack Dart Adapters
* [**37. Official Supabase Adapter**](file:///root/dev/Bloom/docs/adapters/supabase.md) — `BloomSupabaseAuthAdapter`, session management, token refresh, and CRUD table repositories.
* [**38. Official Serverpod Adapter**](file:///root/dev/Bloom/docs/adapters/serverpod.md) — `BloomServerpodClient`, real-time stream signal binding, and delegate CRUD repositories.

---

### 📖 Section I: Guides, Recipes & Specifications
* [**39. Full Public API Reference**](file:///root/dev/Bloom/docs/guides/api_reference.md) — Symbol-level index of exported framework classes and methods.
* [**40. Migration Guide from Vanilla Flutter**](file:///root/dev/Bloom/docs/guides/migration_guide.md) — Migrating from Riverpod, BLoC, manual GoRouter, and Dio to Bloom.
* [**41. Troubleshooting & FAQ**](file:///root/dev/Bloom/docs/guides/troubleshooting_and_faq.md) — Solutions to common toolchain, Shorebird, UDP discovery, and HTTP errors.
* [**42. Architectural Best Practices**](file:///root/dev/Bloom/docs/guides/best_practices.md) — Domain-driven folder layouts, controller boundaries, and key design.
* [**43. End-to-End Cookbook**](file:///root/dev/Bloom/docs/guides/cookbook.md) — Recipes for offline CRUD, OTA patching, and prebuild plugin additions.
* [**44. Contributing & Monorepo Guide**](file:///root/dev/Bloom/docs/guides/contributing.md) — Monorepo structure, 4-package validation matrix, and commit standards.

---

### 🌐 Section K: Bloom JS Native (Fine-Grained Web Architecture)
* [**45. Thinking in Signals & Pure Dart AST**](file:///root/dev/Bloom/docs/js-native/01_thinking_in_signals.md) — Mental model, VDOM vs Fine-Grained Signals, Dual-Backend architecture.
* [**46. Describing the UI & Elements**](file:///root/dev/Bloom/docs/js-native/02_describing_the_ui.md) — All 38 HTML AST element builders, fragments, conditional `Show`, and keyed `ForEach`.
* [**47. Reactivity & State Management**](file:///root/dev/Bloom/docs/js-native/03_reactivity_and_state.md) — `signal`, `computed`, `effect`, `batch`, `untracked`, and `_Region` cleanup scopes.
* [**48. Interactivity, Events & Forms**](file:///root/dev/Bloom/docs/js-native/04_interactivity_and_forms.md) — `BloomEvent` abstraction, form validation, keyboard focus management, VM testing.
* [**49. Server-Side Rendering (SSR) & SSG**](file:///root/dev/Bloom/docs/js-native/05_server_side_rendering_and_ssg.md) — Sub-millisecond `renderToHtml()`, `BloomApiRouter.ssr()`, `HeadManager`, `JsonLd`.
* [**50. NPM Ecosystem & JS Interop**](file:///root/dev/Bloom/docs/js-native/06_npm_and_js_interop.md) — Modern `dart:js_interop` extension types, Bun ESM toolchain, Three.js, Chart.js.
* [**51. Developer Tooling & CLI Suite**](file:///root/dev/Bloom/docs/js-native/07_developer_tooling_and_cli.md) — Native `bloom js dev` zero-Python server, `bloom js build --analyze`.
* [**52. Complete JS Native API Reference**](file:///root/dev/Bloom/docs/js-native/08_api_reference.md) — Symbol-level index of exported AST descriptors and browser mounting handles.

---

### 🔍 Section L: Transparency & Honesty Disclosures
* [**53. Platform Capabilities & Current Gaps**](file:///root/dev/Bloom/docs/transparency/platform_capabilities_and_gaps.md) — Honest evaluation of production-ready modules versus staged Dart facades/protocols.

---

## 🛡️ Hardening Roadmap: Post-v1.0 Platform Expansion (Phases 9 – 16)

* [**00. Hardening Roadmap Executive Overview**](file:///root/dev/Bloom/docs/hardening-phases/00_hardening_roadmap_overview.md) — Master roadmap across Extension, Runtime, and Application platform tiers.
* [**Phase 9: Bloom Native Module Platform & DSL**](file:///root/dev/Bloom/docs/hardening-phases/phase_09_module_platform_and_dsl.md) — `bloom create module`, Native Module DSL (`@BloomModule`), Dart ↔ Swift/Kotlin binding generators, typed arguments, native events, native streams, native views (`BloomNativeView`), native lifecycle, thread/queue semantics.
* [**Phase 10: Autolinking, Monorepos & Native Dependency Resolution**](file:///root/dev/Bloom/docs/hardening-phases/phase_10_autolinking_and_dependency_graph.md) — `bloom add` autolinking, transitive module discovery, duplicate native module detection, `bloom deps`, `bloom why`, `bloom resolve`, `bloom.lock`, native dependency constraints, monorepo workspace discovery.
* [**Phase 11: Bloom Updates Platform & Runtime Fingerprinting**](file:///root/dev/Bloom/docs/hardening-phases/phase_11_updates_platform_and_runtime_fingerprinting.md) — `bloom_updates` client, update manifest schema, runtime compatibility & cryptographic fingerprinting, channels & branches, staged percentage rollouts, instant rollback, embedded fallback, background downloading.
* [**Phase 12: Router Expansion, API Routes & Full-Stack Web (SSR/SSG)**](file:///root/dev/Bloom/docs/hardening-phases/phase_12_router_expansion_and_fullstack_web.md) — API routes (`routes/api/*`), route handlers & middleware, loaders & actions, error & loading routes, Static Site Generation (`bloom build web --static`), Server-Side Rendering (`bloom build web --server`), SEO metadata, sitemap/robots generator, PWA & web manifest.
* [**Phase 13: Error Observability, Crash SDK & Telemetry**](file:///root/dev/Bloom/docs/hardening-phases/phase_13_observability_and_crash_sdk.md) — Automatic Flutter & native crash capture, release fingerprinting, breadcrumb recording timeline, structured context (`Bloom.captureException`), source map & dSYM symbolication, error grouping.
* [**Phase 14: Professional Tooling, Typed Config & Security Audit**](file:///root/dev/Bloom/docs/hardening-phases/phase_14_professional_tooling_and_security.md) — `bloom.config.dart` typed config, environment schema validation, feature flags, config diffing (`bloom config diff`), asset optimization pipeline, `bloom assets analyze`, dependency & permission audit, secret detection, reproducible builds & provenance.
* [**Phase 15: Developer Experience, Dev Launcher & Module Sandbox**](file:///root/dev/Bloom/docs/hardening-phases/phase_15_dx_dev_launcher_and_testing_lab.md) — Template registry & remote templates (`bloom create --template`), Bloom Dev Launcher, team dev server discovery, request replay & state/query inspectors, module sandbox (`bloom module dev`), native test harness (`bloom module test`), network & permission simulation.
* [**Phase 16: Ecosystem Registry, Upgrade Engine & Continuous Doctor**](file:///root/dev/Bloom/docs/hardening-phases/phase_16_ecosystem_registry_and_upgrade_engine.md) — `bloom upgrade` migration engine, breaking-change analyzer (`bloom doctor --upgrade`), Bloom Package Registry & compatibility badges, plugin certification lab, `bloom explain`, `bloom graph`, `bloom report`, continuous CI doctor agent.
* [**Phase 17: Production Parity, Reference Sample Applications & Launch Readiness**](file:///root/dev/Bloom/docs/hardening-phases/phase_17_production_parity_and_reference_samples.md) — Reference applications (`bloom_ecommerce`, `bloom_social_feed`, `bloom_fullstack_api`), full-stack API routes & SSR validation, offline queue recipes, multi-sample CI matrix verification.
