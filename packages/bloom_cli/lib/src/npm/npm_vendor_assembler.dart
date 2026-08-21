import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'npm_manifest.dart';
import 'npm_resolver.dart';
import 'importmap_manager.dart';

class NpmVendorAssembler {
  final BloomProject project;
  final NpmManifest manifest;

  NpmVendorAssembler(this.project) : manifest = NpmManifest.read(project);

  /// Check if Bun runtime is installed on the host system.
  static bool get hasBun {
    try {
      final res = Process.runSync('bun', ['--version']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Verify all vendor files are in place; re-download any missing ones.
  /// Rebuild the importmap from the current manifest state.
  Future<void> assemble({bool preferBun = true}) async {
    if (manifest.isEmpty) return;

    final useBun = preferBun && hasBun;
    final toolLabel = useBun ? 'Bun toolchain' : 'ESM CDN resolver';
    print(Ansi.step('\n⚙️  Assembling ${manifest.count} NPM package(s) via $toolLabel...\n'));

    final resolver = NpmResolver();
    int assembled = 0;

    for (final entry in manifest.packages) {
      final vendorAbsPath = p.join(project.rootDir.path, entry.vendorFile);
      final vendorFile = File(vendorAbsPath);

      if (!vendorFile.existsSync()) {
        print(Ansi.info('  Missing vendor file for "${entry.alias}". Resolving...'));
        bool bunSuccess = false;

        if (useBun) {
          bunSuccess = await _vendorWithBun(entry.npmName, entry.version, vendorAbsPath);
        }

        if (!bunSuccess) {
          await resolver.downloadVendorBundle(
            entry.npmName,
            entry.version,
            project.rootDir.path,
            entry.vendorFile,
          );
        }
        print(Ansi.success('  Installed: ${entry.vendorFile}'));
      } else {
        final sizeKb = (vendorFile.lengthSync() / 1024).toStringAsFixed(1);
        print(Ansi.info('  ${entry.alias}@${entry.version}  ${sizeKb}kB  [cached]'));
      }
      assembled++;
    }

    // Rebuild the full importmap from manifest — ensures it's always in sync
    final manager = ImportMapManager(project.rootDir.path);
    for (final entry in manifest.packages) {
      await manager.addEntry(
        packageName: entry.npmName,
        vendorPath: entry.vendorFile,
      );
    }

    print(Ansi.success('\n✓ $assembled NPM package(s) assembled. Importmap updated.\n'));
  }

  Future<bool> _vendorWithBun(String npmName, String version, String targetPath) async {
    try {
      final tempDir = Directory.systemTemp.createTempSync('bloom_bun_');
      try {
        final installRes = await Process.run('bun', ['add', '$npmName@$version'],
            workingDirectory: tempDir.path);
        if (installRes.exitCode != 0) return false;

        // Bundle/build with bun build --minify
        final outputFile = File(targetPath);
        outputFile.parent.createSync(recursive: true);

        final buildRes = await Process.run(
          'bun',
          ['build', '--target', 'browser', '--minify', npmName, '--outfile', targetPath],
          workingDirectory: tempDir.path,
        );
        return buildRes.exitCode == 0 && outputFile.existsSync();
      } finally {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    } catch (_) {
      return false;
    }
  }
}
