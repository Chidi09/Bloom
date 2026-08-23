// Typed wrapper around `github-calendar` (installed via
// `bloom add npm:github-calendar` — see bloom.yaml / web/index.html). Loaded
// as an ES module through the import map in web/index.html; its bootstrap
// <script type="module"> assigns the default export to `window.GitHubCalendar`
// for this binding to find.
library;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('GitHubCalendar')
external JSPromise? _gitHubCalendar(
  JSAny container,
  JSString username, [
  JSObject? options,
]);

/// Renders an interactive, responsive GitHub contribution heat-map into a DOM element.
class GitHubCalendarPlugin {
  /// Fetches and renders public commit history for [username] into [container].
  static Future<bool> render(
    web.Element container,
    String username, {
    bool responsive = true,
    bool tooltips = true,
    String? summaryText,
  }) async {
    try {
      final options = <String, dynamic>{
        'responsive': responsive,
        'tooltips': tooltips,
        if (summaryText != null) 'summary_text': summaryText,
      }.jsify() as JSObject;

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
