import 'dart:async';

import 'events.dart';
import 'framework.dart';

/// Represents the result of evaluating a route navigation guard.
///
/// Returned by [BloomRouteGuard.canActivate]. A guard result determines whether
/// navigation to a target route is permitted to proceed ([isAllowed] is `true`)
/// or must be redirected to an alternate path ([redirectPath]).
///
/// When a guard returns a redirect, client routers halt navigation to the requested
/// path and instead navigate to [redirectPath].
///
/// ```dart
/// class AuthGuard extends BloomRouteGuard {
///   final bool isLoggedIn;
///   const AuthGuard(this.isLoggedIn);
///
///   @override
///   GuardResult canActivate(String location, Map<String, String> params) {
///     if (!isLoggedIn) {
///       return GuardResult.redirect('/login');
///     }
///     return GuardResult.allow();
///   }
/// }
/// ```
class GuardResult {
  /// Whether navigation to the target route is permitted to proceed.
  final bool isAllowed;

  /// Target path to redirect to when navigation is disallowed.
  ///
  /// Null when [isAllowed] is `true`.
  final String? redirectPath;

  const GuardResult._({required this.isAllowed, this.redirectPath});

  /// Creates a guard result permitting navigation to proceed.
  factory GuardResult.allow() => const GuardResult._(isAllowed: true);

  /// Creates a guard result that cancels the current navigation and redirects to [path].
  factory GuardResult.redirect(String path) =>
      GuardResult._(isAllowed: false, redirectPath: path);

  /// Creates a guard result that blocks navigation without redirecting.
  factory GuardResult.deny() => const GuardResult._(isAllowed: false);
}

/// Outcome of [BloomRouter.resolveRedirects] after following guard redirects.
class GuardResolution {
  /// The final location guards settled on (redirect targets applied).
  final String location;

  /// The route match for [location], or `null` when nothing matched.
  final BloomRouteMatch? match;

  /// Whether a guard blocked navigation without offering a redirect target.
  final bool blocked;

  const GuardResolution({
    required this.location,
    required this.match,
    this.blocked = false,
  });

  /// Resolution for a location with no matching route.
  factory GuardResolution.noMatch(String location) =>
      GuardResolution(location: location, match: null);
}

/// Thrown by [BloomRouter.resolveRedirects] when guard redirects loop.
///
/// Records the visited [chain] and the [offendingTarget] that revisited a
/// location (or exceeded the hop budget), e.g. route A redirecting to B
/// while B redirects back to A.
class BloomRedirectLoopException implements Exception {
  /// Locations visited before the loop was detected, in order.
  final List<String> chain;

  /// The redirect target that closed the loop or broke the hop budget.
  final String offendingTarget;

  const BloomRedirectLoopException(this.chain, this.offendingTarget);

  @override
  String toString() =>
      'BloomRedirectLoopException: guard redirect loop detected: '
      '${[...chain, offendingTarget].join(' -> ')}';
}

/// Speculative prefetching strategies for [Link] navigation targets.
///
/// Configures how aggressively [Link] elements preload route data and
/// lazy components before the user clicks the link.
///
/// Speculative prefetch requests are deduplicated per clean path for the duration
/// of the session, and any network or evaluation errors during prefetch are caught
/// and swallowed silently without affecting application execution.
///
/// ```dart
/// // Prefetch when the link enters the viewport
/// Link(href: '/dashboard', prefetch: PrefetchMode.visible, text: 'Dashboard');
///
/// // Prefetch on pointer hover
/// Link(href: '/settings', prefetch: PrefetchMode.hover, text: 'Settings');
///
/// // Disable prefetching
/// Link(href: '/logout', prefetch: PrefetchMode.off, text: 'Log Out');
/// ```
enum PrefetchMode {
  /// Never prefetch route assets or data ahead of a click.
  off,

  /// Triggers route prefetching when the user hovers over or points at the link (`pointerenter` / `mouseenter`).
  hover,

