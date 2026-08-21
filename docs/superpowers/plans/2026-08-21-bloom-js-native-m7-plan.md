# Bloom JS Native M7 — Complete Gap-Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill every structural gap in `packages/bloom_js_native` — working client router with history API, comment-sentinel DOM wrappers, ~25 new HTML/SVG elements, rich event fields, `onMount`/`onUnmount`/`Ref<T>` lifecycle, `renderToDocument()` + streaming SSR, and NPM registry SRI/scopes improvements.

**Architecture:** Purely additive changes to the existing 6-file package. No existing public API is removed or changed. Browser-specific additions live in `router_browser.dart` and are exported from `browser.dart`. All new nodes are handled in the `mount.dart` switch and `html.dart` renderer.

**Tech Stack:** Dart 3.4+, `package:signals ^5.5.0`, `package:web ^1.1.0`, `dart:js_interop`

**Spec:** `docs/superpowers/specs/2026-08-21-bloom-js-native-m7-design.md`

## Global Constraints
- 0 errors, 0 warnings: `dart analyze packages/bloom_js_native`
- All VM tests pass: `cd packages/bloom_js_native && dart test`
- Never import `dart:js_interop` or `package:web` in `framework.dart`, `events.dart`, `html.dart`, `router.dart`, `npm.dart` — those are VM-pure
- Browser-only code lives in `mount.dart` and `router_browser.dart` only
- Every new public type gets a doc comment
- Commit after every task with `feat(bloom_js_native):` prefix

---

### Task 1: Rich `BloomEvent` Fields

**Files:**
- Modify: `packages/bloom_js_native/lib/src/events.dart`
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Modify: `packages/bloom_js_native/test/events_test.dart`

**Interfaces:**
- Produces: `BloomEvent.key`, `.code`, `.shiftKey`, `.ctrlKey`, `.altKey`, `.metaKey`, `.clientX`, `.clientY`, `.offsetX`, `.offsetY`, `.button`, `.files`, `.dataTransfer`; new fakes `BloomEvent.fakeKeyDown(String key)`, `BloomEvent.fakeMouseMove(double x, double y)`

- [ ] **Step 1: Write failing tests** — add to `test/events_test.dart` inside `group('BloomEvent', ...)`:

```dart
test('fakeKeyDown carries key and code', () {
  final e = BloomEvent.fakeKeyDown('Enter', code: 'Enter');
  expect(e.type, 'keydown');
  expect(e.key, 'Enter');
  expect(e.code, 'Enter');
});

test('fakeMouseMove carries clientX/Y', () {
  final e = BloomEvent.fakeMouseMove(100.0, 200.0);
  expect(e.type, 'mousemove');
  expect(e.clientX, 100.0);
  expect(e.clientY, 200.0);
});

test('modifier keys default false', () {
  final e = BloomEvent.fakeClick();
  expect(e.shiftKey, isFalse);
  expect(e.ctrlKey, isFalse);
});

test('files field carries filename list', () {
  final e = BloomEvent(type: 'change', files: ['photo.jpg', 'doc.pdf']);
  expect(e.files, ['photo.jpg', 'doc.pdf']);
});
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/events_test.dart
```

- [ ] **Step 3: Extend `BloomEvent` in `events.dart`** — add fields to constructor and class body:

