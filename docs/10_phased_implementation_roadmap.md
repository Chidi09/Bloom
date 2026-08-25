# 10. Phased Roadmap & Implementation Plan

> **Status note (2026-08-25):** The phase tracker below was written against the mobile/native client roadmap (CLI, DI, plugins, deep links, Bloom Go shell, OTA) and predates Bloom's server-side track. That track has since shipped independently as a full Django/DRF-inspired backend suite under `packages/` — `bloom_server` (router/DI/middleware), `bloom_db` (ORM) + `bloom_db_generator` + `bloom_migrate`, `bloom_rest` (serializers/viewsets/pagination), `bloom_auth_server` (password + JWT auth, now adding OAuth2), `bloom_admin`, `bloom_realtime` (WebSocket cluster), `bloom_cache` (memory/DB/Redis), `bloom_storage` (disk/S3), `bloom_mail` (now adding templating), `bloom_jobs` (now adding persistent Redis/DB-backed queues), and `bloom_security`. None of these packages are on pub.dev yet — publishing the server suite is the single highest-leverage item not reflected anywhere in the phase list below. The only backend-relevant line still open per Phase 8 is "Serverpod and Supabase official adapters."

## 1. Phase-by-Phase Roadmap

```text
                  BLOOM
                    │
                    ▼
          PHASE 0 — VALIDATION
       (Feasibility, Namespace, Design)
                    │
                    ▼
          PHASE 1 — CLI + CORE (v0.1)
      (create, dev, doctor, DI, Signals, Router)
                    │
                    ▼
          PHASE 2 — DATA & CRUD (v0.2)
     (Queries, Mutations, Cache, Repositories, Auth)
                    │
                    ▼
          PHASE 3 — NATIVE PLUGINS (v0.3)
      (Storage, Notifications, Camera, Prebuild)
                    │
                    ▼
          PHASE 4 — LIFECYCLE & DEEP LINKS (v0.4)
        (Universal Links, Flavors, Background)
                    │
                    ▼
          PHASE 5 — MODERN DEV DX (v0.5)
       (Interactive TUI, Wireless, QR Hosting)
                    │
                    ▼
          PHASE 6 — BLOOM GO SHELL (v0.6)
       (Expo-like Native Client, DevTools Extension)
                    │
                    ▼
          PHASE 7 — OTA DEPLOYMENT (v0.7)
       (Shorebird Orchestration & Patching)
                    │
                    ▼
          PHASE 8 — STABILIZATION & CLOUD (v1.0)
       (Full-stack Dart Adapters & Production 1.0)
```

---

## 2. Detailed Milestone Specifications

### Phase 0: Feasibility & Namespace Validation
* **Objective:** Reserve package namespaces on pub.dev (`bloom_framework`, `bloom_cli`, `bloom_core`).
* **Deliverables:** Architecture validation, API signature drafts, repository setup.

---

### Phase 1: Bloom v0.1 — Core & CLI Foundation
* **Objective:** Deliver "Flutter, but organized." A developer can create, scaffold, manage state, and navigate without assembling separate packages.
* **Deliverables:**
  1. `bloom create`: Interactive project generator with clean architecture.
  2. `bloom dev`: Interactive development orchestrator.
  3. `bloom doctor`: Health and environment diagnostic checks.
  4. `bloom generate`: Scaffolding for routes, pages, controllers, and models.
  5. `bloom.yaml`: Centralized application manifest.
  6. `Bloom.boot()`: Single-call runtime bootstrapper.
  7. Environment loader (`.env`, `.env.local`).
  8. Logging subsystem.
  9. Dependency injection container (`inject<T>()`, `provide<T>()`).
  10. Signals reactivity wrapper (`signal()`, `computed()`, `effect()`, `Watch`).
  11. Filesystem routing scanner compiled to `go_router`.
  12. Testing harness & container override utilities.
* **Success Criterion:** A developer installs `bloom_cli`, runs `bloom create`, creates a route and state controller with `bloom generate`, and runs the app with `bloom dev`.

---

