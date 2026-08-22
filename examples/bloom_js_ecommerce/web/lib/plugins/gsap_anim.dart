// Typed wrapper around `gsap` (installed via `bloom add npm:gsap` — see
// bloom.yaml / web/vendor/). Loaded as an ES module through the import map
// in web/index.html; its bootstrap <script type="module"> assigns the
// named `gsap` export to `window.gsap` for this binding to find.
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('gsap')
external JSObject get _gsapGlobal;

extension type _Gsap._(JSObject _) implements JSObject {
  external JSObject to(web.Element target, JSObject vars);
}

/// Small GSAP-driven micro-animations for storefront UI feedback.
class GsapAnim {
  /// Punchy scale "bump" — used on the navbar cart badge whenever the cart
  /// item count changes, so adding an item reads as a real action.
  static void bump(web.Element element) {
    try {
      _Gsap._(_gsapGlobal).to(element, <String, dynamic>{
        'scale': 1.35,
        'duration': 0.12,
        'yoyo': true,
        'repeat': 1,
        'ease': 'power1.inOut',
      }.jsify() as JSObject);
    } catch (_) {
      // Non-critical UI flourish — never let a JS interop failure break the cart.
    }
  }
}
