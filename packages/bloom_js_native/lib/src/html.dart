import 'framework.dart';

/// HTML void elements — must not have a closing tag.
const _voidElements = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

/// Escape HTML text content and attribute values.
///
/// Covers &, <, >, ", ' — the minimal set needed to prevent XSS via
/// interpolation. Mirrors the sanitize fix from phase12.
String escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#x27;');
}

/// Render a [BloomNode] descriptor tree to an HTML string.
///
/// - Evaluates [Live], [Show], and [ForEach] closures exactly once (no
///   reactivity on the server).
/// - Escapes all text and attribute interpolations.
/// - Void elements are emitted without a closing tag.
///
/// This is the SSR / SSG / SEO backend. The same tree can also be mounted
/// to the real DOM via `mount()`.
String renderToHtml(BloomNode node) {
  final buf = StringBuffer();
  _render(node, buf);
  return buf.toString();
}

void _render(BloomNode node, StringBuffer buf) {
  switch (node) {
    case TextNode(:final text):
      buf.write(escapeHtml(text));

    case SvgNode(
        :final tag,
        :final text,
        :final className,
        :final style,
        :final attrs,
        :final children
      ):
      buf.write('<$tag');
      if (className != null && className.isNotEmpty) {
        buf.write(' class="${escapeHtml(className)}"');
      }
      if (style != null && style.isNotEmpty) {
        buf.write(' style="${escapeHtml(style)}"');
      }
      if (attrs != null) {
        for (final entry in attrs.entries) {
          buf.write(' ${entry.key}="${escapeHtml(entry.value)}"');
        }
      }
      buf.write('>');
      if (text != null) buf.write(escapeHtml(text));
      for (final c in children) {
        _render(c, buf);
      }
      buf.write('</$tag>');

    case ElNode(
        :final tag,
        :final text,
        :final className,
        :final style,
        :final attrs,
        :final children
      ):
      buf.write('<$tag');

      if (className != null && className.isNotEmpty) {
        buf.write(' class="${escapeHtml(className)}"');
      }
      if (style != null && style.isNotEmpty) {
        buf.write(' style="${escapeHtml(style)}"');
      }
      if (attrs != null) {
        for (final entry in attrs.entries) {
          buf.write(' ${entry.key}="${escapeHtml(entry.value)}"');
        }
      }

      final isVoid = _voidElements.contains(tag.toLowerCase());
      if (isVoid) {
        // Void elements cannot have content per spec — silently drop any.
        buf.write('>');
        return;
      }

      buf.write('>');

      if (text != null) buf.write(escapeHtml(text));
      for (final c in children) {
        _render(c, buf);
      }

      buf.write('</$tag>');

    case FragmentNode(:final children):
      for (final c in children) {
        _render(c, buf);
      }

    case LiveNode(:final builder):
      final inner = builder();
      _render(inner, buf);

    case ShowNode(:final child, :final fallback):
      if (node.when()) {
        _render(child, buf);
      } else if (fallback != null) {
        _render(fallback, buf);
      }

    case ForEachNode():
      for (final child in node.buildChildren()) {
        _render(child, buf);
      }

    case StyleNode(:final css):
      // CSS must not be HTML-escaped (quotes are valid inside it); only the
      // `</style>` close sequence is dangerous. Neutralize any `</`.
      buf.write('<style>${css.replaceAll('</', '<\\/')}</style>');

    case RawHtmlNode(:final html):
      // Trusted HTML passthrough — never feed this user input.
      buf.write(html);
  }
}

/// Convenience: render multiple roots (e.g. head + body fragments).
String renderToHtmlAll(List<BloomNode> nodes) {
  final buf = StringBuffer();
  for (final n in nodes) {
    _render(n, buf);
  }
  return buf.toString();
}
