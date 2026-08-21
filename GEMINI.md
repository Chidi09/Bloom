# Bloom Architecture & Development Memory (GEMINI.md)

This document is the persistent memory, architectural contract, and operational guideline for AI agents working in the **Bloom** repository.

---

## 1. 🎨 Strict Aesthetic & UI Rules

* **ABSOLUTELY NO TOY EMOJIS**:
  * Never use random, childish emojis (`🔥`, `🚀`, `✨`, `💡`, `🎉`) in production UI, landing pages, dashboard widgets, or components.
  * Always use clean Material vector icons (`Icons.*_rounded`, `Icons.*_outlined`) or clean SVGs.
* **Design System & Visual Language**:
  * **Theme**: Dark, Linear/Vercel-inspired engineering aesthetics.
  * **Palette**: Deep carbon backgrounds (`#09090B`), subtle elevated surfaces (`#14141A`), crisp borders (`#1E1E24` / `#27272A`), with precise indigo accents (`#6366F1`) and semantic status colors.
* **Bloom UI Primitives First**:
  * Always use native Bloom UI primitives (`BloomCard`, `BloomButton`, `BloomBadge`, `BloomProgress`, `BloomKbd`, `BloomAvatar`, `BloomCheckbox`, `BloomSeparator`) from `package:bloom_todo_ui/ui.dart` or `package:bloom_ui/bloom_ui.dart`.

---

## 2. 🏛️ Core Design Principles (SOLID, DRY, KISS, SoC)

* **DRY (Don't Repeat Yourself)**:
  * Domain entities (`Task`, `Project`, `Workspace`, `Section`, `Priority`, `ActivityEvent`) are defined strictly in `packages/core`.
  * Client apps (`apps/web`, `apps/mobile`) and server (`apps/server`) must re-use the exact same core models without creating duplicate model classes.
* **Separation of Concerns & Single Responsibility (SRP)**:
  * Decompose monolithic layouts into single-responsibility, high-cohesion widgets (`sidebar.dart`, `top_header.dart`, `today_view.dart`, `kanban_view.dart`, `telemetry_panel.dart`, `command_palette.dart`, `quick_add_dialog.dart`).
  * Keep business logic in controllers/stores (`TaskStore`), UI presentation in stateless/stateful widgets, and data access in repositories/DB.
* **Error Handling & Error Boundaries**:
  * **Server**: Register `BloomErrorMiddleware` as the first middleware in `BloomApiRouter`. Throw strongly-typed `BloomApiException` variants (`BloomNotFoundException`, `BloomBadRequestException`, `BloomValidationException`).
  * **Clients**: Always provide dedicated `error.dart` / `_error.dart` route error boundaries for router `errorBuilder` fallbacks.

---

## 3. 🌐 Full-Stack Server, SSR & Documentation Architecture

* **Server Runtime (`apps/server/bin/server.dart`)**:
  * Unified multi-isolate server running on port `8080`.
  * `/` ➔ Native Server-Side Rendered (SSR) HTML landing page (<1ms response, 0kB JS baseline, dynamic DB interpolation).
  * `/app` ➔ Interactive Flutter Web Client single-page app.
  * `/api/*` ➔ High-throughput REST & WebSocket APIs.
* **Auto-Generating OpenAPI & Swagger / Scalar Documentation**:
  * Activated with a single line: `router.enableOpenApi(title: '...', version: '...')`.
  * Dynamically inspects all registered routes in `BloomApiRouter` without manual JSON/YAML writing.
  * Interactive documentation endpoints:
    * `/api/docs` ➔ Modern dark-themed Scalar API explorer with Bloom vector logo.
    * `/api/swagger` ➔ Classic Swagger UI interactive console.
    * `/api/openapi.json` ➔ OpenAPI 3.1 JSON specification.

---

## 4. 🔀 Monorepo Split & Git Remote Operations

* **DO NOT PUSH TO ORIGIN DIRECTLY**:
  * The local workspace contains mixed public framework code and private cloud/dashboard infrastructure.
  * Always execute `/root/dev/Bloom/scripts/push-split.sh` to filter-repo and push clean splits:
    1. **Public Repository**: [`https://github.com/Chidi09/Bloom.git`](https://github.com/Chidi09/Bloom.git) (`packages/`, `apps/`, `examples/`, `benchmarks/`, `bloom-website/`).
    2. **Private Repository**: [`https://github.com/Chidi09/bloom-cloud.git`](https://github.com/Chidi09/bloom-cloud.git) (`cloud-backend/`, `cloud-dashboard/`, `docs/`).
  * Clean up any dangling origin remote afterwards: `git -C /root/dev/Bloom remote remove origin 2>/dev/null || true`.

---

## 5. 🧪 Testing & Code Quality Gates

* **Zero-Error Analysis**:
  * `dart analyze` and `flutter analyze` must pass with **0 errors and 0 warnings** across all packages/apps before committing.
* **Automated Tests**:
  * Run `cd packages/bloom_framework && flutter test`
  * Run `cd packages/bloom_js_native && dart test`
  * Run `cd packages/bloom_seo && dart test`
  * Run `cd examples/bloom_todo/packages/core && dart test`
  * Run `cd examples/bloom_todo/packages/ui && flutter test`

---

## 6. ⚡ Bloom JS Native Architecture & Reactivity Contract

* **Pure Dart AST Descriptors**:
  * All UI components compile to `BloomNode` (`ElNode`, `TextNode`, `LiveNode`, `ShowNode`, `ForEachNode`, `FragmentNode`) in `package:bloom_js_native/bloom_js_native.dart`.
  * **Strict VM/Web Boundary**: `bloom_js_native.dart` is pure Dart (runs on VM, SSR, tests). DOM mounting is strictly isolated in `package:bloom_js_native/browser.dart` via `package:web`.
* **Zero Linter Warnings via Const AST Subclasses**:
  * HTML element builders (`Div`, `Span`, `Button`, `Input`, `Form`, `H1`–`H6`, `Ul`, `Ol`, `Li`, `Link`) are `const` subclasses of `ElNode`, ensuring 0 `non_constant_identifier_names` warnings.
* **Dual-Backend Execution**:
  * **SSR/SSG**: `renderToHtml()` executes pure-Dart descriptor trees in `< 1ms` with full XSS escaping.
  * **Browser Mount**: `mount(app, '#app')` binds fine-grained `signals` effects with scoped `_Region` cleanup to prevent memory leaks.
* **NPM & Vendoring**:
  * Managed via `bloom_cli` (`bloom add npm:<pkg>`, `bloom npm sync`, `NpmVendorAssembler`).
  * Prefers `bun` for local ESM minified bundle vendoring; gracefully falls back to ESM CDN HTTP resolver.

