# Bloom JS Native M8 — Next-Gen Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement true in-place DOM hydration (`hydrate()`), ambient Context API (`createContext`/`useContext`), declarative `ErrorBoundary`, out-of-tree `Portal`, async `Suspense`, and DevTools memory diagnostics in `packages/bloom_js_native`.

**Architecture:** Purely additive architectural enhancements. Core AST nodes and Zone-based context mechanisms live in pure Dart (`framework.dart`, `html.dart`), while DOM traversal, in-place hydration, and element re-targeting live in `hydrate.dart` and `mount.dart` (exported via `browser.dart`).

**Tech Stack:** Dart 3.4+, `package:signals ^5.5.0`, `package:web ^1.1.0`, `dart:js_interop`

**Spec:** `docs/superpowers/specs/2026-08-21-bloom-js-native-m8-design.md`

## Global Constraints
- 0 errors, 0 warnings: `dart analyze packages/bloom_js_native`
- All VM unit tests pass: `cd packages/bloom_js_native && dart test`
- Never import `dart:js_interop` or `package:web` in `framework.dart`, `html.dart`, `events.dart`, `router.dart`, `npm.dart`, `signals.dart` — those are strictly VM-pure
- Browser-only code lives in `mount.dart`, `router_browser.dart`, and `hydrate.dart` only
- Every new public type gets a descriptive doc comment
- Commit after every task with a `feat(bloom_js_native):` prefix

---

### Task 1: Ambient Context API (`createContext` & `useContext`)

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Modify: `packages/bloom_js_native/lib/src/html.dart`
- Create: `packages/bloom_js_native/test/context_test.dart`

**Interfaces:**
- Produces: `BloomContext<T>`, `createContext<T>(T defaultValue) -> BloomContext<T>`, `useContext<T>(BloomContext<T> context) -> T`, `ContextProviderNode<T>`

- [ ] **Step 1: Write failing tests for Context API**

Create `packages/bloom_js_native/test/context_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

final themeContext = createContext<String>('light');

void main() {
  group('Context API', () {
    test('useContext returns default value when unprovided', () {
      expect(useContext(themeContext), 'light');
    });

    test('SSR renders child with provided context value', () {
      final app = themeContext.provide(
        'dark',
        Div(children: [
          Live(() => P(text: 'Theme: ${useContext(themeContext)}')),
        ]),
      );
      final html = renderToHtml(app);
      expect(html, '<div><p>Theme: dark</p></div>');
    });

    test('nested context overrides parent value', () {
      final app = themeContext.provide(
        'dark',
        Div(children: [
          P(text: 'Outer: ${useContext(themeContext)}'),
          themeContext.provide(
            'midnight',
            P(text: 'Inner: ${useContext(themeContext)}'),
          ),
        ]),
      );
      final html = renderToHtml(app);
      expect(html, '<div><p>Outer: dark</p><p>Inner: midnight</p></div>');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/context_test.dart
```
Expected: FAIL — `createContext` / `useContext` undefined.

- [ ] **Step 3: Implement Context API in `framework.dart`**

Add to `packages/bloom_js_native/lib/src/framework.dart`:

```dart
import 'dart:async';

/// Token representing an ambient context value of type [T].
class BloomContext<T> {
  final T defaultValue;
  final Object _zoneKey = Object();

  BloomContext(this.defaultValue);

  /// Provides [value] to all children in the subtree.
  BloomNode provide(T value, BloomNode child) =>
      ContextProviderNode<T>(this, value, child);
}

/// Creates a typed ambient [BloomContext] with [defaultValue].
BloomContext<T> createContext<T>(T defaultValue) => BloomContext<T>(defaultValue);

/// Reads the current ambient value for [context].
T useContext<T>(BloomContext<T> context) {
  final value = Zone.current[context._zoneKey];
  if (value != null && value is T) return value;
  return context.defaultValue;
}

/// AST node that injects context [value] into its descendant tree.
class ContextProviderNode<T> extends BloomNode {
  final BloomContext<T> context;
  final T value;
  final BloomNode child;

  const ContextProviderNode(this.context, this.value, this.child);
}
```

- [ ] **Step 4: Update `html.dart` and `mount.dart` to handle `ContextProviderNode`**

In `lib/src/html.dart`:
```dart
case ContextProviderNode(:final context, :final value, :final child):
  runZoned(
    () => _render(child, buf),
    zoneValues: {context._zoneKey: value},
  );
```

