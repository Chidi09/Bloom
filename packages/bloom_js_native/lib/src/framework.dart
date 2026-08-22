import 'dart:async';
import 'events.dart';
import 'animate.dart';

/// Token representing an ambient context value of type [T].
class BloomContext<T> {
  final T defaultValue;
  final Object zoneKey = Object();

  BloomContext(this.defaultValue);

  /// Provides [value] to all children in the subtree.
  BloomNode provide(T value, BloomNode child) =>
      ContextProviderNode<T>(this, value, child);
}

/// Creates a typed ambient [BloomContext] with [defaultValue].
BloomContext<T> createContext<T>(T defaultValue) => BloomContext<T>(defaultValue);

/// Reads the current ambient value for [context].
T useContext<T>(BloomContext<T> context) {
  final value = Zone.current[context.zoneKey];
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

/// The core descriptor tree — pure Dart, zero DOM dependency.
///
/// Every Bloom component compiles to a [BloomNode] tree first. Two backends
/// consume it:
/// - `BrowserMount` (package:web) for real DOM + signal effects
/// - `renderToHtml()` for SSR / SSG / SEO
sealed class BloomNode {
  const BloomNode();
}

// ── Concrete node types ───────────────────────────────────────────────

/// Plain text leaf.
class TextNode extends BloomNode {
  final String text;
  const TextNode(this.text);
}

/// HTML element descriptor.
class ElNode extends BloomNode {
  /// Lowercase tag name, e.g. "div", "button", "custom-tag".
  final String tag;

  /// Optional single text child sugar — equivalent to `children: [Text(text)]`
  /// when no explicit children are given.
  final String? text;

  /// CSS class attribute.
  final String? className;

  /// Inline style — raw CSS string (e.g. "color: red; display:flex").
  final String? style;

  /// Arbitrary HTML attributes (id, href, placeholder, etc.).
  final Map<String, String>? attrs;

  /// Event handlers keyed by DOM event name (click, input, change...).
  final Map<String, BloomEventHandler>? on;

  /// Child descriptors.
  final List<BloomNode> children;

  const ElNode(
    this.tag, {
    this.text,
    this.className,
    this.style,
    this.attrs,
    this.on,
    this.children = const [],
  });
}

/// Fragment — groups children without introducing a wrapper element.
class FragmentNode extends BloomNode {
  final List<BloomNode> children;
  const FragmentNode([this.children = const []]);
}

/// Reactive boundary — re-evaluates [builder] inside a signal effect
/// and patches only its own DOM region.
class LiveNode extends BloomNode {
  final BloomNode Function() builder;
  const LiveNode(this.builder);
}

/// Memoization boundary — only re-evaluates [builder] when [dependency] produces
/// a value that differs (`!=`) from its previous value.
class MemoNode<T> extends BloomNode {
  final T Function() dependency;
  final BloomNode Function(T value) builder;
  const MemoNode(this.dependency, this.builder);

  /// [dependency], viewed untyped.
  ///
  /// Same contravariance constraint as [ForEachNode.keyFnErased]: a
  /// `case MemoNode():` match binds `T` as `dynamic`, so [builder] must be
  /// cast inside the class rather than at the match site.
  Object? Function() get dependencyErased => dependency;

  /// [builder], accepting an untyped dependency value.
  BloomNode Function(Object? value) get builderErased =>
      (value) => builder(value as T);
}

/// Conditional rendering primitive.
class ShowNode extends BloomNode {
  /// Reactive predicate — called inside an effect (browser) or once (SSR).
  final bool Function() when;
  final BloomNode child;
  final BloomNode? fallback;

  const ShowNode(this.when, {required this.child, this.fallback});
}

/// List rendering primitive. Re-reads [items] reactively; each item is
/// mapped through [builder] to a descriptor.
class ForEachNode<T> extends BloomNode {
  final List<T> Function() items;
  final BloomNode Function(T item) builder;
  final String Function(T item)? keyFn;

  const ForEachNode(this.items, this.builder, {this.keyFn});

  List<BloomNode> buildChildren() =>
      items().map((item) => builder(item)).toList();

  // ── Type-erased views ───────────────────────────────────────────────
  //
  // A `case ForEachNode():` pattern match against a [BloomNode] binds the type
  // argument as `dynamic`, so reading [keyFn] or [builder] at that site casts
  // them to `Function(dynamic)` — which fails at runtime, because function
  // parameters are CONTRAVARIANT: a `String Function(Product)` is not a
  // subtype of `String Function(dynamic)`. The backends therefore cannot touch
  // the raw fields through an erased reference.
  //
  // These getters do the cast inside the class, where `T` is still known, and
  // hand back closures that are safe to call from a type-erased context.

  /// [items], viewed as an untyped list.
  List<Object?> Function() get itemsErased => items;

  /// [keyFn], accepting an untyped item. `null` when the list is unkeyed.
  String Function(Object? item)? get keyFnErased {
    final fn = keyFn;
    if (fn == null) return null;
    return (item) => fn(item as T);
  }

  /// [builder], accepting an untyped item.
  BloomNode Function(Object? item) get builderErased =>
      (item) => builder(item as T);
}

/// Style element helper — emits `<style>css</style>`.
class StyleNode extends BloomNode {
  final String css;
  const StyleNode(this.css);
}

/// Trusted raw HTML passthrough — rendered verbatim by both backends.
///
/// **Never** pass user-supplied input here; this bypasses [escapeHtml].
/// Intended for trusted templates, JSON-LD payloads, and embed snippets.
class RawHtmlNode extends BloomNode {
  final String html;
  const RawHtmlNode(this.html);
}

/// AST node that wraps [child] with a CSS animation described by [animation].
/// On SSR (`html.dart`) it emits a `<style>@keyframes …</style>` block
/// (deduplicated by animation name per render pass) and a wrapper `<div>`
/// carrying the `animation:` inline style. On the browser (`mount.dart`) it
/// injects the `@keyframes` rule into `document.head` once per animation name
/// and creates a wrapper `<div>` with the same inline style.
class AnimatedNode extends BloomNode {
  final BloomNode child;
  final BloomAnimation animation;
  const AnimatedNode({required this.child, required this.animation});
}

// ── Sugar / DSL Constructors ──────────────────────────────────────────

/// Plain text node.
class Text extends TextNode {
  const Text(super.text);
}

/// Fragment grouping.
class Fragment extends FragmentNode {
  const Fragment({required List<BloomNode> children}) : super(children);
  const Fragment.fromList(super.children);
}

/// Reactive text / subtree — the JSX `{expr}` equivalent.
///
/// ```dart
/// Live(() => P(text: 'Count: ${count.value}'))
/// ```
class Live extends LiveNode {
  const Live(super.builder);
}

/// Memoization sugar.
///
/// ```dart
/// Memo(() => user.value.id, (id) => UserCard(id))
/// ```
class Memo<T> extends MemoNode<T> {
  const Memo(super.dependency, super.builder);
}

/// Conditional rendering.
///
/// ```dart
/// Show(() => count.value > 9, child: P(text: 'big'), fallback: P(text:'small'))
/// ```
class Show extends ShowNode {
  const Show(
    super.when, {
    required super.child,
    super.fallback,
  });
}

/// Reactive list rendering.
///
/// ```dart
/// ForEach(() => todos.value, (t) => Li(children: [Text(t.title)]))
/// ```
class ForEach<T> extends ForEachNode<T> {
  const ForEach(
    super.items,
    super.builder, {
    String Function(T item)? key,
  }) : super(keyFn: key);
}

/// Inline stylesheet.
class Style extends StyleNode {
  const Style(super.css);
}

/// Trusted raw HTML passthrough.
class Raw extends RawHtmlNode {
  const Raw(super.html);
}

// ── Lifecycle & Refs ──────────────────────────────────────────────────

/// DOM reference holder. Filled by the browser mount engine.
/// Value is null until the node is mounted.
class Ref<T extends Object> {
  T? _value;

  /// The mounted DOM element. Throws [StateError] if not yet mounted.
  T get value => _value ?? (throw StateError('Ref<$T> not yet mounted'));

  /// Whether this ref has been attached to a DOM element.
  bool get isMounted => _value != null;

  /// Internal — only called by the mount engine.
  // ignore: use_setters_to_change_properties
  void attach(T element) => _value = element;

  /// Internal — called when the mounted subtree is disposed.
  void detach() => _value = null;
}

/// Lifecycle boundary — calls [onMount] after children are added to the DOM
/// and [onUnmount] when the tree is disposed.
///
/// In SSR, only [child] is rendered. Lifecycle callbacks are not invoked.
///
/// ```dart
/// Mount(
///   Canvas(id: 'chart'),
///   onMount: () => initChart(canvasRef.value),
///   onUnmount: () => chart.destroy(),
/// )
/// ```
class MountNode extends BloomNode {
  final BloomNode child;
  final void Function()? onMount;
  final void Function()? onUnmount;
  const MountNode(this.child, {this.onMount, this.onUnmount});
}

/// DSL sugar for [MountNode].
class Mount extends MountNode {
  const Mount(super.child, {super.onMount, super.onUnmount});
}

/// Attaches a [Ref] to the DOM [Element] created by the first child element.
///
/// In SSR, [child] is rendered normally; [ref] remains unmounted.
class RefNode extends BloomNode {
  /// The ref to populate.
  final Ref<Object> ref;
  final BloomNode child;
  const RefNode(this.ref, this.child);
}

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

/// DSL sugar for [ErrorBoundaryNode].
class ErrorBoundary extends ErrorBoundaryNode {
  const ErrorBoundary({
    required super.builder,
    required super.fallback,
  });
}

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

/// DSL sugar for [PortalNode].
class Portal extends PortalNode {
  const Portal({
    required super.child,
    super.targetSelector = 'body',
  });
}

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

  /// [resource], viewed untyped.
  ///
  /// Same contravariance constraint as [ForEachNode.keyFnErased]: a
  /// `case SuspenseNode():` match binds `T` as `dynamic`, so reading
  /// [builder] there casts it to `BloomNode Function(dynamic)` and throws.
  Future<Object?> Function() get resourceErased => resource;

  /// [builder], accepting untyped resolved data.
  BloomNode Function(Object? data) get builderErased =>
      (data) => builder(data as T);
}

