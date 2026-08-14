// lib/src/native/autolink_engine.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Represents a discovered native Bloom module in the dependency graph.
class DiscoveredNativeModule {
  final String name;
  final String version;
  final String packagePath;
  final String sourceType; // 'path', 'hosted', 'git'
  final bool isDirect;
  final Map<String, dynamic> manifest;
  final String fingerprint;

  const DiscoveredNativeModule({
    required this.name,
    required this.version,
    required this.packagePath,
    required this.sourceType,
    required this.isDirect,
    required this.manifest,
    required this.fingerprint,
  });

  bool get hasAndroid =>
      Directory(p.join(packagePath, 'android')).existsSync() ||
      manifest['platforms']?['android'] != null;

  bool get hasIos =>
      Directory(p.join(packagePath, 'ios')).existsSync() ||
      manifest['platforms']?['ios'] != null;

  Map<String, dynamic>? get androidSpec =>
      manifest['platforms']?['android'] as Map<String, dynamic>?;

  Map<String, dynamic>? get iosSpec =>
      manifest['platforms']?['ios'] as Map<String, dynamic>?;
}

/// Autolinking conflict information.
class AutolinkConflict {
  final String moduleName;
  final List<String> conflictingVersions;
  final Map<String, String> requestedBy;

  const AutolinkConflict({
    required this.moduleName,
    required this.conflictingVersions,
    required this.requestedBy,
  });
}

/// Zero-config autolinking and native dependency resolution engine.
class AutolinkEngine {
  final BloomProject project;

  AutolinkEngine(this.project);

