// Typed wrapper around `lenis` (installed via `bloom add npm:lenis` — see
// bloom.yaml / web/index.html). Loaded as an ES module through the import map
// in web/index.html; its bootstrap <script type="module"> assigns the
// default export to `window.Lenis` for this binding to find.
library;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('Lenis')
extension type _LenisJs._(JSObject _) implements JSObject {
  external _LenisJs([JSObject? options]);
  external void raf(num time);
  external void scrollTo(JSAny target, [JSObject? options]);
  external void destroy();
}

/// Smooth momentum scroll coordinator powered by Lenis.
class LenisScroll {
  static _LenisJs? _instance;

  /// Initializes the global Lenis smooth scrolling instance with auto-RAF.
  static void init() {
    try {
      final options = <String, dynamic>{
        'autoRaf': true,
        'duration': 1.2,
        'smoothWheel': true,
      }.jsify() as JSObject;
      _instance = _LenisJs(options);
    } catch (_) {
      // Lenis is a progressive enhancement — falls back to native browser scrolling.
    }
  }

  /// Smoothly scrolls the viewport to [targetSelector] (e.g. '#projects', '#contact').
  static void scrollTo(String targetSelector, {double offset = -64.0}) {
    try {
      if (_instance != null) {
        final options = <String, dynamic>{
          'offset': offset,
          'duration': 1.0,
        }.jsify() as JSObject;
        _instance!.scrollTo(targetSelector.toJS, options);
        return;
      }
    } catch (_) {}

    // Fallback to native browser smooth scrolling
    try {
      final target = web.document.querySelector(targetSelector);
      if (target != null) {
        target.scrollIntoView(
          web.ScrollIntoViewOptions(
            behavior: 'smooth',
            block: 'start',
          ),
        );
      }
    } catch (_) {}
  }

  /// Destroys the active Lenis instance when unmounting.
  static void destroy() {
    try {
      _instance?.destroy();
      _instance = null;
    } catch (_) {}
  }
}
