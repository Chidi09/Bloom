# Bloom Post-v1.0 Hardening Roadmap & Platform Expansion

> **"From a cohesive framework to an extensible, enterprise-grade developer platform."**

With the completion of Bloom v1.0 (Phases 0 through 8), Bloom provides a complete core application foundation: CLI, convention-based runtime, Signals state management, filesystem routing, Bloom Data caching with offline queueing, declarative native prebuild, Bloom Go mobile shell, Shorebird OTA patching, and full-stack adapters.

The **Hardening Roadmap (Phases 9 through 16)** shifts focus from basic framework features to **ecosystem completeness, module extensibility, native autolinking, runtime versioning, full-stack web/SSR expansion, observability, professional tooling, and enterprise governance**.

> ⚠️ **Every phase must satisfy the shared [Spec Conventions & Definition of Done](file:///root/dev/Bloom/docs/hardening-phases/00b_spec_conventions_and_definition_of_done.md)** (anti-patterns A1–A6, the Definition of Done checklist, and the acceptance-criteria format). That document is the contract; individual phase docs may only add to it, never weaken it.

---

## 🗺️ Hardening Phases Matrix

```text
                                  BLOOM PLATFORM
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           ▼                            ▼                            ▼
   EXTENSION PLATFORM            RUNTIME PLATFORM           APPLICATION PLATFORM
  (Phases 9, 10, 15, 16)         (Phases 11, 13)             (Phases 12, 14)
           │                            │                            │
 ┌─────────┴─────────┐        ┌─────────┴─────────┐        ┌─────────┴─────────┐
 │ Phase 9: Modules  │        │ Phase 11: Updates │        │ Phase 12: Router  │
 │ Phase 10: Autolink│        │ Phase 13: Observ. │        │ Phase 14: Tooling │
 │ Phase 15: Sandbox │        │                   │        │                   │
 │ Phase 16: Registry│        │                   │        │                   │
 └───────────────────┘        └───────────────────┘        └───────────────────┘
```

---

## 📋 Summary of Hardening Phases

| Phase | Title | Milestone Focus | Target Deliverables |
| :---: | :--- | :--- | :--- |
| **Phase 9** | [**Bloom Native Module Platform & DSL**](file:///root/dev/Bloom/docs/hardening-phases/phase_09_module_platform_and_dsl.md) | Ecosystem Authoring API | `bloom create module`, Native Module DSL (`@BloomModule`), Dart ↔ Swift/Kotlin binding generators, typed arguments, native events, native streams, native views (`BloomNativeView`), native lifecycle, thread/queue semantics. |
| **Phase 10** | [**Autolinking, Monorepos & Native Dependency Resolution**](file:///root/dev/Bloom/docs/hardening-phases/phase_10_autolinking_and_dependency_graph.md) | Dependency Resolution | `bloom add` autolinking, transitive module discovery, duplicate native module detection, `bloom deps`, `bloom why`, `bloom resolve`, `bloom.lock`, native dependency constraints, monorepo workspace discovery. |
| **Phase 11** | [**Bloom Updates Platform & Runtime Fingerprinting**](file:///root/dev/Bloom/docs/hardening-phases/phase_11_updates_platform_and_runtime_fingerprinting.md) | Safe OTA Update Engine | `bloom_updates` client, update manifest schema, runtime compatibility & cryptographic fingerprinting, channels & branches, staged percentage rollouts, instant rollback, embedded fallback, background downloading. |
| **Phase 12** | [**Router Expansion, API Routes & Full-Stack Web (SSR/SSG)**](file:///root/dev/Bloom/docs/hardening-phases/phase_12_router_expansion_and_fullstack_web.md) | Universal Application Router | API routes (`routes/api/*`), route handlers & middleware, loaders & actions, error & loading routes, Static Site Generation (`bloom build web --static`), Server-Side Rendering (`bloom build web --server`), SEO metadata, sitemap/robots generator, PWA & web manifest. |
| **Phase 13** | [**Error Observability, Crash SDK & Telemetry**](file:///root/dev/Bloom/docs/hardening-phases/phase_13_observability_and_crash_sdk.md) | Reliability & Diagnostics | Automatic Flutter & native crash capture, release fingerprinting, breadcrumb recording timeline, structured context (`Bloom.captureException`), source map & dSYM symbolication, error grouping. |
| **Phase 14** | [**Professional Tooling, Typed Config & Security Audit**](file:///root/dev/Bloom/docs/hardening-phases/phase_14_professional_tooling_and_security.md) | Enterprise Governance | `bloom.config.dart` typed config, environment schema validation, feature flags, config diffing (`bloom config diff`), asset optimization pipeline, `bloom assets analyze`, dependency & permission audit, secret detection, reproducible builds & provenance. |
| **Phase 15** | [**Developer Experience, Dev Launcher & Module Sandbox**](file:///root/dev/Bloom/docs/hardening-phases/phase_15_dx_dev_launcher_and_testing_lab.md) | World-Class DX & Parity | Template registry & remote templates (`bloom create --template`), Bloom Dev Launcher, team dev server discovery, request replay & state/query inspectors, module sandbox (`bloom module dev`), native test harness (`bloom module test`), network & permission simulation. |
| **Phase 16** | [**Ecosystem Registry, Upgrade Engine & Continuous Doctor**](file:///root/dev/Bloom/docs/hardening-phases/phase_16_ecosystem_registry_and_upgrade_engine.md) | Long-Term Platform Health | `bloom upgrade` migration engine, breaking-change analyzer (`bloom doctor --upgrade`), Bloom Package Registry & compatibility badges, plugin certification lab, `bloom explain`, `bloom graph`, `bloom report`, continuous CI doctor agent. |

---

## 🎯 The North Star Milestone

> **"A third-party developer can create a Bloom native module using the Bloom Module DSL, publish it, install it into a Bloom application with zero-config autolinking, run it in the Bloom Dev Launcher, and safely ship OTA code patches strictly validated against the native binary's runtime fingerprint."**
