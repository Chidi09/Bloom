// lib/src/utils/project.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class DiscoveredRoute {
  final String relativeFilePath;
  final String routePath;
  final String componentClassName;
  final bool isIndex;
  final bool isParameterized;
  final List<String> parameters;

  const DiscoveredRoute({
    required this.relativeFilePath,
    required this.routePath,
    required this.componentClassName,
    this.isIndex = false,
    this.isParameterized = false,
    this.parameters = const [],
  });
}

class BloomProject {
  final Directory rootDir;
  final File bloomYamlFile;
  final File pubspecFile;

  BloomProject({
    required this.rootDir,
    required this.bloomYamlFile,
    required this.pubspecFile,
  });

  /// Find the Bloom project in [currentDir] or any ancestor directory.
  static BloomProject? find([Directory? currentDir]) {
    var dir = currentDir ?? Directory.current;
    while (true) {
      final bloomYaml = File(p.join(dir.path, 'bloom.yaml'));
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));

      if (bloomYaml.existsSync()) {
        return BloomProject(
          rootDir: dir,
          bloomYamlFile: bloomYaml,
          pubspecFile: pubspec,
        );
      }

      final parent = dir.parent;
      if (parent.path == dir.path) break; // reached filesystem root
      dir = parent;
    }
    return null;
  }

  /// Read the parsed `bloom.yaml` content.
  Map<dynamic, dynamic> loadBloomConfig() {
    if (!bloomYamlFile.existsSync()) return {};
    final content = bloomYamlFile.readAsStringSync();
    final doc = loadYaml(content);
    if (doc is Map) return doc;
    return {};
  }

  /// Get the project name from `bloom.yaml` or `pubspec.yaml`.
  String get projectName {
    final config = loadBloomConfig();
    if (config['name'] != null) return config['name'].toString();
    if (pubspecFile.existsSync()) {
      final doc = loadYaml(pubspecFile.readAsStringSync());
      if (doc is Map && doc['name'] != null) {
        return doc['name'].toString();
      }
    }
    return p.basename(rootDir.path);
  }

  /// Scan `lib/routes/` directory and extract all filesystem routes.
  List<DiscoveredRoute> scanRoutes() {
    final routesDir = Directory(p.join(rootDir.path, 'lib', 'routes'));
    if (!routesDir.existsSync()) return [];

    final routes = <DiscoveredRoute>[];
    final entities = routesDir.listSync(recursive: true);

    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      // Relative path from `lib/routes/`
      var relative = p.relative(entity.path, from: routesDir.path);
      // Normalized with forward slashes
      relative = relative.replaceAll('\\', '/');

      // Ignore private/layout files like `_layout.dart`
      final filename = p.basename(relative);
      if (filename.startsWith('_')) continue;

      var routePath = '/' + relative.replaceAll('.dart', '');

      // Replace index with empty
      bool isIndex = false;
      if (routePath == '/index' || routePath.endsWith('/index')) {
        isIndex = true;
        routePath = routePath.replaceAll('/index', '');
        if (routePath.isEmpty) routePath = '/';
      }

      // Remove tab grouping parens like `/(tabs)/home` -> `/home`
      routePath = routePath.replaceAll(RegExp(r'\([^)]+\)/?'), '');
      if (routePath.isEmpty) routePath = '/';

      // Parameter extraction: `[id]` -> `:id`
      final params = <String>[];
      final paramRegex = RegExp(r'\[([^\]]+)\]');
      final isParameterized = paramRegex.hasMatch(routePath);
      for (final match in paramRegex.allMatches(routePath)) {
        final paramName = match.group(1)!;
        params.add(paramName);
      }
      routePath = routePath.replaceAllMapped(paramRegex, (m) => ':${m.group(1)}');

      // Derive class name from file path
      final className = _deriveClassName(relative);

      routes.add(
        DiscoveredRoute(
          relativeFilePath: relative,
          routePath: routePath,
          componentClassName: className,
          isIndex: isIndex,
          isParameterized: isParameterized,
          parameters: params,
        ),
      );
    }

    // Sort routes so static routes come before parameterized routes
    routes.sort((a, b) {
      if (a.routePath == '/') return -1;
      if (b.routePath == '/') return 1;
      if (a.isParameterized && !b.isParameterized) return 1;
      if (!a.isParameterized && b.isParameterized) return -1;
      return a.routePath.compareTo(b.routePath);
    });

    return routes;
  }

  String _deriveClassName(String relativePath) {
    // E.g. "users/[id].dart" -> "UsersIdRoute"
    final clean = relativePath
        .replaceAll('.dart', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('(', '')
        .replaceAll(')', '');

    final parts = clean.split(RegExp(r'[/_\-]'));
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part.isEmpty) continue;
      buffer.write(part[0].toUpperCase() + part.substring(1));
    }
    buffer.write('Route');
    return buffer.toString();
  }
}