  /// Discovers all direct and transitive Bloom native modules.
  List<DiscoveredNativeModule> discoverModules() {
    final modules = <String, DiscoveredNativeModule>{};
    final directDeps = _getDirectDependencies();

    // 1. Inspect package_config.json if available
    final packageConfigFile = File(
      p.join(project.rootDir.path, '.dart_tool', 'package_config.json'),
    );

    if (packageConfigFile.existsSync()) {
      try {
        final json = jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
        final packages = json['packages'] as List<dynamic>? ?? [];

        for (final pkg in packages) {
          final pkgName = pkg['name'] as String;
          final rootUri = pkg['rootUri'] as String;

          String pkgPath;
          if (rootUri.startsWith('file://')) {
            pkgPath = Uri.parse(rootUri).toFilePath();
          } else {
            // Relative URI relative to .dart_tool/
            pkgPath = p.normalize(p.join(project.rootDir.path, '.dart_tool', rootUri));
          }

          final manifestFile = File(p.join(pkgPath, 'bloom.module.yaml'));
          if (manifestFile.existsSync()) {
            final manifest = _loadYamlMap(manifestFile);
            final version = _resolvePackageVersion(pkgPath, manifest);
            final sourceType = _resolveSourceType(pkgPath);
            final fingerprint = _calculateFingerprint(pkgPath, manifestFile);

            modules[pkgName] = DiscoveredNativeModule(
              name: pkgName,
              version: version,
              packagePath: pkgPath,
              sourceType: sourceType,
              isDirect: directDeps.contains(pkgName),
              manifest: manifest,
              fingerprint: fingerprint,
            );
          }
        }
      } catch (_) {}
    }

    // 2. Inspect workspace packages or sibling packages/modules directory
    final searchDirs = [
      Directory(p.join(project.rootDir.path, 'packages')),
      Directory(p.join(project.rootDir.path, 'modules')),
      Directory(p.join(project.rootDir.parent.path, 'packages')),
      Directory(p.join(project.rootDir.parent.path, 'modules')),
    ];

    for (final dir in searchDirs) {
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          final manifestFile = File(p.join(entity.path, 'bloom.module.yaml'));
          final pubspecFile = File(p.join(entity.path, 'pubspec.yaml'));

          if (manifestFile.existsSync() && pubspecFile.existsSync()) {
            final manifest = _loadYamlMap(manifestFile);
            final pubspec = _loadYamlMap(pubspecFile);
            final pkgName = pubspec['name']?.toString() ?? p.basename(entity.path);

            if (!modules.containsKey(pkgName)) {
              final version = pubspec['version']?.toString() ?? '0.1.0';
              final fingerprint = _calculateFingerprint(entity.path, manifestFile);

              modules[pkgName] = DiscoveredNativeModule(
                name: pkgName,
                version: version,
                packagePath: entity.path,
                sourceType: 'path',
                isDirect: directDeps.contains(pkgName),
                manifest: manifest,
                fingerprint: fingerprint,
              );
            }
          }
        }
      }
    }

    // 3. Inspect plugins declared in bloom.yaml
    final config = project.loadBloomConfig();
    final plugins = config['plugins'] is List ? (config['plugins'] as List) : [];
    for (final plugin in plugins) {
      final pluginName = plugin is String ? plugin : (plugin is Map ? plugin.keys.first.toString() : '');
      if (pluginName.isNotEmpty && !modules.containsKey(pluginName)) {
        // Built-in or synthetic module
        modules[pluginName] = DiscoveredNativeModule(
          name: pluginName,
          version: '1.0.0',
          packagePath: project.rootDir.path,
          sourceType: 'builtin',
          isDirect: true,
          manifest: {
            'name': pluginName,
            'platforms': {
              'android': {'min_sdk': 24, 'target_sdk': 34},
              'ios': {'min_version': '15.0'},
            },
          },
          fingerprint: 'builtin-$pluginName',
        );
      }
    }

    return modules.values.toList();
  }

  /// Detects version collisions among discovered native modules.
  List<AutolinkConflict> detectConflicts() {
    final conflicts = <AutolinkConflict>[];
    // In a multi-package tree, check if multiple versions of the same native binary are requested
    final Map<String, Set<String>> versionsByModule = {};
    final Map<String, Map<String, String>> requestedBy = {};

    final modules = discoverModules();
    for (final mod in modules) {
      versionsByModule.putIfAbsent(mod.name, () => {}).add(mod.version);
      requestedBy.putIfAbsent(mod.name, () => {})[mod.packagePath] = mod.version;
    }

    for (final entry in versionsByModule.entries) {
      if (entry.value.length > 1) {
        conflicts.add(AutolinkConflict(
          moduleName: entry.key,
          conflictingVersions: entry.value.toList(),
          requestedBy: requestedBy[entry.key] ?? {},
        ));
      }
    }

    return conflicts;
  }

  /// Runs full zero-config autolinking for Android and iOS targets, and generates bloom.lock.
  Future<bool> runAutolink() async {
    final modules = discoverModules();
    final conflicts = detectConflicts();

    if (conflicts.isNotEmpty) {
      print(Ansi.error('\n✖ Duplicate Native Module Conflict Detected:'));
      for (final c in conflicts) {
        print('  ${Ansi.boldText(c.moduleName)}:');
        print('    Conflicting versions: ${c.conflictingVersions.join(', ')}');
        print('    Requested by:');
        c.requestedBy.forEach((path, ver) {
          print('      • $path ➔ $ver');
        });
      }
      print('\nSuggested Action: Run `bloom why <module>` to inspect dependency chains.\n');
      return false;
    }

    // 1. Generate android/bloom_autolinking.gradle
    _generateAndroidAutolinking(modules);

    // 2. Generate ios/BloomAutolinking.podspec.json
    _generateIosAutolinking(modules);

    // 3. Generate deterministic bloom.lock
    _generateBloomLock(modules);

    return true;
  }

  void _generateAndroidAutolinking(List<DiscoveredNativeModule> modules) {
    final androidDir = Directory(p.join(project.rootDir.path, 'android'));
    if (!androidDir.existsSync()) return;

    final gradleFile = File(p.join(androidDir.path, 'bloom_autolinking.gradle'));
    final buffer = StringBuffer();

    buffer.writeln('// AUTO-GENERATED BY BLOOM CLI AUTOLINKING ENGINE. DO NOT EDIT.');
    buffer.writeln('// Discovered native modules for Android build.');
    buffer.writeln();
    buffer.writeln('gradle.projectsLoaded {');

    for (final mod in modules.where((m) => m.hasAndroid && m.sourceType != 'builtin')) {
      final moduleAndroidDir = p.join(mod.packagePath, 'android');
      if (Directory(moduleAndroidDir).existsSync()) {
        final projName = ':${mod.name}';
        buffer.writeln("    include '$projName'");
        buffer.writeln("    project('$projName').projectDir = new File('${p.normalize(moduleAndroidDir)}')");
      }
    }

    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('subprojects {');
    buffer.writeln('    afterEvaluate { project ->');
    buffer.writeln('        if (project.hasProperty("android")) {');
    buffer.writeln('            project.android {');
    buffer.writeln('                compileSdkVersion 34');
    buffer.writeln('                defaultConfig {');
    buffer.writeln('                    minSdkVersion 24');
    buffer.writeln('                    targetSdkVersion 34');
    buffer.writeln('                }');
    buffer.writeln('            }');
    buffer.writeln('        }');
    buffer.writeln('    }');
    buffer.writeln('}');

    gradleFile.writeAsStringSync(buffer.toString());
  }

  void _generateIosAutolinking(List<DiscoveredNativeModule> modules) {
    final iosDir = Directory(p.join(project.rootDir.path, 'ios'));
    if (!iosDir.existsSync()) return;

    final jsonFile = File(p.join(iosDir.path, 'BloomAutolinking.podspec.json'));
    final podspecList = <Map<String, dynamic>>[];

    for (final mod in modules.where((m) => m.hasIos && m.sourceType != 'builtin')) {
      final iosPath = p.join(mod.packagePath, 'ios');
      if (Directory(iosPath).existsSync()) {
        podspecList.add({
          'name': mod.name,
          'version': mod.version,
          'path': p.normalize(iosPath),
          'frameworks': mod.iosSpec?['frameworks'] ?? [],
        });
      }
    }

    final output = {
      'generated_by': 'Bloom Autolink Engine',
      'modules': podspecList,
    };

    jsonFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  }

  void _generateBloomLock(List<DiscoveredNativeModule> modules) {
    final lockFile = File(p.join(project.rootDir.path, 'bloom.lock'));
    final buffer = StringBuffer();

    buffer.writeln('# AUTO-GENERATED BY BLOOM CLI. DO NOT EDIT.');
    buffer.writeln('lockfile_version: 1');
    buffer.writeln('bloom_version: 1.0.0');
    buffer.writeln('generated_at: ${DateTime.now().toUtc().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('native_modules:');

    for (final mod in modules) {
      buffer.writeln('  ${mod.name}:');
      buffer.writeln('    version: ${mod.version}');
      buffer.writeln('    source: ${mod.sourceType}');
      buffer.writeln('    path: "${p.relative(mod.packagePath, from: project.rootDir.path)}"');
      buffer.writeln('    fingerprint: "${mod.fingerprint}"');
      buffer.writeln('    is_direct: ${mod.isDirect}');

      if (mod.androidSpec != null || mod.hasAndroid) {
        buffer.writeln('    android:');
        buffer.writeln('      min_sdk: ${mod.androidSpec?['min_sdk'] ?? 24}');
        buffer.writeln('      target_sdk: ${mod.androidSpec?['target_sdk'] ?? 34}');
        final deps = mod.androidSpec?['dependencies'] as List? ?? [];
        if (deps.isNotEmpty) {
          buffer.writeln('      dependencies:');
          for (final d in deps) {
            buffer.writeln('        - "$d"');
          }
        }
      }

      if (mod.iosSpec != null || mod.hasIos) {
        buffer.writeln('    ios:');
        buffer.writeln('      min_version: "${mod.iosSpec?['min_version'] ?? '15.0'}"');
        final frameworks = mod.iosSpec?['frameworks'] as List? ?? [];
        if (frameworks.isNotEmpty) {
          buffer.writeln('      frameworks:');
          for (final f in frameworks) {
            buffer.writeln('        - "$f"');
          }
        }
      }
      buffer.writeln();
    }

    lockFile.writeAsStringSync(buffer.toString());
  }

  Set<String> _getDirectDependencies() {
    final direct = <String>{};
    if (project.pubspecFile.existsSync()) {
      try {
        final yaml = loadYaml(project.pubspecFile.readAsStringSync()) as YamlMap?;
        final deps = yaml?['dependencies'] as YamlMap?;
        if (deps != null) {
          for (final k in deps.keys) {
            direct.add(k.toString());
          }
        }
      } catch (_) {}
    }
    return direct;
  }

  Map<String, dynamic> _loadYamlMap(File file) {
    try {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is YamlMap) {
        return _deepConvertYamlMap(yaml);
      }
    } catch (_) {}
    return {};
  }

  Map<String, dynamic> _deepConvertYamlMap(YamlMap map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      final strKey = key.toString();
      if (value is YamlMap) {
        result[strKey] = _deepConvertYamlMap(value);
      } else if (value is YamlList) {
        result[strKey] = value.map((e) => e is YamlMap ? _deepConvertYamlMap(e) : e).toList();
      } else {
        result[strKey] = value;
      }
    });
    return result;
  }

  String _resolvePackageVersion(String pkgPath, Map<String, dynamic> manifest) {
    final pubspecFile = File(p.join(pkgPath, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      final pubspec = _loadYamlMap(pubspecFile);
      if (pubspec['version'] != null) {
        return pubspec['version'].toString();
      }
    }
    return manifest['version']?.toString() ?? '1.0.0';
  }

  String _resolveSourceType(String pkgPath) {
    if (pkgPath.contains('.pub-cache')) {
      return 'hosted';
    } else if (pkgPath.contains('git')) {
      return 'git';
    }
    return 'path';
  }

  String _calculateFingerprint(String pkgPath, File manifestFile) {
    final hashInput = StringBuffer();
    hashInput.writeln(manifestFile.readAsStringSync());

    final nativeDirs = [
      Directory(p.join(pkgPath, 'android')),
      Directory(p.join(pkgPath, 'ios')),
    ];

    for (final d in nativeDirs) {
      if (d.existsSync()) {
        final files = d.listSync(recursive: true).whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final f in files) {
          hashInput.writeln('${p.basename(f.path)}:${f.lengthSync()}');
        }
      }
    }

    return sha256.convert(utf8.encode(hashInput.toString())).toString().substring(0, 16);
  }
}
