import 'dart:async';
import 'events.dart';
import 'animate.dart';

/// Token representing an ambient context value of type [T].
///
/// Context allows passing data down through a subtree without manually threading
/// properties through every intermediate component ("prop drilling"). A context
/// is created via [createContext], injected into a subtree via [provide], and
/// consumed inside descendant components via [useContext].
///
/// ### Zone-Based Propagation and Limitations
/// Context values are propagated through Dart [Zone] values captured during
/// synchronous tree mounting and SSR rendering.
///
/// **Important Gotcha**: When a reactive boundary (such as [Live] or [Show])
/// rebuilds in response to a signal update, its builder callback executes in
/// the [Zone] captured when that reactive effect was originally mounted. If an
/// ancestor provider dynamically changes the value it supplies, descendant
/// reactive rebuilds will continue to read the value from their initial mount zone
/// unless the provider itself triggers a rebuild of the entire subtree. For dynamic
/// state that changes over time, use `Signal<T>` instead of relying on mutable context.
///
/// ```dart
/// final themeContext = createContext('light');
///
/// BloomNode themedCard() {
///   final theme = useContext(themeContext);
///   return Div(
///     className: 'card card-$theme',
///     text: 'Current theme: $theme',
///   );
/// }
///
/// BloomNode app() => themeContext.provide(
///   'dark',
///   Div(
///     children: [
///       themedCard(),
///     ],
///   ),
/// );
/// ```
class BloomContext<T> {
  /// The fallback value returned by [useContext] when no matching provider
  /// exists in the ancestor hierarchy.
  final T defaultValue;

  /// The unique key used to look up and store this context's value within
  /// the ambient [Zone].
  final Object zoneKey = Object();

  /// Creates a new ambient [BloomContext] token with the specified [defaultValue].
  BloomContext(this.defaultValue);

  /// Provides [value] to all children in the [child] subtree.
  ///
  /// Wraps [child] in a [ContextProviderNode] that scopes [value] in the
  /// execution [Zone] for both SSR rendering and DOM mounting.
  ///
  /// ```dart
  /// final userContext = createContext<String>('Guest');
  ///
  /// BloomNode profileSection() => userContext.provide(
  ///   'Alice',
  ///   Div(children: [Text('Profile content')]),
  /// );
  /// ```
  BloomNode provide(T value, BloomNode child) =>
      ContextProviderNode<T>(this, value, child);
}

/// Creates a typed ambient [BloomContext] with [defaultValue].
///
/// Returns a context token that can be passed to [BloomContext.provide] to
/// inject a value into a subtree, and to [useContext] to read the nearest
/// provided value within that subtree.
///
/// ```dart
/// final authContext = createContext<User?>(null);
/// ```
BloomContext<T> createContext<T>(T defaultValue) => BloomContext<T>(defaultValue);

/// Reads the current ambient value for [context] from the surrounding [Zone].
///
/// If an ancestor [ContextProviderNode] provided a value for [context], that
/// value is returned. If no provider is found in the current zone hierarchy,
/// returns `context.defaultValue`.
///
/// ### Reactive Note
/// Calling [useContext] is not reactive by itself. If you need UI to update when
/// context data changes, store a `Signal<T>` in the context and read `signal.value`
/// inside a [Live] or [Show] boundary.
///
/// ```dart
/// BloomNode userBadge() {
///   final user = useContext(authContext);
///   return Span(
///     text: user != null ? 'Logged in as ${user.name}' : 'Anonymous',
///   );
/// }
/// ```
T useContext<T>(BloomContext<T> context) {
  final value = Zone.current[context.zoneKey];
  if (value != null && value is T) return value;
  return context.defaultValue;
}

/// AST node that injects context [value] into its descendant [child] tree.
///
/// During SSR (`renderToHtml`) and DOM mounting (`mount`), [ContextProviderNode]
/// executes the rendering of [child] within a [runZoned] block carrying
/// `{context.zoneKey: value}` in `zoneValues`.
///
/// This node does not emit any wrapper HTML elements or sentinel comments; it
/// acts as a pure scoping boundary for ambient context lookups.
///
/// Usually created via [BloomContext.provide] rather than directly instantiating this class.
class ContextProviderNode<T> extends BloomNode {
  /// The [BloomContext] token being provided.
  final BloomContext<T> context;

  /// The value injected into the ambient zone for [child] and its descendants.
  final T value;

  /// The descendant subtree that has access to [value].
  final BloomNode child;

  /// Creates a [ContextProviderNode] associating [context] with [value] over [child].
  const ContextProviderNode(this.context, this.value, this.child);
}

/// The core descriptor tree root — pure Dart, zero DOM dependency.
///
/// Every Bloom component compiles to a [BloomNode] AST tree first.
/// Zero browser or DOM APIs are imported by `framework.dart`, allowing
/// descriptor trees to be constructed and evaluated anywhere Dart runs:
///
/// - **Browser Mount**: `mount(node, '#app')` in `package:bloom_js_native/browser.dart`
///   creates real DOM nodes via `package:web` and sets up fine-grained `signals` effects.
/// - **SSR / SSG**: `renderToHtml(node)` in `package:bloom_js_native/bloom_js_native.dart`
///   evaluates the tree to an HTML string in `<1ms` with full HTML entity escaping.
/// - **Testing**: Descriptors can be inspected, traversed, and tested in pure Dart VM tests
///   without headless browsers.
sealed class BloomNode {
  /// Base const constructor for all [BloomNode] descriptors.
  const BloomNode();
}

// ── Concrete node types ───────────────────────────────────────────────

/// Plain text leaf descriptor.
///
/// Mounts to a single `web.Text` DOM node via `web.document.createTextNode(text)`
/// in the browser. During server-side rendering (`renderToHtml`), the text is
/// sanitized via [escapeHtml] to prevent cross-site scripting (XSS).
///
/// Usually created using the DSL sugar [Text].
class TextNode extends BloomNode {
  /// The raw text content of this node.
  final String text;

  /// Creates a text leaf descriptor with [text].
  const TextNode(this.text);
}

/// HTML element descriptor.
///
/// Represents an HTML or custom element in the Bloom descriptor tree.
///
/// ### DOM Mounting and SSR
/// - **Browser (`mount`)**: Creates a `web.Element` matching [tag] via
///   `web.document.createElement(tag)`. Applies [className], [style], [attrs],
///   registers event listeners from [on], creates an optional text child node if
///   [text] is non-null, and recursively mounts [children].
/// - **SSR (`renderToHtml`)**: Emits `<tag [class] [style] [attrs]>...children</tag>`
///   with all attributes and text contents HTML-escaped. If [tag] is a standard
///   HTML void element (e.g. `img`, `input`, `br`, `hr`), it is emitted without
///   a closing tag and any children are omitted.
///
/// Most HTML elements have dedicated sugar subclasses such as [Div], [Span],
/// [Button], [Input], [Form], and [A]. Use [ElNode] or [El] directly when creating
/// custom elements or tags without a dedicated sugar class.
class ElNode extends BloomNode {
  /// Lowercase tag name, e.g. "div", "button", "custom-tag".
  final String tag;

  /// Optional single text child sugar — equivalent to `children: [Text(text)]`
  /// when no explicit children are given.
  final String? text;

  /// CSS class attribute applied to the element.
  final String? className;

  /// Inline style — raw CSS string (e.g. "color: red; display: flex;").
  final String? style;

  /// Arbitrary HTML attributes (id, href, placeholder, etc.).
  final Map<String, String>? attrs;

