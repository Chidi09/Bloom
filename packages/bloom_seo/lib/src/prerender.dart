import 'package:bloom_js_native/bloom_js_native.dart';

import 'head.dart';

/// Static-site prerender helper — runs the same descriptor tree server-side
/// via [renderToHtml] and wraps it in a full HTML document using [HeadManager].
///
/// ```dart
/// final head = HeadManager(initialTitle: 'Home');
/// final html = prerenderRoute(
///   body: Fragment(children: [H1(text: 'Hello')]),
///   head: head,
/// );
/// // html is a complete <!DOCTYPE html> document
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

/// Prerender multiple routes to a map of path → HTML.
///
/// Useful for SSG: write each value to `dist/<path>/index.html`.
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
