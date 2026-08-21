# Bloom JS Native (M4–M6) Design Specification

## 1. Goal & Architectural Overview
Deliver Milestones M4, M5, and M6 for Bloom JS Native by maximizing reuse of existing CLI modules (`packages/bloom_cli/lib/src/npm/`), view widgets (`examples/bloom_todo/apps/web/lib/views/`), server router (`packages/bloom_framework/lib/src/server/api_router.dart`), and pre-rendering engine (`packages/bloom_cli/lib/src/web/prerender_engine.dart`).

## 2. Milestone Decomposition

### M4: Bun Vendoring & CLI Toolchain
- **Location**: `packages/bloom_cli/lib/src/npm/bun_vendor_assembler.dart` and `packages/bloom_cli/lib/src/commands/npm_command.dart`.
- **Functionality**:
  - `NpmVendorAssembler` augmented with `BunRunner`: checks `which bun`.
  - When `bun` exists: runs `bun add <pkg>@<ver>` in an isolated `.bloom/vendor_tmp` cache, extracts ESM bundles to `web/vendor/<pkg>.min.js`, and builds local `./vendor/<pkg>.min.js` import maps.
  - When `bun` does not exist: falls back transparently to CDN HTTP streaming (`NpmResolver`).
  - Command: `bloom npm sync` / `bloom js vendor` updates both `web/vendor/` and `web/index.html` `<script type="importmap">`.

### M5: SSR Endpoint on `BloomApiRouter` & Native SSG Pre-rendering
- **Location**: `packages/bloom_framework/lib/src/server/api_router.dart` and `packages/bloom_cli/lib/src/web/prerender_engine.dart`.
- **Functionality**:
  - `BloomApiRouter` extension / method:
    ```dart
    void ssr(
      String path,
      BloomNode Function(BloomRequest req) builder, {
      HeadManager Function(BloomRequest req)? head,
      String Function(String bodyHtml, HeadManager? head)? layout,
    });
    ```
  - Sub-millisecond execution (<1ms response) using pure-Dart `renderToHtml(node)`.
  - `BloomPrerenderEngine` detects `target: web_dom` in `bloom.yaml` and executes pure-Dart SSG via `prerenderRoute()` directly without launching headless Puppeteer.

### M6: Full Example Integration & Documentation
- **Location**: `examples/bloom_todo/apps/web/` and `packages/bloom_js_native/docs/`.
- **Functionality**:
  - Integrate JS plugins (`lucide`, `canvas_confetti`, `sonner`, `clsx`, `formkit_auto_animate`) with Bloom JS Native DOM views.
  - Verify complete view pipeline (`today_view.dart`, `kanban_view.dart`, `table_view.dart`, `telemetry_panel.dart`).
  - Complete documentation guides and update root `GEMINI.md` architectural contracts.

## 3. Testing & Quality Standards
- 0 analyzer warnings and 0 errors across all modified packages.
- Comprehensive unit tests covering Bun resolution, SSR router endpoints, and SSG rendering.
