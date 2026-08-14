// lib/src/native/workspace_manager.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'prebuild_engine.dart';

enum WorkspaceProjectType {
  app,
  package,
  nativeModule,
}

class WorkspaceProject {
  final String name;
  final String version;
  final WorkspaceProjectType type;
  final Directory dir;
  final List<String> dependencies;

  const WorkspaceProject({
    required this.name,
    required this.version,
    required this.type,
    required this.dir,
    this.dependencies = const [],
  });

  String get typeLabel {
    switch (type) {
      case WorkspaceProjectType.app:
        return '📱 App';
      case WorkspaceProjectType.package:
        return '📦 Dart Package';
      case WorkspaceProjectType.nativeModule:
        return '🔌 Native Module';
    }
  }
}

/// Discovers and coordinates multi-package monorepos and workspaces.
class BloomWorkspaceManager {
  final Directory rootDir;

  BloomWorkspaceManager(this.rootDir);

  /// Discovers the nearest workspace root or uses current directory.
  static BloomWorkspaceManager? find([Directory? startDir]) {
    var current = startDir ?? Directory.current;
    while (true) {
      final pubspec = File(p.join(current.path, 'pubspec.yaml'));
      final hasApps = Directory(p.join(current.path, 'apps')).existsSync();
      final hasPackages = Directory(p.join(current.path, 'packages')).existsSync();
      final hasModules = Directory(p.join(current.path, 'modules')).existsSync();

      if (hasApps || hasPackages || hasModules) {
        return BloomWorkspaceManager(current);
      }

      if (pubspec.existsSync()) {
        try {
          final yaml = loadYaml(pubspec.readAsStringSync());
          if (yaml is YamlMap && yaml.containsKey('workspace')) {
            return BloomWorkspaceManager(current);
          }
        } catch (_) {}
      }

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    return null;
  }

  /// Discovers all projects inside the workspace.
  List<WorkspaceProject> discoverProjects() {
    final projects = <WorkspaceProject>[];
    final subdirs = ['apps', 'packages', 'modules', 'examples'];

    for (final sub in subdirs) {
      final dir = Directory(p.join(rootDir.path, sub));
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          final pubspecFile = File(p.join(entity.path, 'pubspec.yaml'));
          final moduleYamlFile = File(p.join(entity.path, 'bloom.module.yaml'));
          final bloomYamlFile = File(p.join(entity.path, 'bloom.yaml'));

          if (pubspecFile.existsSync()) {
            try {
              final yaml = loadYaml(pubspecFile.readAsStringSync()) as YamlMap?;
              final name = yaml?['name']?.toString() ?? p.basename(entity.path);
              final version = yaml?['version']?.toString() ?? '0.1.0';
              final deps = <String>[];
              final rawDeps = yaml?['dependencies'] as YamlMap?;
              if (rawDeps != null) {
                for (final k in rawDeps.keys) {
                  deps.add(k.toString());
                }
              }

              WorkspaceProjectType type = WorkspaceProjectType.package;
              if (moduleYamlFile.existsSync()) {
                type = WorkspaceProjectType.nativeModule;
              } else if (bloomYamlFile.existsSync() || sub == 'apps') {
                type = WorkspaceProjectType.app;
              }

              projects.add(WorkspaceProject(
                name: name,
                version: version,
                type: type,
                dir: entity,
                dependencies: deps,
              ));
            } catch (_) {}
          }
        }
      }
    }

    return projects;
  }

  /// Performs genuine topological sort of workspace projects.
  /// A dependency will always appear before any project that depends on it.
  List<WorkspaceProject> topologicalSort() {
    final projects = discoverProjects();
    final projectMap = {for (final p in projects) p.name: p};
    final inDegree = <String, int>{for (final p in projects) p.name: 0};
    final outgoing = <String, Set<String>>{for (final p in projects) p.name: <String>{}};

    for (final project in projects) {
      for (final dep in project.dependencies) {
        if (projectMap.containsKey(dep)) {
          // dep -> project (dep must be tested before project)
          outgoing[dep]!.add(project.name);
          inDegree[project.name] = (inDegree[project.name] ?? 0) + 1;
        }
      }
    }

    // Queue of projects with 0 dependencies within the workspace
    final queue = projects.where((p) => (inDegree[p.name] ?? 0) == 0).map((p) => p.name).toList()
      ..sort();

    final result = <WorkspaceProject>[];
    while (queue.isNotEmpty) {
      final currentName = queue.removeAt(0);
      final currentProj = projectMap[currentName]!;
      result.add(currentProj);

      for (final dependent in outgoing[currentName] ?? <String>{}) {
        inDegree[dependent] = (inDegree[dependent] ?? 1) - 1;
        if (inDegree[dependent] == 0) {
          queue.add(dependent);
          queue.sort();
        }
      }
    }

    // Handle any circular or remaining packages
    for (final project in projects) {
      if (!result.contains(project)) {
        result.add(project);
      }
    }

    return result;
  }

  /// Prints workspace status overview.
  void printStatus() {
    final projects = discoverProjects();
    print(Ansi.boldText('\n🏢 Bloom Workspace Status: ${rootDir.path}\n'));

    if (projects.isEmpty) {
      print(Ansi.warn('No apps or packages found in workspace directories (apps/, packages/, modules/).'));
      return;
    }

    print('Found ${projects.length} project(s) across workspace:\n');
    for (final p in projects) {
      final relPath = p.dir.path.replaceFirst('${rootDir.path}/', '');
      print('  ${p.typeLabel}  ${Ansi.boldText(p.name)} (v${p.version}) ➔ ${Ansi.cyan}$relPath${Ansi.reset}');
    }
    print('');
  }

  /// Runs Prebuild on all apps in the workspace in parallel.
  Future<int> prebuildAll() async {
    final apps = discoverProjects().where((p) => p.type == WorkspaceProjectType.app).toList();
    print(Ansi.boldText('\n⚙  Running Prebuild in parallel across ${apps.length} workspace app(s)...\n'));

    final results = await Future.wait(apps.map((proj) async {
      print('› Prebuilding: ${Ansi.cyan}${proj.name}${Ansi.reset}');
      final bloomProj = BloomProject(
        rootDir: proj.dir,
        bloomYamlFile: File(p.join(proj.dir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(proj.dir.path, 'pubspec.yaml')),
      );

      final engine = PrebuildEngine(bloomProj);
      return engine.run();
    }));

    final failed = results.where((ok) => !ok).length;
    return failed == 0 ? 0 : 1;
  }

  /// Runs tests across all workspace packages with true topological dependency ordering.
  Future<int> testAll() async {
    final ordered = topologicalSort();
    print(Ansi.boldText('\n🧪 Running tests across ${ordered.length} workspace package(s) (topological order)...\n'));

    var failed = 0;
    for (final proj in ordered) {
      final testDir = Directory(p.join(proj.dir.path, 'test'));
      if (!testDir.existsSync()) continue;

      print('› Testing [${proj.typeLabel}]: ${Ansi.cyan}${proj.name}${Ansi.reset}');
      final result = await Process.run('flutter', ['test'], workingDirectory: proj.dir.path);
      if (result.exitCode != 0) {
        print(Ansi.error('Tests failed in ${proj.name}:\n${result.stdout}\n${result.stderr}'));
        failed++;
      } else {
        print(Ansi.success('All tests passed in ${proj.name}!'));
      }
    }

    return failed == 0 ? 0 : 1;
  }
}
