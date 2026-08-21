import 'dart:js_interop';
import 'package:signals/signals.dart';
import 'package:web/web.dart' as web;
import 'framework.dart';
import 'router.dart';

/// Client-side router using the HTML5 History API.
///
/// Usage:
/// ```dart
/// final ctrl = BloomRouterController(BloomRouter([
///   BloomRoute('/', (_) => HomePage()),
///   BloomRoute('/about', (_) => AboutPage()),
/// ]));
///
/// // In app tree:
/// Live(() => ctrl.resolve())
///
/// // Navigate programmatically:
/// ctrl.navigate('/about');
/// ```
class BloomRouterController {
  final BloomRouter _router;
  late final Signal<String> currentPath;
  late final void Function(web.Event) _popStateListener;

  BloomRouterController(this._router) {
    currentPath = signal(web.window.location.pathname);
    _popStateListener = (web.Event _) {
      currentPath.value = web.window.location.pathname;
    };
    web.window.addEventListener('popstate', _popStateListener.toJS);
  }

  /// Navigate to [path] — pushes to browser history and updates [currentPath].
  void navigate(String path) {
    web.window.history.pushState(null, '', path);
    currentPath.value = path.split('?').first.split('#').first;
  }

  /// Replace current history entry without a new history item.
  void replace(String path) {
    web.window.history.replaceState(null, '', path);
    currentPath.value = path.split('?').first.split('#').first;
  }

  /// Resolve current path to a descriptor. Returns empty fragment on no match.
  BloomNode resolve() {
    final m = _router.match(currentPath.value);
    return m == null ? FragmentNode(const []) : m.route.builder(m.params);
  }

  /// Remove popstate listener. Call on app unmount.
  void dispose() {
    web.window.removeEventListener('popstate', _popStateListener.toJS);
  }
}
