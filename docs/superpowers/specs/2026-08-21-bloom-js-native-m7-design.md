# Bloom JS Native M7+ Complete Gap-Fill Design Specification

## 1. Goal & Scope

Fill every structural gap in `packages/bloom_js_native` identified by the August 2026 audit. The package is functional for its M1–M3 surface, but is missing a working client router, has DOM-polluting reactive wrappers, lacks 60+ HTML elements, has a thin event API, and has no component lifecycle or SSR document-wrapping. This spec covers all of it as a single coherent milestone (M7) targeting the `bloom_js_native` package and its in-tree example.

## 2. Architecture Overview

Seven sub-systems are updated. Each is additive; none break existing public API.

| Sub-system | Status Before | Target After |
|---|---|---|
| Router | Path-matching stub only | History API + reactive route signal + `navigate()` |
| Mount engine | `<span>` wrapper pollution | Comment-node sentinels, clean reconciliation |
| HTML DSL | ~30 elements, 6 event types | ~55 elements, 18 event types, `cx()` utility |
| Events | `value`, `checked` only | 15 fields, fully typed keyboard/mouse/pointer |
| Component lifecycle | None | `onMount`, `onUnmount`, `Ref<T>` |
| SSR | Fragment renderer only | `renderToDocument()`, streaming SSR |
| NPM registry | No SRI / scopes | SRI integrity, sub-path scopes, conflict warnings |

## 3. Sub-System Designs

### 3.1 Router — History API + Reactive Route Signal

**New file:** `lib/src/router_browser.dart` (browser-only; exported from `browser.dart`)

```
BloomRouterController
  ├── final Signal<String> currentPath   ← reactive
  ├── void navigate(String path)         ← pushState + update signal
  ├── void replace(String path)          ← replaceState + update signal
  ├── BloomNode resolve()                ← match currentPath → builder()
  └── void dispose()                     ← remove popstate listener
```

`BloomRouter` (VM-side, existing) gains:
- `BloomRoute? notFound` — matched when no route matches
- `bool trailing` — treat `/foo/` == `/foo`

`Link` (existing) gains:
- `bool external` — skip intercept for off-site hrefs
- Browser-only: if a `BloomRouterController` is ambient (stored in a top-level final), clicks call `navigate()` and `preventDefault()`

The controller subscribes to `window.onpopstate` and calls `navigate` on browser back/forward. `navigate()` uses `window.history.pushState`.

### 3.2 Mount Engine — Comment Sentinel Wrappers

Replace every `web.document.createElement('span')` reactive container with a **comment-node pair sentinel**:

```
<!-- bloom:live:N --> ... children ... <!-- /bloom:live:N -->
```

A `_Sentinel` holds `startComment` + `endComment`. Insert/remove children between them. This:
- Has zero impact on CSS flex/grid
- Is invisible in DevTools element view (only comment nodes)
- Fixes keyed reconciliation reordering (operate between sentinel nodes)

`_Region` gains `_Sentinel? sentinel` so it can locate its DOM range. The `_bindKeyedForEach` reconciliation is rewritten to:
1. Build `newOrder` list of keys
2. For unchanged keys, skip rebuild (only rebuild if signal dependencies changed)
3. For deleted keys, dispose + remove nodes
4. For new keys, mount and insert before end sentinel
5. Reorder in one pass using `insertBefore`

### 3.3 HTML DSL — Missing Elements & Events

**New elements added to `framework.dart`:**

Form controls: `Select`, `Option`, `Optgroup`  
Tables: `Table`, `Thead`, `Tbody`, `Tfoot`, `Tr`, `Th`, `Td`, `Caption`, `Colgroup`, `Col`  
Media: `Video`, `Audio`, `Source`, `Track`, `Picture`  
Layout: `Br`, `Hr`, `Figure`, `Figcaption`  
Text semantics: `Blockquote`, `Cite`, `Time`, `Mark`, `Small`, `Sub`, `Sup`, `Abbr`, `Kbd`, `Samp`, `Var`  
Interactive: `Details`, `Summary`, `Dialog`  
Embedded: `IFrame`, `Canvas`  
SVG inline: `Svg`, `SvgPath`, `SvgCircle`, `SvgRect`, `SvgG`, `SvgLine`, `SvgText`, `SvgUse`  
Head elements (SSR only): `HeadEl`, `TitleEl`, `MetaEl`, `LinkEl`, `ScriptEl`

**New event sugar on `_mergeEvents` and `El` / element constructors:**

Add: `onMouseEnter`, `onMouseLeave`, `onMouseDown`, `onMouseUp`, `onMouseMove`, `onFocus`, `onBlur`, `onKeyPress` (deprecated but common), `onScroll`, `onWheel`, `onDrop`, `onDragOver`, `onDragStart`, `onPointerDown`, `onPointerUp`, `onContextMenu`, `onDblClick`, `onTouchStart`, `onTouchEnd`

**New `cx()` utility in `framework.dart`:**

```dart
/// Conditional className builder — clsx-style.
/// cx(['base', isActive && 'active', null, condition ? 'a' : 'b'])
String cx(List<Object?> parts) { ... }
```

### 3.4 Events — Rich BloomEvent Fields

