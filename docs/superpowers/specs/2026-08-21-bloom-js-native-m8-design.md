# Bloom JS Native M8 — Comprehensive Next-Gen Runtime Design Specification

## 1. Goal & Architectural Scope

This specification defines **Milestone 8 (M8)** for `packages/bloom_js_native`. Following the M7 gap-fill (events, SVG/Table DSL, lifecycle, router controller, sentinels), M8 equips the runtime with modern full-stack web capabilities:
1. **True In-Place Hydration (`hydrate()`)**: Attaches reactivity to existing SSR DOM nodes without DOM re-creation or layout thrashing.
2. **Ambient Context API (`createContext<T>()`)**: Pure-Dart ambient context passing without prop drilling.
3. **Error Boundaries (`ErrorBoundary`)**: Declarative error interception for reactive subtrees.
4. **Portals (`Portal`)**: Out-of-tree DOM mounting for modals, dialogs, and popovers.
5. **Async Suspense (`Suspense<T>`)**: Declarative async resource handling with fallback states.
6. **DevTools & Runtime Diagnostics**: Live inspection hooks for signal tracking and sentinel memory cleanup.

---

## 2. Sub-System Architecture

### 2.1 True In-Place DOM Hydration (`hydrate()`)

**Files:** `lib/src/hydrate.dart`, exported via `lib/browser.dart`

```dart
/// Hydrates a server-rendered DOM tree with reactive listeners in-place.
BloomMountHandle hydrate(BloomNode root, String selector);
```

#### How it works:
1. **Server Phase (`renderToHtml(..., hydratable: true)` / `renderToDocument`)**:
   - SSR output includes matching comment markers (`<!-- bloom:live:id -->`, `<!-- bloom:show:id -->`, `<!-- bloom:foreach:id -->`).
2. **Client Phase (`hydrate`)**:
   - Queries `selector` root.
   - Walks the existing DOM tree and correlates elements/comments with the `BloomNode` AST.
   - Attaches event listeners (`_attachListener`) directly to existing `web.Element` instances.
   - Binds `_Sentinel` instances around existing comment boundaries without removing or recreating children.

---

### 2.2 Ambient Context API (`createContext<T>()`)

**Files:** `lib/src/framework.dart`, `lib/bloom_js_native.dart`

```dart
/// Creates a typed ambient Context token.
BloomContext<T> createContext<T>(T defaultValue);

abstract class BloomContext<T> {
  T get defaultValue;
  BloomNode provide(T value, BloomNode child);
}

/// Reads the nearest ambient context value from within a component tree.
T useContext<T>(BloomContext<T> context);
```

- In pure Dart / SSR, context is resolved synchronously via Zone values (`runZoned`).
- In browser mounting, context propagation works seamlessly across `_mountNode` calls and reactive `_bindSentinelRegion` rebuilds.

---

### 2.3 Error Boundaries (`ErrorBoundary`)

**Files:** `lib/src/framework.dart`, `lib/src/mount.dart`, `lib/src/html.dart`

```dart
class ErrorBoundary extends BloomNode {
  final BloomNode Function() builder;
  final BloomNode Function(Object error, StackTrace stackTrace) fallback;

  const ErrorBoundary({
    required this.builder,
    required this.fallback,
  });
}
```

- **SSR (`html.dart`)**: Evaluates `builder()`. If an uncaught exception is thrown, catches it and renders `fallback(error, stackTrace)`.
- **Browser Mount (`mount.dart`)**: Wraps mounting and reactive region execution in a guarded block. If an error occurs during runtime reactivity, catches and safely swaps the sentinel content to the fallback subtree.

---

### 2.4 Portals (`Portal`)

**Files:** `lib/src/framework.dart`, `lib/src/mount.dart`, `lib/src/html.dart`

```dart
class Portal extends BloomNode {
  final BloomNode child;
  final String targetSelector;

  const Portal({
    required this.child,
    this.targetSelector = 'body',
  });
}
```

- **SSR (`html.dart`)**: Appends portal children into a dedicated portal section or renders inline with portal data attributes (`data-bloom-portal`).
- **Browser Mount (`mount.dart`)**: Resolves target container via `web.document.querySelector(targetSelector)` and mounts child nodes directly into the target element while retaining parent reactive region disposal lifecycle.

---

### 2.5 Async Resource Suspense (`Suspense<T>`)

**Files:** `lib/src/framework.dart`, `lib/src/mount.dart`, `lib/src/html.dart`

```dart
class Suspense<T> extends BloomNode {
  final Future<T> Function() resource;
  final BloomNode Function(T data) builder;
  final BloomNode fallback;

  const Suspense({
    required this.resource,
    required this.builder,
    required this.fallback,
  });
}
```

- **SSR (`renderToDocument` / `renderToStream`)**: Supports async resolution before flushing, or renders fallback shell for client-side streaming.
- **Browser Mount (`mount.dart`)**: Immediately mounts `fallback` inside a sentinel, evaluates `resource()`, and smoothly replaces sentinel children with `builder(data)` upon future completion.

---

### 2.6 DevTools & Runtime Diagnostics Hook

**Files:** `lib/src/devtools.dart`

```dart
class BloomJsDevTools {
  static bool enableDiagnostics = false;
  static int activeRegionCount = 0;
  static int activeSentinelCount = 0;
  static final List<void Function(String event, Map<String, dynamic> data)> _listeners = [];
  
  static void notify(String event, Map<String, dynamic> data) { ... }
}
```

- Tracks active `_Region` disposers and sentinel lifecycles to guarantee zero memory leaks in long-lived SPAs.

---

## 3. Testing Strategy

1. **VM Unit Tests (`dart test`)**:
   - `test/context_test.dart`: Context inheritance, fallback to default, multiple nested contexts.
   - `test/error_boundary_test.dart`: Error trapping in SSR and error fallback formatting.
   - `test/suspense_test.dart`: Async resource resolution and fallback rendering.
   - `test/devtools_test.dart`: Diagnostic counter tracking and listener notifications.
2. **Browser Integration Tests (`dart test -p chrome`)**:
   - `test/hydrate_test.dart`: Verification of zero DOM replacement during hydration.
   - `test/portal_test.dart`: DOM verification of out-of-tree mounting to document body.
3. **Monorepo Quality Gate**:
   - `dart analyze packages/bloom_js_native` (0 errors, 0 warnings).
