// lib/src/generator/route_typegen.dart
import 'package:meta/meta.dart';
import '../utils/project.dart';

/// Represents a parsed Bloom route pattern and its extracted parameters.
@immutable
class ParsedRoute {
  /// The route path pattern, e.g. `'/'`, `'/cart'`, `'/p/:slug'`, `'/docs/*'`.
  final String path;

  /// Dynamic parameter names extracted from `:param` segments, e.g. `['slug']`.
  final List<String> params;

  /// Whether the path pattern contains a wildcard (`*`) matching remaining segments.
  final bool hasWildcard;

  const ParsedRoute({
    required this.path,
    required this.params,
    required this.hasWildcard,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedRoute &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() =>
      'ParsedRoute(path: $path, params: $params, hasWildcard: $hasWildcard)';
}

/// Represents a generated Dart route identifier and its source declaration code.
@immutable
class GeneratedRouteSymbol {
  final ParsedRoute route;
  final String identifier;
  final bool isConst;
  final String declarationCode;

  const GeneratedRouteSymbol({
    required this.route,
    required this.identifier,
    required this.isConst,
    required this.declarationCode,
  });
}

/// Result of route code generation including emitted Dart source and metadata.
@immutable
class RouteTypegenResult {
  final String code;
  final List<GeneratedRouteSymbol> symbols;
  final List<String> warnings;

  const RouteTypegenResult({
    required this.code,
    required this.symbols,
    required this.warnings,
  });
}

/// Static analysis and code generation for Bloom typed routes.
///
/// ### Naming Rules
/// 1. **Root Route** (`'/'` or `''`): Mapped to `routeHome`.
/// 2. **Static Routes** (no `:param` or `*`): Emitted as `const String route<PascalCaseSegments> = '<path>';`.
///    Example: `'/cart'` -> `routeCart`, `'/admin/products/new'` -> `routeAdminProductsNew`.
/// 3. **Parameterized Routes**: Emitted as `String route<PascalCaseSegments>By<PascalCaseParams>({required String ...}) => '<interpolated>';`.
///    Example: `'/p/:slug'` -> `routePBySlug({required String slug})`,
///             `'/admin/products/:id'` -> `routeAdminProductsById({required String id})`.
/// 4. **Wildcard Routes**: Emitted with `{required String rest}` parameter.
///    Example: `'/docs/*'` -> `routeDocs({required String rest}) => '/docs/$rest'`.
/// 5. **Collision Resolution**: If two different route patterns map to the same base identifier,
///    a numeric suffix (`2`, `3`, ...) is appended and a warning is logged.
class RouteTypegen {
  static final RegExp _routeRegex = RegExp(
    r'''(?<!\.)\bBloomRoute\s*\(\s*r?(?:'([^']*)'|"([^"]*)")''',
    multiLine: true,
  );

  static final RegExp _paramRegex = RegExp(r':([a-zA-Z_][a-zA-Z0-9_]*)');

  /// Parses `BloomRoute('pattern', ...)` calls out of Dart source code.
  ///
  /// Skips duplicate route paths (keeping the first occurrence) and ignores
  /// `BloomRoute.shell(...)` declarations.
  static List<ParsedRoute> parseSource(
    String dartSource, {
    void Function(String warning)? onWarning,
  }) {
    final routes = <ParsedRoute>[];
    final seenPaths = <String>{};

    for (final match in _routeRegex.allMatches(dartSource)) {
      final rawPath = match.group(1) ?? match.group(2);
      if (rawPath == null) continue;

      final path = rawPath.trim();
      if (seenPaths.contains(path)) {
        onWarning?.call(
          'Duplicate route path "$path" found; keeping first occurrence.',
        );
        continue;
      }
      seenPaths.add(path);

      final params = <String>[];
      for (final paramMatch in _paramRegex.allMatches(path)) {
        final name = paramMatch.group(1)!;
        if (!params.contains(name)) {
          params.add(name);
        }
      }

      final hasWildcard = path.contains('*');
      routes.add(
        ParsedRoute(
          path: path,
          params: List.unmodifiable(params),
          hasWildcard: hasWildcard,
        ),
      );
    }

    return routes;
  }

  /// Converts filesystem [DiscoveredRoute] entries into [ParsedRoute] instances.
  static List<ParsedRoute> fromDiscoveredRoutes(
    List<DiscoveredRoute> discovered,
  ) {
    final routes = <ParsedRoute>[];
    for (final d in discovered) {
      routes.add(
        ParsedRoute(
          path: d.routePath,
          params: List.unmodifiable(d.parameters),
          hasWildcard: d.routePath.contains('*'),
        ),
      );
    }
    return routes;
  }

  /// Merges primary parsed routes with secondary discovered filesystem routes.
  ///
  /// Existing route paths in [primary] take precedence over [secondary].
  static List<ParsedRoute> mergeRoutes(
    List<ParsedRoute> primary,
    List<ParsedRoute> secondary, {
    void Function(String warning)? onWarning,
  }) {
    final result = List<ParsedRoute>.from(primary);
    final seenPaths = primary.map((r) => r.path).toSet();

    for (final sec in secondary) {
      if (seenPaths.contains(sec.path)) {
        onWarning?.call(
          'Filesystem route "${sec.path}" already defined in entry file; skipping.',
        );
        continue;
      }
      seenPaths.add(sec.path);
      result.add(sec);
    }

    return result;
  }

  /// Generates the complete Dart source code for the given [routes].
  static RouteTypegenResult generate({
    required List<ParsedRoute> routes,
    String entryPath = 'lib/main.dart',
    void Function(String warning)? onWarning,
  }) {
    final warnings = <String>[];
    void reportWarning(String w) {
      warnings.add(w);
      onWarning?.call(w);
    }

    final usedIdentifiers = <String>{};
    final symbols = <GeneratedRouteSymbol>[];

    for (final route in routes) {
      final baseIdentifier = _deriveBaseIdentifier(route);
      final identifier = _resolveUniqueIdentifier(
        baseIdentifier,
        route.path,
        usedIdentifiers,
        reportWarning,
      );

      final isConst = route.params.isEmpty && !route.hasWildcard;
      final declarationCode = _buildDeclaration(identifier, route);

      symbols.add(
        GeneratedRouteSymbol(
          route: route,
          identifier: identifier,
          isConst: isConst,
          declarationCode: declarationCode,
        ),
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('// GENERATED FILE — DO NOT EDIT BY HAND.');
    buffer.writeln('// Regenerate with: bloom typegen');
    buffer.writeln('// Source: $entryPath');
    buffer.writeln();
    buffer.writeln('/// Route Builder Functions & Constants');
    buffer.writeln('///');
    buffer.writeln('/// Generated by Bloom Typegen.');
    buffer.writeln('///');
    buffer.writeln('/// Naming Rules:');
    buffer.writeln('/// - Root route (\'/\' or \'\') is mapped to `routeHome`.');
    buffer.writeln(
      '/// - Static routes are generated as `const String route<Segments> = \'<path>\';`.',
    );
    buffer.writeln(
      '/// - Parameterized routes are generated as `String route<Segments>By<Params>({required String ...}) => \'<interpolated_path>\';`.',
    );
    buffer.writeln(
      '/// - Wildcard routes are generated with `{required String rest}` parameter.',
    );
    buffer.writeln(
      '/// - Segment names are converted to PascalCase and joined. Param names are camelCased.',
    );
    buffer.writeln();

    for (var i = 0; i < symbols.length; i++) {
      buffer.writeln(symbols[i].declarationCode);
      if (i < symbols.length - 1) {
        buffer.writeln();
      }
    }

    return RouteTypegenResult(
      code: buffer.toString(),
      symbols: List.unmodifiable(symbols),
      warnings: List.unmodifiable(warnings),
    );
  }

  static String _deriveBaseIdentifier(ParsedRoute route) {
    final path = route.path;

    if (path == '/' || path.isEmpty) {
      if (route.hasWildcard) return 'routeHomeWildcard';
      if (route.params.isNotEmpty) {
        return 'routeHomeBy${route.params.map(_toPascalCase).join('And')}';
      }
      return 'routeHome';
    }

    var cleanPath = path;
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    if (cleanPath.endsWith('/')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    }

    final segments = cleanPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    final staticSegments = segments
        .where((s) => !s.startsWith(':') && !s.startsWith('*'))
        .toList();

    final staticPart = staticSegments.map(_toPascalCase).join();
    final paramPart = route.params.isNotEmpty
        ? 'By${route.params.map(_toPascalCase).join('And')}'
        : '';

    if (staticPart.isEmpty) {
      if (paramPart.isNotEmpty) {
        return 'route$paramPart';
      }
      return 'routeWildcard';
    }

    return 'route$staticPart$paramPart';
  }

  static String _resolveUniqueIdentifier(
    String baseName,
    String routePath,
    Set<String> used,
    void Function(String warning) onWarning,
  ) {
    if (!used.contains(baseName)) {
      used.add(baseName);
      return baseName;
    }

    // Attempt wildcard suffix if baseName collision occurs
    if (baseName.endsWith('Wildcard') == false && routePath.contains('*')) {
      final wildcardCandidate = '${baseName}Wildcard';
      if (!used.contains(wildcardCandidate)) {
        used.add(wildcardCandidate);
        return wildcardCandidate;
      }
    }

    var counter = 2;
    while (used.contains('$baseName$counter')) {
      counter++;
    }
    final resolved = '$baseName$counter';
    used.add(resolved);
    onWarning(
      'Naming collision for route "$routePath": resolved identifier to "$resolved".',
    );
    return resolved;
  }

  static String _buildDeclaration(String identifier, ParsedRoute route) {
    if (route.params.isEmpty && !route.hasWildcard) {
      final pathStr = route.path.isEmpty ? '/' : route.path;
      return "const String $identifier = '$pathStr';";
    }

    final namedArgs = <String>[];
    for (final p in route.params) {
      namedArgs.add('required String ${_toCamelCase(p)}');
    }
    if (route.hasWildcard) {
      namedArgs.add('required String rest');
    }

    var interpolated = route.path.isEmpty ? '/' : route.path;
    for (final p in route.params) {
      final camel = _toCamelCase(p);
      // Word-boundary-aware: a plain replaceAll(':$p', ...) would also match
      // inside a longer param name sharing the same prefix (e.g. replacing
      // ':id' before ':idx' would corrupt ':idx' into '$idx' -> '$id' + 'x').
      interpolated = interpolated.replaceAll(
        RegExp(':$p(?![a-zA-Z0-9_])'),
        '\$$camel',
      );
    }
    if (route.hasWildcard) {
      interpolated = interpolated.replaceAll('*', '\$rest');
    }

    if (namedArgs.length > 1) {
      final formattedArgs = namedArgs.map((a) => '  $a,').join('\n');
      return 'String $identifier({\n$formattedArgs\n}) => \'$interpolated\';';
    } else {
      return 'String $identifier({${namedArgs.first}}) => \'$interpolated\';';
    }
  }

  static String _toPascalCase(String input) {
    if (input.isEmpty) return '';
    final parts = input
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((p) => p.isNotEmpty);
    return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  static String _toCamelCase(String input) {
    if (input.isEmpty) return '';
    final parts = input
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      final single = parts.first;
      return single[0].toLowerCase() + single.substring(1);
    }
    final first = parts.first[0].toLowerCase() + parts.first.substring(1);
    final rest = parts
        .skip(1)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join();
    return '$first$rest';
  }
}