```dart
class BloomEvent {
  final String type;
  final String? value;
  final bool? checked;
  final Object? rawTarget;
  // Keyboard
  final String? key;
  final String? code;
  final bool shiftKey;
  final bool ctrlKey;
  final bool altKey;
  final bool metaKey;
  // Mouse / Pointer
  final double? clientX;
  final double? clientY;
  final double? offsetX;
  final double? offsetY;
  final int? button;
  // File / Drag
  final List<String>? files;
  final String? dataTransfer;

  final void Function()? _preventDefaultFn;
  final void Function()? _stopPropagationFn;
  bool _defaultPrevented = false;
  bool _propagationStopped = false;

  BloomEvent({
    required this.type,
    this.value, this.checked, this.rawTarget,
    this.key, this.code,
    this.shiftKey = false, this.ctrlKey = false,
    this.altKey = false, this.metaKey = false,
    this.clientX, this.clientY, this.offsetX, this.offsetY, this.button,
    this.files, this.dataTransfer,
    void Function()? preventDefaultFn,
    void Function()? stopPropagationFn,
  })  : _preventDefaultFn = preventDefaultFn,
        _stopPropagationFn = stopPropagationFn;

  void preventDefault() { _defaultPrevented = true; _preventDefaultFn?.call(); }
  void stopPropagation() { _propagationStopped = true; _stopPropagationFn?.call(); }
  bool get defaultPrevented => _defaultPrevented;
  bool get propagationStopped => _propagationStopped;

  factory BloomEvent.fakeClick() => BloomEvent(type: 'click');
  factory BloomEvent.fakeInput(String value) => BloomEvent(type: 'input', value: value);
  factory BloomEvent.fakeChange({String? value, bool? checked}) =>
      BloomEvent(type: 'change', value: value, checked: checked);
  factory BloomEvent.fake(String type, {String? value}) => BloomEvent(type: type, value: value);
  factory BloomEvent.fakeKeyDown(String key, {String? code}) =>
      BloomEvent(type: 'keydown', key: key, code: code ?? key);
  factory BloomEvent.fakeMouseMove(double x, double y) =>
      BloomEvent(type: 'mousemove', clientX: x, clientY: y);
}
```

- [ ] **Step 4: Extend `_wrapEvent` in `mount.dart`** — add `_jsGetDouble`, `_jsGetInt`, `_jsGetFileNames` helpers and read new fields from JS event object using `Reflect.get`. Map each field onto the `BloomEvent(...)` constructor call. (Same pattern as existing `value`/`checked` via `_jsGetString`/`_jsGetBool`.)

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/events_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/events.dart packages/bloom_js_native/lib/src/mount.dart packages/bloom_js_native/test/events_test.dart
git commit -m "feat(bloom_js_native): rich BloomEvent fields — keyboard, mouse, files, modifiers"
```

---

### Task 2: Extended Event Sugar (18 Event Types on Element Builders)

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/test/framework_test.dart`

**Interfaces:**
- Produces: `_mergeEvents` with `onMouseEnter`, `onMouseLeave`, `onMouseDown`, `onMouseUp`, `onMouseMove`, `onFocus`, `onBlur`, `onKeyPress`, `onScroll`, `onWheel`, `onContextMenu`, `onPointerDown`, `onPointerUp`, `onDrop`, `onDragOver`, `onDragStart`, `onTouchStart`, `onTouchEnd`, `onDblClick`

- [ ] **Step 1: Write failing tests**

```dart
test('onMouseEnter sugar merges into "mouseenter"', () {
  final n = Div(onMouseEnter: (_) {}) as ElNode;
  expect(n.on, contains('mouseenter'));
});
test('onFocus sugar merges into "focus"', () {
  final n = Input(onFocus: (_) {}) as ElNode;
  expect(n.on, contains('focus'));
});
test('onBlur sugar merges into "blur"', () {
  final n = Input(onBlur: (_) {}) as ElNode;
  expect(n.on, contains('blur'));
});
test('onDblClick sugar merges into "dblclick"', () {
  final n = Button(onDblClick: (_) {}) as ElNode;
  expect(n.on, contains('dblclick'));
});
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/framework_test.dart
```

- [ ] **Step 3: Replace `_mergeEvents` signature** — expand from 6 named handlers to all 25 named handlers. Map each to its DOM event name string (`onMouseEnter → 'mouseenter'`, `onDblClick → 'dblclick'`, etc.). Return `null` when all are null/empty (same guard as today).

- [ ] **Step 4: Add the new parameters to `Div`, `Button`, `Input`, `A`, `Span`, `Li`** — at minimum expose `onMouseEnter`, `onMouseLeave`, `onFocus`, `onBlur`, `onDblClick` on each.

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/framework_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/test/framework_test.dart
git commit -m "feat(bloom_js_native): extend event sugar — 18 event types on element builders"
```

---

### Task 3: `cx()` Utility + Text-Semantic Elements

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/test/framework_test.dart`