  /// Event handlers keyed by DOM event name (click, input, change...).
  final Map<String, BloomEventHandler>? on;

  /// Child descriptors nested within this element.
  final List<BloomNode> children;

  /// Creates an element descriptor with [tag] and optional styling, attributes,
  /// event handlers, and child descriptors.
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

/// Fragment — groups multiple child nodes without introducing a wrapper DOM element.
///
/// ### DOM Mounting and SSR
/// - **Browser (`mount`)**: Appends each child in [children] sequentially into the
///   parent DOM container without creating an intermediate container node.
/// - **SSR (`renderToHtml`)**: Renders each child in [children] sequentially into
///   the output stream with no wrapper tags.
///
/// Usually created using the DSL sugar [Fragment].
class FragmentNode extends BloomNode {
  /// The list of child descriptors grouped by this fragment.
  final List<BloomNode> children;

  /// Creates a fragment descriptor containing [children].
  const FragmentNode([this.children = const []]);
}

/// Reactive boundary — re-evaluates [builder] inside a signal effect
/// and patches only its own DOM region.
///
/// ### DOM Mounting and Sentinels
/// In the browser, [LiveNode] mounts to a pair of sentinel comments:
/// `<!-- bloom:live -->` and `<!-- /bloom:live -->`.
///
/// It establishes a fine-grained `signals` effect that automatically tracks
/// all signal reads occurring synchronously within [builder]. When any tracked
/// signal updates, the effect runs:
/// 1. Disposes all child effects, event listeners, and subscriptions owned by
///    the previous subtree's `_Region`.
/// 2. Executes [builder] to obtain the new descriptor tree.
/// 3. Updates or reconciles the DOM nodes positioned strictly between the
///    sentinel comments, leaving the surrounding DOM untouched.
///
/// ### SSR Behavior
/// During server-side rendering (`renderToHtml`), [builder] is executed exactly
/// once synchronously to produce the static HTML output. No signals effects or
/// sentinels are created on the server.
///
/// Usually created using the DSL sugar [Live].
class LiveNode extends BloomNode {
  /// The reactive builder callback invoked to produce this boundary's subtree.
  final BloomNode Function() builder;

  /// Creates a reactive boundary descriptor driven by [builder].
  const LiveNode(this.builder);
}

/// Memoization boundary — only re-evaluates [builder] when [dependency] produces
/// a value that differs (`!=`) from its previous value.
///
/// ### DOM Mounting and Sentinels
/// In the browser, [MemoNode] mounts between a pair of sentinel comments:
/// `<!-- bloom:memo -->` and `<!-- /bloom:memo -->`.
///
/// Tracks signal reads inside [dependency]. When an upstream signal updates,
/// [dependency] is re-evaluated. If the returned value is identical or equal
/// (`==`) to the previous value, [builder] is **not** re-run and the existing DOM
/// is preserved. Only when the value changes (`!=`) is [builder] called with the
/// new value to update the DOM region.
///
/// ### SSR Behavior
/// In SSR (`renderToHtml`), [dependency] is called once and its result is passed
/// to [builder] to render the initial markup.
///
/// Usually created using the DSL sugar [Memo].
class MemoNode<T> extends BloomNode {
  /// Reactive computation returning the dependency value of type [T].
  final T Function() dependency;

  /// Builder that produces a descriptor tree from the evaluated dependency [value].
  final BloomNode Function(T value) builder;

  /// Creates a memoization boundary descriptor with [dependency] and [builder].
  const MemoNode(this.dependency, this.builder);

  /// [dependency], viewed untyped as `Object? Function()`.
  ///
  /// ### Contravariance in Dart Pattern Matching
  /// When pattern matching against `case MemoNode():` in mount or render code,
  /// Dart binds the generic type `T` as `dynamic`. Accessing [builder] through
  /// an erased reference would cast it to `BloomNode Function(dynamic)`, which
  /// fails at runtime because Dart function parameters are **contravariant**:
  /// a `BloomNode Function(MyData)` is not a subtype of `BloomNode Function(dynamic)`.
  ///
  /// This getter performs the cast `(value as T)` internally within [MemoNode]
  /// where `T` is statically known, returning a closure that backend engines
  /// can safely call without type errors.
  Object? Function() get dependencyErased => dependency;

  /// [builder], accepting an untyped `Object?` dependency value.
  ///
  /// Safely casts the untyped value to [T] before invoking [builder].
  /// See [dependencyErased] for why this type erasure is necessary.
  BloomNode Function(Object? value) get builderErased =>
      (value) => builder(value as T);
}

/// Conditional rendering primitive.
///
/// Mounts [child] when [when] evaluates to `true`, and optional [fallback]
/// when [when] evaluates to `false`.
///
/// ### DOM Mounting and Sentinels
/// In the browser, [ShowNode] mounts between sentinel comments:
/// `<!-- bloom:show -->` and `<!-- /bloom:show -->`.
///
/// Evaluates [when] inside a signal effect. When the boolean result transitions
/// between `true` and `false`, the previous branch's scoped region is disposed
/// and the active branch ([child] or [fallback]) is mounted between the sentinels.
/// If [fallback] is null and [when] is `false`, an empty fragment is mounted.
///
/// ### SSR Behavior
/// During SSR (`renderToHtml`), [when] is evaluated once synchronously. If `true`,
/// [child] is rendered; if `false`, [fallback] is rendered (or nothing if null).
///
/// Usually created using the DSL sugar [Show].
class ShowNode extends BloomNode {
  /// Reactive predicate — called inside a signals effect (browser) or once (SSR).
  final bool Function() when;

  /// The descriptor tree rendered when [when] evaluates to `true`.
  final BloomNode child;

  /// Optional descriptor tree rendered when [when] evaluates to `false`.
  final BloomNode? fallback;

  /// Creates a conditional rendering descriptor with predicate [when], primary
  /// [child], and optional [fallback].
  const ShowNode(this.when, {required this.child, this.fallback});
}

/// List rendering primitive. Re-reads [items] reactively; each item is
/// mapped through [builder] to a descriptor.
///
/// ### DOM Mounting and Reconciliation
/// In the browser, [ForEachNode] mounts between sentinel comments:
/// `<!-- bloom:foreach -->` and `<!-- /bloom:foreach -->`.
///
/// - **Keyed lists (`keyFn != null`)**: Fine-grained list reconciliation.
///   Each item is identified by the unique string returned from [keyFn]. When
///   [items] updates, existing DOM nodes and reactive sub-regions for unchanged
///   keys are retained and repositioned, new keys are mounted, and removed keys
///   are disposed. This preserves input focus, text selection, and internal state.
/// - **Unkeyed lists (`keyFn == null`)**: When [items] updates, all existing child
///   regions between the sentinels are disposed and rebuilt from scratch.
///
/// ### SSR Behavior
/// During SSR (`renderToHtml`), [items] is called once synchronously and each
/// item is mapped via [builder] to render the child nodes in order.
///
/// Usually created using the DSL sugar [ForEach].
class ForEachNode<T> extends BloomNode {
  /// Reactive getter returning the list of items to render.
  final List<T> Function() items;

  /// Factory callback mapping each item of type [T] to its [BloomNode] descriptor.
  final BloomNode Function(T item) builder;

  /// Optional key extractor function returning a unique string identifier for [item].
  final String Function(T item)? keyFn;

  /// Creates a list rendering descriptor with [items], [builder], and optional [keyFn].
  const ForEachNode(this.items, this.builder, {this.keyFn});

  /// Synchronously evaluates [items] and maps each element through [builder].
  ///
  /// Used by SSR rendering and unkeyed browser reconciliation passes.
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