/// DSL sugar for [SuspenseNode].
class Suspense<T> extends SuspenseNode<T> {
  const Suspense({
    required super.resource,
    required super.builder,
    required super.fallback,
  });
}

// ── Helpers for Attr / Event Merging ──────────────────────────────────

Map<String, String>? _mergeAttrs(
    Map<String, String>? base, Map<String, String> additions) {
  if (base == null && additions.isEmpty) return null;
  if (base == null) return additions.isEmpty ? null : additions;
  if (additions.isEmpty) return base;
  return {...additions, ...base};
}

Map<String, BloomEventHandler>? _mergeEvents(
  Map<String, BloomEventHandler>? base, {
  BloomEventHandler? onClick,
  BloomEventHandler? onDblClick,
  BloomEventHandler? onInput,
  BloomEventHandler? onChange,
  BloomEventHandler? onSubmit,
  BloomEventHandler? onKeyDown,
  BloomEventHandler? onKeyUp,
  BloomEventHandler? onKeyPress,
  BloomEventHandler? onFocus,
  BloomEventHandler? onBlur,
  BloomEventHandler? onMouseEnter,
  BloomEventHandler? onMouseLeave,
  BloomEventHandler? onMouseDown,
  BloomEventHandler? onMouseUp,
  BloomEventHandler? onMouseMove,
  BloomEventHandler? onScroll,
  BloomEventHandler? onWheel,
  BloomEventHandler? onContextMenu,
  BloomEventHandler? onPointerDown,
  BloomEventHandler? onPointerUp,
  BloomEventHandler? onDrop,
  BloomEventHandler? onDragOver,
  BloomEventHandler? onDragStart,
  BloomEventHandler? onTouchStart,
  BloomEventHandler? onTouchEnd,
}) {
  final extras = <String, BloomEventHandler>{
    if (onClick != null) 'click': onClick,
    if (onDblClick != null) 'dblclick': onDblClick,
    if (onInput != null) 'input': onInput,
    if (onChange != null) 'change': onChange,
    if (onSubmit != null) 'submit': onSubmit,
    if (onKeyDown != null) 'keydown': onKeyDown,
    if (onKeyUp != null) 'keyup': onKeyUp,
    if (onKeyPress != null) 'keypress': onKeyPress,
    if (onFocus != null) 'focus': onFocus,
    if (onBlur != null) 'blur': onBlur,
    if (onMouseEnter != null) 'mouseenter': onMouseEnter,
    if (onMouseLeave != null) 'mouseleave': onMouseLeave,
    if (onMouseDown != null) 'mousedown': onMouseDown,
    if (onMouseUp != null) 'mouseup': onMouseUp,
    if (onMouseMove != null) 'mousemove': onMouseMove,
    if (onScroll != null) 'scroll': onScroll,
    if (onWheel != null) 'wheel': onWheel,
    if (onContextMenu != null) 'contextmenu': onContextMenu,
    if (onPointerDown != null) 'pointerdown': onPointerDown,
    if (onPointerUp != null) 'pointerup': onPointerUp,
    if (onDrop != null) 'drop': onDrop,
    if (onDragOver != null) 'dragover': onDragOver,
    if (onDragStart != null) 'dragstart': onDragStart,
    if (onTouchStart != null) 'touchstart': onTouchStart,
    if (onTouchEnd != null) 'touchend': onTouchEnd,
  };
  if (base == null && extras.isEmpty) return null;
  if (base == null) return extras;
  if (extras.isEmpty) return base;
  return {...base, ...extras};
}