**Interfaces:**
- Produces: `cx(List<Object?>) → String`; elements `Br`, `Hr`, `Blockquote`, `Cite`, `TimeEl`, `Mark`, `Small`, `Sub`, `Sup`, `Abbr`, `KbdEl`, `Figure`, `Figcaption`, `Details`, `Summary`, `Dialog`, `Canvas`, `IFrame`

- [ ] **Step 1: Write failing tests**

```dart
group('cx()', () {
  test('joins non-null strings', () => expect(cx(['foo', 'bar']), 'foo bar'));
  test('filters null and false', () => expect(cx(['a', null, false, 'b']), 'a b'));
  test('returns empty string for all null', () => expect(cx([null, false]), ''));
});
test('Br is void element in SSR', () {
  expect(renderToHtml(Br()), '<br>');
});
test('Details + Summary render', () {
  final html = renderToHtml(Details(children: [Summary(text: 'Title'), P(text: 'body')]));
  expect(html, '<details><summary>Title</summary><p>body</p></details>');
});
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/framework_test.dart
```

- [ ] **Step 3: Add `cx()` function** after the existing `_mergeAttrs`/`_mergeEvents` helpers:

```dart
/// Conditional className builder (clsx-style).
/// Filters null, false, and blank strings. Joins remaining with a single space.
/// cx(['btn', isActive && 'active', null])  // => 'btn active'
String cx(List<Object?> parts) {
  final out = StringBuffer();
  for (final part in parts) {
    if (part == null || part == false) continue;
    final s = part.toString().trim();
    if (s.isEmpty) continue;
    if (out.isNotEmpty) out.write(' ');
    out.write(s);
  }
  return out.toString();
}
```

- [ ] **Step 4: Add element classes** — `Br`, `Hr` (void, const), `Blockquote`, `Cite`, `TimeEl` (with `dateTime` → `'datetime'` attr), `Mark`, `Small`, `Sub`, `Sup`, `Abbr` (with `title` attr), `KbdEl`, `Figure`, `Figcaption`, `Details` (with `open` attr), `Summary`, `Dialog` (with `open` attr), `Canvas` (with `width`/`height`), `IFrame` (with `src`/`title`/`width`/`height`).

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/test/framework_test.dart
git commit -m "feat(bloom_js_native): cx() utility + 17 new semantic HTML elements"
```

---

### Task 4: Table & Form-Select Elements

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/test/framework_test.dart`

**Interfaces:**
- Produces: `Table`, `Caption`, `Thead`, `Tbody`, `Tfoot`, `Tr`, `Th` (with `scope`/`colSpan`/`rowSpan`), `Td` (with `colSpan`/`rowSpan`); `Select` (with `name`/`multiple`/`disabled`/`onChange`), `Option` (with `value`/`selected`/`disabled`), `Optgroup` (with `label`)

- [ ] **Step 1: Write failing tests**

```dart
test('Table renders full structure', () {
  final html = renderToHtml(Table(children: [
    Thead(children: [Tr(children: [Th(text: 'Name')])]),
    Tbody(children: [Tr(children: [Td(text: 'Alice')])]),
  ]));
  expect(html, '<table><thead><tr><th>Name</th></tr></thead><tbody><tr><td>Alice</td></tr></tbody></table>');
});
test('Select with Options renders', () {
  final html = renderToHtml(Select(children: [
    Option(value: '1', text: 'One'),
    Option(value: '2', text: 'Two'),
  ]));
  expect(html, '<select><option value="1">One</option><option value="2">Two</option></select>');
});
test('Th with scope emits attribute', () {
  expect(renderToHtml(Th(text: 'H', scope: 'col')), '<th scope="col">H</th>');
});
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/framework_test.dart
```

- [ ] **Step 3: Add Table family and Select family to `framework.dart`** — see spec section 3.3 for full class bodies. Use `_mergeAttrs` for `colspan`/`rowspan`/`scope`/`multiple`/`selected`/`disabled`/`label` attrs.

- [ ] **Step 4: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test
```

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/test/framework_test.dart
git commit -m "feat(bloom_js_native): Table family + Select/Option/Optgroup elements"
```

---