  /// [items], viewed as an untyped list getter `List<Object?> Function()`.
  List<Object?> Function() get itemsErased => items;

  /// [keyFn], accepting an untyped item `Object?`. Returns `null` when the list is unkeyed.
  ///
  /// Safely casts the argument to [T] internally before calling [keyFn].
  String Function(Object? item)? get keyFnErased {
    final fn = keyFn;
    if (fn == null) return null;
    return (item) => fn(item as T);
  }

  /// [builder], accepting an untyped item `Object?`.
  ///
  /// Safely casts the argument to [T] internally before calling [builder].
  BloomNode Function(Object? item) get builderErased =>
      (item) => builder(item as T);
}

/// Style element helper — emits `<style>css</style>`.
///
/// In the browser (`mount`), creates a `<style>` element containing [css]. If
/// `bloomStyleNonce` is configured, it is attached as the `nonce` attribute for
/// Content Security Policy (CSP) compliance.
///
/// In SSR (`renderToHtml`), outputs `<style>css</style>` with any closing `</`
/// sequences neutralized to prevent stylesheet breakout attacks.
///
/// Usually created using the DSL sugar [Style].
class StyleNode extends BloomNode {
  /// The raw CSS stylesheet content.
  final String css;

  /// Creates a style element descriptor with raw [css].
  const StyleNode(this.css);
}

/// Trusted raw HTML passthrough — rendered verbatim by both backends.
///
/// ### Security Warning
/// **Never** pass unescaped user-supplied input to [RawHtmlNode] or [Raw].
/// This node bypasses HTML escaping completely and directly sets `.innerHTML`
/// in the browser, making the application vulnerable to XSS attacks if fed
/// untrusted data.
///
/// ### DOM Mounting and SSR
/// - **Browser (`mount`)**: Mounts as a `<span>` element host whose `innerHTML`
///   is assigned [html].
/// - **SSR (`renderToHtml`)**: Writes [html] directly into the output stream.
///
/// Usually created using the DSL sugar [Raw].
class RawHtmlNode extends BloomNode {
  /// The raw HTML string to insert.
  final String html;

  /// Creates a raw HTML passthrough descriptor with [html].
  const RawHtmlNode(this.html);
}

/// AST node that wraps [child] with a CSS animation described by [animation].
///
/// ### DOM Mounting and SSR
/// - **SSR (`renderToHtml`)**: Emits a `<style>@keyframes ...</style>` block
///   (deduplicated by animation name per render pass) and a wrapper `<div>`
///   carrying the `animation:` inline style.
/// - **Browser (`mount`)**: Injects the `@keyframes` rule into `document.head`
///   once per animation name for the lifetime of the page, and creates a wrapper
///   `<div>` with the animation's inline style enclosing [child].
class AnimatedNode extends BloomNode {
  /// The descriptor tree enclosed within the animated wrapper `<div>`.
  final BloomNode child;

  /// The animation configuration describing keyframes, duration, timing, and fill mode.
  final BloomAnimation animation;

  /// Creates an animated wrapper descriptor enclosing [child] with [animation].
  const AnimatedNode({required this.child, required this.animation});
}

// ── Sugar / DSL Constructors ──────────────────────────────────────────

/// Plain text node sugar.
///
/// Mounts to a `web.Text` node in the browser and escapes text in SSR.
///
/// ```dart
/// P(
///   children: [
///     const Text('Hello, '),
///     Span(className: 'font-bold', text: 'World!'),
///   ],
/// )
/// ```
class Text extends TextNode {
  /// Creates a plain text node with [text].
  const Text(super.text);
}

/// Fragment grouping sugar.
///
/// Groups multiple sibling nodes without introducing an additional wrapper DOM element.
///
/// ```dart
/// Fragment(
///   children: [
///     H1(text: 'Title'),
///     P(text: 'First paragraph'),
///     P(text: 'Second paragraph'),
///   ],
/// )
/// ```
class Fragment extends FragmentNode {
  /// Creates a fragment from a named list of [children].
  const Fragment({required List<BloomNode> children}) : super(children);

  /// Creates a fragment from a positional list of [children].
  const Fragment.fromList(super.children);
}

/// Reactive text / subtree — the JSX `{expr}` equivalent.
///
/// Automatically tracks any `Signal` read during the execution of [builder]
/// and updates only this region when signals change.
///
/// ### DOM Representation
/// Mounts between sentinel comments `<!-- bloom:live -->` and `<!-- /bloom:live -->`
/// rather than creating a wrapper element.
///
/// ```dart
/// final count = signal(0);
///
/// BloomNode counterView() => Div(
///   children: [
///     Live(() => P(text: 'Current count: ${count.value}')),
///     Button(
///       text: 'Increment',
///       onClick: (e) => count.value++,
///     ),
///   ],
/// );
/// ```
class Live extends LiveNode {
  /// Creates a reactive boundary descriptor driven by [builder].
  const Live(super.builder);
}

/// Memoization sugar.
///
/// Only re-evaluates [builder] when [dependency] returns a value that differs
/// (`!=`) from the previous execution. Prevents expensive subtree re-evaluations
/// when unrelated signals update.
///
/// ### DOM Representation
/// Mounts between sentinel comments `<!-- bloom:memo -->` and `<!-- /bloom:memo -->`.
///
/// ```dart
/// final activeUserId = signal('user-1');
///
/// BloomNode userProfileView() => Div(
///   children: [
///     Memo(
///       () => activeUserId.value,
///       (id) => Div(
///         className: 'profile-card',
///         text: 'Loaded profile for: $id',
///       ),
///     ),
///   ],
/// );
/// ```
class Memo<T> extends MemoNode<T> {
  /// Creates a memoized boundary descriptor with [dependency] and [builder].
  const Memo(super.dependency, super.builder);
}

/// Conditional rendering sugar.
///
/// Mounts [child] when [when] returns `true`, or [fallback] when `false`.
///
/// ### DOM Representation
/// Mounts between sentinel comments `<!-- bloom:show -->` and `<!-- /bloom:show -->`.
///
/// ```dart
/// final isLoggedIn = signal(false);
///
/// BloomNode authSection() => Show(
///   () => isLoggedIn.value,
///   child: Button(
///     text: 'Log out',
///     onClick: (e) => isLoggedIn.value = false,
///   ),
///   fallback: Button(
///     text: 'Log in',
///     onClick: (e) => isLoggedIn.value = true,
///   ),
/// );
/// ```
class Show extends ShowNode {
  /// Creates a conditional rendering boundary with predicate [when], [child],
  /// and optional [fallback].
  const Show(
    super.when, {
    required super.child,
    super.fallback,
  });
}

/// Reactive list rendering sugar.
///
/// Renders a dynamic list of items. When [key] is supplied, enables fine-grained
/// DOM reconciliation, reusing elements for unchanged keys and only updating
/// insertions, deletions, and moves.
///
/// ### DOM Representation
/// Mounts between sentinel comments `<!-- bloom:foreach -->` and `<!-- /bloom:foreach -->`.
///
/// ```dart
/// class Todo {
///   final String id;
///   final String title;
///   Todo(this.id, this.title);
/// }
///
/// final todos = signal<List<Todo>>([
///   Todo('1', 'Buy milk'),
///   Todo('2', 'Write tests'),
/// ]);
///
/// BloomNode todoList() => Ul(
///   children: [
///     ForEach<Todo>(
///       () => todos.value,
///       (item) => Li(
///         key: item.id,
///         text: item.title,
///       ),
///       key: (item) => item.id,
///     ),
///   ],
/// );
/// ```
class ForEach<T> extends ForEachNode<T> {
  /// Creates a reactive list descriptor with [items], [builder], and optional [key] extractor.
  const ForEach(
    super.items,
    super.builder, {
    String Function(T item)? key,
  }) : super(keyFn: key);
}

/// Inline stylesheet sugar.
///
/// Emits a `<style>` block containing [css].
///
/// ```dart
/// const customStyles = Style('''
///   .custom-card {
///     padding: 16px;
///     border-radius: 8px;
///     background: #14141a;
///   }
/// ''');
/// ```
class Style extends StyleNode {
  /// Creates an inline `<style>` element descriptor with [css].
  const Style(super.css);
}

/// Trusted raw HTML passthrough sugar.
///
/// Inserts raw HTML without entity escaping.
///
/// ### Security Warning
/// **Never** pass untrusted or user-supplied input to [Raw]. In the browser,
/// this sets `.innerHTML` directly on a `<span>` wrapper element and bypasses
/// sanitization.
///
/// ```dart
/// const mathSnippet = Raw('<math><semantics><mrow><mi>x</mi><mo>+</mo><mn>1</mn></mrow></semantics></math>');
/// ```
class Raw extends RawHtmlNode {
  /// Creates a raw HTML passthrough descriptor with [html].
  const Raw(super.html);
}

// ── Lifecycle & Refs ──────────────────────────────────────────────────

/// Reference holder for imperative access to mounted DOM elements.
///
/// Created before mounting and passed to a [RefNode] or component with ref support.
/// The browser mount engine automatically populates [value] when the DOM element
/// is created and attached, and resets it when unmounted.
///
/// ### SSR Behavior
/// In SSR (`renderToHtml`), refs remain unpopulated and [isMounted] returns `false`.
/// Attempting to read [value] during SSR will throw a [StateError].
///
/// ```dart
/// final inputRef = Ref<Object>();
///
/// BloomNode searchBox() => Mount(
///   RefNode(
///     inputRef,
///     Input(placeholder: 'Search documentation...'),
///   ),
///   onMount: () {
///     // Focus element when mounted in the browser
///     if (inputRef.isMounted) {
///       // Interop or custom logic with inputRef.value
///     }
///   },
/// );
/// ```
class Ref<T extends Object> {
  T? _value;

