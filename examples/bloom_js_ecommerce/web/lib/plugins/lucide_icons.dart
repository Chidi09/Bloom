// Typed wrapper around `lucide` (installed via `bloom add npm:lucide` — see
// bloom.yaml / web/vendor/). Loaded as an ES module through the import map
// in web/index.html; its bootstrap <script type="module"> assigns the full
// module namespace to `window.lucide` for this binding to find.
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('lucide')
extension type _LucideModule._(JSObject _) implements JSObject {
  external JSArray get ShoppingCart;
  external JSArray get Trash2;
  external JSArray get LogOut;
  external JSArray get User;
  external web.SVGElement createElement(JSArray iconNode);
}

@JS('lucide')
external _LucideModule get _lucide;

enum LucideIconName { shoppingCart, trash2, logOut, user }

/// Renders a real Lucide icon as an inline `<svg>` string (via
/// `lucide.createElement` + `outerHTML`), suitable for [Raw].
class LucideIcons {
  static final Map<String, String> _cache = {};

  static String svg(LucideIconName name, {String className = 'w-4 h-4'}) {
    return _cache.putIfAbsent('${name.name}:$className', () {
      try {
        final iconNode = switch (name) {
          LucideIconName.shoppingCart => _lucide.ShoppingCart,
          LucideIconName.trash2 => _lucide.Trash2,
          LucideIconName.logOut => _lucide.LogOut,
          LucideIconName.user => _lucide.User,
        };
        final el = _lucide.createElement(iconNode);
        el.setAttribute('class', className);
        return (el.outerHTML as JSString).toDart;
      } catch (_) {
        return ''; // Non-critical — falls back to no icon if interop fails.
      }
    });
  }
}