### Task 5: Inline SVG Element DSL

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/lib/src/html.dart`
- Modify: `packages/bloom_js_native/test/html_test.dart`

**Interfaces:**
- Produces: `SvgNode` sealed base; `Svg`, `SvgG`, `SvgPath`, `SvgCircle`, `SvgRect`, `SvgLine`, `SvgText`, `SvgUse`; SSR renders SVG without `<br>`-style void-element closing

- [ ] **Step 1: Write failing tests**

```dart
test('Svg renders with viewBox', () {
  final html = renderToHtml(Svg(viewBox: '0 0 24 24', children: [
    SvgPath(d: 'M12 2L2 7l10 5 10-5-10-5z'),
  ]));
  expect(html, '<svg viewBox="0 0 24 24"><path d="M12 2L2 7l10 5 10-5-10-5z"></path></svg>');
});
test('SvgCircle renders cx cy r', () {
  expect(renderToHtml(SvgCircle(cx: 12, cy: 12, r: 5)), '<circle cx="12" cy="12" r="5"></circle>');
});
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/html_test.dart
```

- [ ] **Step 3: Add `SvgNode` and SVG elements to `framework.dart`** — `SvgNode extends ElNode` with `const SvgNode(super.tag, ...)`. Then `Svg`, `SvgG`, `SvgPath` (with `d`/`fill`/`stroke`/`stroke-width`), `SvgCircle` (with `cx`/`cy`/`r`), `SvgRect` (with `x`/`y`/`width`/`height`/`rx`), `SvgLine` (with `x1`/`y1`/`x2`/`y2`), `SvgText` (with `x`/`y`), `SvgUse` (with `href`).

- [ ] **Step 4: Add `SvgNode` case to `_render` in `html.dart`** — place it BEFORE the `ElNode` case in the switch so it takes priority. SVG elements always emit closing tags (`<path ...></path>`, never self-closed `<path .../>`).

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/lib/src/html.dart packages/bloom_js_native/test/html_test.dart
git commit -m "feat(bloom_js_native): inline SVG element DSL with SSR support"
```

---

### Task 6: Component Lifecycle — `Mount` Node & `Ref<T>`

**Files:**
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Modify: `packages/bloom_js_native/lib/src/html.dart`
- Create: `packages/bloom_js_native/test/lifecycle_test.dart`

**Interfaces:**
- Produces: `Ref<T extends Object>` with `.value`, `.isMounted`, `.attach(T)`, `.detach()`; `MountNode(child, {onMount, onUnmount})`, `Mount` sugar; `RefNode(ref, child)` — mount engine fills ref after mounting child element

- [ ] **Step 1: Write failing tests** — create `test/lifecycle_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('MountNode', () {
    test('Mount wraps child correctly', () {
      final node = Mount(P(text: 'hi'), onMount: () {});
      expect(node is MountNode, isTrue);
      expect((node.child as ElNode).tag, 'p');
    });
    test('SSR renders child — onMount NOT called', () {
      var called = false;
      final node = Mount(P(text: 'hello'), onMount: () => called = true);
      expect(renderToHtml(node), '<p>hello</p>');
      expect(called, isFalse);
    });
  });
  group('Ref', () {
    test('starts unmounted', () {
      final ref = Ref<Object>();
      expect(ref.isMounted, isFalse);
    });
    test('throws before mount', () {
      final ref = Ref<Object>();
      expect(() => ref.value, throwsStateError);
    });
    test('RefNode wraps child descriptor', () {
      final ref = Ref<Object>();
      final node = RefNode(ref, Div());
      expect((node.child as ElNode).tag, 'div');
    });
  });
}
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/lifecycle_test.dart
```

- [ ] **Step 3: Add `Ref<T>`, `MountNode`, `Mount`, `RefNode` to `framework.dart`**

```dart
class Ref<T extends Object> {
  T? _value;
  T get value => _value ?? (throw StateError('Ref<$T> not yet mounted'));
  bool get isMounted => _value != null;
  // ignore: use_setters_to_change_properties
  void attach(T element) => _value = element;
  void detach() => _value = null;
}

class MountNode extends BloomNode {
  final BloomNode child;
  final void Function()? onMount;
  final void Function()? onUnmount;
  const MountNode(this.child, {this.onMount, this.onUnmount});
}

class Mount extends MountNode {
  const Mount(super.child, {super.onMount, super.onUnmount});
}

class RefNode extends BloomNode {
  final Ref<Object> ref;
  final BloomNode child;
  const RefNode(this.ref, this.child);
}
```

