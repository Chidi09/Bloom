# Design Spec: Bloom JS Native Website Landing Pages

**Date:** 2026-08-27  
**Status:** Approved  
**Scope:** Landing Pages (`/`, `/bloom`, `/build`, `/ship`, `/server`) & Static Site Generator (SSG)

---

## 1. Overview & Goals

Create a pure **Bloom JS Native** implementation of the official Bloom marketing website landing pages. The solution replaces the Astro/Node stack with a pure Dart architecture:
1. **Zero-Node SSG Engine**: Pre-renders all static landing pages directly to static HTML (`dist/`) using `renderToHtml()` in `<1ms` per page.
2. **Linear/Vercel Engineering Aesthetics**: Dark carbon palette (`#09090B`), elevated surfaces (`#14141A`), crisp borders (`#1E1E24`), and precision SVG vector icons.
3. **Fine-Grained Client Reactivity**: Client JS bundle (`web/main.dart` -> `dist/main.js`) mounting interactive islands (Benchmark Telemetry, Command Palette, Code Copy Toasts, Mobile Menu).
4. **Complete SEO & Metadata**: Dynamic OpenGraph tags, Twitter Cards, Sitemap, and JSON-LD structured data via `package:bloom_seo`.

---

## 2. Architecture & Directory Layout

The new project is housed under `apps/bloom_website_native/`:

```
apps/bloom_website_native/
├── pubspec.yaml                 # Dependencies: bloom_js_native, bloom_seo, web, etc.
├── bloom.yaml                   # Bloom project manifest
├── bin/
│   └── ssg.dart                 # Dart SSG builder: renders HTML to dist/
├── web/
│   ├── index.html               # Entry template shell with head links & CSS imports
│   ├── main.dart                # Client hydration & interactive islands entry point
│   └── styles/
│       └── main.css             # Tailwind CSS & design token variables
├── lib/
│   ├── design/
│   │   ├── tokens.dart          # Colors, borders, typography, shadows
│   │   └── theme.dart           # Design tokens & color constants
│   ├── components/
│   │   ├── cn.dart              # Class name merger
│   │   ├── button_variants.dart # CVA button variant generator
│   │   ├── ui.dart              # Badges, cards, status pills, hugeIcons, code blocks
│   │   ├── navbar.dart          # Sticky blurred navbar with mobile drawer
│   │   ├── footer.dart          # Clean footer with platform links & ecosystem info
│   │   ├── tech_marquee.dart    # Infinite scrolling framework logos
│   │   ├── command_palette.dart # Ctrl+K command modal with signals
│   │   └── toast_system.dart    # Reactive floating toast notification
│   └── pages/
│       ├── page_layout.dart     # Common page shell (Navbar, Content, Footer, Head)
│       ├── home_page.dart       # Platform Overview & Hero
│       ├── bloom_page.dart      # Runtime & Signals Reactivity
│       ├── build_page.dart      # Build Tooling, CLI & Fast Compilation
│       ├── ship_page.dart       # OTA Releases & Cloud Distribution
│       └── server_page.dart     # Dart Backend, SSR & OpenAPI Endpoints
└── test/
    └── ssg_render_test.dart     # Unit test verifying HTML generation for all pages
```

---

## 3. Landing Pages Breakdown

### 3.1. Platform Home (`/` - `home_page.dart`)
* **Hero**: Eyebrow badge (*"Bloom v1.0 Released"*), high-contrast title (*"The Application Platform for Dart & Flutter"*), subtitle, primary CTA (*"Get Started"*), secondary CTA (*"Explore Architecture"*), interactive copyable install command `bloom create my_app`.
* **Product Pillars**: 3 interactive pillar cards for **Build**, **Ship**, and **Bloom**.
* **Live Telemetry & Benchmark Panel**: Real-time ticker demonstrating zero-VDOM signals vs virtual DOM diffing (adapted from `BenchmarkComponent`).
* **Feature Grid**: Fine-grained reactivity, sub-ms SSR, OTA patches, multi-isolate server.
* **Marquee Ribbon**: Ecosystem integrations.

### 3.2. Bloom Runtime (`/bloom` - `bloom_page.dart`)
* **Hero**: Focus on Signals Engine and sub-millisecond AST descriptors.
* **Interactive Reactivity Model**: Visual breakdown of direct DOM text/attribute bindings.
* **Component Model**: Pure Dart AST nodes (`Div`, `Span`, `Live`, `ForEach`, `Show`).

### 3.3. Build Tooling (`/build` - `build_page.dart`)
* **Hero**: Sub-second incremental compilation and hot reload.
* **CLI Explorer**: Visual simulator of `bloom dev`, `bloom build`, `bloom prebuild`.
* **Zero-Config Asset Pipeline**: Asset optimization and Tailwind integration.

### 3.4. Ship & OTA (`/ship` - `ship_page.dart`)
* **Hero**: Over-The-Air patching with Shorebird engine and cloud distribution.
* **Release Pipeline**: Interactive channels visualizer (Dev -> Staging -> Production).
* **Rollback Safeguards**: Instant rollback and patch telemetry.

### 3.5. Fullstack Server (`/server` - `server_page.dart`)
* **Hero**: High-throughput multi-isolate Dart server runtime.
* **OpenAPI 3.1 & Docs**: Interactive documentation preview (Scalar & Swagger endpoints).
* **Unified SSR**: `<1ms` SSR response times with zero Chromium/Puppeteer overhead.

---

## 4. UI Primitives & Design System

Following the patterns in `benchmarks/marketplace/bloom`:
* **HugeIcons SVG Collection**: Clean 1.5px stroke vector icons (terminal, zap, layers, server, rocket, check, copy, search, code, github). No toy emojis.
* **`bloomButton`**: High-cohesion button supporting `primary`, `secondary`, `outline`, `ghost`, and `destructive` styles.
* **`bloomBadge`**: Status badges supporting `brand`, `success`, `warning`, and `default`.
* **`codeBlock`**: Syntax-styled container with copy-to-clipboard trigger.
* **`bloomCard`**: Dark surface card with subtle `#1E1E24` border and hover transitions.

---

## 5. SSG Build & Hydration Pipeline

1. **`bin/ssg.dart`**:
   * Registers all 5 landing routes.
   * Compiles HTML using `renderToHtml()` wrapped with complete SEO metadata and CSS links.
   * Writes output to:
     * `dist/index.html`
     * `dist/bloom/index.html`
     * `dist/build/index.html`
     * `dist/ship/index.html`
     * `dist/server/index.html`
     * `dist/sitemap.xml`
     * `dist/llms.txt`
   * Copies `web/styles/main.css` and static assets to `dist/`.
2. **`web/main.dart`**:
   * Compiled with `dart compile js web/main.dart -o dist/main.js -O2`.
   * Mounts reactive islands (`mount(CommandPalette(), '#bloom-palette')`, `mount(ToastSystem(), '#bloom-toast')`, etc.).

---

## 6. Testing & Quality Gate

* **Tests**: `dart test` in `apps/bloom_website_native` validates that all 5 routes render non-empty HTML containing required heading tags and metadata.
* **Analysis**: `dart analyze .` passes with 0 errors and 0 warnings.