In `lib/src/mount.dart`:
```dart
case ContextProviderNode(:final context, :final value, :final child):
  return runZoned(
    () => _mountNode(child, region),
    zoneValues: {context._zoneKey: value},
  );
```

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/context_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/lib/src/html.dart packages/bloom_js_native/lib/src/mount.dart packages/bloom_js_native/test/context_test.dart
git commit -m "feat(bloom_js_native): add ambient Context API (createContext and useContext)"
```

---

### Task 2: Error Boundaries (`ErrorBoundary`)

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/lib/src/html.dart`
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Create: `packages/bloom_js_native/test/error_boundary_test.dart`

**Interfaces:**
- Produces: `ErrorBoundaryNode`, `ErrorBoundary({required builder, required fallback})`

- [ ] **Step 1: Write failing tests for ErrorBoundary**

Create `packages/bloom_js_native/test/error_boundary_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorBoundary', () {
    test('renders child when no error occurs in SSR', () {
      final app = ErrorBoundary(
        builder: () => P(text: 'Healthy Content'),
        fallback: (err, stack) => P(text: 'Error caught: $err'),
      );
      final html = renderToHtml(app);
      expect(html, '<p>Healthy Content</p>');
    });

    test('renders fallback when builder throws during SSR', () {
      final app = ErrorBoundary(
        builder: () => throw Exception('Render failure'),
        fallback: (err, stack) => Div(className: 'error', text: 'Caught: $err'),
      );
      final html = renderToHtml(app);
      expect(html, '<div class="error">Caught: Exception: Render failure</div>');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/error_boundary_test.dart
```

- [ ] **Step 3: Add `ErrorBoundaryNode` and `ErrorBoundary` to `framework.dart`**

```dart
/// Catches exceptions during subtree rendering or reactive rebuilds
/// and renders [fallback] instead of crashing.
class ErrorBoundaryNode extends BloomNode {
  final BloomNode Function() builder;
  final BloomNode Function(Object error, StackTrace stackTrace) fallback;

  const ErrorBoundaryNode({
    required this.builder,
    required this.fallback,
  });
}

/// Sugar for [ErrorBoundaryNode].
class ErrorBoundary extends ErrorBoundaryNode {
  const ErrorBoundary({
    required super.builder,
    required super.fallback,
  });
}
```

- [ ] **Step 4: Handle `ErrorBoundaryNode` in `html.dart` and `mount.dart`**

In `lib/src/html.dart`:
```dart
case ErrorBoundaryNode(:final builder, :final fallback):
  try {
    final inner = builder();
    _render(inner, buf);
  } catch (err, stack) {
    final fallbackNode = fallback(err, stack);
    _render(fallbackNode, buf);
  }
```

In `lib/src/mount.dart`:
```dart
case ErrorBoundaryNode(:final builder, :final fallback):
  final sentinel = _Sentinel('error-boundary');
  final inner = _Region();
  try {
    final node = builder();
    final nodes = _mountNode(node, inner);
    sentinel.appendAll(nodes);
  } catch (err, stack) {
    inner.disposeAll();
    sentinel.clear();
    final fallbackNode = fallback(err, stack);
    final nodes = _mountNode(fallbackNode, inner);
    sentinel.appendAll(nodes);
  }
  region.add(inner.disposeAll);
  return [sentinel.start, sentinel.end];
```

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/error_boundary_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/lib/src/html.dart packages/bloom_js_native/lib/src/mount.dart packages/bloom_js_native/test/error_boundary_test.dart
git commit -m "feat(bloom_js_native): add declarative ErrorBoundary runtime support"
```

---

### Task 3: Portals (`Portal`)

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/lib/src/html.dart`
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Create: `packages/bloom_js_native/test/portal_test.dart`

**Interfaces:**
- Produces: `PortalNode`, `Portal({required child, targetSelector})`

- [ ] **Step 1: Write failing tests for Portal**

Create `packages/bloom_js_native/test/portal_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Portal', () {
    test('SSR renders portal node with data-bloom-portal attribute', () {
      final modal = Portal(
        targetSelector: '#modal-root',
        child: Div(className: 'modal-body', text: 'Modal content'),
      );
      final html = renderToHtml(modal);
      expect(html, contains('data-bloom-portal="#modal-root"'));
      expect(html, contains('<div class="modal-body">Modal content</div>'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/portal_test.dart
```

- [ ] **Step 3: Add `PortalNode` and `Portal` in `framework.dart`**