/// Conditional className builder — clsx-style.
///
/// Filters `null`, `false`, and blank strings. Joins remaining values
/// with a single space and trims each part.
///
/// ```dart
/// cx(['btn', isActive && 'btn-active', null])  // => 'btn btn-active'
/// ```
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

// ── Generic Element ───────────────────────────────────────────────────

class El extends ElNode {
  El(
    super.tag, {
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
    BloomEventHandler? onDblClick,
    BloomEventHandler? onInput,
    BloomEventHandler? onChange,
    BloomEventHandler? onSubmit,
    BloomEventHandler? onKeyDown,
    BloomEventHandler? onKeyUp,
    BloomEventHandler? onKeyPress,
    BloomEventHandler? onFocus,
    BloomEventHandler? onBlur,
    BloomEventHandler? onMouseEnter,
    BloomEventHandler? onMouseLeave,
    BloomEventHandler? onMouseDown,
    BloomEventHandler? onMouseUp,
    BloomEventHandler? onMouseMove,
    BloomEventHandler? onScroll,
    BloomEventHandler? onWheel,
    BloomEventHandler? onContextMenu,
    BloomEventHandler? onPointerDown,
    BloomEventHandler? onPointerUp,
    BloomEventHandler? onDrop,
    BloomEventHandler? onDragOver,
    BloomEventHandler? onDragStart,
    BloomEventHandler? onTouchStart,
    BloomEventHandler? onTouchEnd,
  }) : super(
          on: _mergeEvents(on,
              onClick: onClick,
              onDblClick: onDblClick,
              onInput: onInput,
              onChange: onChange,
              onSubmit: onSubmit,
              onKeyDown: onKeyDown,
              onKeyUp: onKeyUp,
              onKeyPress: onKeyPress,
              onFocus: onFocus,
              onBlur: onBlur,
              onMouseEnter: onMouseEnter,
              onMouseLeave: onMouseLeave,
              onMouseDown: onMouseDown,
              onMouseUp: onMouseUp,
              onMouseMove: onMouseMove,
              onScroll: onScroll,
              onWheel: onWheel,
              onContextMenu: onContextMenu,
              onPointerDown: onPointerDown,
              onPointerUp: onPointerUp,
              onDrop: onDrop,
              onDragOver: onDragOver,
              onDragStart: onDragStart,
              onTouchStart: onTouchStart,
              onTouchEnd: onTouchEnd),
        );