### Phase 2: Bloom v0.2 — Data & Server State
* **Objective:** Deliver "Flutter, but productive." Complete server-state and offline caching runtime.
* **Deliverables:**
  1. `query<T>()`: Asynchronous query engine with memory caching and background revalidation.
  2. `mutation<T, P>()`: Asynchronous mutation engine with optimistic updates and rollback.
  3. Cache invalidation engine with declarative key matching.
  4. Offline persistence adapter and mutation replay queue.
  5. Standardized Repository pattern and HTTP client wrapper.
  6. Authentication abstraction and session management.
* **Success Criterion:** A production-style CRUD application with optimistic updates and offline caching built 100% using Bloom conventions.

---

### Phase 3: Bloom v0.3 — Native Integration & Prebuild
* **Objective:** Deliver "Flutter, but native setup is easy." Declarative platform configurations.
* **Deliverables:**
  1. Declarative plugin configuration API in `bloom.yaml`.
  2. Managed vs. Bare native modes.
  3. `bloom prebuild` transformation engine for Android & iOS manifests.
  4. Reference plugins: Secure Storage, Notifications, Camera.
  5. Automated runtime permission handling.
* **Success Criterion:** Adding camera, notifications, or keychain storage requires only updating `bloom.yaml` without editing XML or plist files for standard configurations.

---

### Phase 4: Bloom v0.4 — Advanced Mobile Capabilities
* **Objective:** Deep link orchestration, flavors, and background task management.
* **Deliverables:**
  1. Automated App Links (Android) & Universal Links (iOS) generator.
  2. Multi-environment build flavors (dev, staging, prod).
  3. Background task and lifecycle synchronization.

---

### Phase 5: Bloom v0.5 — Modern Dev DX & QR Hosting
* **Objective:** Deliver "Flutter, but development feels modern."
* **Deliverables:**
  1. Interactive TUI with hot reload, restart, device switching, and DevTools shortcuts.
  2. `bloom dev --wireless` Wi-Fi pairing and debugging.
  3. `bloom build --dev` with local artifact server and terminal ASCII QR code.

---

### Phase 6: Bloom v0.6 — Bloom Go Native Shell & DevTools
* **Objective:** Zero-install mobile development and visual inspection.
* **Deliverables:**
  1. Standalone Bloom Go native shell for iOS and Android.
  2. JIT Dart bundle streaming over local network.
  3. Bloom DevTools visual extension for Flutter DevTools.

---

### Phase 7: Bloom v0.7 — Shorebird OTA Integration
* **Objective:** Frictionless continuous delivery and instant patching.
* **Deliverables:**
  1. `bloom deploy` command wrapping Shorebird CLI.
  2. Release channel management and automated rollouts.

---

### Phase 8: Bloom v1.0 — Production Platform & Full-Stack Dart
* **Objective:** Enterprise stability and full-stack integrations.
* **Deliverables:**
  1. API freeze and 1.0 stability guarantee.
  2. Serverpod and Supabase official adapters.
  3. Comprehensive documentation portal, tutorials, and enterprise migration guides.

---

## 3. Success Metrics & Real-World Benchmark

To evaluate Bloom's architectural efficacy, we measure head-to-head against standard Flutter development on the same reference application:

| Metric | Standard Flutter Setup | Bloom Framework | Target Improvement |
| :--- | :--- | :--- | :--- |
| **Setup Time to First Screen** | ~15–30 mins (installing 5+ packages) | < 2 mins (`bloom create`) | **85%+ reduction** |
| **Configuration Files Touched** | 8+ files (xml, plist, yaml, gradle, env) | 1 file (`bloom.yaml`) | **80%+ reduction** |
| **Boilerplate Lines for Routing & Auth** | ~250–400 lines | ~40 lines | **80%+ reduction** |
| **Dependencies Evaluated & Maintained** | 10–15 disparate pub packages | 1 unified runtime (`bloom_framework`) | **90%+ reduction** |
| **Time to Authenticated CRUD Screen** | ~2–4 hours | ~20–30 mins | **75%+ reduction** |
