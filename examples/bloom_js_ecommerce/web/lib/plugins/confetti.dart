// Typed wrapper around the `canvas-confetti` NPM package (installed via
// `bloom add npm:canvas-confetti` — see bloom.yaml / web/vendor/). The real
// npm package is loaded as an ES module through the import map in
// web/index.html, whose bootstrap <script type="module"> assigns its
// default export to `window.canvas_confetti` for this binding to find.
import 'dart:js_interop';

@JS('canvas_confetti')
external void _confetti(JSAny? options);

/// Fires a short confetti burst — used to celebrate a successful checkout.
class Confetti {
  static void burst({double x = 0.5, double y = 0.6}) {
    try {
      final opts = <String, dynamic>{
        'particleCount': 80,
        'spread': 75,
        'origin': {'x': x, 'y': y},
        'colors': ['#6366F1', '#10B981', '#F4F4F5'],
        'disableForReducedMotion': true,
      }.jsify();
      _confetti(opts);
    } catch (_) {
      // Non-critical UI flourish — never let a JS interop failure break checkout.
    }
  }
}
