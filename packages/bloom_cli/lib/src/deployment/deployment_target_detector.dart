// lib/src/deployment/deployment_target_detector.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../utils/project.dart';

/// Supported application deployment targets in Bloom.
enum BloomDeploymentTarget {
  flutter,
  jsNative,
  server,
  hybrid;

  /// Identifier string used in CLI flags and configuration files.
  String get id {
    switch (this) {
      case BloomDeploymentTarget.flutter:
        return 'flutter';
      case BloomDeploymentTarget.jsNative:
        return 'js_native';
      case BloomDeploymentTarget.server:
        return 'server';
      case BloomDeploymentTarget.hybrid:
        return 'hybrid';
    }
  }

  /// Human-readable display label.
  String get displayName {
    switch (this) {
      case BloomDeploymentTarget.flutter:
        return 'Flutter (Web & Mobile)';
      case BloomDeploymentTarget.jsNative:
        return 'Bloom JS Native';
      case BloomDeploymentTarget.server:
        return 'Bloom Server (Backend)';
      case BloomDeploymentTarget.hybrid:
        return 'Hybrid Full-Stack';
    }
  }

  /// Human-readable summary of the target platform and runtime profile.
  String get description {
    switch (this) {
      case BloomDeploymentTarget.flutter:
        return 'Flutter web artifact served via minimal runtime container.';
      case BloomDeploymentTarget.jsNative:
        return 'Pure Dart fine-grained reactive web application with optional SSR profile.';
      case BloomDeploymentTarget.server:
        return 'High-throughput Dart API & backend server with database connectivity.';
      case BloomDeploymentTarget.hybrid:
        return 'Unified full-stack application with client and server Compose services.';
    }
  }

  /// Parses a string into a [BloomDeploymentTarget], or returns `null` if invalid.
  static BloomDeploymentTarget? parse(String? input) {
    if (input == null) return null;
    final normalized = input.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'flutter':
        return BloomDeploymentTarget.flutter;
      case 'js':
      case 'js_native':
      case 'jsnative':
      case 'bloom_js_native':
        return BloomDeploymentTarget.jsNative;
      case 'server':
      case 'backend':
      case 'bloom_server':
        return BloomDeploymentTarget.server;
      case 'hybrid':
      case 'fullstack':
      case 'full_stack':
        return BloomDeploymentTarget.hybrid;
      default:
        return null;
    }
  }
}

/// Detailed result of application target detection.
class BloomTargetDetectionResult {
  /// The resolved application target.
  final BloomDeploymentTarget target;

  /// The name of the application.
  final String appName;

  /// Human-readable explanations for why this target was chosen.
  final List<String> reasons;

  /// Whether server entrypoint or server packages were detected.
  final bool hasServer;

  /// Whether Flutter dependencies or SDK were detected.
  final bool hasFlutter;

  /// Whether JS Native web packages were detected.
  final bool hasJsNative;

  /// Whether Server-Side Rendering (SSR) profile is enabled or present.
  final bool hasSsr;

  /// Service names for container composition (e.g. `web`, `server`, `db`).
  final List<String> services;

  /// Database dialect if detected (e.g. `postgres`, `sqlite`).
  final String? databaseDialect;

  /// Default port mappings for detected services.
  final Map<String, int> defaultPorts;

  const BloomTargetDetectionResult({
    required this.target,
    required this.appName,
    required this.reasons,
    this.hasServer = false,
    this.hasFlutter = false,
    this.hasJsNative = false,
    this.hasSsr = false,
    this.services = const [],
    this.databaseDialect,
    this.defaultPorts = const {},
  });
}

/// Detects project target type for deployment and Docker containerization.
class BloomDeploymentTargetDetector {
  const BloomDeploymentTargetDetector();

