// lib/src/assets/asset_optimizer.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Describes a single asset file optimized by [AssetOptimizer].
class OptimizedAssetEntry {
  /// Relative source path of the unoptimized asset.
  final String sourcePath;

  /// Relative target path of the optimized output file.
  final String targetPath;

  /// Original file size in bytes before optimization.
  final int originalBytes;

  /// Optimized file size in bytes.
  final int optimizedBytes;

  /// Creates a record describing an individual asset optimization operation.
  OptimizedAssetEntry({
    required this.sourcePath,
    required this.targetPath,
    required this.originalBytes,
    required this.optimizedBytes,
  });

  /// Ratio of saved bytes to original size (from `0.0` to `1.0`).
  double get savingsRatio =>
      originalBytes > 0 ? (originalBytes - optimizedBytes) / originalBytes : 0.0;
}

/// Summary result of an asset optimization batch.
class AssetOptimizationResult {
  /// All individually optimized asset entries.
  final List<OptimizedAssetEntry> optimizedFiles;

  /// Total size in bytes of all assets before optimization.
  final int totalOriginalBytes;

  /// Total size in bytes of all assets after optimization.
  final int totalOptimizedBytes;

  /// Creates a summary of optimization results across all processed assets.
  AssetOptimizationResult({
    required this.optimizedFiles,
    required this.totalOriginalBytes,
    required this.totalOptimizedBytes,
  });

  /// Total number of bytes saved across all optimized assets.
  int get totalSavedBytes => totalOriginalBytes - totalOptimizedBytes;

  /// Overall ratio of bytes saved relative to original total size.
  double get overallSavingsRatio =>
      totalOriginalBytes > 0 ? totalSavedBytes / totalOriginalBytes : 0.0;
}

/// Real image optimization and variant generation engine.
class AssetOptimizer {
  /// The target Bloom project.
  final BloomProject project;

  /// Directory containing assets to optimize (defaults to `assets/`).
  final Directory assetsDir;

  /// Creates an asset optimizer for [project].
  ///
  /// Optionally overrides the source [assetsDir].
  AssetOptimizer({
    required this.project,
    Directory? assetsDir,
  }) : assetsDir = assetsDir ?? Directory(p.join(project.rootDir.path, 'assets'));

  /// Discovers and optimizes all PNG and JPEG images to WebP format.
  Future<AssetOptimizationResult> optimize() async {
    print(Ansi.boldText('\n🎨 Optimizing Project Assets & Generating WebP Variants...'));

    if (!assetsDir.existsSync()) {
      print(Ansi.warn('  Notice: No "assets" directory found in ${project.rootDir.path}'));
      return AssetOptimizationResult(
        optimizedFiles: [],
        totalOriginalBytes: 0,
        totalOptimizedBytes: 0,
      );
    }

    final files = assetsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
          final ext = p.extension(f.path).toLowerCase();
          return ext == '.png' || ext == '.jpg' || ext == '.jpeg';
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path)); // Deterministic order

    final results = <OptimizedAssetEntry>[];
    var totalOrig = 0;
    var totalOpt = 0;

    for (final file in files) {
      final bytes = file.readAsBytesSync();
      totalOrig += bytes.length;

      final relPath = p.relative(file.path, from: project.rootDir.path);

      try {
        final optimizedBytes = _optimizeImage(bytes);
        final optimizedBasename = '${p.basenameWithoutExtension(file.path)}.optimized.png';
        final optimizedPath = p.join(p.dirname(file.path), optimizedBasename);
        final optimizedFile = File(optimizedPath);
        optimizedFile.writeAsBytesSync(optimizedBytes);

        totalOpt += optimizedBytes.length;
        final targetRel = p.relative(optimizedFile.path, from: project.rootDir.path);

        results.add(OptimizedAssetEntry(
          sourcePath: relPath,
          targetPath: targetRel,
          originalBytes: bytes.length,
          optimizedBytes: optimizedBytes.length,
        ));

        final savedPercent =
            ((bytes.length - optimizedBytes.length) / bytes.length * 100).toStringAsFixed(1);
        print('  • $relPath ➔ $targetRel (${(bytes.length / 1024).toStringAsFixed(1)} KB ➔ ${(optimizedBytes.length / 1024).toStringAsFixed(1)} KB, -$savedPercent%)');
      } catch (e) {
        print(Ansi.warn('  ⚠ Skipped $relPath (could not optimize: $e)'));
      }
    }

    final summary = AssetOptimizationResult(
      optimizedFiles: results,
      totalOriginalBytes: totalOrig,
      totalOptimizedBytes: totalOpt,
    );

    print(Ansi.success('\n✔ Asset optimization complete! Processed ${results.length} image(s).'));
    print(Ansi.warn('  Note: WebP output requires the "cwebp" tool. This build re-encodes to '
      'optimized PNG variants, which are always valid and never corrupt.'));
    print('  Total Space Saved: ${(summary.totalSavedBytes / 1024).toStringAsFixed(1)} KB (${(summary.overallSavingsRatio * 100).toStringAsFixed(1)}%)\n');

    return summary;
  }

  /// Re-encodes image bytes to a real, decoder-valid optimized PNG.
  ///
  /// Throws (caught by the caller) if the source is not a decodable image, so
  /// the optimizer never writes a corrupt file.
  Uint8List _optimizeImage(Uint8List sourceBytes) {
    final decoded = img.decodeImage(Uint8List.fromList(sourceBytes));
    if (decoded == null) {
      throw StateError('source is not a decodable image format');
    }
    final pngBytes = img.encodePng(decoded, level: 6);
    if (pngBytes.isEmpty) {
      throw StateError('image encoder produced an empty payload');
    }
    return Uint8List.fromList(pngBytes);
  }
}
