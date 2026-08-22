// lib/src/virtual.dart
//
// Thin, exact interop wrapper around `@tanstack/virtual-core`'s vanilla
// (framework-agnostic) `Virtualizer` class — install the npm package via
// `bloom add npm:@tanstack/virtual-core`, then bootstrap it in index.html:
//
// ```html
// <script type="module">
//   import { Virtualizer, observeElementRect, observeElementOffset, elementScroll }
//     from "@tanstack/virtual-core";
//   window.__bloomVirtualCore = { Virtualizer, observeElementRect, observeElementOffset, elementScroll };
// </script>
// ```
//
// `@tanstack/virtual-core`'s vanilla usage contract (there is no framework
// adapter here, unlike `@tanstack/react-virtual`) is: construct the
// `Virtualizer`, call `instance._didMount()` once (keep its cleanup
// function), call `instance._willUpdate()` after mount and again after any
// `setOptions()` call, and read `getVirtualItems()` / `getTotalSize()`
// whenever `onChange` fires. [BloomVirtualizer] does exactly that and
// surfaces the result as Bloom `Signal`s so `Live()` regions re-render
// automatically — no manual DOM patching required by callers.
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'signals.dart' as sig;
import 'framework.dart' show Ref;

@JS('__bloomVirtualCore.Virtualizer')
extension type _JsVirtualizer._(JSObject _) implements JSObject {
  external _JsVirtualizer(JSObject options);
  external JSArray<JSObject> getVirtualItems();
  external num getTotalSize();
  external JSFunction _didMount();
  external void _willUpdate();
  external void setOptions(JSObject options);
  external void scrollToIndex(num index, JSObject? opts);
}

@JS('__bloomVirtualCore.observeElementRect')
external JSFunction get _observeElementRect;

@JS('__bloomVirtualCore.observeElementOffset')
external JSFunction get _observeElementOffset;

@JS('__bloomVirtualCore.elementScroll')
external JSFunction get _elementScroll;

extension type _JsVirtualItem._(JSObject _) implements JSObject {
  external num get index;
  external num get start;
  external num get size;
  external JSAny get key;
}

/// One windowed row/item: [index] into the full list, and the pixel [start]
/// offset / [size] to position it at within the scroll container.
class BloomVirtualItem {
  final int index;
  final double start;
  final double size;

  const BloomVirtualItem({required this.index, required this.start, required this.size});
}

/// Windows a long list down to only the items currently within (plus
/// [overscan] around) the visible scroll viewport, so the DOM node count
/// stays bounded regardless of how many total items there are.
///
/// Usage:
/// ```dart
/// final scrollRef = Ref<web.Element>();
/// final virtualizer = BloomVirtualizer(
///   scrollElementRef: scrollRef,
///   count: () => products.length,
///   estimateSize: (i) => 220,
/// );
///
/// RefNode(scrollRef, Mount(
///   Div(
///     className: 'overflow-y-auto',
///     style: 'height: 80vh',
///     children: [Live(() => renderWindow(virtualizer))],
///   ),
///   onMount: virtualizer.attach,
///   onUnmount: virtualizer.dispose,
/// ));
/// ```
class BloomVirtualizer {
  final Ref<web.Element> scrollElementRef;
  final int Function() count;
  final double Function(int index) estimateSize;
  final int overscan;
  final double gap;

  late final _JsVirtualizer _instance;
  JSFunction? _unmount;

  final sig.Signal<List<BloomVirtualItem>> items = sig.signal(const []);
  final sig.Signal<double> totalSize = sig.signal(0);

  BloomVirtualizer({
    required this.scrollElementRef,
    required this.count,
    required this.estimateSize,
    this.overscan = 5,
    this.gap = 0,
  }) {
    _instance = _JsVirtualizer(_buildOptions());
  }

  JSObject _buildOptions() {
    return {
      'count': count(),
      'overscan': overscan,
      'gap': gap,
      'getScrollElement': (() => scrollElementRef.value).toJS,
      'estimateSize': ((JSNumber index) => estimateSize(index.toDartInt).toJS).toJS,
      'observeElementRect': _observeElementRect,
      'observeElementOffset': _observeElementOffset,
      'scrollToFn': _elementScroll,
      'onChange': ((JSAny? _, JSAny? __) => _pull()).toJS,
    }.jsify()! as JSObject;
  }

  void _pull() {
    final raw = _instance.getVirtualItems().toDart;
    items.value = raw.map((jsItem) {
      final it = jsItem as _JsVirtualItem;
      return BloomVirtualItem(index: it.index.toInt(), start: it.start.toDouble(), size: it.size.toDouble());
    }).toList();
    totalSize.value = _instance.getTotalSize().toDouble();
  }

  /// Call from a `Mount`/`RefNode` `onMount` once [scrollElementRef] is
  /// attached to a real, already-in-document DOM element.
  void attach() {
    _unmount = _instance._didMount();
    _instance._willUpdate();
    _pull();
  }

  /// Call whenever [count] (or the underlying data it reads) changes, so
  /// the virtualizer re-measures against the new item count.
  void refresh() {
    _instance.setOptions(_buildOptions());
    _instance._willUpdate();
    _pull();
  }

  /// Call from `onUnmount` to detach scroll/resize observers.
  void dispose() {
    _unmount?.callAsFunction();
    _unmount = null;
  }
}