  /// Triggers route prefetching when the link scrolls into the viewport via `IntersectionObserver`.
  visible,
}

/// Convenience alias for [PrefetchMode].
typedef LinkPrefetch = PrefetchMode;

/// Module-level set of already-prefetched clean paths for session idempotency.
final Set<String> _prefetchedPaths = <String>{};

/// Abstract contract for route navigation guards.
///
/// Guards intercept route transitions before a route match is rendered. If any
/// guard attached to a [BloomRoute] returns a [GuardResult] where [GuardResult.isAllowed]
/// is `false`, the navigation sequence is halted and the router redirects to
/// [GuardResult.redirectPath] if one was specified.
///
/// Guards can be synchronous or asynchronous.
///
/// ```dart
/// class AdminGuard extends BloomRouteGuard {
///   final Future<bool> Function() checkAdmin;
///   const AdminGuard(this.checkAdmin);
///
///   @override
///   Future<GuardResult> canActivate(String location, Map<String, String> params) async {
///     final isAdmin = await checkAdmin();
///     return isAdmin ? GuardResult.allow() : GuardResult.redirect('/unauthorized');
///   }
/// }
/// ```
abstract class BloomRouteGuard {
  /// Base const constructor for route guards.
  const BloomRouteGuard();

  /// Evaluates whether navigation to [location] with extracted route [params] is allowed.
  ///
  /// [location] contains the full target URL string including any query parameters
  /// and hash fragments (e.g. `'/search?q=shoes&page=2#top'`).
  FutureOr<GuardResult> canActivate(String location, Map<String, String> params);
}

/// Parses a URL or query string into a single-value map of query parameters.
///
/// Keys and values are percent-decoded, `+` is converted to spaces, and duplicate
/// keys follow "last-wins" semantics. Keys without values are assigned an empty string.
/// If no query string is present, returns an empty map.
///
/// Safe for both server-side rendering (SSR) and browser environments.
///
/// ```dart
/// final query = parseQueryString('/search?q=shoes+sale&category=footwear');
/// print(query['q']); // 'shoes sale'
/// print(query['category']); // 'footwear'
/// ```
Map<String, String> parseQueryString(String location) {
  final query = _extractQueryString(location);
  if (query.isEmpty) return const {};
  return Uri.splitQueryString(query);
}

/// Parses a URL or query string into a multi-value map preserving repeated keys.
///
/// Keys and values are percent-decoded, `+` is converted to spaces, and repeated
/// keys (e.g. `?tag=news&tag=tech`) are collected into a [List<String>] in order of appearance.
/// Keys without values are assigned a list containing an empty string (`['']`).
/// If no query string is present, returns an empty map.
///
/// Safe for both server-side rendering (SSR) and browser environments.
///
/// ```dart
/// final allParams = parseQueryStringAll('/filter?tag=web&tag=dart&sort=asc');
/// print(allParams['tag']); // ['web', 'dart']
/// print(allParams['sort']); // ['asc']
/// ```
Map<String, List<String>> parseQueryStringAll(String location) {
  final query = _extractQueryString(location);
  if (query.isEmpty) return const {};
  final result = <String, List<String>>{};
  for (final part in query.split('&')) {
    if (part.isEmpty) continue;
    final eqIdx = part.indexOf('=');
    String rawKey;
    String rawValue;
    if (eqIdx == -1) {
      rawKey = part;
      rawValue = '';
    } else {
      rawKey = part.substring(0, eqIdx);
      rawValue = part.substring(eqIdx + 1);
    }
    final key = Uri.decodeQueryComponent(rawKey);
    final value = Uri.decodeQueryComponent(rawValue);
    (result[key] ??= []).add(value);
  }
  return result;
}

/// Extracts the hash fragment from a URL or location string without the leading `#`.
///
/// If no hash fragment is present in [location], returns an empty string.
///
/// Safe for both server-side rendering (SSR) and browser environments.
///
/// ```dart
/// final fragment = parseFragment('/docs/guide#getting-started');
/// print(fragment); // 'getting-started'
/// ```
String parseFragment(String location) {
  final hashIdx = location.indexOf('#');
  if (hashIdx == -1) return '';
  return location.substring(hashIdx + 1);
}