  /// The mounted DOM element instance.
  ///
  /// Throws [StateError] if accessed before the element has mounted to the DOM
  /// or after it has been unmounted/disposed. Check [isMounted] before accessing
  /// [value] if mounting timing is uncertain.
  T get value => _value ?? (throw StateError('Ref<$T> not yet mounted'));

  /// Whether this ref currently holds an active, mounted DOM element.
  bool get isMounted => _value != null;

  /// Attaches [element] to this ref.
  ///
  /// Called internally by the Bloom browser mount engine upon element creation.
  // ignore: use_setters_to_change_properties
  void attach(T element) => _value = element;

  /// Detaches the element and resets this ref to unmounted state.
  ///
  /// Called internally by the Bloom mount engine when the enclosing subtree is unmounted.
  void detach() => _value = null;
}

/// Lifecycle boundary node that triggers callbacks on mount and unmount.
///
/// Executes [onMount] after the child tree is attached to the DOM, and
/// [onUnmount] when the subtree is removed or disposed.
///
/// ### DOM Mounting and SSR
/// - **Browser (`mount`)**: [onMount] is executed in a microtask immediately after
///   DOM nodes are appended to the document. [onUnmount] is registered with the
///   enclosing region and called when the region is torn down or rebuilt.
/// - **SSR (`renderToHtml`)**: Renders [child] only. Lifecycle callbacks [onMount]
///   and [onUnmount] are intentionally ignored on the server.
///
/// Usually created using the DSL sugar [Mount].
class MountNode extends BloomNode {
  /// The child descriptor tree enclosed by this lifecycle boundary.
  final BloomNode child;

  /// Callback executed asynchronously in a microtask after [child] is inserted into the DOM.
  final void Function()? onMount;

  /// Callback executed synchronously when [child] is removed from the DOM.
  final void Function()? onUnmount;

  /// Creates a lifecycle boundary descriptor wrapping [child] with optional [onMount] and [onUnmount].
  const MountNode(this.child, {this.onMount, this.onUnmount});
}

/// DSL sugar for [MountNode].
///
/// Attaches lifecycle hooks to [child] for browser DOM mount and unmount events.
///
/// ```dart
/// BloomNode timerWidget() => Mount(
///   Div(text: 'Timer active'),
///   onMount: () {
///     print('Widget entered the DOM');
///   },
///   onUnmount: () {
///     print('Widget left the DOM');
///   },
/// );
/// ```
class Mount extends MountNode {
  /// Creates a lifecycle boundary wrapping [child] with optional [onMount] and [onUnmount] hooks.
  const Mount(super.child, {super.onMount, super.onUnmount});
}

/// Attaches a [Ref] to the first `web.Element` created by [child].
///
/// In the browser, the mount engine inspects the DOM nodes emitted by [child],
/// attaches the first `Element` instance to [ref], and registers [Ref.detach]
/// into the region's disposer list to clear the ref when unmounted.
///
/// In SSR (`renderToHtml`), [child] renders normally and [ref] remains unattached.
///
/// ```dart
/// final canvasRef = Ref<Object>();
///
/// BloomNode chart() => RefNode(
///   canvasRef,
///   Canvas(attrs: {'id': 'telemetry-canvas'}),
/// );
/// ```
class RefNode extends BloomNode {
  /// The [Ref] instance to populate with the mounted DOM element.
  final Ref<Object> ref;

  /// The child descriptor whose root DOM element will be attached to [ref].
  final BloomNode child;

  /// Creates a [RefNode] connecting [ref] to the primary element emitted by [child].
  const RefNode(this.ref, this.child);
}

/// Catches exceptions during subtree rendering or reactive rebuilds
/// and renders [fallback] instead of crashing.
///
/// ### DOM Mounting and Sentinels
/// In the browser, [ErrorBoundaryNode] mounts between sentinel comments:
/// `<!-- bloom:error-boundary -->` and `<!-- /bloom:error-boundary -->`.
///
/// Installs an ambient error boundary handler in the [Zone]. If [builder] throws
/// during initial mount, or if an unhandled error occurs during a nested reactive
/// update or [SuspenseNode] failure, the error is caught, the failed subtree's
/// resources are disposed, and [fallback] is mounted in place between the sentinels.
/// If [fallback] itself throws, the error bubbles up to the next enclosing error boundary.
///
/// ### SSR Behavior
/// In SSR (`renderToHtml`), executes [builder] inside a `try/catch`. If an exception
/// is thrown, renders `fallback(err, stack)`.
///
/// Usually created using the DSL sugar [ErrorBoundary].
class ErrorBoundaryNode extends BloomNode {
  /// Factory building the primary subtree.
  final BloomNode Function() builder;

  /// Fallback builder invoked with the caught [Object] error and [StackTrace] when [builder] fails.
  final BloomNode Function(Object error, StackTrace stackTrace) fallback;