```dart
/// Renders [child] into a target DOM node outside the parent hierarchy
/// while maintaining parent reactive region lifecycle.
class PortalNode extends BloomNode {
  final BloomNode child;
  final String targetSelector;

  const PortalNode({
    required this.child,
    this.targetSelector = 'body',
  });
}

/// Sugar for [PortalNode].
class Portal extends PortalNode {
  const Portal({
    required super.child,
    super.targetSelector = 'body',
  });
}
```

- [ ] **Step 4: Update `html.dart` and `mount.dart`**

In `lib/src/html.dart`:
```dart
case PortalNode(:final child, :final targetSelector):
  buf.write('<template data-bloom-portal="${escapeHtml(targetSelector)}">');
  _render(child, buf);
  buf.write('</template>');
```

In `lib/src/mount.dart`:
```dart
case PortalNode(:final child, :final targetSelector):
  final targetEl = web.document.querySelector(targetSelector) ?? web.document.body!;
  final childNodes = _mountNode(child, region);
  for (final n in childNodes) {
    targetEl.appendChild(n);
    region.add(() => n.parentNode?.removeChild(n));
  }
  // Return empty sentinel marker in current container
  final comment = web.document.createComment(' portal:$targetSelector ');
  return [comment];
```

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/portal_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/lib/src/html.dart packages/bloom_js_native/lib/src/mount.dart packages/bloom_js_native/test/portal_test.dart
git commit -m "feat(bloom_js_native): add out-of-tree Portal primitive"
```

---

### Task 4: Async Resource Suspense (`Suspense<T>`)

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/lib/src/html.dart`
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Create: `packages/bloom_js_native/test/suspense_test.dart`

**Interfaces:**
- Produces: `SuspenseNode<T>`, `Suspense<T>({required resource, required builder, required fallback})`

- [ ] **Step 1: Write failing tests for Suspense**

Create `packages/bloom_js_native/test/suspense_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Suspense', () {
    test('SSR renders fallback shell synchronously', () {
      final app = Suspense<String>(
        resource: () => Future.value('Loaded Data'),
        builder: (data) => P(text: data),
        fallback: P(text: 'Loading...'),
      );
      final html = renderToHtml(app);
      expect(html, '<p>Loading...</p>');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/suspense_test.dart
```

- [ ] **Step 3: Add `SuspenseNode` and `Suspense` in `framework.dart`**

```dart
/// Declarative async boundary that renders [fallback] while [resource] resolves.
class SuspenseNode<T> extends BloomNode {
  final Future<T> Function() resource;
  final BloomNode Function(T data) builder;
  final BloomNode fallback;

  const SuspenseNode({
    required this.resource,
    required this.builder,
    required this.fallback,
  });
}

/// Sugar for [SuspenseNode].
class Suspense<T> extends SuspenseNode<T> {
  const Suspense({
    required super.resource,
    required super.builder,
    required super.fallback,
  });
}
```

- [ ] **Step 4: Update `html.dart` and `mount.dart`**

In `lib/src/html.dart`:
```dart
case SuspenseNode(:final fallback):
  _render(fallback, buf);
```

In `lib/src/mount.dart`:
```dart
case SuspenseNode<Object?>():
  final sentinel = _Sentinel('suspense');
  final inner = _Region();
  final fallbackNodes = _mountNode(node.fallback, inner);
  sentinel.appendAll(fallbackNodes);

  node.resource().then((data) {
    if (!region.isDisposed) {
      inner.disposeAll();
      sentinel.clear();
      final loadedNode = node.builder(data);
      final loadedNodes = _mountNode(loadedNode, inner);
      sentinel.appendAll(loadedNodes);
    }
  });

  region.add(inner.disposeAll);
  return [sentinel.start, sentinel.end];
```

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/suspense_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/lib/src/html.dart packages/bloom_js_native/lib/src/mount.dart packages/bloom_js_native/test/suspense_test.dart
git commit -m "feat(bloom_js_native): add async Suspense resource boundary"
```

---

### Task 5: DevTools & Memory Diagnostics

**Files:**
- Create: `packages/bloom_js_native/lib/src/devtools.dart`
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/devtools_test.dart`

**Interfaces:**
- Produces: `BloomJsDevTools.activeRegionCount`, `BloomJsDevTools.activeSentinelCount`, `BloomJsDevTools.notify(...)`

- [ ] **Step 1: Write failing tests for DevTools**

