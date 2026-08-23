// Typed wrapper around `typed.js` (installed via `bloom add npm:typed.js` — see
// bloom.yaml / web/index.html). Loaded as an ES module through the import map
// in web/index.html; its bootstrap <script type="module"> assigns the
// default export to `window.Typed` for this binding to find.
library;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('Typed')
extension type _TypedJs._(JSObject _) implements JSObject {
  external _TypedJs(JSAny elementOrSelector, JSObject options);
  external void destroy();
  external void stop();
  external void start();
  external void reset();
}

/// Typewriter animation effect cycling through developer roles in the hero section.
class TypedEffect {
  final _TypedJs? _instance;

  TypedEffect._(this._instance);

  /// Initializes and mounts a typewriter animation into [element].
  static TypedEffect? start(
    web.Element element, {
    required List<String> strings,
    int typeSpeed = 45,
    int backSpeed = 25,
    int backDelay = 1800,
    int startDelay = 400,
    bool loop = true,
    bool showCursor = true,
    String cursorChar = '▎',
  }) {
    try {
      final options = <String, dynamic>{
        'strings': strings,
        'typeSpeed': typeSpeed,
        'backSpeed': backSpeed,
        'backDelay': backDelay,
        'startDelay': startDelay,
        'loop': loop,
        'showCursor': showCursor,
        'cursorChar': cursorChar,
      }.jsify() as JSObject;

      final instance = _TypedJs(element, options);
      return TypedEffect._(instance);
    } catch (_) {
      // In case Typed.js fails to initialize, fallback to static text in element
      try {
        if (strings.isNotEmpty) {
          element.textContent = strings.first;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Disposes the Typed.js instance and removes the cursor element from the DOM.
  void destroy() {
    try {
      _instance?.destroy();
    } catch (_) {}
  }
}
