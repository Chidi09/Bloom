import 'package:bloom_js_native/bloom_js_native.dart';

import 'head.dart';

/// Prerenders a pure Dart [BloomNode] UI tree to a complete static HTML document.
///
/// Evaluates the [body] component tree server-side via [renderToHtml],
/// synchronously resolving reactive descriptor nodes (including `Live`, `Show`,
/// and `ForEach`), and wraps the resulting markup in a standard `<!DOCTYPE html>` shell.
///
/// ### Head Management Integration
///
/// - If [head] is provided, syncs `head.lang.value = lang` and delegates to
///   [HeadManager.wrapDocument], injecting reactive `<title>`, `<meta>`,
///   Open Graph, and Twitter tags into `<head>`.
/// - If [head] is `null`, generates a lightweight HTML5 document with charset
///   and viewport meta tags.
/// - [extraHead] can be used to inject additional static tags (e.g. font links,
///   stylesheets, or [JsonLd.toScriptTag] structured data).
///
/// ### Example
///
/// ```dart
/// final head = HeadManager(
///   initialTitle: 'Bloom Documentation',
///   initialDescription: 'Fast, reactive web apps in pure Dart.',
/// );
///
/// final html = prerenderRoute(
///   body: Div(
///     children: [
///       H1(text: 'Welcome to Bloom'),
///       Paragraph(text: 'Build modern full-stack web applications.'),
///     ],
///   ),
///   head: head,
///   extraHead: '<link rel="stylesheet" href="/main.css">',
///   lang: 'en',
/// );
/// ```
String prerenderRoute({
  required BloomNode body,
  HeadManager? head,
  String? extraHead,
  String lang = 'en',
}) {
  final bodyHtml = renderToHtml(body);
  if (head != null) {
    // Ensure lang is synced.
    head.lang.value = lang;
    return head.wrapDocument(bodyHtml, extraHead: extraHead);
  }
  final extra = extraHead != null ? '\n$extraHead' : '';
  return '''<!DOCTYPE html>
<html lang="$lang">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">$extra
</head>
<body>
$bodyHtml
</body>
</html>''';
}

/// Prerenders multiple application routes to a map of route path to full HTML string.
///
/// Designed for Static Site Generation (SSG) workflows where each generated
/// HTML string can be written to disk (e.g. `dist/$path/index.html`).
///
/// - [routes]: Map of route paths (e.g. `'/'`, `'/about'`) to their root [BloomNode] UI tree.
/// - [headFor]: Optional factory callback returning a customized [HeadManager] per route.
/// - [extraHeadFor]: Optional callback returning additional `<head>` tags (e.g. per-page JSON-LD or CSS links).
///
/// Returns a `Map<String, String>` where each key is a route path and each value
/// is the corresponding complete `<!DOCTYPE html>` document.
///
/// ### Example
///
/// ```dart
/// final siteHtml = prerenderRoutes(
///   {
///     '/': H1(text: 'Home Page'),
///     '/about': H1(text: 'About Us'),
///     '/pricing': H1(text: 'Pricing Plans'),
///   },
///   headFor: (path) => HeadManager(initialTitle: 'Site - $path'),
/// );
///
/// for (final entry in siteHtml.entries) {
///   print('Route ${entry.key} -> ${entry.value.length} bytes');
/// }
/// ```
Map<String, String> prerenderRoutes(
  Map<String, BloomNode> routes, {
  HeadManager Function(String path)? headFor,
  String Function(String path)? extraHeadFor,
}) {
  final out = <String, String>{};
  for (final entry in routes.entries) {
    final head = headFor?.call(entry.key);
    final extra = extraHeadFor?.call(entry.key);
    out[entry.key] = prerenderRoute(
      body: entry.value,
      head: head,
      extraHead: extra,
    );
  }
  return out;
}
