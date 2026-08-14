// lib/src/native/dependency_graph.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Represents a package node in the Bloom dependency graph.
class GraphPackageNode {
  final String name;
  final String version;
  final bool isDirect;
  final bool isNativeModule;
  final List<String> nativePlatforms;
  final List<String> dependencies;
  final Map<String, dynamic>? moduleManifest;

  const GraphPackageNode({
    required this.name,
    required this.version,
    required this.isDirect,
    this.isNativeModule = false,
    this.nativePlatforms = const [],
    this.dependencies = const [],
    this.moduleManifest,
  });
}

/// Resolves, analyzes, and renders the Bloom dependency graph.
class DependencyGraphResolver {
  final BloomProject project;
  final Map<String, GraphPackageNode> _nodes = {};

  DependencyGraphResolver(this.project);

  /// Resolves all nodes in the dependency graph.
  Map<String, GraphPackageNode> resolveGraph() {
    _nodes.clear();

    final directDeps = <String, String>{};
    if (project.pubspecFile.existsSync()) {
      try {
        final yaml = loadYaml(project.pubspecFile.readAsStringSync()) as YamlMap?;
        final deps = yaml?['dependencies'] as YamlMap?;
        if (deps != null) {
          for (final entry in deps.entries) {
            directDeps[entry.key.toString()] = entry.value?.toString() ?? 'any';
          }
        }
      } catch (_) {}
    }

    final packageConfigFile = File(
      p.join(project.rootDir.path, '.dart_tool', 'package_config.json'),
    );

    if (packageConfigFile.existsSync()) {
      try {
        final json = jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
        final packages = json['packages'] as List<dynamic>? ?? [];

        for (final pkg in packages) {
          final pkgName = pkg['name'] as String;
          if (pkgName == project.projectName) continue;

          final rootUri = pkg['rootUri'] as String;
          String pkgPath;
          if (rootUri.startsWith('file://')) {
            pkgPath = Uri.parse(rootUri).toFilePath();
          } else {
            pkgPath = p.normalize(p.join(project.rootDir.path, '.dart_tool', rootUri));
          }

          final pubspecFile = File(p.join(pkgPath, 'pubspec.yaml'));
          final manifestFile = File(p.join(pkgPath, 'bloom.module.yaml'));

          String version = '0.0.0';
          final subDeps = <String>[];

          if (pubspecFile.existsSync()) {
            try {
              final pubYaml = loadYaml(pubspecFile.readAsStringSync()) as YamlMap?;
              version = pubYaml?['version']?.toString() ?? '0.0.0';
              final subYamlDeps = pubYaml?['dependencies'] as YamlMap?;
              if (subYamlDeps != null) {
                for (final k in subYamlDeps.keys) {
                  subDeps.add(k.toString());
                }
              }
            } catch (_) {}
          }

          final isNative = manifestFile.existsSync();
          final platforms = <String>[];
          Map<String, dynamic>? manifestData;

          if (isNative) {
            try {
              final raw = loadYaml(manifestFile.readAsStringSync());
              if (raw is YamlMap) {
                manifestData = Map<String, dynamic>.from(raw);
                final plats = manifestData['platforms'];
                if (plats is Map) {
                  for (final k in plats.keys) {
                    platforms.add(k.toString());
                  }
                }
              }
            } catch (_) {}
            if (platforms.isEmpty) {
              if (Directory(p.join(pkgPath, 'android')).existsSync()) platforms.add('android');
              if (Directory(p.join(pkgPath, 'ios')).existsSync()) platforms.add('ios');
            }
          }

          _nodes[pkgName] = GraphPackageNode(
            name: pkgName,
            version: version,
            isDirect: directDeps.containsKey(pkgName),
            isNativeModule: isNative,
            nativePlatforms: platforms,
            dependencies: subDeps,
            moduleManifest: manifestData,
          );
        }
      } catch (_) {}
    }

    // 2. Discover path dependencies from pubspec.yaml if missing
    if (project.pubspecFile.existsSync()) {
      try {
        final yaml = loadYaml(project.pubspecFile.readAsStringSync()) as YamlMap?;
        final deps = yaml?['dependencies'] as YamlMap?;
        if (deps != null) {
          for (final entry in deps.entries) {
            final pkgName = entry.key.toString();
            if (_nodes.containsKey(pkgName) || pkgName == 'flutter') continue;

            if (entry.value is YamlMap && (entry.value as YamlMap).containsKey('path')) {
              final relPath = (entry.value as YamlMap)['path'].toString();
              final pkgDir = Directory(p.normalize(p.join(project.rootDir.path, relPath)));
              if (pkgDir.existsSync()) {
                final manifestFile = File(p.join(pkgDir.path, 'bloom.module.yaml'));
                final isNative = manifestFile.existsSync();
                final platforms = <String>[];
                Map<String, dynamic>? manifestData;
                if (isNative) {
                  try {
                    final raw = loadYaml(manifestFile.readAsStringSync());
                    if (raw is YamlMap) {
                      manifestData = Map<String, dynamic>.from(raw);
                      final plats = manifestData['platforms'];
                      if (plats is Map) {
                        for (final k in plats.keys) {
                          platforms.add(k.toString());
                        }
                      }
                    }
                  } catch (_) {}
                }
                _nodes[pkgName] = GraphPackageNode(
                  name: pkgName,
                  version: '1.0.0',
                  isDirect: true,
                  isNativeModule: isNative,
                  nativePlatforms: platforms.isNotEmpty ? platforms : ['android', 'ios'],
                  dependencies: [],
                  moduleManifest: manifestData,
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    // 3. Include plugins from bloom.yaml if missing
    final config = project.loadBloomConfig();
    final plugins = config['plugins'] is List ? (config['plugins'] as List) : [];
    for (final plugin in plugins) {
      final pluginName = plugin is String ? plugin : (plugin is Map ? plugin.keys.first.toString() : '');
      if (pluginName.isNotEmpty && !_nodes.containsKey(pluginName)) {
        _nodes[pluginName] = GraphPackageNode(
          name: pluginName,
          version: '1.0.0',
          isDirect: true,
          isNativeModule: true,
          nativePlatforms: ['android', 'ios'],
          dependencies: [],
        );
      }
    }

    return _nodes;
  }

  /// Formats and renders the entire dependency tree as ASCII output.
  String renderTree() {
    final nodes = resolveGraph();
    final buffer = StringBuffer();

    buffer.writeln('📦 ${Ansi.boldText(project.projectName)} (root)');

    final directNodes = nodes.values.where((n) => n.isDirect).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (var i = 0; i < directNodes.length; i++) {
      final isLast = i == directNodes.length - 1;
      final node = directNodes[i];
      _renderNode(node, buffer, prefix: '', isLast: isLast, visited: <String>{project.projectName});
    }

    return buffer.toString();
  }

  void _renderNode(
    GraphPackageNode node,
    StringBuffer buffer, {
    required String prefix,
    required bool isLast,
    required Set<String> visited,
  }) {
    final connector = isLast ? '└── ' : '├── ';
    final childPrefix = prefix + (isLast ? '    ' : '│   ');

    final nativeBadge = node.isNativeModule
        ? ' ${Ansi.cyan}[Native: ${node.nativePlatforms.map((p) => p[0].toUpperCase() + p.substring(1)).join(', ')}]${Ansi.reset}'
        : '';

    final nameFormatted = node.isNativeModule
        ? Ansi.boldText(node.name)
        : node.name;

    buffer.writeln('$prefix$connector$nameFormatted (v${node.version})$nativeBadge');

    if (visited.contains(node.name)) return;
    visited.add(node.name);

    final childDeps = node.dependencies
        .where((dep) => _nodes.containsKey(dep) && !visited.contains(dep))
        .map((dep) => _nodes[dep]!)
        .where((n) => n.isNativeModule || n.dependencies.any((d) => _nodes[d]?.isNativeModule == true))
        .toList();

    for (var i = 0; i < childDeps.length; i++) {
      _renderNode(
        childDeps[i],
        buffer,
        prefix: childPrefix,
        isLast: i == childDeps.length - 1,
        visited: visited,
      );
    }
  }

  /// Traces and explains why a dependency or module is present in the project.
  String explain(String targetPackage) {
    resolveGraph();
    final buffer = StringBuffer();

    final target = _nodes[targetPackage];
    if (target == null) {
      return 'Package "$targetPackage" is not part of the project dependency graph.';
    }

    buffer.writeln('${Ansi.boldText(target.name)} (v${target.version})');

    final paths = _findPathsToRoot(targetPackage);
    if (paths.isEmpty) {
      buffer.writeln('└── ${project.projectName} (root)');
    } else {
      for (final p in paths) {
        final reversed = p.reversed.toList();
        buffer.writeln('├── ${reversed.join(' ➔ ')}');
      }
    }

    if (target.isNativeModule) {
      buffer.writeln('\nNative Capabilities:');
      final plats = target.nativePlatforms;
      for (final plat in plats) {
        buffer.writeln('  • ${plat[0].toUpperCase() + plat.substring(1)} Native Bridge & Manifest');
      }

      final manifest = target.moduleManifest;
      if (manifest != null && manifest['permissions'] != null) {
        buffer.writeln('\nRequired Permissions:');
        final rawPerms = manifest['permissions'];
        final List<String> permStrings = [];
        if (rawPerms is List) {
          for (final p in rawPerms) {
            permStrings.add(p.toString());
          }
        } else if (rawPerms is Map) {
          for (final entry in rawPerms.entries) {
            final desc = entry.value is Map ? entry.value['description'] : entry.value;
            permStrings.add('${entry.key}${desc != null ? ' ($desc)' : ''}');
          }
        }
        for (final p in permStrings) {
          buffer.writeln('  + $p');
        }
      }
    }

    return buffer.toString();
  }

  List<List<String>> _findPathsToRoot(String target) {
    final results = <List<String>>[];
    final direct = _nodes.values.where((n) => n.isDirect).map((n) => n.name).toSet();

    if (direct.contains(target)) {
      results.add([target, '${project.projectName} (root)']);
      return results;
    }

    void dfs(String current, List<String> currentPath, Set<String> visited) {
      if (visited.contains(current)) return;
      visited.add(current);

      for (final node in _nodes.values) {
        if (node.dependencies.contains(current)) {
          final newPath = [...currentPath, node.name];
          if (node.isDirect) {
            results.add([...newPath, '${project.projectName} (root)']);
          } else {
            dfs(node.name, newPath, Set.from(visited));
          }
        }
      }
    }

    dfs(target, [target], {});
    return results;
  }
}
