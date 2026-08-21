import 'events.dart';
import 'framework.dart';

/// Minimal client-side router for Bloom JS Native (phase 3 stub).
///
/// Full history-API integration ships in M3. This stub provides the
/// descriptor-level primitives so routes can be tested on the VM without
/// a browser and the example app can be structured ahead of the real
/// router implementation.

/// Route definition — pairs a path pattern with a builder.
class BloomRoute {
  /// Path pattern, e.g. "/", "/users/:id", "/docs/*".
  final String path;

  /// Builder that receives extracted params and returns a [BloomNode] tree.
  final BloomNode Function(Map<String, String> params) builder;

  const BloomRoute(this.path, this.builder);
}

/// Simple path matcher extracted for VM-testability.
///
/// Supports:
/// - static segments: "/about"
/// - param segments: "/users/:id"
/// - wildcard: "/docs/*"  (captures remainder as "wildcard")
class BloomRouter {
  final List<BloomRoute> routes;

  /// Fallback route when no pattern matches. If null, [match] returns null
  /// on unmatched paths.
  final BloomRoute? notFound;

  /// When true, trailing slashes are stripped before matching.
  /// `/about/` is treated as `/about`. Default: false.
  final bool trailing;

  BloomRouter(this.routes, {this.notFound, this.trailing = false});

  /// Match [path] against registered routes.
  /// Returns the matched route and extracted params, or null.
  ({BloomRoute route, Map<String, String> params})? match(String path) {
    // Strip query and hash.
    var clean = path.split('?').first.split('#').first;
    if (trailing && clean.length > 1 && clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    for (final route in routes) {
      final params = _matchPattern(route.path, clean);
      if (params != null) return (route: route, params: params);
    }
    if (notFound != null) return (route: notFound!, params: {});
    return null;
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
  Link({
    required String href,
    super.text,
    super.className,
    super.style,
    Map<String, String>? attrs,
    super.children = const [],
    Map<String, BloomEventHandler>? on,
    BloomEventHandler? onClick,
  }) : super(
          'a',
          attrs: {'href': href, if (attrs != null) ...attrs},
          on: onClick == null && on == null
              ? null
              : {
                  if (on != null) ...on,
                  if (onClick != null) 'click': onClick,
                },
        );

  const Link.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.on,
    super.children = const [],
  }) : super('a');
}