/// Serializes a map of query parameters into a URL query string prefixed with `?`.
///
/// Handles percent-encoding of keys and values, unrolls [Iterable] values into repeated keys,
/// and ignores entries with `null` values. Returns an empty string if [query] is empty
/// or contains only null values.
///
/// Safe for both server-side rendering (SSR) and browser environments.
///
/// ```dart
/// final qs = buildQueryString({
///   'q': 'shoes',
///   'page': 2,
///   'tag': ['sale', 'men'],
///   'empty': null,
/// });
/// print(qs); // '?q=shoes&page=2&tag=sale&tag=men'
/// ```
String buildQueryString(Map<String, dynamic> query) {
  if (query.isEmpty) return '';
  final pairs = <String>[];
  query.forEach((key, value) {
    if (value == null) return;
    final encodedKey = Uri.encodeQueryComponent(key);
    if (value is Iterable) {
      for (final item in value) {
        if (item == null) continue;
        pairs.add('$encodedKey=${Uri.encodeQueryComponent(item.toString())}');
      }
    } else {
      pairs.add('$encodedKey=${Uri.encodeQueryComponent(value.toString())}');
    }
  });
  return pairs.isEmpty ? '' : '?${pairs.join('&')}';
}

String _extractQueryString(String location) {
  var s = location;
  final hIdx = s.indexOf('#');
  if (hIdx != -1) {
    s = s.substring(0, hIdx);
  }
  final qIdx = s.indexOf('?');
  if (qIdx != -1) {
    return s.substring(qIdx + 1);
  }
  if (!s.contains('/') && s.contains('=')) {
    return s;
  }
  return '';
}

/// Route definition that pairs a URL path pattern with view builders, loaders, and guards.
///
/// Represents a single route or route subtree in a [BloomRouter].
///
/// ### Path Pattern Syntax
/// - **Static segments**: `/users/list` matches `/users/list` exactly.
/// - **Dynamic parameters**: `/users/:id` matches `/users/42` and extracts `{'id': '42'}`
///   into the `params` map. Parameter values are automatically URI-decoded.
/// - **Wildcards**: `/docs/*` matches `/docs/guide/start` and extracts the remaining path
///   under the `'wildcard'` key (`{'wildcard': 'guide/start'}`).
/// - **Root route**: `''` or `'/'` matches the root path.
///
/// ### Data Loaders and Suspense
/// When [loader] is provided, entering this route automatically wraps the route content
/// in a [Suspense] boundary. While [loader] is executing, [loadingFallback] (or an empty
/// fragment if omitted) is rendered. Once resolved, [dataBuilder] is called with both
/// the route `params` and the loaded data. If [dataBuilder] is omitted, [builder] is
/// called with `params` alone.
///
/// ```dart
/// final userRoute = BloomRoute(
///   '/users/:id',
///   null,
///   loader: (params) => fetchUserProfile(params['id']!),
///   loadingFallback: () => const Div(text: 'Loading user...'),
///   dataBuilder: (params, user) => Div(
///     children: [
///       H1(text: 'User: ${(user as User).name}'),
///     ],
///   ),
/// );
/// ```
///
/// ### Persistent Shell Routes
/// Use [BloomRoute.shell] to wrap nested sub-routes in persistent layout chrome
/// (such as navigation sidebars and headers) without affecting URL hierarchy.
class BloomRoute {
  /// Path pattern to match against, e.g. `'/'`, `'/users/:id'`, or `'/docs/*'`.
  final String path;

  /// Builder that receives extracted [params] and returns a [BloomNode] tree.
  final BloomNode Function(Map<String, String> params)? builder;

  /// Layout wrapper function that encloses child route content within a shell.
  final BloomNode Function(BloomNode child, Map<String, String> params)? layout;

