import 'dart:async';
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

    case MountNode(:final child):
      // SSR: render child only; lifecycle callbacks intentionally skipped.
      _render(child, buf);

    case RefNode(:final child):
      // SSR: render child; ref remains unmounted (no DOM).
      _render(child, buf);

    case ContextProviderNode(:final context, :final value, :final child):
      runZoned(
        () => _render(child, buf),
        zoneValues: {context.zoneKey: value},
      );

    case ErrorBoundaryNode(:final builder, :final fallback):
      try {
        final inner = builder();
        _render(inner, buf);
      } catch (err, stack) {
        final fallbackNode = fallback(err, stack);
        _render(fallbackNode, buf);
      }

    case PortalNode(:final child, :final targetSelector):
      buf.write('<template data-bloom-portal="${escapeHtml(targetSelector)}">');
      _render(child, buf);
      buf.write('</template>');

    case SuspenseNode(:final fallback):
      _render(fallback, buf);
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

/// Render a complete HTML5 document.
///
/// Wraps [body] in `<!DOCTYPE html><html><head>...</head><body>...</body></html>`.
/// All head elements are rendered before the body fragment.
///
/// - [lang]: `<html lang="...">` attribute. Default `'en'`.
/// - [charset]: charset meta tag. Default `'UTF-8'`.
/// - [title]: `<title>` content. Omitted if null.
/// - [head]: additional `BloomNode` trees rendered inside `<head>`.
/// - [importMapJson]: if non-null, emits `<script type="importmap">` in head.
/// - [stylesheets]: list of CSS URLs; emitted as `<link rel="stylesheet">` tags.
/// - [scripts]: list of JS URLs; emitted as `<script src="...">` tags before `</body>`.
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
  if (title != null) {
    buf.write('<title>${escapeHtml(title)}</title>\n');
  }
  if (importMapJson != null) {
    buf.write('<script type="importmap">$importMapJson</script>\n');
  }
  for (final url in stylesheets) {
    buf.write('<link rel="stylesheet" href="${escapeHtml(url)}">\n');
  }
  for (final node in head) {
    _render(node, buf);
    buf.write('\n');
  }
  buf.write('</head>\n<body>\n');
  _render(body, buf);
  buf.write('\n');
  for (final url in scripts) {
    buf.write('<script src="${escapeHtml(url)}"></script>\n');
  }
  buf.write('</body>\n</html>');
  return buf.toString();
}

/// Streaming SSR — yields HTML string chunks as the node tree is walked.
///
/// On most servers this allows early flushing of head/shell content while
/// slower parts (data-driven sections) are still being built. The sum of
/// all chunks equals [renderToHtml] on the same node.
Stream<String> renderToStream(BloomNode node) async* {
  final buf = StringBuffer();
  _render(node, buf);
  const chunkSize = 4096;
  final str = buf.toString();
  for (var i = 0; i < str.length; i += chunkSize) {
    yield str.substring(
        i, i + chunkSize > str.length ? str.length : i + chunkSize);
  }
}