`BloomEvent` gains optional fields (all nullable, VM-testable):
- `String? key` — keyboard key name ("Enter", "Escape", "a", …)
- `String? code` — physical key code ("KeyA", "ArrowUp", …)
- `bool shiftKey`, `bool ctrlKey`, `bool altKey`, `bool metaKey`
- `double? clientX`, `double? clientY` — mouse position in viewport
- `double? offsetX`, `double? offsetY` — mouse position relative to target
- `int? button` — which mouse button (0=left, 1=middle, 2=right)
- `List<String>? files` — filenames from file input
- `String? dataTransfer` — drag text data

`_wrapEvent()` in `mount.dart` reads all of these via `Reflect.get` (same pattern as existing `value`/`checked`).

Test fakes gain: `BloomEvent.fakeKeyDown(String key)`, `BloomEvent.fakeMouseMove(double x, double y)`.

### 3.5 Component Lifecycle — `onMount`, `onUnmount`, `Ref<T>`

Three new node types added to `framework.dart`:

```dart
/// Lifecycle hook — callback fires after the node's DOM subtree is appended.
class MountNode extends BloomNode {
  final BloomNode child;
  final void Function()? onMount;
  final void Function()? onUnmount;
  const MountNode(this.child, {this.onMount, this.onUnmount});
}
class Mount extends MountNode { ... }

/// DOM reference box — filled by mount engine with the created Element.
class Ref<T extends Object> {
  T? _value;
  T get value => _value ?? (throw StateError('Ref not yet mounted'));
  bool get isMounted => _value != null;
}

/// Attaches a Ref to the first child ElNode's DOM element.
class RefNode extends BloomNode {
  final Ref<web.Element> ref; // typed as Object? in pure-Dart barrel
  final BloomNode child;
  const RefNode(this.ref, this.child);
}
```

`mount.dart` handles `MountNode` and `RefNode` in the switch:
- `MountNode`: mount child, then schedule `onMount` via `Future.microtask`. Dispose registers `onUnmount`.
- `RefNode`: mount child, obtain first returned `Element`, set `ref._value`.

### 3.6 SSR — `renderToDocument()` + Streaming

**New functions in `html.dart`:**

```dart
/// Wraps output in a full HTML document shell.
String renderToDocument(
  BloomNode body, {
  String lang = 'en',
  String charset = 'UTF-8',
  String? title,
  List<BloomNode> head = const [],
  String? importMapJson,
  List<String> stylesheets = const [],
  List<String> scripts = const [],
});

/// Streaming SSR — yields chunks as the tree is walked.
/// Enables early flush on servers supporting chunked transfer.
Stream<String> renderToStream(BloomNode node);
```

Hydration markers: add `data-bloom-id="N"` attribute on ElNode during SSR when `hydratable: true` flag is passed. The browser mount checks for these and reuses existing DOM nodes instead of creating new ones (basic hydration, not full diff).

### 3.7 NPM Registry — SRI, Scopes, Conflict Warnings

`NpmDependency` gains:
- `String? integrity` — SRI hash (`sha384-...`)
- `String? subPath` — import sub-path (e.g. `lucide/icons` → separate scope entry)

`NpmRegistry` gains:
- `static List<String> conflicts()` — returns specifiers registered more than once
- Import map generation includes `"scopes": {}` block for sub-path dependencies
- `generateImportMapTag()` emits `integrity` attribute when set

## 4. File Map

| File | Action | Responsibility |
|---|---|---|
| `lib/src/framework.dart` | Modify | Add ~25 element classes, `cx()`, `MountNode`, `RefNode`, `Ref<T>`, extended `_mergeEvents` |
| `lib/src/events.dart` | Modify | Add 10 new BloomEvent fields + fakes |
| `lib/src/html.dart` | Modify | `renderToDocument()`, `renderToStream()`, SVG handling |
| `lib/src/mount.dart` | Modify | Comment sentinels, rich event wrapping, `MountNode`/`RefNode` cases |
| `lib/src/router.dart` | Modify | `notFound` route, trailing-slash option |
| `lib/src/router_browser.dart` | Create | `BloomRouterController`, history API, popstate |
| `lib/src/npm.dart` | Modify | `integrity`, `subPath`, `conflicts()`, `scopes` in import map |
| `lib/bloom_js_native.dart` | Modify | Export new nodes, `cx`, `Ref`, updated signals |
| `lib/browser.dart` | Modify | Export `router_browser.dart` |
| `test/framework_test.dart` | Modify | Tests for new elements, `cx()`, `MountNode`, `RefNode` |
| `test/events_test.dart` | Modify | Tests for all new BloomEvent fields |
| `test/html_test.dart` | Modify | Tests for `renderToDocument()`, streaming, SVG, hydration markers |
| `test/router_test.dart` | Modify | Tests for `notFound`, trailing-slash |
| `test/npm_test.dart` | Modify | Tests for SRI, scopes, conflicts |
| `test/lifecycle_test.dart` | Create | Tests for `Mount`, `Ref`, onMount/onUnmount |

## 5. Testing Standards

- 0 errors, 0 warnings: `dart analyze packages/bloom_js_native`
- All tests pass on VM: `cd packages/bloom_js_native && dart test`
- Mount/router browser tests are skipped on VM (tagged `@Skip('browser-only')`); they run in `dart test -p chrome` only
- Every new public API has at least one passing test

## 6. Non-Goals

- No virtual DOM / diffing engine
- No Flutter widgets
- No server-side WebSocket in this package
- No CSS-in-Dart compiler (cx() is className concatenation only)
- No full hydration (partial marker-based reuse is sufficient for M7)