  /// Navigation guards evaluated before this route is activated.
  final List<BloomRouteGuard> guards;

  /// Nested child routes matched within this route's hierarchy.
  final List<BloomRoute> children;

  /// Async data loader executed upon navigation before this route renders.
  ///
  /// When defined, this route's view is automatically wrapped in a [Suspense] boundary.
  /// The returned future resolves before [dataBuilder] (or [builder]) is displayed.
  final Future<dynamic> Function(Map<String, String> params)? loader;

  /// Builder invoked with extracted [params] and resolved [loader] data.
  final BloomNode Function(Map<String, String> params, dynamic data)?
      dataBuilder;

  /// Fallback descriptor displayed within [Suspense] while [loader] is pending.
  final BloomNode Function()? loadingFallback;

  /// Creates a route definition matching [path].
  const BloomRoute(
    this.path,
    this.builder, {
    this.layout,
    this.guards = const [],
    this.children = const [],
    this.loader,
    this.dataBuilder,
    this.loadingFallback,
  });

  /// Factory constructor for persistent shell layouts enclosing nested [routes].
  ///
  /// Allows persistent UI chrome (such as top navigation bars, sidebars, and footers)
  /// to surround child routes without altering the URL path hierarchy.
  ///
  /// ```dart
  /// final shellRoute = BloomRoute.shell(
  ///   layout: (child, params) => Div(
  ///     className: 'app-container',
  ///     children: [
  ///       const Nav(text: 'Header'),
  ///       child,
  ///     ],
  ///   ),
  ///   routes: [
  ///     BloomRoute('/home', (params) => const Div(text: 'Home')),
  ///     BloomRoute('/profile', (params) => const Div(text: 'Profile')),
  ///   ],
  /// );
  /// ```
  factory BloomRoute.shell({
    required BloomNode Function(BloomNode child, Map<String, String> params) layout,
    required List<BloomRoute> routes,
    List<BloomRouteGuard> guards = const [],
  }) {
    return BloomRoute(
      '',
      null,
      layout: layout,
      guards: guards,
      children: routes,
    );
  }
}

/// Result of a successful route match containing the matched route and extracted parameters.
///
/// Created by [BloomRouter.match] when a URL path successfully satisfies a [BloomRoute] pattern.
/// Contains extracted route parameters ([params]), single-value query parameters ([query]),
/// multi-value query parameters ([queryAll]), and the optional hash [fragment].
class BloomRouteMatch {
  /// The [BloomRoute] that matched the requested path.
  final BloomRoute route;

  /// Extracted route parameters, keyed by parameter name with URI-decoded string values.
  final Map<String, String> params;

  /// Extracted route query parameters (single value per key, last wins).
  final Map<String, String> query;

  /// Extracted route query parameters preserving multiple values for repeated keys.
  final Map<String, List<String>> queryAll;

  /// Extracted URL hash fragment without the leading `#`.
  final String fragment;

  final BloomNode Function()? _buildNode;

  /// Creates a route match result.
  const BloomRouteMatch({
    required this.route,
    required this.params,
    this.query = const {},
    this.queryAll = const {},
    this.fragment = '',
    BloomNode Function()? buildNode,
  }) : _buildNode = buildNode;

  /// Builds and returns the [BloomNode] descriptor tree for this route match.
  ///
  /// If the matched route defines a [BloomRoute.loader], this method returns a
  /// [Suspense] node wrapping the loader resource, rendering [BloomRoute.loadingFallback]
  /// while pending and [BloomRoute.dataBuilder] once resolved.
  BloomNode build() {
    if (_buildNode != null) return _buildNode();
    final loader = route.loader;
    if (loader != null) {
      return Suspense<dynamic>(
        resource: () => loader(params),
        builder: (data) {
          if (route.dataBuilder != null) return route.dataBuilder!(params, data);
          if (route.builder != null) return route.builder!(params);
          return const FragmentNode([]);
        },
        fallback: route.loadingFallback?.call() ?? const FragmentNode([]),
      );
    }
    if (route.builder != null) return route.builder!(params);
    return const FragmentNode([]);
  }
}

