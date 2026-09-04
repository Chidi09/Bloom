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

final _tagNameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_.:-]*$');
final _attrNameRegex = RegExp(r'^[a-zA-Z0-9_.:-]+$');

void _validateTagName(String tag) {
  if (!_tagNameRegex.hasMatch(tag)) {
    throw ArgumentError(
      'Invalid tag name "$tag" in SSR rendering. '
      'Tag names must not be empty and may only contain ASCII letters, digits, hyphen, underscore, colon, and period, starting with a letter.',
    );
  }
}

void _validateAttributeName(String name) {
  if (!_attrNameRegex.hasMatch(name)) {
    throw ArgumentError(
      'Invalid attribute name "$name" in SSR rendering. '
      'Attribute names must not be empty and may only contain ASCII letters, digits, hyphen, underscore, colon, and period.',
    );
  }
}

/// Escapes special HTML characters in text content and attribute values to prevent XSS.
///
/// Encodes `&` (`&amp;`), `<` (`&lt;`), `>` (`&gt;`), `"` (`&quot;`), and `'` (`&#x27;`).
/// This function is applied automatically during SSR rendering for all element text nodes,
/// class names, style strings, and attribute values.
///
/// ```dart
/// final safe = escapeHtml('<script>alert("xss")</script>');
/// // Returns: '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'
/// ```
String escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#x27;');
}

/// Renders a [BloomNode] descriptor tree synchronously to an HTML string.
///
/// This is the primary server-side rendering (SSR) and static site generation (SSG) entry point.
/// It executes entirely in pure Dart and requires no browser DOM, Flutter runtime, or JS interop.
///
/// ### Reactive Node Degradation during SSR
/// - **[LiveNode] / [Live]**: Evaluates its builder closure exactly once during the render pass.
///   No signal subscriptions or reactive effect listeners are retained on the server.
/// - **[ShowNode] / [Show]**: Evaluates its `when()` predicate closure once. Renders `child` if
///   true or `fallback` if false.
/// - **[ForEachNode] / [ForEach]**: Evaluates its `items()` collection closure once and renders
///   each item via `builder` to static HTML.
/// - **[MountNode] / [Mount]**: Renders its `child` directly; lifecycle callbacks (`onMount`,
///   `onUnmount`) are ignored during SSR.
/// - **[RefNode]**: Renders its `child`; DOM references are not attached during SSR.
/// - **[ContextProviderNode]**: Provides ambient context values down the subtree using Dart Zones.
/// - **[ErrorBoundaryNode]**: Renders `builder()`; if an exception is thrown, synchronously renders
///   `fallback(error, stack)`.
/// - **[PortalNode]**: Emits `<template data-bloom-portal="...">` enclosing the portal subtree.
/// - **[SuspenseNode]**: In synchronous [renderToHtml], renders the `fallback` node only.
///   For asynchronous out-of-order streaming of Suspense boundaries, use [renderToStreamWithSuspense].
///
/// ### Tag and Attribute Validation & Security
/// - Tag names and attribute names are strictly validated against alphanumeric identifier patterns
///   and will throw an [ArgumentError] if an invalid name is encountered.
/// - Text content, class names, styles, and attribute values are automatically escaped via [escapeHtml].
/// - Void elements (e.g. `<img>`, `<input>`, `<br>`, `<meta>`, `<link>`) are emitted without closing tags.
///
/// ```dart
/// final html = renderToHtml(
///   Div(
///     className: 'user-profile',
///     children: [
///       const H1(text: 'Account Details'),
///       P(text: 'Welcome, Alice'),
///     ],
///   ),
/// );
/// ```
String renderToHtml(BloomNode node) {
  return runZoned(() {
    final buf = StringBuffer();
    _render(node, buf);
    return buf.toString();
  }, zoneValues: {_keyframesZoneKey: <String>{}});
}

/// Zone key scoping animation-keyframe deduplication to a single top-level
/// render pass. A previous global mutable set was shared across concurrent
/// SSR streams: one stream's `clear()`/entries corrupted another's,
/// dropping or duplicating `@keyframes` blocks. Each public entrypoint runs
/// in its own zone with a fresh set; async Suspense continuations inherit
/// the zone they were scheduled in, so concurrent streams stay isolated.
const _keyframesZoneKey = #bloom.keyframes;