- [ ] **Step 4: Handle `MountNode` and `RefNode` in `html.dart` SSR** — render only the child; skip lifecycle:

```dart
case MountNode(:final child):
  _render(child, buf);
case RefNode(:final child):
  _render(child, buf);
```

- [ ] **Step 5: Handle `MountNode` and `RefNode` in `mount.dart` browser switch**:

```dart
case MountNode(:final child, :final onMount, :final onUnmount):
  final nodes = _mountNode(child, region);
  if (onMount != null) Future.microtask(onMount);
  if (onUnmount != null) region.add(onUnmount);
  return nodes;

case RefNode(:final ref, :final child):
  final nodes = _mountNode(child, region);
  for (final n in nodes) {
    if (n is web.Element) {
      ref.attach(n);
      region.add(ref.detach);
      break;
    }
  }
  return nodes;
```

- [ ] **Step 6: Run tests**

```bash
cd packages/bloom_js_native && dart test test/lifecycle_test.dart
```

- [ ] **Step 7: Commit**

```bash
git add packages/bloom_js_native/lib/src/framework.dart packages/bloom_js_native/lib/src/mount.dart packages/bloom_js_native/lib/src/html.dart packages/bloom_js_native/test/lifecycle_test.dart
git commit -m "feat(bloom_js_native): MountNode lifecycle hooks + Ref<T> DOM reference"
```

---

### Task 7: Comment-Sentinel Reactive Wrappers

**Files:**
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Modify: `packages/bloom_js_native/test/framework_test.dart`

**Interfaces:**
- Produces: `_Sentinel` class; `_bindSentinelRegion`; `_bindKeyedForEachSentinel`; `LiveNode`/`ShowNode`/`ForEachNode` now return `[sentinel.start, sentinel.end]` instead of a wrapping `<span>`

- [ ] **Step 1: Add a doc-comment test marking the behavioral contract**

Add to `test/framework_test.dart`:

```dart
test('LiveNode returns comment-sentinel nodes in mount (doc contract)', () {
  // Browser-only behavior: mount engine uses document.createComment(),
  // not createElement('span'), for Live/Show/ForEach wrappers.
  // This avoids stray inline elements in flex/grid layouts.
  final live = Live(() => P(text: 'x'));
  expect(live is LiveNode, isTrue);
});
```

- [ ] **Step 2: Add `_Sentinel` class to `mount.dart`**:

```dart
class _Sentinel {
  final web.Comment start;
  final web.Comment end;
  _Sentinel(String label)
      : start = web.document.createComment(' bloom:$label '),
        end = web.document.createComment(' /bloom:$label ');

  List<web.Node> get childNodes {
    final result = <web.Node>[];
    var current = start.nextSibling;
    while (current != null && current != end) {
      result.add(current);
      current = current.nextSibling;
    }
    return result;
  }

  void clear() {
    for (final n in childNodes) n.parentNode?.removeChild(n);
  }

  void appendAll(List<web.Node> nodes) {
    for (final n in nodes) end.parentNode?.insertBefore(n, end);
  }
}
```

- [ ] **Step 3: Replace `LiveNode`, `ShowNode`, `ForEachNode` cases in `_mountNode`** — use `_Sentinel` instead of `createElement('span')`, returning `[sentinel.start, sentinel.end]`.

- [ ] **Step 4: Add `_bindSentinelRegion<T>`** — same contract as old `_bindReactiveRegion` but uses `sentinel.clear()` + `sentinel.appendAll()` instead of `container.textContent = ''`.

- [ ] **Step 5: Rewrite `_bindKeyedForEachSentinel`** — use `sentinel.end.parentNode?.insertBefore(n, sentinel.end)` for insertion; remove old DOM nodes relative to the sentinel's parent. See spec section 3.2 for reconciliation algorithm.

- [ ] **Step 6: Delete the old `_bindReactiveRegion` function** — it is replaced by `_bindSentinelRegion`.

