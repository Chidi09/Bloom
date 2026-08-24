// lib/src/assets/asset_analyzer.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Information about a discovered asset file and its usage across the project.
class AssetFileInfo {
  /// Relative path of the asset from the project root.
  final String relativePath;

  /// Size of the asset file in bytes.
  final int sizeBytes;

  /// Whether this asset is referenced in project source code.
  final bool isUsed;

  /// Creates an asset file descriptor with path, size, and usage status.
  AssetFileInfo({
    required this.relativePath,
    required this.sizeBytes,
    required this.isUsed,
  });
}

/// Aggregated results from analyzing project asset references.
class AssetAnalysisResult {
  /// All discovered physical asset files in the project.
  final List<AssetFileInfo> allAssets;

  /// Discovered asset files not referenced in any project Dart source.
  final List<AssetFileInfo> unusedAssets;

  /// Total size in bytes of all discovered assets.
  final int totalAssetBytes;

  /// Total size in bytes of all unused/unreferenced assets.
  final int unusedAssetBytes;

  /// Creates an analysis result summary with asset counts and byte metrics.
  AssetAnalysisResult({
    required this.allAssets,
    required this.unusedAssets,
    required this.totalAssetBytes,
    required this.unusedAssetBytes,
  });
}

/// Static analyzer to detect orphaned or unreferenced assets across Dart sources.
class AssetAnalyzer {
  /// The target Bloom project.
  final BloomProject project;

  /// Directory containing project asset files (defaults to `assets/`).
  final Directory assetsDir;

  /// Directory containing Dart source code to scan (defaults to `lib/`).
  final Directory libDir;

  /// Creates an asset analyzer for [project].
  ///
  /// Scans [assetsDir] (defaulting to `<project>/assets`) against Dart sources
  /// found in [libDir] (defaulting to `<project>/lib`).
  AssetAnalyzer({
    required this.project,
    Directory? assetsDir,
    Directory? libDir,
  })  : assetsDir = assetsDir ?? Directory(p.join(project.rootDir.path, 'assets')),
        libDir = libDir ?? Directory(p.join(project.rootDir.path, 'lib'));

  /// Analyzes the project codebase and returns used and unused asset metrics.
  AssetAnalysisResult analyze() {
    print(Ansi.boldText('\n🔍 Analyzing asset references across lib/...'));

    if (!assetsDir.existsSync()) {
      print(Ansi.warn('  Notice: No "assets" directory found in ${project.rootDir.path}'));
      return AssetAnalysisResult(
        allAssets: [],
        unusedAssets: [],
        totalAssetBytes: 0,
        unusedAssetBytes: 0,
      );
    }

    final physicalAssets = assetsDir
        .listSync(recursive: true)
        .whereType<File>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path)); // Deterministic order

    final sourceFiles = libDir.existsSync()
        ? libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
        : <File>[];

    final combinedSourceCode = StringBuffer();
    for (final src in sourceFiles) {
      try {
        combinedSourceCode.writeln(src.readAsStringSync());
      } catch (_) {}
    }
    final allCode = combinedSourceCode.toString();

    final allAssets = <AssetFileInfo>[];
    final unusedAssets = <AssetFileInfo>[];
    var totalBytes = 0;
    var unusedBytes = 0;

    for (final asset in physicalAssets) {
      final relPath = p.relative(asset.path, from: project.rootDir.path).replaceAll('\\', '/');
      final baseName = p.basenameWithoutExtension(asset.path);
      final size = asset.lengthSync();
      totalBytes += size;

      // Check if path or basename is referenced in Dart code
      final isDirectlyReferenced = allCode.contains(relPath) ||
          allCode.contains(p.basename(asset.path)) ||
          allCode.contains(baseName);

      final fileInfo = AssetFileInfo(
        relativePath: relPath,
        sizeBytes: size,
        isUsed: isDirectlyReferenced,
      );
      allAssets.add(fileInfo);

      if (!isDirectlyReferenced) {
        unusedAssets.add(fileInfo);
        unusedBytes += size;
      }
    }

    if (unusedAssets.isNotEmpty) {
      print(Ansi.warn('\n⚠ ${unusedAssets.length} Unused Asset(s) Detected (Wasted: ${(unusedBytes / 1024).toStringAsFixed(1)} KB):'));
      for (final unused in unusedAssets) {
        print('  • ${unused.relativePath} (${(unused.sizeBytes / 1024).toStringAsFixed(1)} KB)');
      }
    } else {
      print(Ansi.success('✔ All ${physicalAssets.length} asset(s) are actively referenced.'));
    }

    return AssetAnalysisResult(
      allAssets: allAssets,
      unusedAssets: unusedAssets,
      totalAssetBytes: totalBytes,
      unusedAssetBytes: unusedBytes,
    );
  }
}
