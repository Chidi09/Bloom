import 'dart:js_interop';
import 'package:signals/signals.dart';
import 'package:web/web.dart' as web;
import 'framework.dart';
import 'router.dart';

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

/// Client-side router using the HTML5 History API with async guard evaluation,
/// automatic scroll restoration, and link prefetch observation.
class BloomRouterController {
  final BloomRouter _router;

  /// Whether scroll restoration is enabled (defaults to true).
  final bool scrollRestoration;

  late final Signal<String> currentPath;
  late final void Function(web.Event) _popStateListener;

  String? _previousScrollRestoration;
  String? _currentKey;
  int _keySeq = 0;
  final Map<String, (double, double)> _scrollPositions = {};
  web.IntersectionObserver? _intersectionObserver;

  BloomRouterController(this._router, {this.scrollRestoration = true}) {
    currentPath = signal(web.window.location.pathname);

    if (scrollRestoration) {
      try {
        _previousScrollRestoration = web.window.history.scrollRestoration;
        web.window.history.scrollRestoration = 'manual';
      } catch (_) {}
    }

    final existingKey = _extractKey(web.window.history.state);
    if (existingKey != null) {
      _currentKey = existingKey;
    } else {
      _currentKey = _generateKey();
      if (scrollRestoration) {
        try {
          web.window.history.replaceState(
            _createState(_currentKey!),
            '',
            web.window.location.href,
          );
        } catch (_) {}
      }
    }

    _initIntersectionObserver();

    _popStateListener = (web.Event e) {
      _saveScroll();
      JSAny? eventState;
      if (e.isA<web.PopStateEvent>()) {
        eventState = (e as web.PopStateEvent).state;
      }
      eventState ??= web.window.history.state;
      final destKey = _extractKey(eventState);
      _currentKey = destKey ?? _generateKey();
      final newPath = web.window.location.pathname;
      _handleNavigation(
        newPath,
        replaceState: false,
        isPopState: true,
        restoreKey: destKey,
      );
    };
    web.window.addEventListener('popstate', _popStateListener.toJS);

    _schedulePostNavigationWork(restoreKey: null);
  }

  String _generateKey() =>
      'bloom_${DateTime.now().millisecondsSinceEpoch}_${++_keySeq}';

  JSObject _createState(String key) {
    return {'bloomKey': key}.jsify()! as JSObject;
  }

  String? _extractKey(JSAny? state) {
    if (state == null) return null;
    if (state.isA<JSString>()) {
      return (state as JSString).toDart;
    }
    if (state.isA<JSObject>()) {
      try {
        final val = _reflectGet(state, 'bloomKey') ??
            _reflectGet(state, '__bloom_key__');
        if (val != null && val.isA<JSString>()) {
          return (val as JSString).toDart;
        }
      } catch (_) {}
    }
    return null;
  }

  void _saveScroll() {
    if (!scrollRestoration || _currentKey == null) return;
    try {
      final x = web.window.scrollX.toDouble();
      final y = web.window.scrollY.toDouble();
      _scrollPositions[_currentKey!] = (x, y);
    } catch (_) {}
  }

  /// Navigate to [path] — evaluates guards, pushes history, and updates [currentPath].
  Future<void> navigate(String path) async {
    await _handleNavigation(path, replaceState: false);
  }

  /// Replace current history entry without a new history item.
  Future<void> replace(String path) async {
    await _handleNavigation(path, replaceState: true);
  }

  Future<void> _handleNavigation(
    String path, {
    required bool replaceState,
    bool isPopState = false,
    String? restoreKey,
  }) async {
    // Not on a popstate: the listener has already saved the outgoing scroll
    // position under the OUTGOING key, and has since repointed [_currentKey]
    // at the destination entry. Saving again here would write the current
    // (pre-render) offset under the destination's key, clobbering the very
    // position we are about to restore.
    if (!isPopState) _saveScroll();

    final clean = path.split('?').first.split('#').first;
    final match = _router.match(clean);
    if (match != null) {
      final guardRes =
          await _router.evaluateGuards(match.route, clean, match.params);
      if (!guardRes.isAllowed && guardRes.redirectPath != null) {
        return _handleNavigation(guardRes.redirectPath!, replaceState: true);
      }
    }

    if (!isPopState) {
      if (replaceState) {
        final key = _currentKey ?? _generateKey();
        _currentKey = key;
        web.window.history.replaceState(_createState(key), '', path);
      } else {
        final newKey = _generateKey();
        _currentKey = newKey;
        web.window.history.pushState(_createState(newKey), '', path);
      }
    }

    currentPath.value = clean;
    _schedulePostNavigationWork(restoreKey: isPopState ? restoreKey : null);
  }

  void _schedulePostNavigationWork({String? restoreKey}) {
    _intersectionObserver?.disconnect();

    Future.microtask(() {
      if (scrollRestoration) {
        try {
          if (restoreKey != null && _scrollPositions.containsKey(restoreKey)) {
            final (x, y) = _scrollPositions[restoreKey]!;
            web.window.scrollTo(web.ScrollToOptions(left: x, top: y));
          } else {
            web.window.scrollTo(web.ScrollToOptions(left: 0, top: 0));
          }
        } catch (_) {}
      }

      _observeVisibleLinks();
    });
  }

  void _initIntersectionObserver() {
    try {
      _intersectionObserver = web.IntersectionObserver(
        ((JSArray<web.IntersectionObserverEntry> entries,
            web.IntersectionObserver observer) {
          for (final entry in entries.toDart) {
            if (entry.isIntersecting) {
              final target = entry.target;
              final href = target.getAttribute('href');
              if (href != null && href.isNotEmpty) {
                BloomRouter.prefetch(href);
                observer.unobserve(target);
              }
            }
          }
        }).toJS,
      );
    } catch (_) {}
  }

  void _observeVisibleLinks() {
    if (_intersectionObserver == null) return;
    try {
      final elements =
          web.document.querySelectorAll('a[data-bloom-prefetch="visible"]');
      for (var i = 0; i < elements.length; i++) {
        final el = elements.item(i);
        if (el != null && el.isA<web.Element>()) {
          _intersectionObserver!.observe(el as web.Element);
        }
      }
    } catch (_) {}
  }

  /// Resolve current path to a descriptor.
  BloomNode resolve() {
    final m = _router.match(currentPath.value);
    return m == null ? const FragmentNode([]) : m.build();
  }

  /// Remove popstate listener and restore history scroll restoration. Call on app unmount.
  void dispose() {
    web.window.removeEventListener('popstate', _popStateListener.toJS);
    if (scrollRestoration && _previousScrollRestoration != null) {
      try {
        web.window.history.scrollRestoration = _previousScrollRestoration!;
      } catch (_) {}
    }
    _intersectionObserver?.disconnect();
    _intersectionObserver = null;
  }
}