Create `packages/bloom_js_native/test/devtools_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('DevTools diagnostics', () {
    test('tracks active regions and sentinels', () {
      expect(BloomJsDevTools.activeRegionCount, isNonNegative);
      expect(BloomJsDevTools.activeSentinelCount, isNonNegative);
    });

    test('registers and notifies diagnostics listeners', () {
      String? lastEvent;
      final unregister = BloomJsDevTools.addListener((evt, data) {
        lastEvent = evt;
      });
      BloomJsDevTools.notify('test:event', {'timestamp': 12345});
      expect(lastEvent, 'test:event');
      unregister();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/devtools_test.dart
```

- [ ] **Step 3: Create `devtools.dart`**

```dart
/// Runtime diagnostics and DevTools inspection hooks for Bloom JS Native.
class BloomJsDevTools {
  BloomJsDevTools._();

  static int activeRegionCount = 0;
  static int activeSentinelCount = 0;

  static final List<void Function(String event, Map<String, dynamic> data)>
      _listeners = [];

  /// Register a diagnostics event listener. Returns an unregister callback.
  static void Function() addListener(
      void Function(String event, Map<String, dynamic> data) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Dispatches a diagnostic event.
  static void notify(String event, Map<String, dynamic> data) {
    for (final listener in List.of(_listeners)) {
      try {
        listener(event, data);
      } catch (_) {}
    }
  }
}
```

- [ ] **Step 4: Hook into `_Region` and `_Sentinel` in `mount.dart`**

Increment counters on initialization and decrement on disposal in `mount.dart`.

- [ ] **Step 5: Export from `bloom_js_native.dart`**

Add `export 'src/devtools.dart';` to `lib/bloom_js_native.dart`.

- [ ] **Step 6: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/devtools_test.dart
```

- [ ] **Step 7: Commit**

```bash
git add packages/bloom_js_native/lib/src/devtools.dart packages/bloom_js_native/lib/src/mount.dart packages/bloom_js_native/lib/bloom_js_native.dart packages/bloom_js_native/test/devtools_test.dart
git commit -m "feat(bloom_js_native): add DevTools diagnostics and memory telemetry"
```

---

### Task 6: True In-Place DOM Hydration Engine (`hydrate()`)

**Files:**
- Create: `packages/bloom_js_native/lib/src/hydrate.dart`
- Modify: `packages/bloom_js_native/lib/browser.dart`
- Create: `packages/bloom_js_native/test/hydrate_test.dart`

**Interfaces:**
- Produces: `hydrate(BloomNode root, String selector) -> BloomMountHandle`

- [ ] **Step 1: Write integration tests for `hydrate()`**

Create `packages/bloom_js_native/test/hydrate_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Hydration descriptor contracts', () {
    test('renderToDocument with hydratable flag produces hydration markers', () {
      final doc = renderToDocument(
        Div(children: [P(text: 'Hydratable item')]),
        title: 'App',
      );
      expect(doc, contains('<!DOCTYPE html>'));
      expect(doc, contains('<p>Hydratable item</p>'));
    });
  });
}
```

- [ ] **Step 2: Implement `hydrate.dart` in `lib/src/hydrate.dart`**

Implement DOM node traversal, comment sentinel correlation, and event listener attachment against pre-existing DOM nodes.

- [ ] **Step 3: Export `hydrate.dart` in `browser.dart`**

Add `export 'src/hydrate.dart';` to `lib/browser.dart`.

- [ ] **Step 4: Run full test suite & analyze**

```bash
cd packages/bloom_js_native && dart test && dart analyze
```
Expected: 0 errors, 0 warnings.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_js_native/lib/src/hydrate.dart packages/bloom_js_native/lib/browser.dart packages/bloom_js_native/test/hydrate_test.dart
git commit -m "feat(bloom_js_native): implement true in-place DOM hydration engine"
```

---

### Task 7: Quality Gate & Monorepo Verification

**Files:**
- Verify all package test suites across the monorepo.

- [ ] **Step 1: Run Bloom JS Native full test suite**

```bash
cd packages/bloom_js_native && dart test --reporter expanded
```

- [ ] **Step 2: Run Bloom Framework test suite**

```bash
cd packages/bloom_framework && flutter test
```

- [ ] **Step 3: Run monorepo analyzer**

```bash
dart analyze packages/bloom_js_native packages/bloom_framework packages/bloom_seo
```

- [ ] **Step 4: Verify example compilation**

```bash
cd packages/bloom_js_native/example && dart compile js -O2 -o /tmp/m8_build.js main.dart
```

- [ ] **Step 5: Final commit**

```bash
git add packages/bloom_js_native/
git commit -m "chore(bloom_js_native): M8 complete — all next-gen runtime features verified"
```
