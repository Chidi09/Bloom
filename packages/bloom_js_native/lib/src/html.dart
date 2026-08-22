import 'dart:async';
import 'dart:convert';
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
  _emittedKeyframeNames.clear();
  final buf = StringBuffer();
  _render(node, buf);
  return buf.toString();
}

/// Tracks animation names whose `@keyframes` block has already been emitted
/// in the current top-level render pass. Cleared at the start of every
/// public render entrypoint.
final Set<String> _emittedKeyframeNames = {};

/// Hook invoked by [_render] whenever it encounters a [SuspenseNode], used
/// by [renderToStreamWithSuspense] to progressively stream boundaries that
/// are nested inside [ElNode]/[FragmentNode] children rather than only at
/// the root. When null, [_render] falls back to its default synchronous
/// behavior (render the fallback only).
typedef _SuspenseHook = void Function(SuspenseNode<dynamic> node, StringBuffer buf);

void _render(BloomNode node, StringBuffer buf, [_SuspenseHook? onSuspense]) {
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
        _render(c, buf, onSuspense);
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
        _render(c, buf, onSuspense);
      }

      buf.write('</$tag>');

    case FragmentNode(:final children):
      for (final c in children) {
        _render(c, buf, onSuspense);
      }

    case LiveNode(:final builder):
      final inner = builder();
      _render(inner, buf, onSuspense);

    case MemoNode(:final dependency, :final builder):
      final value = dependency();
      _render(builder(value), buf, onSuspense);

    case ShowNode(:final child, :final fallback):
      if (node.when()) {
        _render(child, buf, onSuspense);
      } else if (fallback != null) {
        _render(fallback, buf, onSuspense);
      }

    case ForEachNode():
      for (final child in node.buildChildren()) {
        _render(child, buf, onSuspense);
      }

    case StyleNode(:final css):
      // CSS must not be HTML-escaped (quotes are valid inside it); only the
      // `</style>` close sequence is dangerous. Neutralize any `</`.
      buf.write('<style>${css.replaceAll('</', '<\\/')}</style>');

    case RawHtmlNode(:final html):
      // Trusted HTML passthrough — never feed this user input.
      buf.write(html);

    case AnimatedNode(:final child, :final animation):
      if (_emittedKeyframeNames.add(animation.name)) {
        buf.write('<style>${animation.toKeyframesCSS()}</style>');
      }
      buf.write('<div style="${animation.toInlineStyle()}">');
      _render(child, buf, onSuspense);
      buf.write('</div>');

    case MountNode(:final child):
      // SSR: render child only; lifecycle callbacks intentionally skipped.
      _render(child, buf, onSuspense);

    case RefNode(:final child):
      // SSR: render child; ref remains unmounted (no DOM).
      _render(child, buf, onSuspense);

    case ContextProviderNode(:final context, :final value, :final child):
      runZoned(
        () => _render(child, buf, onSuspense),
        zoneValues: {context.zoneKey: value},
      );

    case ErrorBoundaryNode(:final builder, :final fallback):
      try {
        final inner = builder();
        _render(inner, buf, onSuspense);
      } catch (err, stack) {
        final fallbackNode = fallback(err, stack);
        _render(fallbackNode, buf, onSuspense);
      }

    case PortalNode(:final child, :final targetSelector):
      buf.write('<template data-bloom-portal="${escapeHtml(targetSelector)}">');
      _render(child, buf, onSuspense);
      buf.write('</template>');

    case SuspenseNode(:final fallback):
      if (onSuspense != null) {
        onSuspense(node, buf);
      } else {
        _render(fallback, buf, onSuspense);
      }
  }
}

/// Convenience: render multiple roots (e.g. head + body fragments).
String renderToHtmlAll(List<BloomNode> nodes) {
  _emittedKeyframeNames.clear();
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
  _emittedKeyframeNames.clear();
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
  _emittedKeyframeNames.clear();
  final buf = StringBuffer();
  _render(node, buf);
  const chunkSize = 4096;
  final str = buf.toString();
  for (var i = 0; i < str.length; i += chunkSize) {
    yield str.substring(
        i, i + chunkSize > str.length ? str.length : i + chunkSize);
  }
}