  const El.raw(
    super.tag, {
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  });
}

// ── HTML Element Subclasses ───────────────────────────────────────────

class Div extends ElNode {
  Div({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
    BloomEventHandler? onDblClick,
    BloomEventHandler? onInput,
    BloomEventHandler? onChange,
    BloomEventHandler? onSubmit,
    BloomEventHandler? onKeyDown,
    BloomEventHandler? onKeyUp,
    BloomEventHandler? onFocus,
    BloomEventHandler? onBlur,
    BloomEventHandler? onMouseEnter,
    BloomEventHandler? onMouseLeave,
    BloomEventHandler? onMouseDown,
    BloomEventHandler? onMouseUp,
    BloomEventHandler? onMouseMove,
    BloomEventHandler? onScroll,
    BloomEventHandler? onContextMenu,
    BloomEventHandler? onDrop,
    BloomEventHandler? onDragOver,
  }) : super(
          'div',
          on: _mergeEvents(on,
              onClick: onClick,
              onDblClick: onDblClick,
              onInput: onInput,
              onChange: onChange,
              onSubmit: onSubmit,
              onKeyDown: onKeyDown,
              onKeyUp: onKeyUp,
              onFocus: onFocus,
              onBlur: onBlur,
              onMouseEnter: onMouseEnter,
              onMouseLeave: onMouseLeave,
              onMouseDown: onMouseDown,
              onMouseUp: onMouseUp,
              onMouseMove: onMouseMove,
              onScroll: onScroll,
              onContextMenu: onContextMenu,
              onDrop: onDrop,
              onDragOver: onDragOver),
        );

  const Div.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('div');
}

class Span extends ElNode {
  Span({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
    BloomEventHandler? onDblClick,
    BloomEventHandler? onMouseEnter,
    BloomEventHandler? onMouseLeave,
  }) : super(
          'span',
          on: _mergeEvents(on,
              onClick: onClick,
              onDblClick: onDblClick,
              onMouseEnter: onMouseEnter,
              onMouseLeave: onMouseLeave),
        );

  const Span.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('span');
}

class P extends ElNode {
  P({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
  }) : super(
          'p',
          on: _mergeEvents(on, onClick: onClick),
        );

  const P.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('p');
}

class H1 extends ElNode {
  H1({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
  }) : super(
          'h1',
          on: _mergeEvents(on, onClick: onClick),
        );

  const H1.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h1');
}

class H2 extends ElNode {
  H2({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
  }) : super(
          'h2',
          on: _mergeEvents(on, onClick: onClick),
        );

  const H2.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h2');
}

class H3 extends ElNode {
  H3({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
  }) : super(
          'h3',
          on: _mergeEvents(on, onClick: onClick),
        );

