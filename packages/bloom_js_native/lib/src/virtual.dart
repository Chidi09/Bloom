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

/// Represents a single visible row or item calculated by [BloomVirtualizer].
///
/// Contains the item's original [index] in the backing dataset, along with its
/// pixel layout positioning within the scroll container: [start] offset and [size].
///
/// ```dart
/// Div(
///   style: 'position: absolute; top: 0; left: 0; width: 100%; '
///          'height: ${item.size}px; transform: translateY(${item.start}px);',
///   text: 'Item #${item.index}',
/// )
/// ```
class BloomVirtualItem {
  /// The zero-based index of this item within the full collection.
  final int index;

  /// The top pixel offset of this item relative to the scroll container's inner content.
  final double start;

  /// The rendered height or dimension of this item in pixels.
  final double size;

  /// Creates a [BloomVirtualItem] with the given [index], [start] offset, and [size].
  const BloomVirtualItem({required this.index, required this.start, required this.size});
}

/// Reactive list virtualization engine wrapping vendored `@tanstack/virtual-core`.
///
/// Restricts DOM rendering to only the items currently inside the visible viewport
/// (plus an [overscan] margin), maintaining constant DOM memory and layout performance
/// regardless of list size.
///
/// ### Required Lifecycle & Call Order
/// 1. **Construct**: Instantiate [BloomVirtualizer] with a [scrollElementRef], [count],
///    and [estimateSize].
/// 2. **Attach on Mount**: In a [Mount] or [RefNode] `onMount` callback, call [attach].
///    The container DOM element must already be mounted in the document.
/// 3. **Refresh on Change**: Call [refresh] whenever the collection changes or [count] updates.
///    *Note*: Calling [refresh] before the element is attached will throw.
/// 4. **Dispose on Unmount**: Call [dispose] in `onUnmount` to release scroll and resize observers.
///
/// ### Example
/// ```dart
/// final scrollRef = Ref<web.Element>();
/// final virtualizer = BloomVirtualizer(
///   scrollElementRef: scrollRef,
///   count: () => products.length,
///   estimateSize: (index) => 64.0,
///   overscan: 5,
/// );
///
/// RefNode(
///   scrollRef,
///   Mount(
///     Div(
///       style: 'height: 400px; overflow-y: auto; position: relative;',
///       children: [
///         Live(() => Div(
///           style: 'height: ${virtualizer.totalSize.value}px; position: relative; width: 100%;',
///           children: virtualizer.items.value.map((item) {
///             final product = products[item.index];
///             return Div(
///               style: 'position: absolute; top: 0; left: 0; width: 100%; '
///                      'height: ${item.size}px; transform: translateY(${item.start}px);',
///               text: product.name,
///             );
///           }).toList(),
///         )),
///       ],
///     ),
///     onMount: virtualizer.attach,
///     onUnmount: virtualizer.dispose,
///   ),
/// );
/// ```
class BloomVirtualizer {
  /// Reference to the scrollable container DOM element (`overflow-y: auto`).
  final Ref<web.Element> scrollElementRef;

  /// Callback returning the total number of items in the full dataset.
  final int Function() count;

  /// Callback estimating the height in pixels of an item at [index].
  final double Function(int index) estimateSize;

  /// Number of extra items rendered above and below the visible viewport. Defaults to 5.
  final int overscan;

  /// Fixed gap in pixels between consecutive items. Defaults to 0.
  final double gap;

  late final _JsVirtualizer _instance;
  JSFunction? _unmount;

  /// Reactive signal containing the list of [BloomVirtualItem]s currently in the visible window.
  final sig.Signal<List<BloomVirtualItem>> items = sig.signal(const []);

  /// Reactive signal containing the total estimated scrollable height in pixels.
  final sig.Signal<double> totalSize = sig.signal(0);

  /// Creates a [BloomVirtualizer] configured with the specified scrolling container and sizing options.
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

  /// Connects scroll and resize observers to [scrollElementRef] and performs the initial measurement pass.
  ///
  /// Must be invoked from an `onMount` callback after [scrollElementRef] is attached to a real DOM element.
  void attach() {
    _unmount = _instance._didMount();
    _instance._willUpdate();
    _pull();
  }

  /// Recomputes virtual window layout after [count] or dataset dimensions change.
  ///
  /// Must only be called after [attach] has run on a mounted DOM element.
  void refresh() {
    _instance.setOptions(_buildOptions());
    _instance._willUpdate();
    _pull();
  }

  /// Disconnects scroll and resize observers and releases internal JS resources.
  ///
  /// Call from an `onUnmount` callback when the scroll container is detached.
  void dispose() {
    _unmount?.callAsFunction();
    _unmount = null;
  }
}