/// True out-of-order streaming SSR, analogous to React's
/// `renderToPipeableStream`/`renderToReadableStream`.
///
/// Unlike [renderToStream] (which fully renders the tree synchronously
/// before chunking the finished string), this function flushes the shell
/// — including each top-level [SuspenseNode]'s `fallback` — as its first
/// chunk, then streams a `<script>` replacement snippet for each Suspense
/// boundary as its `resource` resolves, in resolution order (not
/// necessarily source order). This lets the initial paint reach the
/// client before slow data-dependent sections are ready.
///
/// Progressive support: every [SuspenseNode] in the tree gets a streamed
/// replacement chunk — the root itself, a direct child of a root
/// [FragmentNode], or one nested arbitrarily deep inside [ElNode]/
/// [FragmentNode] (and other passthrough wrapper) children. Boundaries are
/// discovered via a hook threaded through [_render]'s normal recursive
/// walk, so no rendering logic is duplicated. Content resolved by a
/// boundary's `builder` is itself walked with the same hook, so a
/// [SuspenseNode] nested inside resolved async content also streams.
Stream<String> renderToStreamWithSuspense(BloomNode node) async* {
  _emittedKeyframeNames.clear();

  final shellBuf = StringBuffer();
  final controller = StreamController<String>();
  var outstanding = 0;
  var shellDone = false;
  var counter = 0;

  void maybeClose() {
    if (shellDone && outstanding == 0 && !controller.isClosed) {
      controller.close();
    }
  }

  void onSuspense(SuspenseNode<dynamic> boundary, StringBuffer buf) {
    final id = 'bloom-suspense-${counter++}';
    buf.write('<div id="$id">');
    _render(boundary.fallback, buf, onSuspense);
    buf.write('</div>');
    // Routed through a `dynamic`-typed reference so `resource`/`builder`
    // are invoked via fully dynamic dispatch. Reading them through any
    // statically-typed `SuspenseNode<...>` view (even `<dynamic>`) trips
    // Dart's generic covariance check — the real object is
    // `SuspenseNode<T>` for some concrete `T`, and a `BloomNode
    // Function(T)` is genuinely not a `BloomNode Function(dynamic)` by
    // Dart's static function-subtyping rules. Dynamic dispatch skips
    // that check and calls correctly regardless of `T`.
    final dynamic dynBoundary = boundary;
    outstanding++;
    () async {
      try {
        final data = await dynBoundary.resource();
        final resolved = dynBoundary.builder(data) as BloomNode;
        final innerBuf = StringBuffer();
        // Nested boundaries discovered here (from resolved async content)
        // register themselves via the same [onSuspense] hook, incrementing
        // [outstanding] before this task's own decrement below — so the
        // stream never closes early while a nested boundary is pending.
        _render(resolved, innerBuf, onSuspense);
        final safeJson = jsonEncode(innerBuf.toString())
            .replaceAll('</script', '<\\/script');
        if (!controller.isClosed) {
          controller.add(
            '<script>(function(){var e=document.getElementById("$id");'
            'if(e){e.outerHTML=$safeJson;}})();</script>',
          );
        }
      } catch (_) {
        // Resource rejected — the fallback already flushed in the shell
        // stands as the final content for this boundary.
      } finally {
        outstanding--;
        maybeClose();
      }
    }();
  }

  _render(node, shellBuf, onSuspense);
  shellDone = true;
  // Closes immediately if no boundary was encountered (outstanding stays 0).
  // If boundaries resolved synchronously-fast enough to have already closed
  // the controller by this point, buffered events are still delivered once
  // `controller.stream` gets its listener below — never skip the `yield*`.
  maybeClose();

  yield shellBuf.toString();
  yield* controller.stream;
}
