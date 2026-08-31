import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'toast_system.dart';

bool _initialized = false;

/// Browser implementation: bridges the DOM-level `bloom:toast` CustomEvents
/// dispatched by copy-to-clipboard affordances and demo confirm buttons into
/// the signal-driven toast system.
///
/// Registered from `siteToastViewport()` (mounted once at the app root in
/// main.dart) so a single listener lives for the app lifetime.
void ensureToastEventBridge() {
  if (_initialized) return;
  _initialized = true;
  web.window.addEventListener(
    'bloom:toast',
    ((web.Event event) {
      try {
        final detail = (event as web.CustomEvent).detail;
        if (detail == null) return;
        final data = detail.dartify();
        if (data is Map) {
          showToast(
            data['title']?.toString() ?? 'Notification',
            data['message']?.toString() ?? '',
            type: data['type']?.toString() ?? 'purple',
          );
        }
      } catch (_) {}
    }).toJS,
  );
}