/// Pure Dart route matching and navigation guard evaluation engine.
///
/// Operates without DOM dependencies, making it usable across VM unit tests,
/// server-side rendering (SSR), and browser-side client routers.
///
/// Matches URL paths against a tree of [BloomRoute] definitions, parses parameters,
/// evaluates [BloomRouteGuard] instances, and coordinates speculative route prefetching.
///
/// ```dart
/// final router = BloomRouter([
///   BloomRoute('/', (params) => const Div(text: 'Home')),
///   BloomRoute('/users/:id', (params) => Div(text: 'User ${params['id']}')),
/// ], notFound: BloomRoute('*', (params) => const Div(text: '404 Not Found')));
///
/// final match = router.match('/users/42?tab=profile#bio');
/// if (match != null) {
///   print(match.query['tab']); // 'profile'
///   print(match.fragment); // 'bio'
///   final node = match.build();
/// }
/// ```
class BloomRouter {
  static final List<BloomRouter> _activeRouters = [];

  /// Registered route hierarchy.
  final List<BloomRoute> routes;

  /// Fallback route definition rendered when no registered pattern matches.
  final BloomRoute? notFound;

  /// Whether trailing slashes are stripped from paths before matching.
  final bool trailing;

  /// Creates a [BloomRouter] with the given [routes] hierarchy and options.
  BloomRouter(this.routes, {this.notFound, this.trailing = false}) {
    if (!_activeRouters.contains(this)) {
      _activeRouters.add(this);
    }
  }

  /// Prefetches route data and lazy components for [path] across all active router instances.
  ///
  /// Clean paths (excluding query strings and hashes) are prefetched at most once per session.
  /// Any errors during prefetching are swallowed silently to avoid interrupting execution.
  static Future<void> prefetch(String path) async {
    final clean = path.split('?').first.split('#').first;
    if (_prefetchedPaths.contains(clean)) return;

    for (final router in _activeRouters) {
      final m = router.match(clean);
      if (m != null) {
        await router.prefetchRoute(clean);
        return;
      }
    }
  }

  /// Clears the session-level cache of prefetched paths.
  static void clearPrefetchCache() {
    _prefetchedPaths.clear();
  }

  /// Prefetches route data and lazily-loaded components for [path] using this router instance.
  Future<void> prefetchRoute(String path) async {
    final clean = path.split('?').first.split('#').first;
    if (_prefetchedPaths.contains(clean)) return;
    _prefetchedPaths.add(clean);

    try {
      final m = match(clean);
      if (m == null) return;
      await _warmMatch(m);
    } catch (_) {
      _prefetchedPaths.remove(clean);
    }
  }

  static Future<void> _warmMatch(BloomRouteMatch match) async {
    final route = match.route;
    final params = match.params;
    final futures = <Future<dynamic>>[];

    // 1. Warm route loader if present
    if (route.loader != null) {
      try {
        final f = route.loader!(params);
        futures.add(f);
      } catch (_) {}
    }

    // 2. Warm lazy components if builder returns a SuspenseNode or tree
    if (route.builder != null) {
      try {
        final node = route.builder!(params);
        _collectSuspenseResources(node, futures);
      } catch (_) {}
    }

    if (futures.isNotEmpty) {
      await Future.wait(
        futures.map((f) => f.catchError((Object _) => null)),
      );
    }
  }

  static void _collectSuspenseResources(
    BloomNode node,
    List<Future<dynamic>> futures,
  ) {
    if (node is SuspenseNode) {
      try {
        futures.add(node.resourceErased());
      } catch (_) {}
    } else if (node is FragmentNode) {
      for (final child in node.children) {
        _collectSuspenseResources(child, futures);
      }
    } else if (node is ElNode) {
      for (final child in node.children) {
        _collectSuspenseResources(child, futures);
      }
    }
  }

