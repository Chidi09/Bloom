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

### 🔍 Section J: Transparency & Honesty Disclosures
* [**45. Platform Capabilities & Current Gaps**](file:///root/dev/Bloom/docs/transparency/platform_capabilities_and_gaps.md) — Honest evaluation of production-ready modules versus staged Dart facades/protocols.