  /// Creates an error boundary descriptor with [builder] and error [fallback].
  const ErrorBoundaryNode({
    required this.builder,
    required this.fallback,
  });
}

/// DSL sugar for [ErrorBoundaryNode].
///
/// Protects the application UI from crashing due to exceptions in child components
/// or nested reactive rebuilds.
///
/// ```dart
/// BloomNode safeDashboard() => ErrorBoundary(
///   builder: () => Div(
///     children: [
///       H1(text: 'Analytics'),
///       riskyAnalyticsWidget(),
///     ],
///   ),
///   fallback: (error, stack) => Div(
///     className: 'error-banner',
///     text: 'Failed to load dashboard: $error',
///   ),
/// );
/// ```
class ErrorBoundary extends ErrorBoundaryNode {
  /// Creates an error boundary wrapping [builder] with [fallback].
  const ErrorBoundary({
    required super.builder,
    required super.fallback,
  });
}

/// Renders [child] into a target DOM node outside the parent hierarchy
/// while maintaining parent reactive region lifecycle.
///
/// ### DOM Mounting and SSR
/// - **Browser (`mount`)**: Queries the document for [targetSelector] (defaulting
///   to `document.body` if unmatched) and appends the mounted DOM nodes of [child]
///   into that target container. At the original AST position, it leaves a comment
///   node `<!-- portal:targetSelector -->`. When the parent region is disposed,
///   the portaled DOM nodes are cleaned up from the target container.
/// - **SSR (`renderToHtml`)**: Emits `<template data-bloom-portal="targetSelector">child</template>`
///   so client-side hydration or inspection tools can relocate portaled content.
///
/// Usually created using the DSL sugar [Portal].
class PortalNode extends BloomNode {
  /// The descriptor tree to render into the target container.
  final BloomNode child;

  /// The CSS selector identifying the destination container element (e.g. `'body'`, `'#modal-root'`).
  final String targetSelector;

  /// Creates a portal descriptor directing [child] to [targetSelector].
  const PortalNode({
    required this.child,
    this.targetSelector = 'body',
  });
}

/// DSL sugar for [PortalNode].
///
/// Renders overlays, modals, and tooltips directly into `document.body` or a
/// custom container while preserving lexical state and reactive lifecycle.
///
/// ```dart
/// BloomNode modalDialog(bool isOpen) => Show(
///   () => isOpen,
///   child: Portal(
///     targetSelector: 'body',
///     child: Div(
///       className: 'modal-backdrop',
///       children: [
///         Div(className: 'modal-card', text: 'Modal dialog content'),
///       ],
///     ),
///   ),
/// );
/// ```
class Portal extends PortalNode {
  /// Creates a portal descriptor for [child] with destination [targetSelector].
  const Portal({
    required super.child,
    super.targetSelector = 'body',
  });
}

/// Declarative async boundary that renders [fallback] while [resource] resolves.
///
/// ### DOM Mounting and SSR
/// - **Browser (`mount`)**: Mounts between sentinel comments `<!-- bloom:suspense -->`
///   and `<!-- /bloom:suspense -->`. Mounts [fallback] initially while asynchronously
///   awaiting [resource]. When the future completes, disposes the fallback region
///   and mounts `builder(data)` between the sentinels. If [resource] rejects,
///   renders [errorBuilder] if provided or bubbles the error to the nearest [ErrorBoundary].
/// - **Streaming SSR (`renderToStreamWithSuspense`)**: Emits [fallback] in the
///   initial HTML shell wrapped in `<div id="bloom-suspense-N">`. When [resource]
///   resolutes on the server, streams an out-of-order `<script>` tag that replaces
///   the fallback container's `outerHTML` with the resolved content.
/// - **Synchronous SSR (`renderToHtml`)**: Renders [fallback] only.
///
/// Usually created using the DSL sugar [Suspense].
class SuspenseNode<T> extends BloomNode {
  /// Async factory returning a [Future] with the resolved data of type [T].
  final Future<T> Function() resource;

  /// Builder constructing the descriptor tree once [resource] resolves with [data].
  final BloomNode Function(T data) builder;

  /// Descriptor tree displayed while [resource] is still pending.
  final BloomNode fallback;

  /// Optional error builder invoked if [resource] rejects with an exception.
  final BloomNode Function(Object error, StackTrace stackTrace)? errorBuilder;

  /// Creates a suspense boundary descriptor with async [resource], resolved [builder],
  /// loading [fallback], and optional [errorBuilder].
  const SuspenseNode({
    required this.resource,
    required this.builder,
    required this.fallback,
    this.errorBuilder,
  });

  /// [resource], viewed untyped as `Future<Object?> Function()`.
  ///
  /// ### Contravariance in Dart Pattern Matching
  /// When pattern matching against `case SuspenseNode():` in mount or render code,
  /// Dart binds the generic type `T` as `dynamic`. Accessing [builder] through
  /// an erased reference would cast it to `BloomNode Function(dynamic)`, which
  /// fails at runtime because Dart function parameters are **contravariant**:
  /// a `BloomNode Function(UserData)` is not a subtype of `BloomNode Function(dynamic)`.
  ///
  /// This getter performs the cast `(data as T)` internally within [SuspenseNode]
  /// where `T` is statically known, returning a closure that backend engines
  /// can safely call without type errors.
  Future<Object?> Function() get resourceErased => resource;

