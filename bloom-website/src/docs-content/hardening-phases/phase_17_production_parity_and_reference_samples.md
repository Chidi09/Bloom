# Phase 17: Production Parity, Reference Sample Applications & Ecosystem Launch Readiness

> **Objective:** Deliver official production reference sample applications (`bloom_ecommerce`, `bloom_social_feed`, `bloom_fullstack_api`), verify full-stack architectural recipes across mobile, web, and backend, and establish end-to-end validation suites.

---

## 🏗️ Architecture & Reference Applications Matrix

```text
                                Bloom Ecosystem Launch Readiness
                                               │
               ┌───────────────────────────────┼───────────────────────────────┐
               ▼                               ▼                               ▼
       bloom_ecommerce                 bloom_social_feed              bloom_fullstack_api
    (Commerce & Offline)             (Infinite Feed & Media)         (Web SSR & API Routes)
               │                               │                               │
       ┌───────┴───────┐               ┌───────┴───────┐               ┌───────┴───────┐
       ▼               ▼               ▼               ▼               ▼               ▼
 Signals State   Offline Queue   Signals Store   Observability   API Middleware    SSR Engine
 GoRouter Shell  Stripe Checkout Infinite Query  Asset Pipeline  Postgres/Supabase Web Manifest
```

---

## 📦 1. Official Reference Sample Applications

### 1. `examples/bloom_ecommerce`
* **Features:**
  * Filesystem routing with `_layout.dart` bottom navigation shell (`/catalog`, `/cart`, `/checkout`, `/orders`).
  * Signals state management for reactive shopping cart (`CartController`, `computed` total price, badge counters).
  * `BloomData.query` for product catalog with stale-while-revalidate caching and search filters.
  * `OfflineMutationQueue` for offline order drafting and automated replay on network reconnection.
  * `BloomAuthGuard` protecting `/checkout` and `/orders` screens.

### 2. `examples/bloom_social_feed`
* **Features:**
  * Dynamic timeline feed with infinite scrolling and query pagination.
  * Media capture via `BloomCamera` with simulated fallback and asset optimization.
  * Real-time notifications simulation with `BloomNotifications` and permissions handling.
  * `BloomObservability` crash and breadcrumb recording for user interactions.

### 3. `examples/bloom_fullstack_api`
* **Features:**
  * Full-stack unified client and server architecture.
  * API Routes (`lib/routes/api/users.dart`, `lib/routes/api/health.dart`) with request middleware and JWT auth validation.
  * Server-Side Rendering (SSR) HTML hydration with SEO metadata tags and robots/sitemap generators.
  * Progressive Web App (PWA) manifest configuration.

---

## 🧪 Verification & Acceptance Criteria

> See [Spec Conventions & Definition of Done](file:///root/dev/Bloom/docs/hardening-phases/00b_spec_conventions_and_definition_of_done.md). Anti-patterns A1–A6 apply.

### C1. Reference Applications Compile and Analyze Cleanly
* **When** `flutter analyze` or `dart analyze` is run on all reference applications in `examples/`.
* **Then** 0 errors, 0 warnings, and 0 linter violations are reported.
* **Must not** have placeholder imports or broken unresolved dependencies (A1/A2).

### C2. E-Commerce Cart & Offline Queue Functionality
* **When** adding items to cart and placing an order while offline.
* **Then** the cart signal updates synchronously, the mutation is queued in `OfflineMutationQueue`, and replays upon `BloomDev.setOffline(false)`.

### C3. Social Feed Infinite Pagination & Media Capture
* **When** fetching feed pages, then `BloomData` caches and concatenates page results reactively with zero memory leaks.

### C4. Full-Stack API Route Handling & SSR Generation
* **When** querying `routes/api/*` endpoints, JSON responses with headers and HTTP status codes are produced deterministically.

### C5. CLI Doctor & CI Diagnostics
* **When** running `bloom doctor --ci` on all sample projects, all health checks pass with exit code `0`.
