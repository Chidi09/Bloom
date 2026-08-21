# Bloom Native Mobile AST Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Fabric-grade Native Mobile AST Layout & Rendering Engine in `packages/bloom_framework/lib/src/native_engine/` and showcase it with `examples/bloom_portfolio`.

**Architecture:** Implement `BloomFlexLayoutEngine` (flexbox solver with flex-wrap and percentage support), `BloomLeafRenderBox` (direct GPU paint hook for signals), `BloomNativeInputHost` (cursor/IME preservation), `BloomVirtualSliverList` (windowed recycling), and `BloomPortalHost` (z-index overlay stack).

**Tech Stack:** Dart 3.5+, Flutter 3.24+, `package:bloom_framework`, `package:bloom_js_native`, `package:signals_flutter`.

**Spec:** [`docs/superpowers/specs/2026-08-21-bloom-native-mobile-engine-design.md`](file:///root/dev/Bloom/docs/superpowers/specs/2026-08-21-bloom-native-mobile-engine-design.md)

## Global Constraints

- Pure Dart & Flutter standard rendering pipeline (no external C++ binaries required).
- Zero-warning rule on `dart analyze` and `flutter analyze`.
- Full-stack parity: The exact same `BloomNode` AST component tree must render on Web (DOM) and Mobile (GPU engine).

---

### Task 1: Implement `BloomFlexLayoutEngine` & Style Resolver

**Files:**
- Create: `packages/bloom_framework/lib/src/native_engine/style_resolver.dart`
- Create: `packages/bloom_framework/lib/src/native_engine/flex_layout.dart`
- Test: `packages/bloom_framework/test/native_engine/flex_layout_test.dart`

**Interfaces:**
- Produces: `class BloomFlexLayout extends MultiChildRenderObjectWidget`, `class RenderBloomFlex extends RenderBox`.

- [ ] **Step 1: Write unit test for Flexbox solver**
- [ ] **Step 2: Implement `StyleResolver` with flex-wrap, percentage, and gap rules**
- [ ] **Step 3: Implement `RenderBloomFlex` with multi-pass layout**
- [ ] **Step 4: Run test to verify it passes**

---

### Task 2: Implement `BloomLeafRenderBox` & Fine-Grained GPU Signal Painting

**Files:**
- Create: `packages/bloom_framework/lib/src/native_engine/leaf_render_box.dart`
- Test: `packages/bloom_framework/test/native_engine/leaf_render_box_test.dart`

**Interfaces:**
- Produces: `class BloomLeafTextWidget extends LeafRenderObjectWidget`, `class RenderBloomLeafText extends RenderBox`.

- [ ] **Step 1: Write unit test verifying signal mutation repaints without layout rebuild**
- [ ] **Step 2: Implement `RenderBloomLeafText` with `TextPainter` and signal subscription**
- [ ] **Step 3: Run test to verify it passes**

---

### Task 3: Implement `BloomNativeInputHost` & `BloomVirtualSliverList`

**Files:**
- Create: `packages/bloom_framework/lib/src/native_engine/input_host.dart`
- Create: `packages/bloom_framework/lib/src/native_engine/virtual_list.dart`
- Create: `packages/bloom_framework/lib/src/native_engine/portal_host.dart`
- Create: `packages/bloom_framework/lib/src/native_engine/native_renderer.dart`

- [ ] **Step 1: Implement `BloomNativeInputHost` with persistent text controller cache**
- [ ] **Step 2: Implement `BloomVirtualSliverList` for `ForEachNode` virtualization**
- [ ] **Step 3: Implement `BloomPortalHost` for overlays and modals**
- [ ] **Step 4: Export in `packages/bloom_framework/lib/bloom_mobile.dart`**

---

### Task 4: Build `examples/bloom_portfolio` Showcase Application

**Files:**
- Create: `examples/bloom_portfolio/packages/core/lib/models/asset.dart`
- Create: `examples/bloom_portfolio/packages/core/lib/models/currency.dart`
- Create: `examples/bloom_portfolio/packages/core/lib/state/portfolio_store.dart`
- Create: `examples/bloom_portfolio/apps/web/lib/views/portfolio_view.dart`
- Create: `examples/bloom_portfolio/apps/web/lib/main.dart`
- Create: `examples/bloom_portfolio/apps/mobile/lib/main.dart`

- [ ] **Step 1: Implement core domain entities and reactive currency math in `packages/core`**
- [ ] **Step 2: Implement pure Dart AST components in `apps/web/lib/views/portfolio_view.dart`**
- [ ] **Step 3: Mount on Web (`apps/web`) and compile with `dart compile js`**
- [ ] **Step 4: Mount exact same AST on Mobile (`apps/mobile`) via `runBloomMobile()`**
- [ ] **Step 5: Run full monorepo analysis gate (`flutter analyze` / `dart analyze`)**
