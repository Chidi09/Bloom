// lib/src/symbolication/symbol_packager.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

class DiscoveredSymbolArtifact {
  final String platform; // 'android', 'ios', 'web'
  final String type; // 'proguard', 'dsym', 'sourcemap'
  final String filePath;
  final int sizeBytes;
  final String sha256Hash;

  DiscoveredSymbolArtifact({
    required this.platform,
    required this.type,
    required this.filePath,
    required this.sizeBytes,
    required this.sha256Hash,
  });

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'type': type,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'sha256Hash': sha256Hash,
      };
}

class BloomSymbolManifest {
  final String appName;
  final String version;
  final String buildNumber;
  final DateTime generatedAt;
  final List<DiscoveredSymbolArtifact> artifacts;

  BloomSymbolManifest({
    required this.appName,
    required this.version,
    required this.buildNumber,
    DateTime? generatedAt,
    required this.artifacts,
  }) : generatedAt = generatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'version': version,
        'buildNumber': buildNumber,
        'generatedAt': generatedAt.toIso8601String(),
        'artifacts': artifacts.map((a) => a.toJson()).toList(),
      };

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Symbol Packaging and Export Engine for Crash Symbolication.
class BloomSymbolPackager {
  final BloomProject project;
  final Directory outputDir;

  BloomSymbolPackager({
    required this.project,
    Directory? outputDir,
  }) : outputDir = outputDir ?? Directory(p.join(project.rootDir.path, '.bloom', 'symbols'));

  /// Discovers symbol artifacts across Android, iOS, and Web build directories.
  List<DiscoveredSymbolArtifact> discoverSymbols() {
    final artifacts = <DiscoveredSymbolArtifact>[];

    // 1. Android ProGuard / R8 mapping files
    final androidMappingDir = Directory(p.join(project.rootDir.path, 'android', 'app', 'build', 'outputs', 'mapping'));
    if (androidMappingDir.existsSync()) {
      final mappingFiles = androidMappingDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('mapping.txt'));
      for (final file in mappingFiles) {
        final bytes = file.readAsBytesSync();
        artifacts.add(DiscoveredSymbolArtifact(
          platform: 'android',
          type: 'proguard',
          filePath: p.relative(file.path, from: project.rootDir.path),
          sizeBytes: bytes.length,
          sha256Hash: sha256.convert(bytes).toString(),
        ));
      }
    }

    // 2. iOS / macOS dSYM bundles
    final iosBuildDir = Directory(p.join(project.rootDir.path, 'build', 'ios'));
    if (iosBuildDir.existsSync()) {
      final dsymEntities = iosBuildDir.listSync(recursive: true).where((e) => e.path.endsWith('.dSYM'));
      for (final entity in dsymEntities) {
        if (entity is Directory) {
          final files = entity.listSync(recursive: true).whereType<File>().toList()
            ..sort((a, b) => a.path.compareTo(b.path));
          var totalSize = 0;
          final hashBuffer = StringBuffer();
          for (final f in files) {
            final b = f.readAsBytesSync();
            totalSize += b.length;
            hashBuffer.write(sha256.convert(b).toString());
          }
          final combinedHash = sha256.convert(utf8.encode(hashBuffer.toString())).toString();
          artifacts.add(DiscoveredSymbolArtifact(
            platform: 'ios',
            type: 'dsym',
            filePath: p.relative(entity.path, from: project.rootDir.path),
            sizeBytes: totalSize,
            sha256Hash: combinedHash,
          ));
        }
      }
    }

    // 3. Web Dart-to-JS source maps
    final webBuildDir = Directory(p.join(project.rootDir.path, 'build', 'web'));
    if (webBuildDir.existsSync()) {
      final mapFiles = webBuildDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.map'));
      for (final file in mapFiles) {
        final bytes = file.readAsBytesSync();
        artifacts.add(DiscoveredSymbolArtifact(
          platform: 'web',
          type: 'sourcemap',
          filePath: p.relative(file.path, from: project.rootDir.path),
          sizeBytes: bytes.length,
          sha256Hash: sha256.convert(bytes).toString(),
        ));
      }
    }

    return artifacts;
  }

  /// Packages discovered symbol artifacts and writes a manifest.
  Future<File> packageSymbols() async {
    print(Ansi.boldText('\n📦 Packaging Symbol Maps for Symbolication & Telemetry...'));

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final artifacts = discoverSymbols();
    final config = project.loadBloomConfig();
    final appName = config['name']?.toString() ?? 'bloom_app';
    final version = config['version']?.toString() ?? '1.0.0';
    final buildNumber = config['build_number']?.toString() ?? '1';

    final manifest = BloomSymbolManifest(
      appName: appName,
      version: version,
      buildNumber: buildNumber,
      artifacts: artifacts,
    );

    final manifestFile = File(p.join(outputDir.path, '${version}_${buildNumber}_manifest.json'));
    manifestFile.writeAsStringSync(manifest.toFormattedJson());

    print('› Discovered ${artifacts.length} symbol artifact(s).');
    for (final a in artifacts) {
      print('  • [${a.platform.toUpperCase()}] ${a.type} ➔ ${a.filePath} (${(a.sizeBytes / 1024).toStringAsFixed(1)} KB)');
    }
    print(Ansi.success('✔ Symbol manifest generated: ${manifestFile.path}\n'));

    return manifestFile;
  }
}
