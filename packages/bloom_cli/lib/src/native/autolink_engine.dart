// lib/src/native/autolink_engine.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Represents a single native module requirement from a package in the dependency tree.
class ModuleRequirement {
  final String moduleName;
  final String versionConstraint;
  final String resolvedVersion;
  final String requesterName;
  final String requesterPath;
  final String packagePath;
  final String sourceType; // 'path', 'hosted', 'git', 'builtin'
  final bool isDirect;
  final Map<String, dynamic> manifest;
  final String fingerprint;

  const ModuleRequirement({
    required this.moduleName,
    required this.versionConstraint,
    required this.resolvedVersion,
    required this.requesterName,
    required this.requesterPath,
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

/// Represents a discovered native Bloom module in the dependency graph.
class DiscoveredNativeModule {
  final String name;
  final String version;
  final String packagePath;
  final String sourceType; // 'path', 'hosted', 'git', 'builtin'
  final bool isDirect;
  final Map<String, dynamic> manifest;
  final String fingerprint;
  final List<ModuleRequirement> requirements;

  const DiscoveredNativeModule({
    required this.name,
    required this.version,
    required this.packagePath,
    required this.sourceType,
    required this.isDirect,
    required this.manifest,
    required this.fingerprint,
    this.requirements = const [],
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
  final List<ModuleRequirement> requirements;

  const AutolinkConflict({
    required this.moduleName,
    required this.conflictingVersions,
    required this.requirements,
  });
}

/// Zero-config autolinking and native dependency resolution engine.
class AutolinkEngine {
  final BloomProject project;

  AutolinkEngine(this.project);

  /// Discovers all direct and transitive module requirements across the dependency tree.
  List<ModuleRequirement> discoverAllRequirements() {
    final requirements = <ModuleRequirement>[];
    final visitedPackages = <String>{};

    // 1. Recursive traversal starting from root project
    void traversePackage(Directory pkgDir, String requesterName, bool isRoot) {
      final normalizedPath = p.normalize(pkgDir.path);
      if (visitedPackages.contains(normalizedPath)) return;
      visitedPackages.add(normalizedPath);

      final pubspecFile = File(p.join(normalizedPath, 'pubspec.yaml'));
      final manifestFile = File(p.join(normalizedPath, 'bloom.module.yaml'));

      if (!pubspecFile.existsSync()) return;
      final pubspec = _loadYamlMap(pubspecFile);
      final currentPkgName = pubspec['name']?.toString() ?? p.basename(normalizedPath);
      final currentVersion = pubspec['version']?.toString() ?? '0.1.0';

      // If current package is a native module, record requirement
      if (manifestFile.existsSync()) {
        final manifest = _loadYamlMap(manifestFile);
        final fingerprint = _calculateFingerprint(normalizedPath, manifestFile);
        final sourceType = _resolveSourceType(normalizedPath);

        requirements.add(ModuleRequirement(
          moduleName: manifest['name']?.toString() ?? currentPkgName,
          versionConstraint: currentVersion,
          resolvedVersion: currentVersion,
          requesterName: requesterName,
          requesterPath: pkgDir.path,
          packagePath: normalizedPath,
          sourceType: sourceType,
          isDirect: isRoot,
          manifest: manifest,
          fingerprint: fingerprint,
        ));
      }

      // Traverse dependencies declared in pubspec.yaml
      final deps = pubspec['dependencies'];
      if (deps is Map) {
        for (final entry in deps.entries) {
          final depName = entry.key.toString();
          if (depName == 'flutter' || depName == 'bloom_framework') continue;

          final val = entry.value;
          if (val is Map && val.containsKey('path')) {
            final relPath = val['path'].toString();
            final targetDir = Directory(p.normalize(p.join(normalizedPath, relPath)));
            if (targetDir.existsSync()) {
              traversePackage(targetDir, currentPkgName, false);
            }
          }
        }
      }
    }

    traversePackage(project.rootDir, project.projectName, true);

    // 2. Inspect package_config.json if available
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

          final manifestFile = File(p.join(pkgPath, 'bloom.module.yaml'));
          if (manifestFile.existsSync()) {
            final manifest = _loadYamlMap(manifestFile);
            final version = _resolvePackageVersion(pkgPath, manifest);
            final sourceType = _resolveSourceType(pkgPath);
            final fingerprint = _calculateFingerprint(pkgPath, manifestFile);

            requirements.add(ModuleRequirement(
              moduleName: manifest['name']?.toString() ?? pkgName,
              versionConstraint: version,
              resolvedVersion: version,
              requesterName: project.projectName,
              requesterPath: project.rootDir.path,
              packagePath: pkgPath,
              sourceType: sourceType,
              isDirect: _getDirectDependencies().contains(pkgName),
              manifest: manifest,
              fingerprint: fingerprint,
            ));
          }
        }
      } catch (_) {}
    }

    // 3. Inspect workspace packages or sibling packages/modules directories
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
            final pkgName = manifest['name']?.toString() ?? pubspec['name']?.toString() ?? p.basename(entity.path);
            final version = pubspec['version']?.toString() ?? '0.1.0';
            final fingerprint = _calculateFingerprint(entity.path, manifestFile);

            requirements.add(ModuleRequirement(
              moduleName: pkgName,
              versionConstraint: version,
              resolvedVersion: version,
              requesterName: 'workspace',
              requesterPath: dir.path,
              packagePath: entity.path,
              sourceType: 'path',
              isDirect: _getDirectDependencies().contains(pkgName),
              manifest: manifest,
              fingerprint: fingerprint,
            ));
          }
        }
      }
    }

    // 4. Builtin plugins from bloom.yaml
    final config = project.loadBloomConfig();
    final plugins = config['plugins'] is List ? (config['plugins'] as List) : [];
    for (final plugin in plugins) {
      final pluginName = plugin is String ? plugin : (plugin is Map ? plugin.keys.first.toString() : '');
      if (pluginName.isNotEmpty) {
        requirements.add(ModuleRequirement(
          moduleName: pluginName,
          versionConstraint: '1.0.0',
          resolvedVersion: '1.0.0',
          requesterName: project.projectName,
          requesterPath: project.rootDir.path,
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
        ));
      }
    }

    return requirements;
  }

  /// Discovers all unique direct and transitive Bloom native modules.
  List<DiscoveredNativeModule> discoverModules() {
    final allReqs = discoverAllRequirements();
    final moduleMap = <String, List<ModuleRequirement>>{};

    for (final req in allReqs) {
      moduleMap.putIfAbsent(req.moduleName, () => []).add(req);
    }

    final modules = <DiscoveredNativeModule>[];
    for (final entry in moduleMap.entries) {
      final reqs = entry.value;
      final first = reqs.first;
      modules.add(DiscoveredNativeModule(
        name: entry.key,
        version: first.resolvedVersion,
        packagePath: first.packagePath,
        sourceType: first.sourceType,
        isDirect: reqs.any((r) => r.isDirect),
        manifest: first.manifest,
        fingerprint: first.fingerprint,
        requirements: reqs,
      ));
    }

    return modules;
  }

  /// Detects version collisions among discovered native modules across the dependency graph.
  List<AutolinkConflict> detectConflicts() {
    final conflicts = <AutolinkConflict>[];
    final allReqs = discoverAllRequirements();
    final Map<String, List<ModuleRequirement>> reqsByModule = {};

    for (final req in allReqs) {
      reqsByModule.putIfAbsent(req.moduleName, () => []).add(req);
    }

    for (final entry in reqsByModule.entries) {
      final moduleName = entry.key;
      final reqs = entry.value;
      final distinctVersions = reqs.map((r) => r.resolvedVersion).toSet().toList();

      if (distinctVersions.length > 1) {
        conflicts.add(AutolinkConflict(
          moduleName: moduleName,
          conflictingVersions: distinctVersions,
          requirements: reqs,
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
        for (final req in c.requirements) {
          print('      • ${req.requesterName} (at ${req.requesterPath}) ➔ requires ${req.resolvedVersion}');
        }
      }
      print('\nSuggested Action: Run `bloom why <module>` to inspect dependency chains.\n');
      return false;
    }

    // 1. Generate & Apply android/bloom_autolinking.gradle
    _generateAndroidAutolinking(modules);

    // 2. Generate & Apply ios/BloomAutolinking.podspec.json + BloomAutolinking.rb
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
    buffer.writeln('// Native module subproject bindings for Android.');
    buffer.writeln();

    for (final mod in modules.where((m) => m.hasAndroid && m.sourceType != 'builtin')) {
      final moduleAndroidDir = p.join(mod.packagePath, 'android');
      if (Directory(moduleAndroidDir).existsSync()) {
        final projName = ':${mod.name}';
        buffer.writeln("include '$projName'");
        buffer.writeln("project('$projName').projectDir = new File('${p.normalize(moduleAndroidDir)}')");
      }
    }

    gradleFile.writeAsStringSync(buffer.toString());

    // Inject into settings.gradle or settings.gradle.kts if missing
    _injectGradleSettingsInclude(androidDir);
  }

  void _injectGradleSettingsInclude(Directory androidDir) {
    final settingsKts = File(p.join(androidDir.path, 'settings.gradle.kts'));
    final settingsGroovy = File(p.join(androidDir.path, 'settings.gradle'));

    if (settingsKts.existsSync()) {
      var content = settingsKts.readAsStringSync();
      if (!content.contains('bloom_autolinking.gradle')) {
        content += '\n// Bloom Native Autolinking\napply(from = "bloom_autolinking.gradle")\n';
        settingsKts.writeAsStringSync(content);
      }
    } else if (settingsGroovy.existsSync()) {
      var content = settingsGroovy.readAsStringSync();
      if (!content.contains('bloom_autolinking.gradle')) {
        content += '\n// Bloom Native Autolinking\napply from: "bloom_autolinking.gradle"\n';
        settingsGroovy.writeAsStringSync(content);
      }
    }
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

    // Generate BloomAutolinking.rb
    final rbFile = File(p.join(iosDir.path, 'BloomAutolinking.rb'));
    final rbBuffer = StringBuffer();
    rbBuffer.writeln('# AUTO-GENERATED BY BLOOM CLI AUTOLINKING ENGINE. DO NOT EDIT.');
    rbBuffer.writeln("require 'json'");
    rbBuffer.writeln();
    rbBuffer.writeln('def use_bloom_modules!(target_installer = nil)');
    rbBuffer.writeln("  json_path = File.join(__dir__, 'BloomAutolinking.podspec.json')");
    rbBuffer.writeln('  return unless File.exist?(json_path)');
    rbBuffer.writeln('  data = JSON.parse(File.read(json_path))');
    rbBuffer.writeln("  (data['modules'] || []).each do |mod|");
    rbBuffer.writeln("    pod mod['name'], :path => mod['path']");
    rbBuffer.writeln('  end');
    rbBuffer.writeln('end');
    rbFile.writeAsStringSync(rbBuffer.toString());

    // Inject into Podfile if missing
    _injectPodfileAutolink(iosDir);
  }

  void _injectPodfileAutolink(Directory iosDir) {
    final podfile = File(p.join(iosDir.path, 'Podfile'));
    if (podfile.existsSync()) {
      var content = podfile.readAsStringSync();
      if (!content.contains('BloomAutolinking.rb')) {
        content = "require_relative 'BloomAutolinking.rb'\n" + content;
        if (!content.contains('use_bloom_modules!')) {
          content = content.replaceFirst('target \'Runner\' do', "target 'Runner' do\n  use_bloom_modules!");
        }
        podfile.writeAsStringSync(content);
      }
    }
  }

  void _generateBloomLock(List<DiscoveredNativeModule> modules) {
    final lockFile = File(p.join(project.rootDir.path, 'bloom.lock'));
    final buffer = StringBuffer();

    buffer.writeln('# AUTO-GENERATED BY BLOOM CLI. DO NOT EDIT.');
    buffer.writeln('lockfile_version: 1');
    buffer.writeln('bloom_version: 1.0.0');
    buffer.writeln();
    buffer.writeln('native_modules:');

    // Sort modules deterministically by name
    final sorted = List<DiscoveredNativeModule>.from(modules)
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final mod in sorted) {
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
          // Strong SHA-256 content hashing of all native source files
          final bytes = f.readAsBytesSync();
          final fileSha = sha256.convert(bytes).toString();
          hashInput.writeln('${p.relative(f.path, from: pkgPath)}:$fileSha');
        }
      }
    }

    return sha256.convert(utf8.encode(hashInput.toString())).toString().substring(0, 16);
  }
}
