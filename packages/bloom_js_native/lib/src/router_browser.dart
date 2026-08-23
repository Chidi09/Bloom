import 'dart:js_interop';
import 'package:signals_core/signals_core.dart';
import 'package:web/web.dart' as web;
import 'a11y.dart';
import 'framework.dart';
import 'router.dart';

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

/// Client-side router controller using the HTML5 History API.
///
/// Coordinates browser-based URL synchronization, asynchronous route guard evaluation,
/// reactive query strings and hash fragments, automatic scroll position restoration across session
/// history entries, accessible screen-reader announcements via [BloomAnnouncer], automatic
/// keyboard focus management, and speculative link prefetching via `IntersectionObserver`.
///
/// ### Scroll Restoration & Fragments
/// When [scrollRestoration] is enabled (the default):
/// - Sets `window.history.scrollRestoration` to `'manual'` to override default browser scrolling.
/// - Tags history entries with unique keys (`bloomKey`) stored in `history.state`.
/// - Records `(scrollX, scrollY)` offsets before navigating away from an entry.
/// - On forward navigation or fresh route pushes:
///   - If a hash fragment is present, scrolls the element with matching `id` (or `name`) into view.
///   - Otherwise, resets the window scroll position to `(0, 0)`.
/// - On back/forward `popstate` navigation, restores the previously saved `(scrollX, scrollY)`
///   coordinates associated with the destination history entry key.
///
/// ### Navigation Accessibility
/// When enabled (the default):
/// - [announceNavigation] politely broadcasts the new document title or pathname to screen
///   readers via [BloomAnnouncer] after the new route renders.
/// - [autoFocus] moves keyboard focus to the target element (preferring `[data-bloom-focus]`,
///   `h1`, `main`, or `document.body`), adding temporary `tabindex="-1"` if necessary.
/// - Initial page load skips automatic announcements and focus resets.
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
///   BloomRoute('/search', (params) => const Div(text: 'Search')),
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
  /// When `true` (the default), overrides `window.history.scrollRestoration` to `'manual'`
  /// and automatically restores scroll coordinates on `popstate` transitions
  /// while resetting scroll to top `(0, 0)` or fragment targets on forward navigations.
  final bool scrollRestoration;

  /// Whether automatic route announcements via [BloomAnnouncer] are enabled.
  ///
  /// When `true` (the default), politely announces each completed client-side navigation
  /// using the document title or pathname. Initial page load is skipped.
  final bool announceNavigation;

  /// Whether automatic keyboard focus management is enabled on route transitions.
  ///
  /// When `true` (the default), moves keyboard focus to the new page content upon
  /// client-side navigation. Prefers elements matching `[data-bloom-focus]`, `h1`,
  /// `main`, or `document.body`. Initial page load is skipped.
  final bool autoFocus;

  /// Optional custom announcer instance used for accessibility announcements.
  ///
  /// If omitted, defaults to [BloomAnnouncer.instance].
  final BloomAnnouncer? announcer;

  /// Reactive signal tracking the current URL pathname.
  ///
  /// Updates automatically on [navigate], [replace], or browser back/forward `popstate` events.
  /// Reading `currentPath.value` inside a [Live] or [Show] boundary triggers a re-render
  /// whenever navigation occurs.
  late final Signal<String> currentPath;

  /// Reactive signal tracking the current URL query parameters (single value per key, last wins).
  ///
  /// Updates automatically on [navigate], [replace], or browser back/forward `popstate` events.
  /// Reading `currentQuery.value` inside a [Live] or [Show] boundary triggers a re-render
  /// whenever query parameters change.
  late final Signal<Map<String, String>> currentQuery;

  /// Reactive signal tracking all current URL query parameters preserving repeated keys.
  ///
  /// Updates automatically on [navigate], [replace], or browser back/forward `popstate` events.
  /// Reading `currentQueryAll.value` inside a [Live] or [Show] boundary triggers a re-render
  /// whenever query parameters change.
  late final Signal<Map<String, List<String>>> currentQueryAll;

  /// Reactive signal tracking the current URL hash fragment (without the leading `#`).
  ///
  /// Updates automatically on [navigate], [replace], or browser back/forward `popstate` events.
  /// Reading `currentFragment.value` inside a [Live] or [Show] boundary triggers a re-render
  /// whenever the hash fragment changes.
  late final Signal<String> currentFragment;

  late final void Function(web.Event) _popStateListener;

  String? _previousScrollRestoration;
  String? _currentKey;
  int _keySeq = 0;
  final Map<String, (double, double)> _scrollPositions = {};
  web.IntersectionObserver? _intersectionObserver;

  /// Creates a client-side router controller managing browser navigation for [_router].
  ///
  /// Attaches a `popstate` event listener to `web.window`, initializes history state keys,
  /// configures viewport prefetching observation, and initializes reactive location signals.
  BloomRouterController(
    this._router, {
    this.scrollRestoration = true,
    this.announceNavigation = true,
    this.autoFocus = true,
    this.announcer,
  }) {
    final initialLocation = _readCurrentBrowserLocation();
    currentPath = signal(web.window.location.pathname);
    currentQuery = signal(parseQueryString(initialLocation));
    currentQueryAll = signal(parseQueryStringAll(initialLocation));
    currentFragment = signal(parseFragment(initialLocation));

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
      final newLocation = _readCurrentBrowserLocation();
      _handleNavigation(
        newLocation,
        replaceState: false,
        isPopState: true,
        restoreKey: destKey,
      );
    };
    web.window.addEventListener('popstate', _popStateListener.toJS);

    _schedulePostNavigationWork(
      restoreKey: null,
      fragment: currentFragment.value,
      isInitial: true,
    );
  }

  static String _readCurrentBrowserLocation() {
    try {
      final path = web.window.location.pathname;
      final search = web.window.location.search;
      final hash = web.window.location.hash;
      return '$path$search$hash';
    } catch (_) {
      return '/';
    }
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
  /// [currentQuery], [currentQueryAll], and [currentFragment], handles fragment/top
  /// scrolling, announces the navigation to screen readers, manages focus, and scans
  /// for visible prefetch links.
  ///
  /// ```dart
  /// Button(
  ///   onClick: (_) => controller.navigate('/dashboard?tab=stats#chart'),
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
  /// await controller.replace('/search?q=shoes&page=2');
  /// ```
  Future<void> replace(String path) async {
    await _handleNavigation(path, replaceState: true);
  }

  /// Navigates to an updated query string on the current pathname by pushing a new history entry.
  ///
  /// Retains the current pathname and any existing hash fragment while updating query parameters.
  /// Values in [query] are serialized with [buildQueryString].
  ///
  /// ```dart
  /// // Updates URL to '/current-path?page=3'
  /// await controller.navigateQuery({'page': 3});
  /// ```
  Future<void> navigateQuery(Map<String, dynamic> query) async {
    await setQuery(query, replace: false);
  }

  /// Replaces the query string on the current pathname in place without pushing a new history entry.
  ///
  /// Useful for filters, search terms, or sorting options that should not create separate
  /// browser back-button entries. Retains the current pathname and any existing hash fragment.
  ///
  /// ```dart
  /// // Updates URL in place to '/current-path?sort=desc'
  /// await controller.replaceQuery({'sort': 'desc'});
  /// ```
  Future<void> replaceQuery(Map<String, dynamic> query) async {
    await setQuery(query, replace: true);
  }

  /// Updates the query parameters on the current path, either pushing or replacing history.
  ///
  /// When [replace] is `true`, uses [replace]; otherwise uses [navigate].
  /// Retains the current pathname and any existing hash fragment.
  ///
  /// ```dart
  /// await controller.setQuery({'filter': 'active'}, replace: true);
  /// ```
  Future<void> setQuery(Map<String, dynamic> query, {bool replace = false}) async {
    final qs = buildQueryString(query);
    final frag = currentFragment.value.isNotEmpty ? '#${currentFragment.value}' : '';
    final target = '${currentPath.value}$qs$frag';
    if (replace) {
      await this.replace(target);
    } else {
      await navigate(target);
    }
  }

  /// Navigates to [fragment] on the current pathname by pushing a new history entry.
  ///
  /// Retains the current pathname and query string while setting or updating the hash fragment.
  ///
  /// ```dart
  /// await controller.navigateFragment('section-2');
  /// ```
  Future<void> navigateFragment(String fragment) async {
    await setFragment(fragment, replace: false);
  }

  /// Replaces the hash fragment on the current pathname in place without pushing a new history entry.
  ///
  /// ```dart
  /// await controller.replaceFragment('section-2');
  /// ```
  Future<void> replaceFragment(String fragment) async {
    await setFragment(fragment, replace: true);
  }

  /// Updates the hash fragment on the current path, either pushing or replacing history.
  ///
  /// [fragment] may optionally include or omit the leading `#`.
  ///
  /// ```dart
  /// await controller.setFragment('top', replace: true);
  /// ```
  Future<void> setFragment(String fragment, {bool replace = false}) async {
    final cleanFrag = fragment.startsWith('#') ? fragment.substring(1) : fragment;
    final qs = buildQueryString(currentQueryAll.value);
    final hashPart = cleanFrag.isNotEmpty ? '#$cleanFrag' : '';
    final target = '${currentPath.value}$qs$hashPart';
    if (replace) {
      await this.replace(target);
    } else {
      await navigate(target);
    }
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
    final match = _router.match(path);
    if (match != null) {
      final guardRes =
          await _router.evaluateGuards(match.route, path, match.params);
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

    final parsedQuery = parseQueryString(path);
    final parsedQueryAll = parseQueryStringAll(path);
    final parsedFragment = parseFragment(path);

    currentPath.value = clean;
    currentQuery.value = parsedQuery;
    currentQueryAll.value = parsedQueryAll;
    currentFragment.value = parsedFragment;

    _schedulePostNavigationWork(
      restoreKey: isPopState ? restoreKey : null,
      fragment: parsedFragment,
      isInitial: false,
    );
  }

  void _schedulePostNavigationWork({
    String? restoreKey,
    String? fragment,
    bool isInitial = false,
  }) {
    _intersectionObserver?.disconnect();

    Future.microtask(() {
      if (scrollRestoration) {
        try {
          if (restoreKey != null && _scrollPositions.containsKey(restoreKey)) {
            final (x, y) = _scrollPositions[restoreKey]!;
            web.window.scrollTo(web.ScrollToOptions(left: x, top: y));
          } else if (fragment != null && fragment.isNotEmpty) {
            final scrolled = _scrollToFragment(fragment);
            if (!scrolled) {
              web.window.scrollTo(web.ScrollToOptions(left: 0, top: 0));
            }
          } else {
            web.window.scrollTo(web.ScrollToOptions(left: 0, top: 0));
          }
        } catch (_) {}
      } else if (fragment != null && fragment.isNotEmpty) {
        try {
          _scrollToFragment(fragment);
        } catch (_) {}
      }

      _observeVisibleLinks();

      if (!isInitial) {
        _announceNavigation();
        _manageFocus();
      }
    });
  }

  bool _scrollToFragment(String fragment) {
    try {
      final decoded = Uri.decodeComponent(fragment);
      web.Element? target = web.document.getElementById(decoded) ??
          web.document.getElementById(fragment);
      if (target == null) {
        final byName = web.document.getElementsByName(decoded);
        if (byName.length > 0) {
          final item = byName.item(0);
          if (item != null && item.isA<web.Element>()) {
            target = item as web.Element;
          }
        }
      }
      if (target == null) {
        final byNameRaw = web.document.getElementsByName(fragment);
        if (byNameRaw.length > 0) {
          final item = byNameRaw.item(0);
          if (item != null && item.isA<web.Element>()) {
            target = item as web.Element;
          }
        }
      }
      if (target != null) {
        target.scrollIntoView();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _announceNavigation() {
    if (!announceNavigation) return;
    try {
      _ensureLiveRegion();
      final title = web.document.title.trim();
      final message = title.isNotEmpty ? title : currentPath.value;
      (announcer ?? BloomAnnouncer.instance).announcePolite(message);
    } catch (_) {}
  }

  /// The DOM id of the live region this controller injects.
  static const String _liveRegionId = 'bloom-router-live-region';

  /// Creates the `aria-live` region that renders the announcer's messages, if
  /// one is not already present.
  ///
  /// [BloomAnnouncer] is pure signal state — `announcePolite` writes to a
  /// [Signal] and touches no DOM. Assistive technology only observes an
  /// announcement when something renders those signals into a live region, so
  /// without this the router would announce into a void and navigation would
  /// stay silent to screen readers.
  ///
  /// An application that already mounts its own [AriaLiveRegion] bound to the
  /// same announcer can give it the id `bloom-router-live-region` to suppress
  /// this one and avoid double announcements.
  void _ensureLiveRegion() {
    if (_liveRegion != null) return;
    if (web.document.getElementById(_liveRegionId) != null) return;
    final body = web.document.body;
    if (body == null) return;

    final container = web.document.createElement('div') as web.HTMLDivElement;
    container.id = _liveRegionId;
    container.setAttribute('style', visuallyHiddenStyle);

    final polite = web.document.createElement('div') as web.HTMLDivElement;
    polite.setAttribute('aria-live', 'polite');
    polite.setAttribute('aria-atomic', 'true');
    polite.setAttribute('role', 'status');

    final assertive = web.document.createElement('div') as web.HTMLDivElement;
    assertive.setAttribute('aria-live', 'assertive');
    assertive.setAttribute('aria-atomic', 'true');
    assertive.setAttribute('role', 'alert');

    container.appendChild(polite);
    container.appendChild(assertive);
    body.appendChild(container);
    _liveRegion = container;

    final source = announcer ?? BloomAnnouncer.instance;
    _liveRegionDisposers.add(effect(() {
      polite.textContent = source.politeMessage.value;
    }));
    _liveRegionDisposers.add(effect(() {
      assertive.textContent = source.assertiveMessage.value;
    }));
  }

  web.HTMLDivElement? _liveRegion;
  final List<void Function()> _liveRegionDisposers = [];

  void _manageFocus() {
    if (!autoFocus) return;
    try {
      web.HTMLElement? target;
      final customTarget = web.document.querySelector(
        '[data-bloom-focus], [data-route-focus], [autofocus]',
      );
      if (customTarget != null && customTarget.isA<web.HTMLElement>()) {
        target = customTarget as web.HTMLElement;
      } else {
        final h1 = web.document.querySelector('h1');
        if (h1 != null && h1.isA<web.HTMLElement>()) {
          target = h1 as web.HTMLElement;
        } else {
          final main = web.document.querySelector('main, [role="main"]');
          if (main != null && main.isA<web.HTMLElement>()) {
            target = main as web.HTMLElement;
          } else if (web.document.body != null) {
            target = web.document.body;
          }
        }
      }

      if (target != null) {
        final hadTabIndex = target.hasAttribute('tabindex');
        if (!hadTabIndex) {
          target.setAttribute('tabindex', '-1');
          late web.EventListener blurListener;
          blurListener = ((web.Event e) {
            target?.removeAttribute('tabindex');
            target?.removeEventListener('blur', blurListener);
          }).toJS;
          target.addEventListener('blur', blurListener);
        }
        target.focus();
      }
    } catch (_) {}
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
  /// Reads reactive location signals, matches against registered [BloomRoute] patterns,
  /// and returns [BloomRouteMatch.build] for the active route (or an empty [FragmentNode]
  /// if no route matches).
  ///
  /// ```dart
  /// BloomNode app() => Live(() => controller.resolve());
  /// ```
  BloomNode resolve() {
    final qs = buildQueryString(currentQueryAll.value);
    final frag = currentFragment.value.isNotEmpty ? '#${currentFragment.value}' : '';
    final fullLocation = '${currentPath.value}$qs$frag';
    final m = _router.match(fullLocation);
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

    for (final d in _liveRegionDisposers) {
      try {
        d();
      } catch (_) {}
    }
    _liveRegionDisposers.clear();
    _liveRegion?.remove();
    _liveRegion = null;
  }
}
