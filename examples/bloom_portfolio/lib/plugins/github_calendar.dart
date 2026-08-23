// Typed wrapper around `github-calendar` (installed via
// `bloom add npm:github-calendar` — see bloom.yaml / web/index.html). Loaded
// as an ES module through the import map in web/index.html; its bootstrap
// <script type="module"> assigns the default export to `window.GitHubCalendar`
// for this binding to find.
library;

import 'dart:js_interop';
// For JSObject.setProperty -- the `proxy` callback has to be attached after
// jsify(), which cannot convert a Dart closure.
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

@JS('GitHubCalendar')
external JSPromise? _gitHubCalendar(
  JSAny container,
  JSString username, [
  JSObject? options,
]);

/// Fetches [url] and resolves with the response body as text.
///
/// This is the shape `github-calendar` expects from its `proxy` option: a
/// function of the username that resolves to the contributions HTML.
Future<JSAny?> _fetchText(String url) async {
  final response = await web.window.fetch(url.toJS).toDart;
  if (!response.ok) {
    throw StateError('GitHub calendar proxy returned ${response.status} for $url');
  }
  return await response.text().toDart;
}

/// Renders an interactive, responsive GitHub contribution heat-map into a DOM element.
class GitHubCalendarPlugin {
  /// Fetches and renders public commit history for [username] into [container].
  ///
  /// [proxyPathPrefix] replaces the library's built-in fetch of
  /// `api.bloggify.net`, which answers 403 with no `Access-Control-Allow-Origin`
  /// and so fails for every username in a browser. Requests are instead sent to
  /// our own origin under this prefix, where the Bloom dev proxy forwards them
  /// to github.com server-side — no CORS involved, and the library receives
  /// exactly the HTML its parser expects. See the `proxy:` block in bloom.yaml.
  static Future<bool> render(
    web.Element container,
    String username, {
    bool responsive = true,
    bool tooltips = true,
    String? summaryText,
    String? proxyPathPrefix,
  }) async {
    try {
      final options = <String, dynamic>{
        'responsive': responsive,
        'tooltips': tooltips,
        if (summaryText != null) 'summary_text': summaryText,
      }.jsify() as JSObject;

      if (proxyPathPrefix != null) {
        // Set after jsify(): a Dart closure cannot survive jsify(), it has to
        // be converted with .toJS and attached to the object directly.
        options.setProperty(
          'proxy'.toJS,
          ((JSString user) =>
                  _fetchText('$proxyPathPrefix/users/${user.toDart}/contributions').toJS)
              .toJS,
        );
      }

      final promise = _gitHubCalendar(container, username.toJS, options);
      if (promise != null) {
        await promise.toDart;
      }
      return true;
    } catch (_) {
      // Non-critical showcase widget — degraded gracefully handled by section
      return false;
    }
  }
}