  /// Matches [path] against registered routes.
  ///
  /// Accepts a full URL location including optional query string and hash fragment.
  /// Matches route patterns against the cleaned path while extracting query parameters
  /// into [BloomRouteMatch.query] and [BloomRouteMatch.queryAll], and hash fragments into
  /// [BloomRouteMatch.fragment]. If [trailing] is `true`, trailing slashes are removed
  /// before evaluation. Returns a [BloomRouteMatch] if a route matches or if [notFound]
  /// is configured; returns `null` otherwise.
  BloomRouteMatch? match(String path) {
    var clean = path.split('?').first.split('#').first;
    if (trailing && clean.length > 1 && clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    final query = parseQueryString(path);
    final queryAll = parseQueryStringAll(path);
    final fragment = parseFragment(path);

    return _matchList(
      routes,
      clean,
      query: query,
      queryAll: queryAll,
      fragment: fragment,
    );
  }

  BloomRouteMatch? _matchList(
    List<BloomRoute> list,
    String clean, {
    Map<String, String> query = const {},
    Map<String, List<String>> queryAll = const {},
    String fragment = '',
  }) {
    for (final route in list) {
      if (route.layout != null && route.children.isNotEmpty) {
        // Shell route
        final childMatch = _matchList(
          route.children,
          clean,
          query: query,
          queryAll: queryAll,
          fragment: fragment,
        );
        if (childMatch != null) {
          return BloomRouteMatch(
            route: childMatch.route,
            params: childMatch.params,
            query: childMatch.query,
            queryAll: childMatch.queryAll,
            fragment: childMatch.fragment,
            buildNode: () => route.layout!(childMatch.build(), childMatch.params),
          );
        }
      } else {
        final params = _matchPattern(route.path, clean);
        if (params != null) {
          return BloomRouteMatch(
            route: route,
            params: params,
            query: query,
            queryAll: queryAll,
            fragment: fragment,
          );
        }
      }
    }
    if (notFound != null) {
      return BloomRouteMatch(
        route: notFound!,
        params: const {},
        query: query,
        queryAll: queryAll,
        fragment: fragment,
      );
    }
    return null;
  }

  /// Evaluates all navigation guards attached to [route] in sequential order.
  ///
  /// Passes the full [location] (including query string and hash fragment) and extracted [params]
  /// to each [BloomRouteGuard.canActivate].
  ///
  /// Returns the first failing [GuardResult] if any guard disallows navigation,
  /// or [GuardResult.allow] if all guards pass.
  Future<GuardResult> evaluateGuards(
    BloomRoute route,
    String location,
    Map<String, String> params,
  ) async {
    for (final guard in route.guards) {
      final res = await guard.canActivate(location, params);
      if (!res.isAllowed) return res;
    }
    return GuardResult.allow();
  }

  /// Follows guard redirects for [location] until navigation is allowed.
  ///
  /// Returns the final location (with its [BloomRouteMatch]) after applying
  /// every guard redirect in the chain. A guard denying without a redirect
  /// target stops resolution and yields that location as blocked.
  ///
  /// Throws [BloomRedirectLoopException] when the chain revisits a location
  /// or exceeds [maxRedirects] hops (default 10) — e.g. route A redirecting
  /// to B while B redirects back to A. Callers (such as the browser
  /// router controller) must surface this instead of recursing forever.
  Future<GuardResolution> resolveRedirects(
    String location, {
    int maxRedirects = 10,
  }) async {
    final visited = <String>[];
    var current = location;
    while (true) {
      final match = this.match(current);
      if (match == null) {
        return GuardResolution.noMatch(current);
      }
      final res = await evaluateGuards(match.route, current, match.params);
      if (res.isAllowed || res.redirectPath == null) {
        return GuardResolution(
          location: current,
          match: match,
          blocked: !res.isAllowed,
        );
      }
      final target = res.redirectPath!;
      if (visited.contains(target) || visited.length >= maxRedirects) {
        throw BloomRedirectLoopException(
          [...visited, current],
          target,
        );
      }
      visited.add(current);
      current = target;
    }
  }

  static Map<String, String>? _matchPattern(String pattern, String path) {
    final pSegs = pattern.split('/').where((s) => s.isNotEmpty).toList();
    final pathSegs = path.split('/').where((s) => s.isNotEmpty).toList();

    // Root special-case.
    if (pSegs.isEmpty) return pathSegs.isEmpty ? {} : null;

    final params = <String, String>{};
    for (var i = 0; i < pSegs.length; i++) {
      final p = pSegs[i];
      if (p == '*') {
        params['wildcard'] = pathSegs.skip(i).join('/');
        return params;
      }
      if (i >= pathSegs.length) return null;
      if (p.startsWith(':')) {
        params[p.substring(1)] = Uri.decodeComponent(pathSegs[i]);
      } else if (p != pathSegs[i]) {
        return null;
      }
    }
    if (pathSegs.length != pSegs.length) return null;
    return params;
  }
}

/// Hyperlink element (`<a>`) with built-in client-side routing and prefetch capabilities.
///
/// Wraps standard HTML anchor attributes and adds integration with [PrefetchMode]
/// and [BloomRouter.prefetch].
///
/// ### Prefetching Behavior
/// - [PrefetchMode.off]: No prefetching is performed.
/// - [PrefetchMode.hover]: Preloads route loaders and components on `pointerenter` / `mouseenter`.
/// - [PrefetchMode.visible]: Marks the element with `data-bloom-prefetch="visible"` for
///   viewport intersection prefetching via `BloomRouterController`.
///
/// Prefetching is opt-in, session-idempotent per clean path, and ignores network or evaluation errors.
///
/// ```dart
/// // Basic link
/// Link(href: '/about', text: 'About Us')
///
/// // Hover-based prefetching
/// Link(href: '/dashboard', prefetch: PrefetchMode.hover, text: 'Dashboard')
///
/// // Viewport visibility prefetching with child nodes
/// Link(
///   href: '/pricing',
///   prefetch: PrefetchMode.visible,
///   children: [
///     const Span(className: 'icon', text: 'tag'),
///     const Span(text: 'View Pricing'),
///   ],
/// )
/// ```
class Link extends ElNode {
  /// Speculative prefetching strategy for this link's destination URL.
  final PrefetchMode prefetch;

