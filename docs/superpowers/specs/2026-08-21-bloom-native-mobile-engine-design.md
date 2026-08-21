# Bloom Native Mobile AST Engine Specification

**Document Version:** 1.0.0  
**Date:** 2026-08-21  
**Status:** Approved  
**Author:** Bloom Architecture & Antigravity  

---

## 1. Executive Summary & Objective

Provide a **Fabric-grade Native Mobile AST Layout & Rendering Subsystem** that enables pure-Dart **Bloom JS Native AST descriptors** (`Div`, `Span`, `Button`, `Input`, `Live`, `Show`, `ForEach`, `Fragment`) to run with **120 FPS native mobile GPU performance** on iOS and Android without a browser DOM, without WebViews, and without the overhead of JavaScript engines (Hermes/V8).

---

## 2. Architectural Comparison: Web DOM vs. Mobile GPU Pipeline

```
                                  ┌─────────────────────────────┐
                                  │  Shared Bloom JS Native AST │
                                  │  (Pure Dart Component Tree) │
                                  └──────────────┬──────────────┘
                                                 │
                         ┌───────────────────────┴───────────────────────┐
                         ▼                                               ▼
         ┌─────────────────────────────┐                 ┌─────────────────────────────┐
         │     WEB BROWSER TARGET      │                 │    NATIVE MOBILE ENGINE     │
         │  (bloom_js_native/browser)  │                 │    (bloom_native_engine)    │
         ├─────────────────────────────┤                 ├─────────────────────────────┤
         │ • Document Object Model     │                 │ 1. Multi-Pass Flex Solver   │
         │ • CSS Engine & Reflow       │                 │    (Resolves flex-wrap,     │
         │ • Direct DOM Node Mutation  │                 │     percentage dimensions)  │
         │ • DOM Event Bubbling        │                 │ 2. Leaf RenderBox Pipeline  │
         │ • Static HTML / SSR         │                 │    (Signals mutate text /   │
         │                             │                 │     fill directly on GPU)   │
         │                             │                 │ 3. Sliver Virtualization    │
         │                             │                 │    (Windowed item recycle)  │
         │                             │                 │ 4. Persistent Input Host    │
         │                             │                 │    (Preserves IME & focus)  │
         │                             │                 │ 5. Portals & Overlay Stack  │
         │                             │                 │    (Fixed / absolute z-idx) │
         └─────────────────────────────┘                 └─────────────────────────────┘
```

---

## 3. Core Engine Modules

### 3.1 `BloomFlexLayoutEngine` (`layout_engine.dart`)
* Resolves CSS / Tailwind flexbox semantics into tight `BoxConstraints`:
  * `flex-direction: row | column | row-reverse | column-reverse`
  * `flex-wrap: wrap | nowrap` (replaces rigid `Row` that overflows)
  * `justify-content`: `flex-start`, `flex-end`, `center`, `space-between`, `space-around`, `space-evenly`
  * `align-items` & `align-self`: `flex-start`, `flex-end`, `center`, `stretch`, `baseline`
  * Percentage width & height calculations based on parent box constraints.
  * Overflow management (`overflow-y: auto | scroll | hidden`).

### 3.2 `BloomLeafRenderBox` (`leaf_render_box.dart`)
* A custom high-performance `RenderBox` for atomic elements (`TextNode`, `Span`, icon badges).
* Subscribes directly to active signals (`Signal<T>`).
* **Zero Widget Tree Rebuilding**: When a signal changes, the leaf render box repaints its cached `TextPainter` and calls `markNeedsPaint()`, completely bypassing layout passes and ancestor widget re-evaluations.

### 3.3 `BloomVirtualSliverList` (`virtual_list.dart`)
* Maps `ForEachNode<T>` into a windowed, memory-efficient recycling sliver viewport.
* Renders only elements currently visible within the viewport plus an adjustable prefetch buffer (default: 200px).
* Supports dynamic item height measurement and key-based cache reuse.

### 3.4 `BloomNativeInputHost` (`input_host.dart`)
* Provides persistent stateful text editing controllers across AST reactive evaluations.
* Maintains cursor selection ranges, hardware/software keyboard insets, auto-focus, and input formatters without resetting text buffers when parent signals mutate.

### 3.5 `BloomPortalOverlayHost` (`portal_host.dart`)
* Renders elements with `fixed`, `absolute`, `z-50`, modal dialogs, and slide-over sheets into an isolated top-level overlay layer, preventing parent layout bounds clipping.

---

## 4. Testing & Verification Gates

1. **Flexbox Layout Unit Tests**: Verify flex-wrap, percentage widths, and gap calculations across constrained and unconstrained boxes.
2. **Signal Repaint Benchmarks**: Verify that mutating a signal in `Live()` triggers only `markNeedsPaint()` on the leaf renderbox without invoking `setState()` on the parent widget tree.
3. **Input Persistence Tests**: Verify that updating external signals while typing in a `BloomNativeInputHost` preserves the cursor position and active focus.
4. **Zero-Warning Gate**: `dart analyze` passes with 0 errors and 0 warnings across all packages.
