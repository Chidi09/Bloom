// lib/src/deployment/docker_bundle_generator.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../templates/deployment_templates.dart';
import '../utils/project.dart';
import 'deployment_target_detector.dart';

/// Bundle containing generated Docker and deployment artifacts.
class BloomDockerBundle {
  final BloomDeploymentTarget target;
  final String appName;
  final bool productionOnly;
  final Map<String, String> files;

  const BloomDockerBundle({
    required this.target,
    required this.appName,
    required this.productionOnly,
    required this.files,
  });

  /// Check if the bundle contains a specific relative file name.
  bool containsFile(String name) => files.containsKey(name);

  /// Get content of a specific file in the bundle.
  String? getFileContent(String name) => files[name];
}

/// Generates production-ready Dockerfiles, .dockerignore, Compose bundles, and environment templates.
class BloomDockerGenerator {
  const BloomDockerGenerator();

  /// Generates the in-memory [BloomDockerBundle] for [project].
  BloomDockerBundle generate({
    required BloomProject project,
    required BloomDeploymentTarget target,
    bool productionOnly = false,
    bool hasSsr = false,
    String? dbDialect,
  }) {
    final appName = project.projectName;
    final files = <String, String>{};

    // 1. Multi-stage Dockerfile
    files['Dockerfile'] = BloomDeploymentTemplates.dockerfile(
      target: target,
      appName: appName,
      hasSsr: hasSsr,
    );

    // 2. .dockerignore (Zero secrets guarantee)
    files['.dockerignore'] = BloomDeploymentTemplates.dockerIgnore();

    // 3. Compose local development bundle (omitted if production-only)
    if (!productionOnly) {
      files['docker-compose.yml'] = BloomDeploymentTemplates.dockerCompose(
        target: target,
        appName: appName,
        dbDialect: dbDialect ?? 'postgres',
      );
    }

    // 4. Safe environment template (no real secrets embedded)
    files['.env.example'] = BloomDeploymentTemplates.envExample(
      target: target,
      appName: appName,
    );

    // 5. Nginx config if target serves static web bundle
    if (target == BloomDeploymentTarget.flutter ||
        (target == BloomDeploymentTarget.jsNative && !hasSsr)) {
      files['nginx.conf'] = BloomDeploymentTemplates.nginxConf();
    }

    return BloomDockerBundle(
      target: target,
      appName: appName,
      productionOnly: productionOnly,
      files: files,
    );
  }

  /// Writes all files in [bundle] to [targetDir].
  List<File> writeBundle({
    required BloomDockerBundle bundle,
    required Directory targetDir,
    bool overwrite = false,
  }) {
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final written = <File>[];

    for (final entry in bundle.files.entries) {
      final filePath = p.join(targetDir.path, entry.key);
      final file = File(filePath);

      if (file.existsSync() && !overwrite) {
        continue;
      }

      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
      written.add(file);
    }

    return written;
  }
}
