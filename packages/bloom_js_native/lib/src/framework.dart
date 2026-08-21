import 'events.dart';

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
  BloomEventHandler? onInput,
  BloomEventHandler? onChange,
  BloomEventHandler? onSubmit,
  BloomEventHandler? onKeyDown,
  BloomEventHandler? onKeyUp,
}) {
  if (base == null &&
      onClick == null &&
      onInput == null &&
      onChange == null &&
      onSubmit == null &&
      onKeyDown == null &&
      onKeyUp == null) {
    return null;
  }
  return {
    if (base != null) ...base,
    if (onClick != null) 'click': onClick,
    if (onInput != null) 'input': onInput,
    if (onChange != null) 'change': onChange,
    if (onSubmit != null) 'submit': onSubmit,
    if (onKeyDown != null) 'keydown': onKeyDown,
    if (onKeyUp != null) 'keyup': onKeyUp,
  };
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
    BloomEventHandler? onInput,
    BloomEventHandler? onChange,
    BloomEventHandler? onSubmit,
    BloomEventHandler? onKeyDown,
    BloomEventHandler? onKeyUp,
  }) : super(
          on: _mergeEvents(on,
              onClick: onClick,
              onInput: onInput,
              onChange: onChange,
              onSubmit: onSubmit,
              onKeyDown: onKeyDown,
              onKeyUp: onKeyUp),
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
    BloomEventHandler? onInput,
    BloomEventHandler? onChange,
    BloomEventHandler? onSubmit,
  }) : super(
          'div',
          on: _mergeEvents(on,
              onClick: onClick,
              onInput: onInput,
              onChange: onChange,
              onSubmit: onSubmit),
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
  }) : super(
          'span',
          on: _mergeEvents(on, onClick: onClick),
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
  }) : super(
          'button',
          on: _mergeEvents(on, onClick: onClick),
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
              onKeyUp: onKeyUp),
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
  }) : super(
          'textarea',
          attrs: _mergeAttrs(attrs, {
            if (placeholder != null) 'placeholder': placeholder,
            if (value != null) 'value': value,
            if (name != null) 'name': name,
            if (rows != null) 'rows': '$rows',
            if (cols != null) 'cols': '$cols',
          }),
          on: _mergeEvents(on, onInput: onInput, onChange: onChange),
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
  }) : super(
          'a',
          attrs: _mergeAttrs(attrs, {
            if (href != null) 'href': href,
            if (target != null) 'target': target,
            if (rel != null) 'rel': rel,
          }),
          on: _mergeEvents(on, onClick: onClick),
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