  const H3.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h3');
}

class H4 extends ElNode {
  H4({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
  }) : super(
          'h4',
          on: _mergeEvents(on, onClick: onClick),
        );

  const H4.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h4');
}

class H5 extends ElNode {
  H5({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
  }) : super(
          'h5',
          on: _mergeEvents(on, onClick: onClick),
        );

  const H5.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h5');
}

class H6 extends ElNode {
  H6({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
  }) : super(
          'h6',
          on: _mergeEvents(on, onClick: onClick),
        );

  const H6.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h6');
}

class Button extends ElNode {
  Button({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
    BloomEventHandler? onDblClick,
    BloomEventHandler? onFocus,
    BloomEventHandler? onBlur,
    BloomEventHandler? onMouseEnter,
    BloomEventHandler? onMouseLeave,
    BloomEventHandler? onMouseDown,
    BloomEventHandler? onMouseUp,
    BloomEventHandler? onKeyDown,
    BloomEventHandler? onKeyUp,
  }) : super(
          'button',
          on: _mergeEvents(on,
              onClick: onClick,
              onDblClick: onDblClick,
              onFocus: onFocus,
              onBlur: onBlur,
              onMouseEnter: onMouseEnter,
              onMouseLeave: onMouseLeave,
              onMouseDown: onMouseDown,
              onMouseUp: onMouseUp,
              onKeyDown: onKeyDown,
              onKeyUp: onKeyUp),
        );

  const Button.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('button');
}

class Input extends ElNode {
  Input({
    super.className,
    super.style,
    Map<String, String>? attrs,
    String? placeholder,
    String? value,
    String? type,
    bool? checked,
    bool? disabled,
    String? name,
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onInput,
    BloomEventHandler? onChange,
    BloomEventHandler? onClick,
    BloomEventHandler? onKeyDown,
    BloomEventHandler? onKeyUp,
    BloomEventHandler? onKeyPress,
    BloomEventHandler? onFocus,
    BloomEventHandler? onBlur,
  }) : super(
          'input',
          attrs: _mergeAttrs(attrs, {
            if (placeholder != null) 'placeholder': placeholder,
            if (value != null) 'value': value,
            if (type != null) 'type': type,
            if (checked == true) 'checked': 'checked',
            if (disabled == true) 'disabled': 'disabled',
            if (name != null) 'name': name,
          }),
          on: _mergeEvents(on,
              onInput: onInput,
              onChange: onChange,
              onClick: onClick,
              onKeyDown: onKeyDown,
              onKeyUp: onKeyUp,
              onKeyPress: onKeyPress,
              onFocus: onFocus,
              onBlur: onBlur),
        );

  const Input.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
  }) : super('input');
}

class Textarea extends ElNode {
  Textarea({
    super.className,
    super.style,
    Map<String, String>? attrs,
    String? placeholder,
    String? value,
    String? name,
    int? rows,
    int? cols,
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onInput,
    BloomEventHandler? onChange,
    BloomEventHandler? onFocus,
    BloomEventHandler? onBlur,
    BloomEventHandler? onKeyDown,
    BloomEventHandler? onKeyUp,
  }) : super(
          'textarea',
          attrs: _mergeAttrs(attrs, {
            if (placeholder != null) 'placeholder': placeholder,
            if (value != null) 'value': value,
            if (name != null) 'name': name,
            if (rows != null) 'rows': '$rows',
            if (cols != null) 'cols': '$cols',
          }),
          on: _mergeEvents(on,
              onInput: onInput,
              onChange: onChange,
              onFocus: onFocus,
              onBlur: onBlur,
              onKeyDown: onKeyDown,
              onKeyUp: onKeyUp),
        );

  const Textarea.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
  }) : super('textarea');
}

class A extends ElNode {
  A({
    super.text,
    super.className,
    super.style,
    Map<String, String>? attrs,
    String? href,
    String? target,
    String? rel,
    super.children = const [],
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onClick,
    BloomEventHandler? onMouseEnter,
    BloomEventHandler? onMouseLeave,
    BloomEventHandler? onFocus,
    BloomEventHandler? onBlur,
  }) : super(
          'a',
          attrs: _mergeAttrs(attrs, {
            if (href != null) 'href': href,
            if (target != null) 'target': target,
            if (rel != null) 'rel': rel,
          }),
          on: _mergeEvents(on,
              onClick: onClick,
              onMouseEnter: onMouseEnter,
              onMouseLeave: onMouseLeave,
              onFocus: onFocus,
              onBlur: onBlur),
        );

  const A.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('a');
}