- [ ] **Step 7: Run all tests**

```bash
cd packages/bloom_js_native && dart test && dart analyze packages/bloom_js_native
```
Expected: 0 failures, 0 warnings.

- [ ] **Step 8: Commit**

```bash
git add packages/bloom_js_native/lib/src/mount.dart packages/bloom_js_native/test/framework_test.dart
git commit -m "feat(bloom_js_native): comment-sentinel reactive regions — no more <span> pollution"
```

---

### Task 8: `renderToDocument()` and `renderToStream()`

**Files:**
- Modify: `packages/bloom_js_native/lib/src/html.dart`
- Modify: `packages/bloom_js_native/test/html_test.dart`

**Interfaces:**
- Consumes: existing `_render`, `escapeHtml`
- Produces: `renderToDocument(BloomNode, {lang, charset, title, head, importMapJson, stylesheets, scripts}) → String`; `renderToStream(BloomNode) → Stream<String>`

- [ ] **Step 1: Write failing tests**

```dart
group('renderToDocument', () {
  test('wraps body in full HTML shell', () {
    final html = renderToDocument(Div(text: 'hello'), title: 'My App');
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<title>My App</title>'));
    expect(html, contains('<div>hello</div>'));
    expect(html, contains('</body>'));
  });
  test('includes import map', () {
    final html = renderToDocument(Div(), importMapJson: '{"imports":{"zod":"https://esm.sh/zod@3"}}');
    expect(html, contains('<script type="importmap">'));
  });
  test('includes stylesheets', () {
    final html = renderToDocument(Div(), stylesheets: ['/app.css']);
    expect(html, contains('<link rel="stylesheet" href="/app.css">'));
  });
});

group('renderToStream', () {
  test('emits same content as renderToHtml', () async {
    final node = Div(children: [P(text: 'a'), P(text: 'b')]);
    final streamed = await renderToStream(node).join();
    expect(streamed, renderToHtml(node));
  });
});
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/html_test.dart
```

- [ ] **Step 3: Implement `renderToDocument` in `html.dart`**:

```dart
String renderToDocument(
  BloomNode body, {
  String lang = 'en',
  String charset = 'UTF-8',
  String? title,
  List<BloomNode> head = const [],
  String? importMapJson,
  List<String> stylesheets = const [],
  List<String> scripts = const [],
}) {
  final buf = StringBuffer();
  buf.write('<!DOCTYPE html>\n<html lang="${escapeHtml(lang)}">\n<head>\n');
  buf.write('<meta charset="${escapeHtml(charset)}">\n');
  buf.write('<meta name="viewport" content="width=device-width, initial-scale=1">\n');
  if (title != null) buf.write('<title>${escapeHtml(title)}</title>\n');
  if (importMapJson != null) buf.write('<script type="importmap">$importMapJson</script>\n');
  for (final url in stylesheets) buf.write('<link rel="stylesheet" href="${escapeHtml(url)}">\n');
  for (final node in head) { _render(node, buf); buf.write('\n'); }
  buf.write('</head>\n<body>\n');
  _render(body, buf);
  buf.write('\n');
  for (final url in scripts) buf.write('<script src="${escapeHtml(url)}"></script>\n');
  buf.write('</body>\n</html>');
  return buf.toString();
}
```

- [ ] **Step 4: Implement `renderToStream` in `html.dart`**:

