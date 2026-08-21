import 'dart:js_interop';
import 'package:signals/signals.dart';
import 'package:web/web.dart' as web;
import 'framework.dart';
import 'router.dart';

/// Client-side router using the HTML5 History API with async guard evaluation.
class BloomRouterController {
  final BloomRouter _router;
  late final Signal<String> currentPath;
  late final void Function(web.Event) _popStateListener;

  BloomRouterController(this._router) {
    currentPath = signal(web.window.location.pathname);
    _popStateListener = (web.Event _) {
      final newPath = web.window.location.pathname;
      _handleNavigation(newPath, replaceState: true);
    };
    web.window.addEventListener('popstate', _popStateListener.toJS);
  }

  /// Navigate to [path] — evaluates guards, pushes history, and updates [currentPath].
  Future<void> navigate(String path) async {
    await _handleNavigation(path, replaceState: false);
  }

  /// Replace current history entry without a new history item.
  Future<void> replace(String path) async {
    await _handleNavigation(path, replaceState: true);
  }

  Future<void> _handleNavigation(String path, {required bool replaceState}) async {
    final clean = path.split('?').first.split('#').first;
    final match = _router.match(clean);
    if (match != null) {
      final guardRes = await _router.evaluateGuards(match.route, clean, match.params);
      if (!guardRes.isAllowed && guardRes.redirectPath != null) {
        return _handleNavigation(guardRes.redirectPath!, replaceState: true);
      }
    }

    if (replaceState) {
      web.window.history.replaceState(null, '', path);
    } else {
      web.window.history.pushState(null, '', path);
    }
    currentPath.value = clean;
  }

  /// Resolve current path to a descriptor.
  BloomNode resolve() {
    final m = _router.match(currentPath.value);
    return m == null ? const FragmentNode([]) : m.build();
  }

  /// Remove popstate listener. Call on app unmount.
  void dispose() {
    web.window.removeEventListener('popstate', _popStateListener.toJS);
  }
}