  /// Creates a hyperlink element targeting [href] with optional [prefetch] behavior.
  Link({
    required String href,
    this.prefetch = PrefetchMode.off,
    super.text,
    super.className,
    super.style,
    Map<String, String>? attrs,
    super.children = const [],
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onClick,
  }) : super(
          'a',
          attrs: {
            'href': href,
            if (prefetch == PrefetchMode.visible)
              'data-bloom-prefetch': 'visible',
            if (attrs != null) ...attrs,
          },
          on: _buildHandlers(
            href: href,
            prefetch: prefetch,
            on: on,
            onClick: onClick,
          ),
        );

  /// Creates a const [Link] descriptor without dynamic event bindings.
  const Link.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
    this.prefetch = PrefetchMode.off,
  }) : super('a');

  static Map<String, BloomEventHandler>? _buildHandlers({
    required String href,
    required PrefetchMode prefetch,
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onClick,
  }) {
    final handlers = <String, BloomEventHandler>{
      if (on != null) ...on,
      if (onClick != null) 'click': onClick,
    };

    if (prefetch == PrefetchMode.hover) {
      final existingPointerEnter = handlers['pointerenter'];
      handlers['pointerenter'] = (e) {
        BloomRouter.prefetch(href);
        existingPointerEnter?.call(e);
      };

      final existingMouseEnter = handlers['mouseenter'];
      handlers['mouseenter'] = (e) {
        BloomRouter.prefetch(href);
        existingMouseEnter?.call(e);
      };
    }

    return handlers.isEmpty ? null : handlers;
  }
}
