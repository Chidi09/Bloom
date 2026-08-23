// Typed wrapper around `canvas-confetti` (installed via
// `bloom add npm:canvas-confetti` — see bloom.yaml / web/index.html). Loaded
// as an ES module through the import map in web/index.html; its bootstrap
// <script type="module"> assigns the default export to `window.canvas_confetti`
// for this binding to find.
library;

import 'dart:js_interop';

@JS('canvas_confetti')
external void _confetti(JSAny? options);

/// Particle confetti bursts to celebrate user interactions (e.g. form submission).
class Confetti {
  /// Fires a burst of particles from normalized coordinate ([x], [y]).
  static void burst({double x = 0.5, double y = 0.6}) {
    try {
      final opts = <String, dynamic>{
        'particleCount': 90,
        'spread': 75,
        'startVelocity': 40,
        'origin': {'x': x, 'y': y},
        'colors': ['#6366F1', '#38BDF8', '#10B981', '#F43F5E', '#A855F7'],
        'disableForReducedMotion': true,
      }.jsify();
      _confetti(opts);
    } catch (_) {
      // Non-critical visual flourish
    }
  }
}
