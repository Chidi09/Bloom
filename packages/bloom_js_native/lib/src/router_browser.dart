import 'dart:js_interop';
import 'package:signals/signals.dart';
import 'package:web/web.dart' as web;
import 'framework.dart';
import 'router.dart';

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

/// Client-side router controller using the HTML5 History API.
///
/// Coordinates browser-based URL synchronization, asynchronous route guard evaluation,
/// automatic scroll position restoration across session history entries, and speculative
/// link prefetching via `IntersectionObserver`.
///
/// ### Scroll Restoration
/// When [scrollRestoration] is enabled (the default):
/// - Sets `window.history.scrollRestoration` to `'manual'` to override default browser scrolling.
/// - Tags history entries with unique keys (`bloomKey`) stored in `history.state`.
/// - Records `(scrollX, scrollY)` offsets before navigating away from an entry.
/// - On forward navigation or fresh route pushes, resets the window scroll position to `(0, 0)`.
/// - On back/forward `popstate` navigation, restores the previously saved `(scrollX, scrollY)`
///   coordinates associated with the destination history entry key.
///
/// ### Lifecycle and Cleanup
/// [BloomRouterController] attaches an active `popstate` listener to `window` and manages
/// an `IntersectionObserver`. When unmounting or tearing down an application, [dispose] must
/// be called to remove the event listener, disconnect the observer, and restore the previous
/// browser `window.history.scrollRestoration` configuration.
///
/// ```dart
/// final router = BloomRouter([
///   BloomRoute('/', (params) => const Div(text: 'Home')),
///   BloomRoute('/about', (params) => const Div(text: 'About')),
/// ]);
///
/// final controller = BloomRouterController(router);
///
/// BloomNode app() => Live(() => controller.resolve());
/// ```
class BloomRouterController {
  final BloomRouter _router;

  /// Whether automatic scroll position restoration is enabled.
  ///
  /// When `true`, overrides `window.history.scrollRestoration` to `'manual'`
  /// and automatically restores scroll coordinates on `popstate` transitions
  /// while resetting scroll to top `(0, 0)` on forward navigations.
  final bool scrollRestoration;

  /// Reactive signal tracking the current URL pathname.
  ///
  /// Updates automatically on [navigate], [replace], or browser back/forward `popstate` events.
  /// Reading `currentPath.value` inside a [Live] or [Show] boundary triggers a re-render
  /// whenever navigation occurs.
  late final Signal<String> currentPath;
  late final void Function(web.Event) _popStateListener;

  String? _previousScrollRestoration;
  String? _currentKey;
  int _keySeq = 0;
  final Map<String, (double, double)> _scrollPositions = {};
  web.IntersectionObserver? _intersectionObserver;

  /// Creates a client-side router controller managing browser navigation for [_router].
  ///
  /// Attaches a `popstate` event listener to `web.window`, initializes history state keys,
  /// and configures viewport prefetching observation.
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

  /// Navigates to [path] by pushing a new entry onto the browser history stack.
  ///
  /// Evaluates any [BloomRouteGuard]s configured on the matching route. If a guard
  /// returns a redirect, navigates to the redirect path instead. Otherwise, pushes
  /// a new history entry with `window.history.pushState`, updates [currentPath],
  /// scrolls to `(0, 0)` in a microtask, and scans for visible prefetch links.
  ///
  /// ```dart
  /// Button(
  ///   onClick: (_) => controller.navigate('/dashboard'),
  ///   text: 'Go to Dashboard',
  /// )
  /// ```
  Future<void> navigate(String path) async {
    await _handleNavigation(path, replaceState: false);
  }

  /// Navigates to [path] by replacing the current browser history entry in place.
  ///
  /// Evaluates route guards similarly to [navigate], but replaces the current history
  /// record via `window.history.replaceState` instead of pushing a new history item.
  /// Useful for authentication redirects or updating URL query parameters without
  /// polluting the browser back-button history.
  ///
  /// ```dart
  /// await controller.replace('/login');
  /// ```
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

  /// Resolves the current URL path against the router and returns the matching [BloomNode] tree.
  ///
  /// Returns [BloomRouteMatch.build] for the active route, or an empty [FragmentNode]
  /// if no route matches.
  ///
  /// ```dart
  /// BloomNode app() => Live(() => controller.resolve());
  /// ```
  BloomNode resolve() {
    final m = _router.match(currentPath.value);
    return m == null ? const FragmentNode([]) : m.build();
  }

  /// Removes the `popstate` window event listener, disconnects the link prefetch observer,
  /// and restores browser history scroll restoration.
  ///
  /// Must be invoked when the application or router controller is torn down to prevent
  /// memory leaks and restore previous browser history settings.
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