  /// Inspects [project] and returns a [BloomTargetDetectionResult].
  BloomTargetDetectionResult detect(BloomProject project,
      {String? explicitTarget}) {
    final rootDir = project.rootDir;
    final appName = project.projectName;
    final config = project.loadBloomConfig();

    // 1. Explicit CLI override
    if (explicitTarget != null) {
      final parsed = BloomDeploymentTarget.parse(explicitTarget);
      if (parsed != null) {
        return _buildResultForTarget(
          target: parsed,
          appName: appName,
          reasons: [
            'Explicit target override specified via CLI flag ("$explicitTarget").'
          ],
          project: project,
          config: config,
        );
      }
    }

    // 2. Explicit config in bloom.yaml
    final deploymentConfig = config['deployment'];
    if (deploymentConfig is Map && deploymentConfig['target'] != null) {
      final configuredTarget =
          BloomDeploymentTarget.parse(deploymentConfig['target']?.toString());
      if (configuredTarget != null) {
        return _buildResultForTarget(
          target: configuredTarget,
          appName: appName,
          reasons: [
            'Target explicitly configured in bloom.yaml under deployment.target ("${deploymentConfig['target']}").'
          ],
          project: project,
          config: config,
        );
      }
    }

    if (config['target'] != null) {
      final configuredTarget =
          BloomDeploymentTarget.parse(config['target']?.toString());
      if (configuredTarget != null) {
        return _buildResultForTarget(
          target: configuredTarget,
          appName: appName,
          reasons: [
            'Target explicitly configured in bloom.yaml ("${config['target']}").'
          ],
          project: project,
          config: config,
        );
      }
    }

    // 3. Inspect pubspec.yaml
    final pubspecFile = project.pubspecFile;
    Map<dynamic, dynamic> pubspec = {};
    if (pubspecFile.existsSync()) {
      try {
        final parsed = loadYaml(pubspecFile.readAsStringSync());
        if (parsed is Map) pubspec = parsed;
      } catch (_) {}
    }

    final deps = <String>{};
    final devDeps = <String>{};

    if (pubspec['dependencies'] is Map) {
      deps.addAll(
          (pubspec['dependencies'] as Map).keys.map((k) => k.toString()));
    }
    if (pubspec['dev_dependencies'] is Map) {
      devDeps.addAll(
          (pubspec['dev_dependencies'] as Map).keys.map((k) => k.toString()));
    }

    final hasFlutterSdk = pubspec['flutter'] != null ||
        (pubspec['environment'] is Map &&
            (pubspec['environment'] as Map).containsKey('flutter')) ||
        deps.contains('flutter');

    final hasJsNativePkg =
        deps.contains('bloom_js_native') || devDeps.contains('bloom_js_native');

    final hasServerPkgs = deps.contains('bloom_db') ||
        deps.contains('bloom_rest') ||
        deps.contains('bloom_auth_server') ||
        deps.contains('bloom_migrate') ||
        deps.contains('postgres');

    // 4. Inspect filesystem indicators
    final serverEntry = File(p.join(rootDir.path, 'bin', 'server.dart'));
    final hasServerEntry = serverEntry.existsSync();

    final appsDir = Directory(p.join(rootDir.path, 'apps'));
    final hasAppsDir = appsDir.existsSync() &&
        appsDir.listSync().whereType<Directory>().isNotEmpty;

    final webMain = File(p.join(rootDir.path, 'web', 'main.dart'));
    final libMain = File(p.join(rootDir.path, 'lib', 'main.dart'));
    final hasWebMain = webMain.existsSync();
    final hasLibMain = libMain.existsSync();

    var hasFlutterCode = false;
    if (hasLibMain) {
      try {
        final content = libMain.readAsStringSync();
        if (content.contains('package:flutter/') ||
            content.contains('runApp(')) {
          hasFlutterCode = true;
        }
      } catch (_) {}
    }

    final hasFlutter = hasFlutterSdk || hasFlutterCode;
    final hasJsNative = hasJsNativePkg || (hasWebMain && !hasFlutter);
    final hasServer = hasServerEntry;

    // Check SSR
    var hasSsr = false;
    if (config['ssr'] == true ||
        (config['web'] is Map && config['web']['ssr'] == true) ||
        (config['features'] is Map && config['features']['ssr'] == true)) {
      hasSsr = true;
    }
    if (hasServerEntry && (hasJsNative || hasFlutter)) {
      hasSsr = true;
    }

    // 5. Check Monorepo / Multi-app Hybrid layout
    if (hasAppsDir) {
      final subdirs = appsDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path).toLowerCase())
          .toList();
      final hasServerSubapp =
          subdirs.any((d) => d == 'server' || d == 'api' || d == 'backend');
      final hasClientSubapp = subdirs.any(
          (d) => d == 'web' || d == 'mobile' || d == 'app' || d == 'client');

