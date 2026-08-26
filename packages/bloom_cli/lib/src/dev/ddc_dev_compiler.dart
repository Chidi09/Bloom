// lib/src/dev/ddc_dev_compiler.dart
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'live_reload_server.dart';

/// Representation of the Dart Dev Compiler (DDC) SDK toolchain and runtime paths.
class DdcToolchain {
  final String sdkBinDir;
  final String sdkRootDir;
  final String? snapshotPath;
  final String? runnerExecutable;
  final String? ddcPlatformDillPath;
  final String? requireJsPath;
  final Directory cacheDir;
  final String sdkVersion;

  DdcToolchain._({
    required this.sdkBinDir,
    required this.sdkRootDir,
    required this.snapshotPath,
    required this.runnerExecutable,
    required this.ddcPlatformDillPath,
    required this.requireJsPath,
    required this.cacheDir,
    required this.sdkVersion,
  });

  /// Whether all necessary DDC binaries, snapshots, and platform summaries exist.
  bool get isAvailable =>
      snapshotPath != null &&
      runnerExecutable != null &&
      ddcPlatformDillPath != null &&
      requireJsPath != null;

  /// Discovers the DDC toolchain from the running Dart SDK or a custom executable.
  static DdcToolchain discover({
    Directory? projectRoot,
    String? customExecutable,
    String? customSdkVersion,
  }) {
    final execPath = customExecutable ?? Platform.resolvedExecutable;
    final sdkBin = p.dirname(execPath);
    final sdkRoot = p.dirname(sdkBin);
    final snapshotsDir = p.join(sdkBin, 'snapshots');

    final aotSnapshot = File(p.join(snapshotsDir, 'dartdevc_aot.dart.snapshot'));
    final jitSnapshot = File(p.join(snapshotsDir, 'dartdevc.dart.snapshot'));

    final execSuffix = Platform.isWindows ? '.exe' : '';
    String? snapshotPath;
    String? runnerExecutable;

    if (aotSnapshot.existsSync()) {
      snapshotPath = aotSnapshot.path;
      runnerExecutable = p.join(sdkBin, 'dartaotruntime$execSuffix');
    } else if (jitSnapshot.existsSync()) {
      snapshotPath = jitSnapshot.path;
      runnerExecutable = p.join(sdkBin, 'dart$execSuffix');
    }

    final ddcPlatformDill =
        File(p.join(sdkRoot, 'lib', '_internal', 'ddc_platform.dill'));
    final requireJs =
        File(p.join(sdkRoot, 'lib', 'dev_compiler', 'amd', 'require.js'));

    final rawVersion = customSdkVersion ?? Platform.version;
    final sanitizedVersion = sanitizeVersion(rawVersion);

    final Directory cache;
    if (projectRoot != null) {
      cache = Directory(
          p.join(projectRoot.path, '.dart_tool', 'bloom', 'ddc', sanitizedVersion));
    } else {
      cache = Directory(p.join(
          Directory.systemTemp.path, 'bloom_ddc_cache', sanitizedVersion));
    }

    return DdcToolchain._(
      sdkBinDir: sdkBin,
      sdkRootDir: sdkRoot,
      snapshotPath: snapshotPath,
      runnerExecutable: runnerExecutable,
      ddcPlatformDillPath:
          ddcPlatformDill.existsSync() ? ddcPlatformDill.path : null,
      requireJsPath: requireJs.existsSync() ? requireJs.path : null,
      cacheDir: cache,
      sdkVersion: rawVersion,
    );
  }

  /// Sanitizes a Dart SDK version string for safe filesystem directory naming.
  static String sanitizeVersion(String rawVersion) {
    final firstPart = rawVersion.split(' ').first;
    return firstPart.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Ensures that cached `dart_sdk.js` and `require.js` exist for the current SDK version.
  Future<bool> ensureSdkArtifacts({
    void Function(String message)? onProgress,
  }) async {
    if (!isAvailable) return false;

    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final cachedSdkJs = File(p.join(cacheDir.path, 'dart_sdk.js'));
    final cachedRequireJs = File(p.join(cacheDir.path, 'require.js'));
    final versionFile = File(p.join(cacheDir.path, '.version'));

    final isCacheValid = cachedSdkJs.existsSync() &&
        cachedSdkJs.lengthSync() > 0 &&
        cachedRequireJs.existsSync() &&
        versionFile.existsSync() &&
        versionFile.readAsStringSync().trim() == sdkVersion.trim();

    if (isCacheValid) {
      return true;
    }

    onProgress?.call('Generating shared DDC SDK runtime (dart_sdk.js)...');
    final sw = Stopwatch()..start();

    // 1. Copy require.js
    final srcRequire = File(requireJsPath!);
    if (srcRequire.existsSync()) {
      srcRequire.copySync(cachedRequireJs.path);
    }

    // 2. Compile dart_sdk.js
    final result = await Process.run(runnerExecutable!, [
      snapshotPath!,
      '--multi-root-scheme=org-dartlang-sdk',
      '--modules=amd',
      '--module-name=dart_sdk',
      '-o',
      cachedSdkJs.path,
      ddcPlatformDillPath!,
    ]);
    sw.stop();

    if (result.exitCode != 0) {
      return false;
    }

    versionFile.writeAsStringSync(sdkVersion);
    final sizeKb = (cachedSdkJs.lengthSync() / 1024).toStringAsFixed(1);
    onProgress?.call(
        '✓ Compiled DDC SDK module ($sizeKb kB) in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
    return true;
  }
}

/// Result of a DDC compilation run.
class DdcCompileResult {
  final bool success;
  final String? error;
  final Duration duration;
  final int outputSizeBytes;

  const DdcCompileResult({
    required this.success,
    this.error,
    required this.duration,
    this.outputSizeBytes = 0,
  });

  double get outputSizeKb => outputSizeBytes / 1024;
}

/// Fast DDC development compiler for Bloom JS Native web applications.
class DdcDevCompiler {
  final DdcToolchain toolchain;
  final File entryFile;
  final File outputFile;
  final File? packageConfigFile;
  final String moduleName;

  DdcDevCompiler({
    required this.toolchain,
    required this.entryFile,
    required this.outputFile,
    this.packageConfigFile,
    this.moduleName = 'main',
  });

  /// Compiles [entryFile] to an AMD module at [outputFile].
  Future<DdcCompileResult> compile({BloomLiveReloadServer? devServer}) async {
    if (!toolchain.isAvailable) {
      const err = 'DDC toolchain is not available on this system.';
      devServer?.broadcastError(err);
      return const DdcCompileResult(
        success: false,
        error: err,
        duration: Duration.zero,
      );
    }

    final sw = Stopwatch()..start();
    final args = <String>[
      toolchain.snapshotPath!,
      if (packageConfigFile != null && packageConfigFile!.existsSync())
        '--packages=${packageConfigFile!.path}',
      '--modules=amd',
      '--module-name=$moduleName',
      '-o',
      outputFile.path,
      entryFile.path,
    ];

    final result = await Process.run(toolchain.runnerExecutable!, args);
    sw.stop();

    if (result.exitCode != 0) {
      final err = '${result.stderr}'.trim();
      final fullErr = err.isNotEmpty ? err : '${result.stdout}'.trim();
      devServer?.broadcastError(fullErr);
      return DdcCompileResult(
        success: false,
        error: fullErr,
        duration: sw.elapsed,
      );
    }

    final sizeBytes = outputFile.existsSync() ? outputFile.lengthSync() : 0;
    return DdcCompileResult(
      success: true,
      duration: sw.elapsed,
      outputSizeBytes: sizeBytes,
    );
  }
}
