// lib/src/symbolication/symbol_packager.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../generator/fingerprint_generator.dart';
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
  final String runtimeFingerprint;
  final DateTime generatedAt;
  final List<DiscoveredSymbolArtifact> artifacts;

  BloomSymbolManifest({
    required this.appName,
    required this.version,
    required this.buildNumber,
    this.runtimeFingerprint = '',
    DateTime? generatedAt,
    required this.artifacts,
  }) : generatedAt = generatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'version': version,
        'buildNumber': buildNumber,
        'runtimeFingerprint': runtimeFingerprint,
        'generatedAt': generatedAt.toIso8601String(),
        'artifacts': artifacts.map((a) => a.toJson()).toList(),
      };

  factory BloomSymbolManifest.fromJson(Map<String, dynamic> json) {
    return BloomSymbolManifest(
      appName: json['appName'] as String? ?? '',
      version: json['version'] as String? ?? '',
      buildNumber: json['buildNumber']?.toString() ?? '1',
      runtimeFingerprint: json['runtimeFingerprint'] as String? ?? '',
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'].toString()) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      artifacts: (json['artifacts'] as List<dynamic>?)
              ?.map((a) => DiscoveredSymbolArtifact(
                    platform: a['platform'].toString(),
                    type: a['type'].toString(),
                    filePath: a['filePath'].toString(),
                    sizeBytes: (a['sizeBytes'] as num).toInt(),
                    sha256Hash: a['sha256Hash'].toString(),
                  ))
              .toList() ??
          [],
    );
  }

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
    final androidMappingDir =
        Directory(p.join(project.rootDir.path, 'android', 'app', 'build', 'outputs', 'mapping'));
    if (androidMappingDir.existsSync()) {
      final mappingFiles = androidMappingDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('mapping.txt'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
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
      final dsymEntities = iosBuildDir
          .listSync(recursive: true)
          .where((e) => e.path.endsWith('.dSYM'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final entity in dsymEntities) {
        if (entity is Directory) {
          final files = entity.listSync(recursive: true).whereType<File>().toList()
            ..sort((a, b) => a.path.compareTo(b.path));
          var totalSize = 0;
          final hashBuffer = StringBuffer();
          for (final f in files) {
            final relativePath = p.relative(f.path, from: entity.path);
            final b = f.readAsBytesSync();
            totalSize += b.length;
            hashBuffer.write('$relativePath:${sha256.convert(b)}');
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
      final mapFiles = webBuildDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.map'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
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

  /// Packages discovered symbol artifacts, writes a manifest JSON and bundles artifacts into a ZIP archive.
  Future<File> packageSymbols() async {
    print(Ansi.boldText('\n📦 Packaging Symbol Maps for Symbolication & Telemetry...'));

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final artifacts = discoverSymbols();
    final config = project.loadBloomConfig();
    final appName = config['name']?.toString() ?? 'bloom_app';
    final version = config['version']?.toString() ?? '1.0.0';
    final buildNumber =
        config['build_number']?.toString() ?? config['buildNumber']?.toString() ?? '1';
    final runtimeFingerprint = FingerprintGenerator(project).computeFingerprint();

    final manifest = BloomSymbolManifest(
      appName: appName,
      version: version,
      buildNumber: buildNumber,
      runtimeFingerprint: runtimeFingerprint,
      artifacts: artifacts,
    );

    final manifestJson = manifest.toFormattedJson();
    final manifestFile = File(p.join(outputDir.path, '${version}_${buildNumber}_manifest.json'));
    manifestFile.writeAsStringSync(manifestJson);

    // Create symbols ZIP archive
    final archive = Archive();
    // 1. Add manifest
    final manifestBytes = utf8.encode(manifestJson);
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 2. Add each artifact file
    for (final artifact in artifacts) {
      final artifactPath = p.join(project.rootDir.path, artifact.filePath);
      final file = File(artifactPath);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        archive.addFile(ArchiveFile(artifact.filePath, bytes.length, bytes));
      } else if (Directory(artifactPath).existsSync()) {
        final dir = Directory(artifactPath);
        final nestedFiles = dir.listSync(recursive: true).whereType<File>();
        for (final nested in nestedFiles) {
          final relPath = p.relative(nested.path, from: project.rootDir.path);
          final bytes = nested.readAsBytesSync();
          archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
        }
      }
    }

    final zipEncoder = ZipEncoder();
    final encodedZip = zipEncoder.encode(archive);
    if (encodedZip != null) {
      final zipFile = File(p.join(outputDir.path, '${version}_${buildNumber}_symbols.zip'));
      zipFile.writeAsBytesSync(encodedZip);
    }

    print('› Discovered ${artifacts.length} symbol artifact(s).');
    for (final a in artifacts) {
      print(
          '  • [${a.platform.toUpperCase()}] ${a.type} ➔ ${a.filePath} (${(a.sizeBytes / 1024).toStringAsFixed(1)} KB)');
    }
    print(Ansi.success('✔ Symbol manifest generated: ${manifestFile.path}\n'));

    return manifestFile;
  }

  /// Returns the path to the packaged ZIP archive for a version/buildNumber.
  File getSymbolsZipFile(String version, String buildNumber) {
    return File(p.join(outputDir.path, '${version}_${buildNumber}_symbols.zip'));
  }
}
