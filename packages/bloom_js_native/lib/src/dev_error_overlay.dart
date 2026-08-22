// lib/src/dev_error_overlay.dart
//
// Dev-mode error overlay content generation, analogous to React/Vite's
// full-screen "red screen of death". Pure string generation — no DOM
// manipulation — so it is unit-testable on the VM and reusable by any
// host (browser mount, dev server middleware injecting into an HTML
// response, a CLI reporter, etc.).
import 'dart:convert';

/// Renders a self-contained, inline-styled HTML fragment describing
/// [error]/[stackTrace] for display during development. The returned
/// string has no external CSS/JS dependencies and is safe to inject
/// directly into a page (e.g. appended to `document.body`).
///
/// [componentName] optionally names the component/route where the error
/// originated, shown as a subtitle. [sourceHint] optionally shows a
/// file/line reference (e.g. `'lib/pages/home.dart:42'`).
String renderDevErrorOverlay(
  Object error,
  StackTrace stackTrace, {
  String? componentName,
  String? sourceHint,
}) {
  final title = _escapeHtml(error.toString());
  final stack = _escapeHtml(stackTrace.toString());
  final subtitleParts = <String>[
    if (componentName != null) 'in $componentName',
    if (sourceHint != null) 'at $sourceHint',
  ];
  final subtitle = subtitleParts.isEmpty ? '' : _escapeHtml(subtitleParts.join(' '));

  return '''
<div data-bloom-dev-error-overlay="true" style="position:fixed;inset:0;z-index:2147483647;background:rgba(24,8,8,0.96);color:#f5e6e6;font-family:ui-monospace,SFMono-Regular,Consolas,Menlo,monospace;padding:32px;overflow:auto;box-sizing:border-box;">
  <div style="max-width:900px;margin:0 auto;">
    <div style="font-size:12px;letter-spacing:0.08em;text-transform:uppercase;color:#ff8a8a;margin-bottom:8px;">Unhandled Error</div>
    <div style="font-size:20px;font-weight:600;line-height:1.4;margin-bottom:4px;white-space:pre-wrap;">$title</div>
    ${subtitle.isEmpty ? '' : '<div style="font-size:14px;color:#e0b3b3;margin-bottom:20px;">$subtitle</div>'}
    <pre style="background:rgba(0,0,0,0.35);border:1px solid rgba(255,255,255,0.08);border-radius:8px;padding:16px;font-size:12px;line-height:1.6;white-space:pre-wrap;overflow-x:auto;">$stack</pre>
  </div>
</div>
''';
}

/// Renders [renderDevErrorOverlay]'s content as a JSON payload instead of
/// HTML — useful for a dev server to push over a WebSocket/SSE channel to
/// a client-side overlay renderer rather than injecting HTML directly.
String renderDevErrorOverlayJson(
  Object error,
  StackTrace stackTrace, {
  String? componentName,
  String? sourceHint,
}) {
  return jsonEncode({
    'type': 'bloom-dev-error',
    'message': error.toString(),
    'stack': stackTrace.toString(),
    if (componentName != null) 'componentName': componentName,
    if (sourceHint != null) 'sourceHint': sourceHint,
  });
}

String _escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