```dart
Stream<String> renderToStream(BloomNode node) async* {
  final buf = StringBuffer();
  _render(node, buf);
  const chunkSize = 4096;
  final str = buf.toString();
  for (var i = 0; i < str.length; i += chunkSize) {
    yield str.substring(i, i + chunkSize > str.length ? str.length : i + chunkSize);
  }
}
```

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/html_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/html.dart packages/bloom_js_native/test/html_test.dart
git commit -m "feat(bloom_js_native): renderToDocument() full HTML shell + renderToStream() streaming SSR"
```

---

### Task 9: Router Completion — History API + Reactive Route Signal

**Files:**
- Modify: `packages/bloom_js_native/lib/src/router.dart`
- Create: `packages/bloom_js_native/lib/src/router_browser.dart`
- Modify: `packages/bloom_js_native/lib/browser.dart`
- Modify: `packages/bloom_js_native/test/router_test.dart`

**Interfaces:**
- Consumes: `BloomRouter`, `BloomRoute`, `signal` from signals
- Produces: `BloomRouter.notFound`, `BloomRouter.trailing`; `BloomRouterController` with `.currentPath` (Signal<String>), `.navigate(path)`, `.replace(path)`, `.resolve() → BloomNode`, `.dispose()`

- [ ] **Step 1: Write failing VM-side router tests**

```dart
test('notFound route matches unmatched path', () {
  final r = BloomRouter(
    [BloomRoute('/home', (_) => Text('home'))],
    notFound: BloomRoute('/404', (_) => Text('not found')),
  );
  final m = r.match('/missing');
  expect(m?.route.path, '/404');
});
test('trailing slash treated as same when trailing=true', () {
  final r = BloomRouter(
    [BloomRoute('/about', (_) => Text('about'))],
    trailing: true,
  );
  expect(r.match('/about/')!.route.path, '/about');
});
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/router_test.dart
```

- [ ] **Step 3: Update `BloomRouter` in `router.dart`**:

```dart
class BloomRouter {
  final List<BloomRoute> routes;
  final BloomRoute? notFound;
  final bool trailing;

  BloomRouter(this.routes, {this.notFound, this.trailing = false});

  ({BloomRoute route, Map<String, String> params})? match(String path) {
    var clean = path.split('?').first.split('#').first;
    if (trailing && clean.length > 1 && clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    for (final route in routes) {
      final params = _matchPattern(route.path, clean);
      if (params != null) return (route: route, params: params);
    }
    if (notFound != null) return (route: notFound!, params: {});
    return null;
  }
  // _matchPattern unchanged
}
```

- [ ] **Step 4: Create `lib/src/router_browser.dart`**:

```dart
import 'dart:js_interop';
import 'package:signals/signals.dart';
import 'package:web/web.dart' as web;
import 'framework.dart';
import 'router.dart';

/// Client-side router using the HTML5 History API.
///
/// Usage:
/// ```dart
/// final ctrl = BloomRouterController(BloomRouter([
///   BloomRoute('/', (_) => HomePage()),
///   BloomRoute('/about', (_) => AboutPage()),
/// ]));
///
/// // In app tree:
/// Live(() => ctrl.resolve())
///
/// // Navigate programmatically:
/// ctrl.navigate('/about');
/// ```
class BloomRouterController {
  final BloomRouter _router;
  late final Signal<String> currentPath;
  late final void Function(web.Event) _popStateListener;

  BloomRouterController(this._router) {
    currentPath = signal(web.window.location.pathname);
    _popStateListener = (web.Event _) {
      currentPath.value = web.window.location.pathname;
    };
    web.window.addEventListener('popstate', _popStateListener.toJS);
  }

  /// Navigate to [path] — pushes to browser history and updates [currentPath].
  void navigate(String path) {
    web.window.history.pushState(null.toJS, '', path.toJS);
    currentPath.value = path.split('?').first.split('#').first;
  }

  /// Replace current history entry without a new history item.
  void replace(String path) {
    web.window.history.replaceState(null.toJS, '', path.toJS);
    currentPath.value = path.split('?').first.split('#').first;
  }

  /// Resolve current path to a descriptor. Returns empty fragment on no match.
  BloomNode resolve() {
    final m = _router.match(currentPath.value);
    return m == null ? FragmentNode(const []) : m.route.builder(m.params);
  }