  /// [builder], accepting untyped resolved `Object?` data.
  ///
  /// Safely casts the untyped data to [T] before invoking [builder].
  /// See [resourceErased] for why this type erasure is necessary.
  BloomNode Function(Object? data) get builderErased =>
      (data) => builder(data as T);
}

/// DSL sugar for [SuspenseNode].
///
/// Renders [fallback] while async data is loading, and seamlessly swaps in
/// the resolved content when [resource] completes.
///
/// ```dart
/// Future<String> fetchUsername() async {
///   await Future.delayed(const Duration(milliseconds: 500));
///   return 'Ada Lovelace';
/// }
///
/// BloomNode userProfile() => Suspense<String>(
///   resource: fetchUsername,
///   fallback: Div(className: 'skeleton-loader', text: 'Loading user...'),
///   builder: (name) => Div(className: 'user-card', text: 'Welcome, $name!'),
///   errorBuilder: (err, stack) => Div(text: 'Failed to load user: $err'),
/// );
/// ```
class Suspense<T> extends SuspenseNode<T> {
  /// Creates a suspense boundary with async [resource], [builder], [fallback],
  /// and optional [errorBuilder].
  const Suspense({
    required super.resource,
    required super.builder,
    required super.fallback,
    super.errorBuilder,
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

/// Conditional className builder — clsx-style utility.
///
/// Filters out `null`, `false`, and blank strings from [parts], trims each valid
/// class name, and joins the remaining entries with a single space.
///
/// ```dart
/// final isActive = true;
/// final isDisabled = false;
///
/// final className = cx([
///   'btn',
///   isActive && 'btn-active',
///   isDisabled && 'btn-disabled',
///   null,
/// ]);
/// // => 'btn btn-active'
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

/// Generic HTML / custom element constructor.
///
/// Provides convenient named event handler parameters ([onClick], [onInput],
/// [onChange], [onSubmit], etc.) that merge automatically into the element's
/// event registry.
///
/// Use [El] when emitting custom elements, web components, or HTML tags that do
/// not have a specialized sugar subclass in Bloom.
///
/// ```dart
/// BloomNode customWidget() => El(
///   'my-custom-element',
///   className: 'custom-widget',
///   attrs: {'data-mode': 'preview'},
///   onClick: (e) => print('Clicked custom element'),
///   children: [
///     P(text: 'Inner text'),
///   ],
/// );
/// ```
class El extends ElNode {
  /// Creates an element with [tag] and optional styling, attributes, event handlers,
  /// and child descriptors.
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

  /// Const constructor for [El] when no event callback shorthand is needed.
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

/// `<div>` — generic division / block layout container.
class Div extends ElNode {
  /// Creates a `<div>` element descriptor with optional styling, attributes,
  /// event listeners, and children.
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

  /// Const constructor for `<div>` without event listener shorthand.
  const Div.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('div');
}

/// `<span>` — generic inline phrasing content container.
class Span extends ElNode {
  /// Creates a `<span>` element descriptor with optional styling, attributes,
  /// event listeners, and children.
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

  /// Const constructor for `<span>` without event listener shorthand.
  const Span.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('span');
}

/// `<p>` — paragraph block element.
class P extends ElNode {
  /// Creates a `<p>` element descriptor with optional styling, attributes,
  /// event listeners, and children.
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

  /// Const constructor for `<p>` without event listener shorthand.
  const P.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('p');
}

/// `<h1>` — highest-level section heading element.
class H1 extends ElNode {
  /// Creates an `<h1>` heading element descriptor.
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

  /// Const constructor for `<h1>` without event listener shorthand.
  const H1.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h1');
}

/// `<h2>` — second-level section heading element.
class H2 extends ElNode {
  /// Creates an `<h2>` heading element descriptor.
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

  /// Const constructor for `<h2>` without event listener shorthand.
  const H2.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h2');
}

/// `<h3>` — third-level section heading element.
class H3 extends ElNode {
  /// Creates an `<h3>` heading element descriptor.
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

  /// Const constructor for `<h3>` without event listener shorthand.
  const H3.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h3');
}

/// `<h4>` — fourth-level section heading element.
class H4 extends ElNode {
  /// Creates an `<h4>` heading element descriptor.
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

  /// Const constructor for `<h4>` without event listener shorthand.
  const H4.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h4');
}

/// `<h5>` — fifth-level section heading element.
class H5 extends ElNode {
  /// Creates an `<h5>` heading element descriptor.
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

  /// Const constructor for `<h5>` without event listener shorthand.
  const H5.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h5');
}

/// `<h6>` — sixth-level section heading element.
class H6 extends ElNode {
  /// Creates an `<h6>` heading element descriptor.
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

  /// Const constructor for `<h6>` without event listener shorthand.
  const H6.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('h6');
}

/// `<button>` — interactive clickable button element.
///
/// **Note**: Standard HTML buttons default to `type="submit"` when placed inside
/// a `<form>`. To prevent unintended form submissions, specify `attrs: {'type': 'button'}`.
class Button extends ElNode {
  /// Creates a `<button>` element descriptor with event listener shorthands.
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

  /// Const constructor for `<button>` without event listener shorthand.
  const Button.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('button');
}

/// `<input>` — interactive form input control element.
///
/// **Void element**: `<input>` cannot have children and is emitted without a closing tag.
///
/// ### Reactivity Pattern
/// Setting [value] configures the initial HTML attribute. For two-way data binding,
/// listen with [onInput] or [onChange] and update a `Signal`:
///
/// ```dart
/// final query = signal('');
///
/// BloomNode searchInput() => Input(
///   placeholder: 'Search items...',
///   value: query.value,
///   onInput: (e) => query.value = (e.target as dynamic).value,
/// );
/// ```
class Input extends ElNode {
  /// Creates an `<input>` element descriptor with attribute and event shorthands.
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

  /// Const constructor for `<input>` without attribute and event shorthands.
  const Input.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
  }) : super('input');
}

/// `<textarea>` — multi-line plain text editing control element.
///
/// In Bloom, [value] sets the initial text attribute shorthand. For interactive
/// updates, attach an [onInput] handler to synchronize state with a `Signal`.
///
/// ```dart
/// final note = signal('');
///
/// BloomNode noteField() => Textarea(
///   rows: 4,
///   placeholder: 'Enter notes here...',
///   onInput: (e) => note.value = (e.target as dynamic).value,
/// );
/// ```
class Textarea extends ElNode {
  /// Creates a `<textarea>` element descriptor with attribute and event shorthands.
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

  /// Const constructor for `<textarea>` without attribute and event shorthands.
  const Textarea.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
  }) : super('textarea');
}

/// `<a>` — anchor / hyperlink element.
///
/// Provides convenient shorthands for [href], [target], and [rel].
///
/// ```dart
/// A(
///   href: 'https://bloom.dev',
///   target: '_blank',
///   rel: 'noopener noreferrer',
///   text: 'Visit Bloom',
/// )
/// ```
class A extends ElNode {
  /// Creates an `<a>` anchor element descriptor with hyperlink shorthands.
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

  /// Const constructor for `<a>` without hyperlink shorthands.
  const A.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('a');
}

/// `<img>` — embedded image element.
///
/// **Void element**: `<img>` cannot have children and is emitted without a closing tag.
/// Requires [src] parameter.
///
/// ```dart
/// Img(
///   src: '/assets/logo.svg',
///   alt: 'Bloom Logo',
///   width: 48,
///   height: 48,
/// )
/// ```
class Img extends ElNode {
  /// Creates an `<img>` element descriptor with image attribute shorthands.
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

  /// Const constructor for `<img>` without attribute shorthands.
  const Img.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
  }) : super('img');
}

