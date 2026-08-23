import 'dart:async';

import 'events.dart';
import 'framework.dart';

/// Guard evaluation result.
class GuardResult {
  final bool isAllowed;
  final String? redirectPath;

  const GuardResult._({required this.isAllowed, this.redirectPath});

  factory GuardResult.allow() => const GuardResult._(isAllowed: true);

  factory GuardResult.redirect(String path) =>
      GuardResult._(isAllowed: false, redirectPath: path);
}

/// Prefetch strategy for [Link] navigation targets.
enum PrefetchMode {
  /// Never prefetch route assets or data ahead of click.
  off,

  /// Begin prefetching on pointerenter/mouseenter.
  hover,

  /// Begin prefetching when the link scrolls into the viewport via IntersectionObserver.
  visible,
}

/// Alias for [PrefetchMode].
typedef LinkPrefetch = PrefetchMode;

/// Module-level set of already-prefetched clean paths for session idempotency.
final Set<String> _prefetchedPaths = <String>{};

/// Abstract contract for route navigation guards.
abstract class BloomRouteGuard {
  const BloomRouteGuard();

  FutureOr<GuardResult> canActivate(String location, Map<String, String> params);
}

/// Route definition — pairs a path pattern with a builder, optional layout, and guards.
class BloomRoute {
  /// Path pattern, e.g. "/", "/users/:id", "/docs/*".
  final String path;

  /// Builder that receives extracted params and returns a [BloomNode] tree.
  final BloomNode Function(Map<String, String> params)? builder;

  /// Optional layout shell that wraps child route nodes.
  final BloomNode Function(BloomNode child, Map<String, String> params)? layout;

  /// List of navigation guards for this route.
  final List<BloomRouteGuard> guards;

  /// Nested sub-routes.
  final List<BloomRoute> children;

  /// Optional data loader, run before [dataBuilder] (or [builder], if
  /// [dataBuilder] is not given) renders. When present, this route's
  /// content is automatically wrapped in a [Suspense] boundary — no
  /// manual composition needed. Analogous to React Router's `loader`.
  ///
  /// For React Router's `action` + revalidation-on-mutation loop: this
  /// [loader] itself is a one-shot fetch run once per navigation, but a
  /// component *inside* the loaded page can instead read a `BloomQuery`
  /// (from `data.dart`) for the same data — `BloomQuery` subscribes to
  /// `BloomData.invalidateQueries` and refetches/reactively updates
  /// automatically. Give a `BloomMutation` (from `mutation.dart`) the
  /// same cache key in `invalidateKeys` so a form submission ("action")
  /// invalidates the page's data without any router changes:
  ///
  ///   // Inside the loaded page component:
  ///   final todoQuery = BloomQuery&lt;Todo&gt;(
  ///     key: ['todo', todoId],
  ///     fetch: () => api.fetchTodo(todoId),
  ///   );
  ///
  ///   // The "action" — submitting this invalidates todoQuery above,
  ///   // which then refetches on its own:
  ///   final updateTodo = BloomMutation&lt;Todo, Todo&gt;(
  ///     mutateFn: api.updateTodo,
  ///     invalidateKeys: [['todo', todoId]],
  ///   );
  final Future<dynamic> Function(Map<String, String> params)? loader;

  /// Builder invoked with both [params] and the resolved [loader] result,
  /// used instead of [builder] when [loader] is present. If [loader] is
  /// present but [dataBuilder] is not given, [builder] is used instead,
  /// receiving only [params] (the loaded data is simply discarded in that
  /// case — useful when you only want the loading gate, not the data).
  final BloomNode Function(Map<String, String> params, dynamic data)?
      dataBuilder;

  /// Fallback node shown while [loader] is pending. Defaults to an empty
  /// fragment if not provided.
  final BloomNode Function()? loadingFallback;

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

  /// Factory for persistent shell layouts (sidebars, navbars).
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

/// Match result containing route, params, and node builder.
class BloomRouteMatch {
  final BloomRoute route;
  final Map<String, String> params;
  final BloomNode Function()? _buildNode;

  const BloomRouteMatch({
    required this.route,
    required this.params,
    BloomNode Function()? buildNode,
  }) : _buildNode = buildNode;

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

/// Simple path matcher extracted for VM-testability.
class BloomRouter {
  static final List<BloomRouter> _activeRouters = [];

  final List<BloomRoute> routes;

  /// Fallback route when no pattern matches.
  final BloomRoute? notFound;

  /// When true, trailing slashes are stripped before matching.
  final bool trailing;

  BloomRouter(this.routes, {this.notFound, this.trailing = false}) {
    if (!_activeRouters.contains(this)) {
      _activeRouters.add(this);
    }
  }

  /// Prefetch route data and lazily-loaded components for [path] across active routers.
  /// Idempotent across a session; swallowed silently on failure.
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

  /// Clears the module-level prefetch cache.
  static void clearPrefetchCache() {
    _prefetchedPaths.clear();
  }

  /// Prefetch route data and lazily-loaded components for [path] using this router.
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

  /// Match [path] against registered routes.
  BloomRouteMatch? match(String path) {
    var clean = path.split('?').first.split('#').first;
    if (trailing && clean.length > 1 && clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }

    return _matchList(routes, clean);
  }

  BloomRouteMatch? _matchList(List<BloomRoute> list, String clean) {
    for (final route in list) {
      if (route.layout != null && route.children.isNotEmpty) {
        // Shell route
        final childMatch = _matchList(route.children, clean);
        if (childMatch != null) {
          return BloomRouteMatch(
            route: childMatch.route,
            params: childMatch.params,
            buildNode: () => route.layout!(childMatch.build(), childMatch.params),
          );
        }
      } else {
        final params = _matchPattern(route.path, clean);
        if (params != null) {
          return BloomRouteMatch(
            route: route,
            params: params,
          );
        }
      }
    }
    if (notFound != null) {
      return BloomRouteMatch(route: notFound!, params: const {});
    }
    return null;
  }

  /// Evaluates all guards attached to [route].
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

class Link extends ElNode {
  final PrefetchMode prefetch;

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