  /// Remove popstate listener. Call on app unmount.
  void dispose() {
    web.window.removeEventListener('popstate', _popStateListener.toJS);
  }
}
```

- [ ] **Step 5: Export from `browser.dart`** — add `export 'src/router_browser.dart';`

- [ ] **Step 6: Run tests**

```bash
cd packages/bloom_js_native && dart test test/router_test.dart
```

- [ ] **Step 7: Commit**

```bash
git add packages/bloom_js_native/lib/src/router.dart packages/bloom_js_native/lib/src/router_browser.dart packages/bloom_js_native/lib/browser.dart packages/bloom_js_native/test/router_test.dart
git commit -m "feat(bloom_js_native): complete client router — history API, reactive currentPath, notFound"
```

---

### Task 10: NPM Registry — SRI, Sub-Path Scopes, Conflict API

**Files:**
- Modify: `packages/bloom_js_native/lib/src/npm.dart`
- Modify: `packages/bloom_js_native/test/npm_test.dart`

**Interfaces:**
- Produces: `NpmDependency.integrity`, `.subPath`; `NpmRegistry.conflicts() → List<String>`; `generateImportMapJson` emits `"scopes"` block for sub-path deps

- [ ] **Step 1: Write failing tests**

```dart
test('integrity field round-trips through toJson', () {
  final dep = NpmDependency('zod', '^3.23.0', integrity: 'sha384-abc123');
  expect(dep.toJson()['integrity'], 'sha384-abc123');
});
test('subPath entry appears in scopes block', () {
  NpmRegistry.clear();
  NpmRegistry.register(NpmDependency('lucide', '^0.460.0'));
  NpmRegistry.register(NpmDependency('lucide', '^0.460.0', subPath: 'icons', importAs: 'lucide/icons'));
  final json = NpmRegistry.generateImportMapJson();
  expect(json, contains('"scopes"'));
  NpmRegistry.clear();
});
test('conflicts() returns empty list by default', () {
  NpmRegistry.clear();
  NpmRegistry.register(NpmDependency('zod', '^3.23.0'));
  expect(NpmRegistry.conflicts(), isEmpty);
  NpmRegistry.clear();
});
```

- [ ] **Step 2: Run to verify fails**

```bash
cd packages/bloom_js_native && dart test test/npm_test.dart
```

- [ ] **Step 3: Extend `NpmDependency` and `NpmRegistry` in `npm.dart`** — add `integrity` and `subPath` fields to `NpmDependency`; include them in `toJson()`. In `NpmRegistry.generateImportMapJson()`, separate sub-path deps into a `"scopes"` block keyed by the base CDN URL. Add `static List<String> conflicts() => const [];` stub (reserved for future version-history tracking).

- [ ] **Step 4: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/npm_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_js_native/lib/src/npm.dart packages/bloom_js_native/test/npm_test.dart
git commit -m "feat(bloom_js_native): NPM registry SRI integrity, sub-path scopes, conflicts() API"
```

---

### Task 11: Barrel Export Audit & Final Quality Gate

**Files:**
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart` (if needed)
- Modify: `packages/bloom_js_native/lib/browser.dart` (if needed)
- Verify: `packages/bloom_js_native/test/` — all 6 test files

**Interfaces:**
- Produces: all new public types reachable via `package:bloom_js_native/bloom_js_native.dart` and browser types via `package:bloom_js_native/browser.dart`

- [ ] **Step 1: Confirm `bloom_js_native.dart` exports all new VM-pure types**

All new types (`Ref`, `MountNode`, `Mount`, `RefNode`, `cx`, all new element classes, `renderToDocument`, `renderToStream`) live in files already exported by the barrel (`framework.dart` and `html.dart`). No changes needed to the barrel unless a new source file was created.

- [ ] **Step 2: Confirm `browser.dart` exports both `mount.dart` and `router_browser.dart`**

```dart
library;

export 'src/mount.dart';
export 'src/router_browser.dart';
```

- [ ] **Step 3: Run full test suite with expanded reporter**

```bash
cd packages/bloom_js_native && dart test --reporter expanded
```
Expected: all groups and tests print green, 0 failures.

- [ ] **Step 4: Run dart analyze**

```bash
dart analyze packages/bloom_js_native
```
Expected: `No issues found!`

- [ ] **Step 5: Verify example still compiles**

```bash
cd packages/bloom_js_native/example && dart compile js -O2 -o /tmp/m7_test.js main.dart 2>&1 | tail -5
```
Expected: compilation succeeds (no errors).

- [ ] **Step 6: Final commit**

```bash
cd /root/dev/Bloom
git add packages/bloom_js_native/
git commit -m "chore(bloom_js_native): M7 complete — all gap-fill tasks done, 0 analyzer warnings"
```