/// `<ul>` — unordered list element.
class Ul extends ElNode {
  /// Creates an `<ul>` unordered list element descriptor.
  Ul({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('ul');

  /// Const constructor for `<ul>`.
  const Ul.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('ul');
}

/// `<ol>` — ordered list element.
class Ol extends ElNode {
  /// Creates an `<ol>` ordered list element descriptor.
  Ol({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('ol');

  /// Const constructor for `<ol>`.
  const Ol.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('ol');
}

/// `<li>` — list item element.
class Li extends ElNode {
  /// Creates an `<li>` list item element descriptor.
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

  /// Const constructor for `<li>` without event listener shorthand.
  const Li.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('li');
}

/// `<form>` — interactive form submission container.
///
/// Provides a convenient [onSubmit] event callback parameter.
class Form extends ElNode {
  /// Creates a `<form>` element descriptor with [onSubmit] event shorthand.
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

  /// Const constructor for `<form>` without event listener shorthand.
  const Form.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('form');
}

/// `<label>` — caption for a form control element.
///
/// Use [htmlFor] to associate this label with a target input ID (maps to `for` attribute).
class Label extends ElNode {
  /// Creates a `<label>` element descriptor with [htmlFor] attribute shorthand.
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

  /// Const constructor for `<label>` without attribute shorthand.
  const Label.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('label');
}

/// `<header>` — introductory or navigational container for a page or section.
class Header extends ElNode {
  /// Creates a `<header>` element descriptor.
  Header({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('header');

  /// Const constructor for `<header>`.
  const Header.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('header');
}

/// `<footer>` — footer container for a page or section.
class Footer extends ElNode {
  /// Creates a `<footer>` element descriptor.
  Footer({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('footer');

  /// Const constructor for `<footer>`.
  const Footer.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('footer');
}

/// `<main>` — dominant central content container of a document.
class Main extends ElNode {
  /// Creates a `<main>` element descriptor.
  Main({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('main');

  /// Const constructor for `<main>`.
  const Main.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('main');
}

/// `<nav>` — section of navigation links.
class Nav extends ElNode {
  /// Creates a `<nav>` element descriptor.
  Nav({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('nav');

  /// Const constructor for `<nav>`.
  const Nav.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('nav');
}

/// `<section>` — standalone generic thematic section of a document.
class Section extends ElNode {
  /// Creates a `<section>` element descriptor.
  Section({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('section');

  /// Const constructor for `<section>`.
  const Section.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('section');
}

/// `<article>` — self-contained, independently distributable composition.
class Article extends ElNode {
  /// Creates an `<article>` element descriptor.
  Article({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('article');

  /// Const constructor for `<article>`.
  const Article.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('article');
}

/// `<aside>` — sidebar or tangentially related content container.
class Aside extends ElNode {
  /// Creates an `<aside>` element descriptor.
  Aside({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('aside');

  /// Const constructor for `<aside>`.
  const Aside.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('aside');
}

/// `<strong>` — content of strong importance, seriousness, or urgency.
class Strong extends ElNode {
  /// Creates a `<strong>` element descriptor.
  Strong({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('strong');

  /// Const constructor for `<strong>`.
  const Strong.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('strong');
}

/// `<em>` — text with emphatic stress.
class Em extends ElNode {
  /// Creates an `<em>` element descriptor.
  Em({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('em');

  /// Const constructor for `<em>`.
  const Em.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('em');
}

/// `<code>` — inline code fragment or computer code snippet.
class Code extends ElNode {
  /// Creates a `<code>` element descriptor.
  Code({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('code');

  /// Const constructor for `<code>`.
  const Code.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('code');
}

/// `<pre>` — preformatted text block preserving whitespace and formatting.
class Pre extends ElNode {
  /// Creates a `<pre>` element descriptor.
  Pre({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('pre');

  /// Const constructor for `<pre>`.
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
///
/// **Void element**: `<br>` cannot have children and is emitted without a closing tag.
class Br extends ElNode {
  /// Creates a `<br>` line break descriptor.
  const Br({super.className, super.attrs}) : super('br');
}

/// `<hr>` — thematic break / horizontal rule (void element).
///
/// **Void element**: `<hr>` cannot have children and is emitted without a closing tag.
class Hr extends ElNode {
  /// Creates an `<hr>` horizontal rule descriptor.
  const Hr({super.className, super.style, super.attrs}) : super('hr');
}

/// `<blockquote>` — section quoted from another source.
class Blockquote extends ElNode {
  /// Creates a `<blockquote>` element descriptor.
  Blockquote({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('blockquote');

  /// Const constructor for `<blockquote>`.
  const Blockquote.raw({super.text, super.className, super.style, super.attrs, super.on, super.children = const []}) : super('blockquote');
}

/// `<cite>` — title of a creative work or citation reference.
class Cite extends ElNode {
  /// Creates a `<cite>` citation descriptor.
  const Cite({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('cite');
}

/// `<time>` — machine-readable date/time representation.
///
/// Use [dateTime] to specify the ISO 8601 timestamp string (maps to `datetime` attribute).
class TimeEl extends ElNode {
  /// Creates a `<time>` element descriptor with [dateTime] attribute shorthand.
  TimeEl({super.text, String? dateTime, super.className, super.style, Map<String, String>? attrs, super.children = const [], super.on})
      : super('time', attrs: _mergeAttrs(attrs, {if (dateTime != null) 'datetime': dateTime}));

  /// Const constructor for `<time>` without attribute shorthand.
  const TimeEl.raw({super.text, super.className, super.style, super.attrs, super.on, super.children = const []}) : super('time');
}

/// `<mark>` — text highlighted for reference or relevance purposes.
class Mark extends ElNode {
  /// Creates a `<mark>` highlight descriptor.
  const Mark({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('mark');
}

/// `<small>` — side-comments, small print, and legal disclaimers.
class Small extends ElNode {
  /// Creates a `<small>` fine-print descriptor.
  const Small({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('small');
}

/// `<sub>` — subscript text.
class Sub extends ElNode {
  /// Creates a `<sub>` subscript descriptor.
  const Sub({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('sub');
}

/// `<sup>` — superscript text.
class Sup extends ElNode {
  /// Creates a `<sup>` superscript descriptor.
  const Sup({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('sup');
}

/// `<abbr>` — abbreviation or acronym.
///
/// Use [title] to provide the expanded description shown on hover.
class Abbr extends ElNode {
  /// Creates an `<abbr>` abbreviation descriptor with [title] shorthand.
  Abbr({super.text, String? title, super.className, super.style, Map<String, String>? attrs, super.children = const [], super.on})
      : super('abbr', attrs: _mergeAttrs(attrs, {if (title != null) 'title': title}));

  /// Const constructor for `<abbr>` without attribute shorthand.
  const Abbr.raw({super.text, super.className, super.style, super.attrs, super.on, super.children = const []}) : super('abbr');
}

/// `<kbd>` — keyboard input or key combination.
class KbdEl extends ElNode {
  /// Creates a `<kbd>` keyboard input descriptor.
  const KbdEl({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('kbd');
}

/// `<figure>` — self-contained figure content (images, charts, code blocks).
class Figure extends ElNode {
  /// Creates a `<figure>` element descriptor.
  Figure({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('figure');

  /// Const constructor for `<figure>`.
  const Figure.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('figure');
}

/// `<figcaption>` — caption or legend for a parent `<figure>`.
class Figcaption extends ElNode {
  /// Creates a `<figcaption>` element descriptor.
  const Figcaption({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('figcaption');
}

/// `<details>` — interactive disclosure widget.
///
/// Use [open] to control whether disclosure is expanded initially.
class Details extends ElNode {
  /// Creates a `<details>` element descriptor with [open] attribute shorthand.
  Details({super.className, super.style, Map<String, String>? attrs, super.children = const [], super.on, bool? open})
      : super('details', attrs: _mergeAttrs(attrs, {if (open == true) 'open': 'open'}));

  /// Const constructor for `<details>` without attribute shorthand.
  const Details.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('details');
}

/// `<summary>` — disclosure summary or caption heading for a parent `<details>`.
class Summary extends ElNode {
  /// Creates a `<summary>` element descriptor.
  const Summary({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('summary');
}

/// `<dialog>` — interactive modal or non-modal dialog window.
///
/// Use [open] to control whether the dialog is open upon mounting.
class Dialog extends ElNode {
  /// Creates a `<dialog>` element descriptor with [open] attribute shorthand.
  Dialog({super.className, super.style, Map<String, String>? attrs, super.children = const [], super.on, bool? open})
      : super('dialog', attrs: _mergeAttrs(attrs, {if (open == true) 'open': 'open'}));

  /// Const constructor for `<dialog>` without attribute shorthand.
  const Dialog.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('dialog');
}

/// `<canvas>` — 2D and WebGL bitmap graphics surface.
///
/// [width] and [height] configure the coordinate space dimensions of the canvas.
class Canvas extends ElNode {
  /// Creates a `<canvas>` element descriptor with [width] and [height] dimension shorthands.
  Canvas({int? width, int? height, super.className, super.style, Map<String, String>? attrs, super.on})
      : super('canvas', attrs: _mergeAttrs(attrs, {if (width != null) 'width': '$width', if (height != null) 'height': '$height'}));

  /// Const constructor for `<canvas>` without dimension shorthands.
  const Canvas.raw({super.className, super.style, super.attrs, super.on}) : super('canvas');
}

/// `<iframe>` — inline frame embedding an external browsing context.
class IFrame extends ElNode {
  /// Creates an `<iframe>` element descriptor with [src], [title], and dimension shorthands.
  IFrame({String? src, String? title, int? width, int? height, super.className, super.style, Map<String, String>? attrs, super.on})
      : super('iframe', attrs: _mergeAttrs(attrs, {
          if (src != null) 'src': src,
          if (title != null) 'title': title,
          if (width != null) 'width': '$width',
          if (height != null) 'height': '$height',
        }));

  /// Const constructor for `<iframe>` without attribute shorthands.
  const IFrame.raw({super.className, super.style, super.attrs, super.on}) : super('iframe');
}

// ── Table Elements ────────────────────────────────────────────────────

/// `<table>` — tabular data container element.
class Table extends ElNode {
  /// Creates a `<table>` element descriptor.
  Table({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('table');

  /// Const constructor for `<table>`.
  const Table.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('table');
}

/// `<caption>` — title or accessibility description for a parent `<table>`.
class Caption extends ElNode {
  /// Creates a `<caption>` table description descriptor.
  const Caption({super.text, super.className, super.style, super.attrs, super.children = const [], super.on}) : super('caption');
}

/// `<thead>` — group of header rows in a `<table>`.
class Thead extends ElNode {
  /// Creates a `<thead>` element descriptor.
  Thead({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('thead');

  /// Const constructor for `<thead>`.
  const Thead.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('thead');
}

/// `<tbody>` — group of body data rows in a `<table>`.
class Tbody extends ElNode {
  /// Creates a `<tbody>` element descriptor.
  Tbody({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('tbody');

  /// Const constructor for `<tbody>`.
  const Tbody.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('tbody');
}

/// `<tfoot>` — group of summary footer rows in a `<table>`.
class Tfoot extends ElNode {
  /// Creates a `<tfoot>` element descriptor.
  Tfoot({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('tfoot');

  /// Const constructor for `<tfoot>`.
  const Tfoot.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('tfoot');
}

/// `<tr>` — row of cells in a `<table>`.
class Tr extends ElNode {
  /// Creates a `<tr>` table row descriptor.
  Tr({super.className, super.style, super.attrs, super.children = const [], super.on}) : super('tr');

  /// Const constructor for `<tr>`.
  const Tr.raw({super.className, super.style, super.attrs, super.on, super.children = const []}) : super('tr');
}

/// `<th>` — header cell in a `<table>`.
///
/// Supports [scope], [colSpan] (`colspan`), and [rowSpan] (`rowspan`) shorthands.
class Th extends ElNode {
  /// Creates a `<th>` table header cell descriptor.
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

  /// Const constructor for `<th>` without attribute shorthands.
  const Th.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('th');
}

/// `<td>` — standard data cell in a `<table>`.
///
/// Supports [colSpan] (`colspan`) and [rowSpan] (`rowspan`) shorthands.
class Td extends ElNode {
  /// Creates a `<td>` table data cell descriptor.
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

  /// Const constructor for `<td>` without attribute shorthands.
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
///
/// Contains child [Option] and [Optgroup] descriptors. Supports [onChange],
/// [onFocus], and [onBlur] event shorthands.
///
/// ```dart
/// final selectedRole = signal('developer');
///
/// BloomNode roleSelector() => Select(
///   name: 'role',
///   onChange: (e) => selectedRole.value = (e.target as dynamic).value,
///   children: [
///     Option(value: 'developer', text: 'Developer'),
///     Option(value: 'designer', text: 'Designer'),
///     Option(value: 'manager', text: 'Manager'),
///   ],
/// );
/// ```
class Select extends ElNode {
  /// Creates a `<select>` drop-down control descriptor.
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

  /// Const constructor for `<select>` without attribute and event shorthands.
  const Select.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('select');
}

/// `<option>` — selectable item in a `<select>` control.
///
/// Requires the [value] parameter. Supports [selected] and [disabled] shorthands.
class Option extends ElNode {
  /// Creates an `<option>` element descriptor with [value] and state shorthands.
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

  /// Const constructor for `<option>` without attribute shorthands.
  const Option.raw({
    super.text,
    super.className,
    super.attrs,
    super.children = const [],
  }) : super('option');
}

/// `<optgroup>` — group of related `<option>` items within a `<select>` control.
///
/// Requires the [label] parameter naming the option group.
class Optgroup extends ElNode {
  /// Creates an `<optgroup>` element descriptor with [label] shorthand.
  Optgroup({
    required String label,
    super.className,
    Map<String, String>? attrs,
    super.children = const [],
  }) : super(
          'optgroup',
          attrs: _mergeAttrs(attrs, {'label': label}),
        );

  /// Const constructor for `<optgroup>` without attribute shorthand.
  const Optgroup.raw({
    super.className,
    super.attrs,
    super.children = const [],
  }) : super('optgroup');
}

// ── SVG Descriptors ───────────────────────────────────────────────────

/// SVG element node base class.
///
/// All SVG descriptors inherit from [SvgNode]. In the browser, elements are
/// created within the SVG XML namespace (`http://www.w3.org/2000/svg`) rather than
/// the standard HTML namespace.
class SvgNode extends ElNode {
  /// Creates an SVG element descriptor with [tag].
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

/// `<svg>` — root SVG graphics viewport container element.
///
/// Supports [viewBox], [width], and [height] attribute shorthands.
///
/// ```dart
/// Svg(
///   viewBox: '0 0 24 24',
///   width: '24',
///   height: '24',
///   children: [
///     SvgPath(d: 'M12 2L2 7l10 5 10-5-10-5z', fill: 'currentColor'),
///   ],
/// )
/// ```
class Svg extends SvgNode {
  /// Creates an `<svg>` viewport container descriptor.
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

  /// Const constructor for `<svg>` without attribute shorthands.
  const Svg.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('svg');
}

/// `<g>` — SVG grouping container element.
class SvgG extends SvgNode {
  /// Creates an SVG `<g>` group descriptor.
  SvgG({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
    super.on,
  }) : super('g');

  /// Const constructor for SVG `<g>`.
  const SvgG.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('g');
}

/// `<path>` — SVG vector shape path element.
///
/// Requires the [d] path data definition string. Supports [fill], [stroke],
/// and [strokeWidth] (`stroke-width`) shorthands.
class SvgPath extends SvgNode {
  /// Creates an SVG `<path>` shape descriptor.
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

  /// Const constructor for SVG `<path>` without attribute shorthands.
  const SvgPath.raw({
    super.className,
    super.attrs,
    super.on,
  }) : super('path');
}

/// `<circle>` — SVG circle shape element.
///
/// Requires center coordinates [cx], [cy], and radius [r].
class SvgCircle extends SvgNode {
  /// Creates an SVG `<circle>` shape descriptor.
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

  /// Const constructor for SVG `<circle>` without attribute shorthands.
  const SvgCircle.raw({
    super.className,
    super.attrs,
    super.on,
  }) : super('circle');
}

/// `<rect>` — SVG rectangle shape element.
///
/// Requires [width] and [height]. Supports [x], [y], corner radius [rx],
/// [fill], and [stroke] shorthands.
class SvgRect extends SvgNode {
  /// Creates an SVG `<rect>` rectangle shape descriptor.
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

  /// Const constructor for SVG `<rect>` without attribute shorthands.
  const SvgRect.raw({
    super.className,
    super.attrs,
    super.on,
  }) : super('rect');
}

/// `<line>` — SVG straight line element.
///
/// Requires start coordinates [x1], [y1] and end coordinates [x2], [y2].
class SvgLine extends SvgNode {
  /// Creates an SVG `<line>` segment descriptor.
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

/// `<text>` — SVG graphical text element.
class SvgText extends SvgNode {
  /// Creates an SVG `<text>` element descriptor with [x], [y], and [fill] shorthands.
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

/// `<use>` — SVG element instance reuse element.
///
/// Requires the [href] target reference URI string.
class SvgUse extends SvgNode {
  /// Creates an SVG `<use>` instance reuse descriptor.
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