      if (hasServerSubapp && hasClientSubapp) {
        return BloomTargetDetectionResult(
          target: BloomDeploymentTarget.hybrid,
          appName: appName,
          reasons: [
            'Detected multi-app monorepo layout under apps/ with client and server sub-applications.',
            'Found sub-applications: ${subdirs.join(', ')}.',
          ],
          hasServer: true,
          hasFlutter: hasFlutter,
          hasJsNative: hasJsNative,
          hasSsr: hasSsr,
          services: ['web', 'server', 'db'],
          databaseDialect: 'postgres',
          defaultPorts: {'server': 8080, 'web': 3000, 'db': 5432},
        );
      }
    }

    // 6. Target Classification
    final reasons = <String>[];

    if (hasServerEntry && (hasFlutter || hasJsNative)) {
      reasons.add('Found standalone server entrypoint at bin/server.dart.');
      if (hasFlutter) reasons.add('Detected Flutter client application.');
      if (hasJsNative)
        reasons.add('Detected Bloom JS Native client application.');

      return BloomTargetDetectionResult(
        target: BloomDeploymentTarget.hybrid,
        appName: appName,
        reasons: reasons,
        hasServer: true,
        hasFlutter: hasFlutter,
        hasJsNative: hasJsNative,
        hasSsr: hasSsr,
        services: ['web', 'server', 'db'],
        databaseDialect: _detectDbDialect(config, project),
        defaultPorts: {'server': 8080, 'web': 3000, 'db': 5432},
      );
    }

    if (hasServer && !hasFlutter && !hasJsNative) {
      if (hasServerEntry)
        reasons.add('Found server entrypoint at bin/server.dart.');
      if (hasServerPkgs)
        reasons.add('Detected Bloom Server backend packages in dependencies.');

      return BloomTargetDetectionResult(
        target: BloomDeploymentTarget.server,
        appName: appName,
        reasons: reasons,
        hasServer: true,
        hasFlutter: false,
        hasJsNative: false,
        hasSsr: false,
        services: ['server', 'db'],
        databaseDialect: _detectDbDialect(config, project),
        defaultPorts: {'server': 8080, 'db': 5432},
      );
    }

    if (hasJsNative && !hasFlutter) {
      if (hasJsNativePkg) reasons.add('Detected bloom_js_native dependency.');
      if (hasWebMain) reasons.add('Found web entrypoint at web/main.dart.');

      return BloomTargetDetectionResult(
        target: BloomDeploymentTarget.jsNative,
        appName: appName,
        reasons: reasons,
        hasServer: false,
        hasFlutter: false,
        hasJsNative: true,
        hasSsr: hasSsr,
        services: ['web'],
        defaultPorts: {'web': 8080},
      );
    }

    // Default: Flutter
    if (hasFlutterSdk)
      reasons.add('Detected Flutter SDK dependency in pubspec.yaml.');
    if (hasFlutterCode)
      reasons
          .add('Detected Flutter entrypoint and widget tree in lib/main.dart.');
    if (reasons.isEmpty) reasons.add('Standard Bloom application layout.');

    return BloomTargetDetectionResult(
      target: BloomDeploymentTarget.flutter,
      appName: appName,
      reasons: reasons,
      hasServer: false,
      hasFlutter: true,
      hasJsNative: false,
      hasSsr: hasSsr,
      services: ['web'],
      defaultPorts: {'web': 8080},
    );
  }

  BloomTargetDetectionResult _buildResultForTarget({
    required BloomDeploymentTarget target,
    required String appName,
    required List<String> reasons,
    required BloomProject project,
    required Map<dynamic, dynamic> config,
  }) {
    switch (target) {
      case BloomDeploymentTarget.flutter:
        return BloomTargetDetectionResult(
          target: target,
          appName: appName,
          reasons: reasons,
          hasFlutter: true,
          services: ['web'],
          defaultPorts: {'web': 8080},
        );
      case BloomDeploymentTarget.jsNative:
        final hasSsr = File(p.join(project.rootDir.path, 'bin', 'server.dart'))
            .existsSync();
        return BloomTargetDetectionResult(
          target: target,
          appName: appName,
          reasons: reasons,
          hasJsNative: true,
          hasSsr: hasSsr,
          services: ['web'],
          defaultPorts: {'web': 8080},
        );
      case BloomDeploymentTarget.server:
        final hasServer = File(p.join(project.rootDir.path, 'bin', 'server.dart')).existsSync();
        return BloomTargetDetectionResult(
          target: target,
          appName: appName,
          reasons: reasons,
          hasServer: hasServer,
          services: ['server', 'db'],
          databaseDialect: _detectDbDialect(config, project),
          defaultPorts: {'server': 8080, 'db': 5432},
        );
      case BloomDeploymentTarget.hybrid:
        final hasServer = File(p.join(project.rootDir.path, 'bin', 'server.dart')).existsSync();
        return BloomTargetDetectionResult(
          target: target,
          appName: appName,
          reasons: reasons,
          hasServer: hasServer,
          hasFlutter: true,
          hasJsNative: false,
          hasSsr: true,
          services: ['web', 'server', 'db'],
          databaseDialect: _detectDbDialect(config, project),
          defaultPorts: {'server': 8080, 'web': 3000, 'db': 5432},
        );
    }
  }

  String _detectDbDialect(Map<dynamic, dynamic> config, BloomProject project) {
    if (config['database'] is Map && config['database']['dialect'] != null) {
      return config['database']['dialect'].toString();
    }
    if (config['db'] != null) {
      return config['db'].toString();
    }
    final settingsFile =
        File(p.join(project.rootDir.path, 'lib', 'settings.dart'));
    if (settingsFile.existsSync()) {
      try {
        final code = settingsFile.readAsStringSync();
        if (code.contains('SqliteDbExecutor')) return 'sqlite';
        if (code.contains('PostgresDbExecutor')) return 'postgres';
      } catch (_) {}
    }
    return 'postgres';
  }
}