/// The keyframe-name set for the current render pass, or the shared fallback
/// when rendering outside a public entrypoint (private [_render] only).
Set<String> get _activeKeyframeNames =>
    Zone.current[_keyframesZoneKey] as Set<String>? ?? _emittedKeyframeNames;

/// Tracks animation names whose `@keyframes` block has already been emitted.
///
/// Legacy shared fallback for [_activeKeyframeNames]; public entrypoints no
/// longer use it directly (they run zoned with a fresh set).
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
      _validateTagName(tag);
      buf.write('<$tag');
      if (className != null && className.isNotEmpty) {
        buf.write(' class="${escapeHtml(className)}"');
      }
      if (style != null && style.isNotEmpty) {
        buf.write(' style="${escapeHtml(style)}"');
      }
      if (attrs != null) {
        for (final entry in attrs.entries) {
          _validateAttributeName(entry.key);
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
      _validateTagName(tag);
      buf.write('<$tag');

      if (className != null && className.isNotEmpty) {
        buf.write(' class="${escapeHtml(className)}"');
      }
      if (style != null && style.isNotEmpty) {
        buf.write(' style="${escapeHtml(style)}"');
      }
      if (attrs != null) {
        for (final entry in attrs.entries) {
          _validateAttributeName(entry.key);
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
      if (_activeKeyframeNames.add(animation.name)) {
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

/// Renders multiple [BloomNode] root fragments sequentially into a single HTML string.
///
/// Useful for concatenating document fragments (such as `<head>` metadata nodes and body content)
/// in a single SSR pass. Clears animation keyframe deduplication state prior to rendering.
///
/// ```dart
/// final html = renderToHtmlAll([
///   const StyleNode('body { margin: 0; }'),
///   const Header(text: 'Bloom Header'),
///   const Main(text: 'Main content'),
/// ]);
/// ```
String renderToHtmlAll(List<BloomNode> nodes) {
  return runZoned(() {
    final buf = StringBuffer();
    for (final n in nodes) {
      _render(n, buf);
    }
    return buf.toString();
  }, zoneValues: {_keyframesZoneKey: <String>{}});
}

/// Renders a complete HTML5 document wrapping [body] with standard boilerplate.
///
/// Produces a complete `<!DOCTYPE html><html lang="...">...</html>` string with
/// metadata tags, stylesheets, custom [head] elements, [body] content, and [scripts].
///
/// - [body]: The main content [BloomNode] placed inside the `<body>` element.
/// - [lang]: Value for the `<html lang="...">` attribute. Defaults to `'en'`.
/// - [charset]: Charset meta tag value (`<meta charset="...">`). Defaults to `'UTF-8'`.
/// - [title]: Page title placed in `<title>`. Omitted if `null`.
/// - [head]: Additional [BloomNode] descriptors rendered directly inside `<head>`.
/// - [importMapJson]: Optional JSON string emitted inside `<script type="importmap">` in `<head>`.
/// - [stylesheets]: List of CSS stylesheet URLs emitted as `<link rel="stylesheet">` tags in `<head>`.
/// - [scripts]: List of JavaScript URLs emitted as `<script src="...">` tags at the bottom of `<body>`.
///
/// ```dart
/// final html = renderToDocument(
///   Div(className: 'app', text: 'Welcome to Bloom'),
///   title: 'Bloom App',
///   stylesheets: ['/styles/app.css'],
///   scripts: ['/main.dart.js'],
/// );
/// ```
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
  return runZoned(() {
    final buf = StringBuffer();
    buf.write('<!DOCTYPE html>\n<html lang="${escapeHtml(lang)}">\n<head>\n');
    buf.write('<meta charset="${escapeHtml(charset)}">\n');
    buf.write(
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n');
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
  }, zoneValues: {_keyframesZoneKey: <String>{}});
}

/// Synchronously renders [node] to an HTML string and streams the output in fixed 4KB chunks.
///
/// Allows HTTP servers to begin flushing initial bytes to the network early. The concatenation
/// of all emitted chunks is identical to calling [renderToHtml] directly on [node].
///
/// For asynchronous streaming with out-of-order [Suspense] resolution, use [renderToStreamWithSuspense].
///
/// ```dart
/// await for (final chunk in renderToStream(App())) {
///   httpResponse.write(chunk);
/// }
/// ```
Stream<String> renderToStream(BloomNode node) {
  // Rendered eagerly so keyframe deduplication is scoped to this call's own
  // zone even when multiple streams are listened to concurrently; only the
  // 4KB chunking below is lazy.
  final html = renderToHtml(node);
  const chunkSize = 4096;
  Iterable<String> chunks() sync* {
    for (var i = 0; i < html.length; i += chunkSize) {
      yield html.substring(
          i, i + chunkSize > html.length ? html.length : i + chunkSize);
    }
  }

  return Stream.fromIterable(chunks());
}

/// Progressively streams HTML with out-of-order resolution for asynchronous [Suspense] boundaries.
///
/// Flushes the initial document shell immediately as its first stream chunk, emitting
/// fallback placeholder elements (`<div id="bloom-suspense-N">...</div>`) for every [SuspenseNode]
/// located anywhere in the tree (including deeply nested children).
///
/// As each boundary's async `resource` future resolves, this function streams an inline `<script>`
/// snippet that replaces the placeholder `<div>` with the resolved HTML content in the client DOM
/// via `outerHTML`. Boundaries stream in whatever order they resolve, rather than source order.
///
/// If an async resource fails and [SuspenseNode.errorBuilder] is provided, the error subtree is
/// rendered and streamed; if no error builder is configured, the initial fallback element remains.
///
/// ```dart
/// final stream = renderToStreamWithSuspense(
///   Div(
///     children: [
///       const H1(text: 'Live Dashboard'),
///       Suspense<UserProfile>(
///         resource: fetchUserProfile,
///         fallback: const Div(text: 'Loading profile...'),
///         builder: (profile) => Div(text: 'Hello, ${profile.name}'),
///       ),
///     ],
///   ),
/// );
/// await for (final chunk in stream) {
///   httpResponse.write(chunk);
/// }
/// ```
Stream<String> renderToStreamWithSuspense(BloomNode node) {
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
      } catch (err, stack) {
        if (boundary.errorBuilder != null) {
          try {
            final errorNode = boundary.errorBuilder!(err, stack);
            final innerBuf = StringBuffer();
            _render(errorNode, innerBuf, onSuspense);
            final safeJson = jsonEncode(innerBuf.toString())
                .replaceAll('</script', '<\\/script');
            if (!controller.isClosed) {
              controller.add(
                '<script>(function(){var e=document.getElementById("$id");'
                'if(e){e.outerHTML=$safeJson;}})();</script>',
              );
            }
          } catch (_) {}
        }
        // Resource rejected — if no errorBuilder was supplied (or if it threw),
        // the fallback already flushed in the shell stands as the final content.
      } finally {
        outstanding--;
        maybeClose();
      }
    }();
  }

  // The shell renders eagerly inside a fresh keyframe zone so concurrent
  // streams cannot corrupt each other's `@keyframes` deduplication state.
  // Async Suspense continuations scheduled above inherit this zone, keeping
  // late-resolved patches scoped to their own stream. Only the chunk
  // delivery in [tail] below is lazy.
  late final String shell;
  runZoned(() {
    _render(node, shellBuf, onSuspense);
    shellDone = true;
    // Closes immediately if no boundary was encountered (outstanding stays
    // 0). If boundaries resolved synchronously-fast enough to have already
    // closed the controller by this point, buffered events are still
    // delivered once `controller.stream` gets its listener below — never
    // skip the subscription.
    maybeClose();
    shell = shellBuf.toString();
  }, zoneValues: {_keyframesZoneKey: <String>{}});
  final shellSnapshot = shell;
  Stream<String> tail() async* {
    yield shellSnapshot;
    yield* controller.stream;
  }

  return tail();
}
