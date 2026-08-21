import 'dart:js_interop';

@JS('confetti')
external void _triggerConfetti(JSObject options);

class Confetti {
  static void burst({double x = 0.5, double y = 0.5}) {
    try {
      final opts = <String, dynamic>{
        'particleCount': 60,
        'spread': 70,
        'origin': {'x': x, 'y': y},
        'colors': ['#6366F1', '#8B5CF6', '#3B82F6', '#10B981'],
        'disableForReducedMotion': true,
      }.jsify() as JSObject;
      _triggerConfetti(opts);
    } catch (_) {}
  }
}