class Img extends ElNode {
  Img({
    required String src,
    String? alt,
    int? width,
    int? height,
    super.className,
    super.style,
    Map<String, String>? attrs,
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onClick,
  }) : super(
          'img',
          attrs: _mergeAttrs(attrs, {
            'src': src,
            if (alt != null) 'alt': alt,
            if (width != null) 'width': '$width',
            if (height != null) 'height': '$height',
          }),
          on: _mergeEvents(on, onClick: onClick),
        );

  const Img.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
  }) : super('img');
}

class Ul extends ElNode {
  Ul({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('ul');

  const Ul.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('ul');
}

class Ol extends ElNode {
  Ol({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('ol');

  const Ol.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('ol');
}

class Li extends ElNode {
  Li({
    super.text,
    super.className,
    super.style,
    super.attrs,
    Map<String, BloomEventHandler>? on,
    super.children = const [],
    BloomEventHandler? onClick,
  }) : super(
          'li',
          on: _mergeEvents(on, onClick: onClick),
        );

  const Li.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('li');
}

class Form extends ElNode {
  Form({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onSubmit,
  }) : super(
          'form',
          on: _mergeEvents(on, onSubmit: onSubmit),
        );

  const Form.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('form');
}

class Label extends ElNode {
  Label({
    super.text,
    super.className,
    super.style,
    Map<String, String>? attrs,
    String? htmlFor,
    super.children = const [],
    super.on,
  }) : super(
          'label',
          attrs: _mergeAttrs(attrs, {
            if (htmlFor != null) 'for': htmlFor,
          }),
        );

  const Label.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('label');
}

class Header extends ElNode {
  Header({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('header');

  const Header.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('header');
}

class Footer extends ElNode {
  Footer({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('footer');

  const Footer.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('footer');
}

class Main extends ElNode {
  Main({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('main');

  const Main.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('main');
}

class Nav extends ElNode {
  Nav({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('nav');

  const Nav.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('nav');
}

class Section extends ElNode {
  Section({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('section');

  const Section.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('section');
}

class Article extends ElNode {
  Article({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('article');

  const Article.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('article');
}

class Aside extends ElNode {
  Aside({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('aside');

  const Aside.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('aside');
}

class Strong extends ElNode {
  Strong({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('strong');

  const Strong.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('strong');
}

class Em extends ElNode {
  Em({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('em');

  const Em.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('em');
}

class Code extends ElNode {
  Code({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('code');

  const Code.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('code');
}

class Pre extends ElNode {
  Pre({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('pre');

  const Pre.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('pre');
}

/// `<br>` — line break (void element).
class Br extends ElNode {
  const Br({super.className, super.attrs}) : super('br');
}

/// `<hr>` — horizontal rule (void element).
class Hr extends ElNode {
  const Hr({super.className, super.style, super.attrs}) : super('hr');
}

/// `<blockquote>` — block quotation.
class Blockquote extends ElNode {
  Blockquote({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('blockquote');
  const Blockquote.raw({super.text, super.className, super.style, super.attrs, super.on, super.children = const []}) : super('blockquote');
}

/// `<cite>` — citation.
class Cite extends ElNode {
  const Cite({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('cite');
}

/// `<time>` — machine-readable date/time.
class TimeEl extends ElNode {
  TimeEl({super.text, String? dateTime, super.className, super.style, Map<String, String>? attrs, super.children = const [], super.on})
      : super('time', attrs: _mergeAttrs(attrs, {if (dateTime != null) 'datetime': dateTime}));
  const TimeEl.raw({super.text, super.className, super.style, super.attrs, super.on, super.children = const []}) : super('time');
}

/// `<mark>` — highlighted text.
class Mark extends ElNode {
  const Mark({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('mark');
}

/// `<small>` — small print.
class Small extends ElNode {
  const Small({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('small');
}

/// `<sub>` — subscript.
class Sub extends ElNode {
  const Sub({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('sub');
}

/// `<sup>` — superscript.
class Sup extends ElNode {
  const Sup({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('sup');
}

/// `<abbr>` — abbreviation.
class Abbr extends ElNode {
  Abbr({super.text, String? title, super.className, super.style, Map<String, String>? attrs, super.children = const [], super.on})
      : super('abbr', attrs: _mergeAttrs(attrs, {if (title != null) 'title': title}));
  const Abbr.raw({super.text, super.className, super.style, super.attrs, super.on, super.children = const []}) : super('abbr');
}

/// `<kbd>` — keyboard input.
class KbdEl extends ElNode {
  const KbdEl({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('kbd');
}

/// `<figure>` — figure with optional caption.
class Figure extends ElNode {
  Figure({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('figure');
  const Figure.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('figure');
}

/// `<figcaption>` — caption for a figure.
class Figcaption extends ElNode {
  const Figcaption({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('figcaption');
}

/// `<details>` — disclosure widget.
class Details extends ElNode {
  Details({super.className, super.style, Map<String, String>? attrs, super.children = const [], super.on, bool? open})
      : super('details', attrs: _mergeAttrs(attrs, {if (open == true) 'open': 'open'}));
  const Details.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('details');
}

/// `<summary>` — visible heading of a `<details>`.
class Summary extends ElNode {
  const Summary({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('summary');
}

/// `<dialog>` — modal/non-modal dialog.
class Dialog extends ElNode {
  Dialog({super.className, super.style, Map<String, String>? attrs, super.children = const [], super.on, bool? open})
      : super('dialog', attrs: _mergeAttrs(attrs, {if (open == true) 'open': 'open'}));
  const Dialog.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('dialog');
}

/// `<canvas>` — 2D/WebGL canvas.
class Canvas extends ElNode {
  Canvas({int? width, int? height, super.className, super.style, Map<String, String>? attrs, super.on})
      : super('canvas', attrs: _mergeAttrs(attrs, {if (width != null) 'width': '$width', if (height != null) 'height': '$height'}));
  const Canvas.raw({super.className, super.style, super.attrs, super.on}) : super('canvas');
}

/// `<iframe>` — inline frame.
class IFrame extends ElNode {
  IFrame({String? src, String? title, int? width, int? height, super.className, super.style, Map<String, String>? attrs, super.on})
      : super('iframe', attrs: _mergeAttrs(attrs, {
          if (src != null) 'src': src,
          if (title != null) 'title': title,
          if (width != null) 'width': '$width',
          if (height != null) 'height': '$height',
        }));
  const IFrame.raw({super.className, super.style, super.attrs, super.on}) : super('iframe');
}

// ── Table Elements ────────────────────────────────────────────────────

/// `<table>` — tabular data element.
class Table extends ElNode {
  Table({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('table');
  const Table.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('table');
}

/// `<caption>` — title or explanation for a table.
class Caption extends ElNode {
  const Caption({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('caption');
}

/// `<thead>` — set of rows defining table column headers.
class Thead extends ElNode {
  Thead({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('thead');
  const Thead.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('thead');
}

/// `<tbody>` — encapsulated set of table rows containing data.
class Tbody extends ElNode {
  Tbody({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('tbody');
  const Tbody.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('tbody');
}

/// `<tfoot>` — set of rows summarizing table columns.
class Tfoot extends ElNode {
  Tfoot({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('tfoot');
  const Tfoot.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('tfoot');
}

/// `<tr>` — row of cells in a table.
class Tr extends ElNode {
  Tr({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('tr');
  const Tr.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('tr');
}

/// `<th>` — header cell in a table.
class Th extends ElNode {
  Th({
    super.text,
    String? scope,
    int? colSpan,
    int? rowSpan,
    super.className,
    super.style,
    Map<String, String>? attrs,
    super.children = const [],
    super.on,
  }) : super(
          'th',
          attrs: _mergeAttrs(attrs, {
            if (scope != null) 'scope': scope,
            if (colSpan != null) 'colspan': '$colSpan',
            if (rowSpan != null) 'rowspan': '$rowSpan',
          }),
        );

  const Th.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('th');
}

/// `<td>` — standard data cell in a table.
class Td extends ElNode {
  Td({
    super.text,
    int? colSpan,
    int? rowSpan,
    super.className,
    super.style,
    Map<String, String>? attrs,
    super.children = const [],
    super.on,
  }) : super(
          'td',
          attrs: _mergeAttrs(attrs, {
            if (colSpan != null) 'colspan': '$colSpan',
            if (rowSpan != null) 'rowspan': '$rowSpan',
          }),
        );

  const Td.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('td');
}

// ── Form Select ───────────────────────────────────────────────────────

/// `<select>` — control that provides a menu of options.
class Select extends ElNode {
  Select({
    String? name,
    bool? multiple,
    bool? disabled,
    super.className,
    super.style,
    Map<String, String>? attrs,
    super.children = const [],
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onChange,
    BloomEventHandler? onFocus,
    BloomEventHandler? onBlur,
  }) : super(
          'select',
          attrs: _mergeAttrs(attrs, {
            if (name != null) 'name': name,
            if (multiple == true) 'multiple': 'multiple',
            if (disabled == true) 'disabled': 'disabled',
          }),
          on: _mergeEvents(on,
              onChange: onChange,
              onFocus: onFocus,
              onBlur: onBlur),
        );

  const Select.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('select');
}

/// `<option>` — item in a select control.
class Option extends ElNode {
  Option({
    required String value,
    super.text,
    bool? selected,
    bool? disabled,
    super.className,
    Map<String, String>? attrs,
    super.children = const [],
  }) : super(
          'option',
          attrs: _mergeAttrs(attrs, {
            'value': value,
            if (selected == true) 'selected': 'selected',
            if (disabled == true) 'disabled': 'disabled',
          }),
        );

  const Option.raw({
    super.text,
    super.className,
    super.attrs,
    super.children = const [],
  }) : super('option');
}

/// `<optgroup>` — group of option items within a select control.
class Optgroup extends ElNode {
  Optgroup({
    required String label,
    super.className,
    Map<String, String>? attrs,
    super.children = const [],
  }) : super(
          'optgroup',
          attrs: _mergeAttrs(attrs, {'label': label}),
        );

  const Optgroup.raw({
    super.className,
    super.attrs,
    super.children = const [],
  }) : super('optgroup');
}

// ── SVG Descriptors ───────────────────────────────────────────────────

/// SVG element node. Emitted with SVG namespace by browser mount and SSR.
class SvgNode extends ElNode {
  const SvgNode(
    super.tag, {
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  });
}

/// `<svg>` — SVG container element.
class Svg extends SvgNode {
  Svg({
    String? viewBox,
    String? width,
    String? height,
    super.className,
    super.style,
    Map<String, String>? attrs,
    super.children = const [],
    super.on,
  }) : super('svg',
            attrs: _mergeAttrs(attrs, {
              if (viewBox != null) 'viewBox': viewBox,
              if (width != null) 'width': width,
              if (height != null) 'height': height,
            }));

  const Svg.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('svg');
}

/// `<g>` — SVG group element.
class SvgG extends SvgNode {
  SvgG({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('g');

  const SvgG.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('g');
}

/// `<path>` — SVG path element.
class SvgPath extends SvgNode {
  SvgPath({
    required String d,
    String? fill,
    String? stroke,
    String? strokeWidth,
    super.className,
    Map<String, String>? attrs,
    super.on,
  }) : super('path',
            attrs: _mergeAttrs(attrs, {
              'd': d,
              if (fill != null) 'fill': fill,
              if (stroke != null) 'stroke': stroke,
              if (strokeWidth != null) 'stroke-width': strokeWidth,
            }));

  const SvgPath.raw({
    super.className,
    super.attrs,
    super.on,
  }) : super('path');
}

/// `<circle>` — SVG circle element.
class SvgCircle extends SvgNode {
  SvgCircle({
    required num cx,
    required num cy,
    required num r,
    String? fill,
    String? stroke,
    super.className,
    Map<String, String>? attrs,
    super.on,
  }) : super('circle',
            attrs: _mergeAttrs(attrs, {
              'cx': '$cx',
              'cy': '$cy',
              'r': '$r',
              if (fill != null) 'fill': fill,
              if (stroke != null) 'stroke': stroke,
            }));

  const SvgCircle.raw({
    super.className,
    super.attrs,
    super.on,
  }) : super('circle');
}

/// `<rect>` — SVG rectangle element.
class SvgRect extends SvgNode {
  SvgRect({
    num? x,
    num? y,
    required num width,
    required num height,
    num? rx,
    String? fill,
    String? stroke,
    super.className,
    Map<String, String>? attrs,
    super.on,
  }) : super('rect',
            attrs: _mergeAttrs(attrs, {
              if (x != null) 'x': '$x',
              if (y != null) 'y': '$y',
              'width': '$width',
              'height': '$height',
              if (rx != null) 'rx': '$rx',
              if (fill != null) 'fill': fill,
              if (stroke != null) 'stroke': stroke,
            }));

  const SvgRect.raw({
    super.className,
    super.attrs,
    super.on,
  }) : super('rect');
}

/// `<line>` — SVG line element.
class SvgLine extends SvgNode {
  SvgLine({
    required num x1,
    required num y1,
    required num x2,
    required num y2,
    String? stroke,
    super.className,
    Map<String, String>? attrs,
    super.on,
  }) : super('line',
            attrs: _mergeAttrs(attrs, {
              'x1': '$x1',
              'y1': '$y1',
              'x2': '$x2',
              'y2': '$y2',
              if (stroke != null) 'stroke': stroke,
            }));
}

/// `<text>` — SVG text element.
class SvgText extends SvgNode {
  SvgText({
    super.text,
    num? x,
    num? y,
    String? fill,
    super.className,
    Map<String, String>? attrs,
    super.on,
    super.children = const [],
  }) : super('text',
            attrs: _mergeAttrs(attrs, {
              if (x != null) 'x': '$x',
              if (y != null) 'y': '$y',
              if (fill != null) 'fill': fill,
            }));
}

/// `<use>` — SVG element reuse instance.
class SvgUse extends SvgNode {
  SvgUse({
    required String href,
    num? x,
    num? y,
    super.className,
    Map<String, String>? attrs,
    super.on,
  }) : super('use',
            attrs: _mergeAttrs(attrs, {
              'href': href,
              if (x != null) 'x': '$x',
              if (y != null) 'y': '$y',
            }));
}
