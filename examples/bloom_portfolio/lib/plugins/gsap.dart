// Typed wrapper around `gsap` (installed via `bloom add npm:gsap` — see
// bloom.yaml / web/index.html). Loaded as an ES module through the import map
// in web/index.html; its bootstrap <script type="module"> assigns the
// named `gsap` export to `window.gsap` for this binding to find.
library;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('gsap')
external JSObject? get _gsapGlobal;

extension type _Gsap._(JSObject _) implements JSObject {
  external JSObject to(JSAny target, JSObject vars);
  external JSObject from(JSAny target, JSObject vars);
  external JSObject fromTo(JSAny target, JSObject fromVars, JSObject toVars);
}

/// GSAP animation helpers for scroll reveals, micro-interactions, and card staggers.
class Gsap {
  /// Animates an element or collection of elements smoothly into view with an
  /// upward slide and fade-in effect.
  static void fadeIn(
    web.Element element, {
    double duration = 0.8,
    double delay = 0.0,
    double y = 24.0,
    String ease = 'power2.out',
  }) {
    try {
      final global = _gsapGlobal;
      if (global == null) return;
      _Gsap._(global).fromTo(
        element,
        <String, dynamic>{'opacity': 0.0, 'y': y}.jsify() as JSObject,
        <String, dynamic>{
          'opacity': 1.0,
          'y': 0.0,
          'duration': duration,
          'delay': delay,
          'ease': ease,
        }.jsify() as JSObject,
      );
    } catch (_) {
      // Non-critical visual flourish — fallback to CSS visibility
    }
  }

  /// Staggers the reveal of all project cards matching [selector].
  static void staggerReveal(
    String selector, {
    double duration = 0.7,
    double stagger = 0.1,
    double y = 30.0,
  }) {
    try {
      final global = _gsapGlobal;
      if (global == null) return;
      _Gsap._(global).fromTo(
        selector.toJS,
        <String, dynamic>{'opacity': 0.0, 'y': y}.jsify() as JSObject,
        <String, dynamic>{
          'opacity': 1.0,
          'y': 0.0,
          'duration': duration,
          'stagger': stagger,
          'ease': 'power2.out',
        }.jsify() as JSObject,
      );
    } catch (_) {
      // Non-critical animation
    }
  }

  /// Interactive hover scale-bump effect for cards or interactive elements.
  static void bump(web.Element element) {
    try {
      final global = _gsapGlobal;
      if (global == null) return;
      _Gsap._(global).to(
        element,
        <String, dynamic>{
          'scale': 1.03,
          'duration': 0.2,
          'yoyo': true,
          'repeat': 1,
          'ease': 'power1.inOut',
        }.jsify() as JSObject,
      );
    } catch (_) {}
  }
}
