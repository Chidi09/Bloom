// lib/src/provenance/provenance_generator.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Cryptographic Build Provenance model.
class BloomBuildProvenance {
  final String buildId;
  final DateTime timestamp;
  final String builder;
  final String commit;
  final Map<String, String> toolchain;
  final String sourceHash;

  BloomBuildProvenance({
    required this.buildId,
    required this.timestamp,
    required this.builder,
    required this.commit,
    required this.toolchain,
    required this.sourceHash,
  });

  Map<String, dynamic> toJson() => {
        'buildId': buildId,
        'timestamp': timestamp.toIso8601String(),
        'builder': builder,
        'commit': commit,
        'toolchain': toolchain,
        'sourceHash': sourceHash,
      };

  factory BloomBuildProvenance.fromJson(Map<String, dynamic> json) {
    return BloomBuildProvenance(
      buildId: json['buildId'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      builder: json['builder'] as String? ?? 'local',
      commit: json['commit'] as String? ?? 'HEAD',
      toolchain: json['toolchain'] is Map ? Map<String, String>.from(json['toolchain'] as Map) : {},
      sourceHash: json['sourceHash'] as String? ?? '',
    );
  }

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Generates reproducible cryptographic build provenance manifests.
class ProvenanceGenerator {
  final BloomProject project;

  ProvenanceGenerator(this.project);

  /// Computes a deterministic SHA-256 hash over all sorted source files in the project.
  String computeSourceHash() {
    final files = _discoverSourceFiles(project.rootDir);
    final buffer = StringBuffer();

    for (final file in files) {
      final relPath = p.relative(file.path, from: project.rootDir.path).replaceAll('\\', '/');
      final bytes = file.readAsBytesSync();
      final fileHash = sha256.convert(bytes).toString();
      buffer.writeln('$relPath:$fileHash');
    }

    return 'sha256:${sha256.convert(utf8.encode(buffer.toString()))}';
  }

  /// Generates the complete build provenance descriptor and writes to build/provenance.json.
  BloomBuildProvenance generateProvenance({
    String? builder,
    String? commit,
    DateTime? timestamp,
    File? outputFile,
  }) {
    print(Ansi.boldText('\n📜 Generating Reproducible Build Provenance Manifest...'));

    final srcHash = computeSourceHash();
    final effectiveTime = timestamp ?? DateTime.now().toUtc();
    final config = project.loadBloomConfig();

    // Derive versions from environment and project config
    final bloomVersion = config['version']?.toString() ?? '0.1.0';
    final dartVersion = Platform.version.split(' ').first;
    final flutterVersion = _detectFlutterVersion();

    final shortHash = srcHash.replaceAll('sha256:', '').substring(0, 8);
    final buildId = 'bld_${effectiveTime.millisecondsSinceEpoch}_$shortHash';

    final effectiveCommit = commit ?? _detectGitCommit() ?? 'dev-build';
    final effectiveBuilder = builder ?? (Platform.environment['CI'] != null ? 'CI (GitHub Actions)' : 'Local Developer');

    final provenance = BloomBuildProvenance(
      buildId: buildId,
      timestamp: effectiveTime,
      builder: effectiveBuilder,
      commit: effectiveCommit,
      toolchain: {
        'bloomVersion': bloomVersion,
        'flutterVersion': flutterVersion,
        'dartVersion': dartVersion,
      },
      sourceHash: srcHash,
    );

    final targetFile = outputFile ??
        File(p.join(project.rootDir.path, 'build', 'provenance.json'));

    if (!targetFile.parent.existsSync()) {
      targetFile.parent.createSync(recursive: true);
    }

    targetFile.writeAsStringSync(provenance.toFormattedJson());
    print(Ansi.success('✔ Provenance manifest generated: ${targetFile.path}'));
    print('  Build ID:     ${provenance.buildId}');
    print('  Source Hash:  ${provenance.sourceHash}\n');

    return provenance;
  }

  List<File> _discoverSourceFiles(Directory dir) {
    final list = <File>[];
    const excludedDirs = {
      '.git',
      '.dart_tool',
      'build',
      'node_modules',
      '.bloom',
      '.idea',
      '.vscode',
    };

    final entities = dir.listSync(recursive: true, followLinks: false);
    for (final e in entities) {
      if (e is File) {
        final rel = p.relative(e.path, from: dir.path);
        final parts = rel.split(p.separator);
        if (parts.any((part) => excludedDirs.contains(part))) {
          continue;
        }

        final fileName = p.basename(e.path);
        final ext = p.extension(e.path).toLowerCase();

        // Include source and configuration files
        if (ext == '.dart' ||
            ext == '.yaml' ||
            ext == '.json' ||
            ext == '.xml' ||
            ext == '.gradle' ||
            fileName == 'bloom.yaml' ||
            fileName == 'pubspec.yaml') {
          list.add(e);
        }
      }
    }

    return list..sort((a, b) => a.path.compareTo(b.path)); // Sort deterministically
  }

  String _detectFlutterVersion() {
    // 1. FLUTTER_ROOT/version if present.
    try {
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot != null) {
        final versionFile = File(p.join(flutterRoot, 'version'));
        if (versionFile.existsSync()) {
          final v = versionFile.readAsStringSync().trim();
          if (v.isNotEmpty) return v;
        }
      }
    } catch (_) {}

    // 2. Query `flutter --version` if the tool is on PATH.
    try {
      final result = Process.runSync('flutter', ['--version'],
          workingDirectory: project.rootDir.path);
      if (result.exitCode == 0) {
        final firstLine = result.stdout.toString().split('\n').first.trim();
        final match = RegExp(r'Flutter (\d[\w.]*)').firstMatch(firstLine);
        if (match != null && match.group(1)!.isNotEmpty) return match.group(1)!;
      }
    } catch (_) {}

    // Never fabricate a version: report unknown rather than a hardcoded value.
    return 'unknown';
  }

  String? _detectGitCommit() {
    try {
      final gitHead = File(p.join(project.rootDir.path, '.git', 'HEAD'));
      if (gitHead.existsSync()) {
        final headContent = gitHead.readAsStringSync().trim();
        if (headContent.startsWith('ref:')) {
          final refPath = headContent.substring(4).trim();
          final refFile = File(p.join(project.rootDir.path, '.git', refPath));
          if (refFile.existsSync()) {
            return refFile.readAsStringSync().trim().substring(0, 7);
          }
        } else if (headContent.length >= 7) {
          return headContent.substring(0, 7);
        }
      }
    } catch (_) {}
    return null;
  }
}
