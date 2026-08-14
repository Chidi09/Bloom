// lib/src/explain/explain_engine.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

class RouteExplanation {
  final String requestedPath;
  final bool isFound;
  final String? filePath;
  final String? pattern;
  final Map<String, String> parameters;
  final String? layoutPath;
  final List<String> guards;

  RouteExplanation({
    required this.requestedPath,
    required this.isFound,
    this.filePath,
    this.pattern,
    this.parameters = const {},
    this.layoutPath,
    this.guards = const [],
  });
}

/// Architectural explanation engine for Bloom routing, state, and modules.
class ExplainEngine {
  final BloomProject project;

  ExplainEngine(this.project);

  /// Explains how a URL path maps into the project's filesystem routes, parameters, layouts, and guards.
  RouteExplanation explainRoute(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final routes = project.scanRoutes();
    final requestedSegments = cleanPath.split('/').where((s) => s.isNotEmpty).toList();

    for (final route in routes) {
      final routeSegments = route.routePath.split('/').where((s) => s.isNotEmpty).toList();
      if (routeSegments.length != requestedSegments.length) {
        continue;
      }

      var matches = true;
      final params = <String, String>{};

      for (var i = 0; i < routeSegments.length; i++) {
        final rSeg = routeSegments[i];
        final reqSeg = requestedSegments[i];

        if (rSeg.startsWith(':')) {
          final paramName = rSeg.substring(1);
          params[paramName] = reqSeg;
        } else if (rSeg != reqSeg) {
          matches = false;
          break;
        }
      }

      if (matches) {
        // Detect layout and guards from file inspection
        final file = File(p.join(project.rootDir.path, 'lib', 'routes', route.relativeFilePath));
        final guards = <String>[];
        String? layoutPath;

        // Check if parent directory has _layout.dart
        final parentDir = file.parent;
        final layoutFile = File(p.join(parentDir.path, '_layout.dart'));
        if (layoutFile.existsSync()) {
          layoutPath = p.relative(layoutFile.path, from: project.rootDir.path).replaceAll('\\', '/');
        }

        if (file.existsSync()) {
          final content = file.readAsStringSync();
          if (content.contains('BloomAuthGuard') || content.contains('@RequireAuth')) {
            guards.add('BloomAuthGuard (redirect: /login)');
          }
          if (content.contains('CustomGuard')) {
            guards.add('CustomGuard');
          }
        }

        final fullRelPath = p.join('lib', 'routes', route.relativeFilePath).replaceAll('\\', '/');

        return RouteExplanation(
          requestedPath: cleanPath,
          isFound: true,
          filePath: fullRelPath,
          pattern: route.routePath,
          parameters: params,
          layoutPath: layoutPath != null ? '$layoutPath (ShellRoute)' : null,
          guards: guards.isNotEmpty ? guards : ['None (Public Route)'],
        );
      }
    }

    return RouteExplanation(
      requestedPath: cleanPath,
      isFound: false,
    );
  }

  /// Prints the formatted explanation to console.
  void printRouteExplanation(RouteExplanation exp) {
    print(Ansi.boldText('\n🔍 Route Architecture Explanation: ${exp.requestedPath}\n'));

    if (!exp.isFound) {
      print(Ansi.warn('⚠ Route "${exp.requestedPath}" is not registered or matched in the filesystem route tree.\n'));
      return;
    }

    print('Route: ${exp.requestedPath}');
    print('  • File:       ${Ansi.cyan}${exp.filePath}${Ansi.reset}');
    print('  • Pattern:    ${exp.pattern}');
    print('  • Parameters: ${exp.parameters.isEmpty ? 'None' : exp.parameters.toString()}');
    if (exp.layoutPath != null) {
      print('  • Layout:     ${exp.layoutPath}');
    }
    print('  • Guards:     [${exp.guards.join(', ')}]\n');
  }
}
