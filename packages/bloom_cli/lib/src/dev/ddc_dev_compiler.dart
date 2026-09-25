// lib/src/dev/ddc_dev_compiler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bazel_worker/bazel_worker.dart'
    show EXIT_CODE_ERROR, Input, WorkRequest;
import 'package:bazel_worker/driver.dart' show BazelWorkerDriver;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'live_reload_server.dart';
import 'signal_key_injector.dart';

typedef DdcSourceTransformer = String Function(
  String source, {
  required String relativePath,
});

typedef DdcProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

typedef DdcWorkerSpawner = Future<Process> Function(
  String executable,
  List<String> arguments,
);

Future<ProcessResult> _runDdcProcess(
  String executable,
  List<String> arguments,
) =>
    Process.run(executable, arguments);

Future<Process> _spawnDdcWorker(
  String executable,
  List<String> arguments,
) =>
    Process.start(executable, arguments);

String _injectStableSignalKeys(
  String source, {
  required String relativePath,
}) =>
    SignalKeyInjector.injectKeys(source, relativePath: relativePath);

/// Representation of the Dart Dev Compiler (DDC) SDK toolchain and runtime paths.
class DdcToolchain {
  final String sdkBinDir;
  final String sdkRootDir;
  final String? snapshotPath;
  final String? runnerExecutable;
  final String? ddcPlatformDillPath;
  final String? ddcOutlineDillPath;
  final String? requireJsPath;
  final Directory cacheDir;
  final String sdkVersion;

  DdcToolchain._({
    required this.sdkBinDir,
    required this.sdkRootDir,
    required this.snapshotPath,
    required this.runnerExecutable,
    required this.ddcPlatformDillPath,
    required this.ddcOutlineDillPath,
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

    final aotSnapshot =
        File(p.join(snapshotsDir, 'dartdevc_aot.dart.snapshot'));
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
    final ddcOutlineDill =
        File(p.join(sdkRoot, 'lib', '_internal', 'ddc_outline.dill'));
    final requireJs =
        File(p.join(sdkRoot, 'lib', 'dev_compiler', 'amd', 'require.js'));

    final rawVersion = customSdkVersion ?? Platform.version;
    final sanitizedVersion = sanitizeVersion(rawVersion);

    final Directory cache;
    if (projectRoot != null) {
      cache = Directory(p.join(
          projectRoot.path, '.dart_tool', 'bloom', 'ddc', sanitizedVersion));
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
      ddcOutlineDillPath:
          ddcOutlineDill.existsSync() ? ddcOutlineDill.path : null,
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
    DdcProcessRunner runProcess = _runDdcProcess,
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
    final srcRequire = File(requireJsPath!);
    if (!srcRequire.existsSync()) return false;
    final sw = Stopwatch()..start();

    final cacheToken = '$pid-${DateTime.now().microsecondsSinceEpoch}';
    final temporarySdkJs = File('${cachedSdkJs.path}.$cacheToken.tmp');
    final temporaryRequireJs = File('${cachedRequireJs.path}.$cacheToken.tmp');
    try {
      // Compile and stage both runtime files before replacing the active cache.
      final result = await runProcess(runnerExecutable!, [
        snapshotPath!,
        '--multi-root-scheme=org-dartlang-sdk',
        '--modules=amd',
        '--module-name=dart_sdk',
        '-o',
        temporarySdkJs.path,
        ddcPlatformDillPath!,
      ]);
      sw.stop();

      if (result.exitCode != 0 ||
          !temporarySdkJs.existsSync() ||
          temporarySdkJs.lengthSync() == 0) {
        return false;
      }

      srcRequire.copySync(temporaryRequireJs.path);
      temporarySdkJs.copySync(cachedSdkJs.path);
      temporaryRequireJs.copySync(cachedRequireJs.path);
      versionFile.writeAsStringSync(sdkVersion);
      final sizeKb = (cachedSdkJs.lengthSync() / 1024).toStringAsFixed(1);
      onProgress?.call(
          '✓ Compiled DDC SDK module ($sizeKb kB) in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
      return true;
    } catch (_) {
      return false;
    } finally {
      if (sw.isRunning) sw.stop();
      try {
        if (temporarySdkJs.existsSync()) temporarySdkJs.deleteSync();
        if (temporaryRequireJs.existsSync()) temporaryRequireJs.deleteSync();
      } catch (_) {}
    }
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
  final DdcSourceTransformer transformSource;
  final DdcProcessRunner runProcess;
  final DdcWorkerSpawner spawnWorker;
  final bool useIncrementalWorker;
  final Map<String, String> _stagedSourceHashes = {};
  BazelWorkerDriver? _workerDriver;
  bool _workerDisabled = false;
  Future<void> _compileQueue = Future.value();

  DdcDevCompiler({
    required this.toolchain,
    required this.entryFile,
    required this.outputFile,
    this.packageConfigFile,
    this.moduleName = 'main',
    this.transformSource = _injectStableSignalKeys,
    this.runProcess = _runDdcProcess,
    this.spawnWorker = _spawnDdcWorker,
    this.useIncrementalWorker = false,
  });

  /// Compiles [entryFile] to an AMD module at [outputFile].
  Future<DdcCompileResult> compile({BloomLiveReloadServer? devServer}) {
    final result = Completer<DdcCompileResult>();
    _compileQueue = _compileQueue.then((_) async {
      try {
        result.complete(await _compile(devServer: devServer));
      } catch (error) {
        final message = 'DDC compilation failed unexpectedly: $error';
        devServer?.broadcastError(message);
        result.complete(DdcCompileResult(
          success: false,
          error: message,
          duration: Duration.zero,
        ));
      }
    });
    return result.future;
  }

  Future<void> dispose() async {
    await _compileQueue;
    final driver = _workerDriver;
    _workerDriver = null;
    if (driver != null) await driver.terminateWorkers();
  }

  Future<DdcCompileResult> _compile({BloomLiveReloadServer? devServer}) async {
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
    // Include source staging and signal-key transformation in the reported
    // duration; both are part of the work triggered by a developer edit.
    final (
      File stagedEntryFile,
      File? stagedPackageConfig,
      List<File> stagedDartFiles
    ) staged;
    try {
      staged = _stageSourcesWithSignalKeys();
    } catch (error) {
      sw.stop();
      final message = 'Failed to stage Dart sources: $error';
      devServer?.broadcastError(message);
      return DdcCompileResult(
        success: false,
        error: message,
        duration: sw.elapsed,
      );
    }
    outputFile.parent.createSync(recursive: true);
    final compileOutputFile = File(
      '${outputFile.path}.bloom-ddc-${pid}-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final compilerArgs = <String>[
      if (staged.$2 != null) '--packages=${staged.$2!.path}',
      '--modules=amd',
      '--module-name=$moduleName',
      '-o',
      compileOutputFile.path,
      staged.$1.path,
    ];

    final ProcessResult result;
    try {
      result = await _runCompiler(
        compilerArgs,
        compileOutputFile,
        staged.$3,
      );
    } catch (error) {
      sw.stop();
      if (compileOutputFile.existsSync()) compileOutputFile.deleteSync();
      final message = 'Failed to start DDC compiler: $error';
      devServer?.broadcastError(message);
      return DdcCompileResult(
        success: false,
        error: message,
        duration: sw.elapsed,
      );
    }
    sw.stop();

    if (result.exitCode != 0) {
      final err = '${result.stderr}'.trim();
      final fullErr = err.isNotEmpty ? err : '${result.stdout}'.trim();
      if (compileOutputFile.existsSync()) compileOutputFile.deleteSync();
      devServer?.broadcastError(fullErr);
      return DdcCompileResult(
        success: false,
        error: fullErr,
        duration: sw.elapsed,
      );
    }

    if (!compileOutputFile.existsSync() ||
        compileOutputFile.lengthSync() == 0) {
      if (compileOutputFile.existsSync()) compileOutputFile.deleteSync();
      final message = 'DDC exited successfully without producing JavaScript.';
      devServer?.broadcastError(message);
      return DdcCompileResult(
        success: false,
        error: message,
        duration: sw.elapsed,
      );
    }

    compileOutputFile.copySync(outputFile.path);
    compileOutputFile.deleteSync();
    final sizeBytes = outputFile.lengthSync();
    return DdcCompileResult(
      success: true,
      duration: sw.elapsed,
      outputSizeBytes: sizeBytes,
    );
  }

  Future<ProcessResult> _runCompiler(
    List<String> compilerArgs,
    File compileOutputFile,
    List<File> stagedDartFiles,
  ) async {
    final executable = toolchain.runnerExecutable!;
    final oneShotArgs = [toolchain.snapshotPath!, ...compilerArgs];
    if (!useIncrementalWorker || _workerDisabled) {
      return runProcess(executable, oneShotArgs);
    }

    try {
      final worker = _workerDriver ??= BazelWorkerDriver(
        () async {
          final process = await spawnWorker(executable, [
            toolchain.snapshotPath!,
            '--persistent_worker',
            '--reuse-compiler-result',
            '--use-incremental-compiler',
          ]);
          // A worker that exits early makes the driver's stdin write fail with
          // a broken pipe. The driver already reports that as a failed
          // response; observe the sink so the error is not also uncaught.
          process.stdin.done.catchError((Object _) {});
          return process;
        },
        maxWorkers: 1,
        maxIdleWorkers: 1,
        maxRetries: 0,
      );
      final inputs = stagedDartFiles
          .map((file) => Input(
                path: file.absolute.path,
                digest: sha256.convert(file.readAsBytesSync()).bytes,
              ))
          .toList();
      final sdkOutlinePath = toolchain.ddcOutlineDillPath;
      if (sdkOutlinePath == null) {
        throw StateError('DDC SDK outline summary is unavailable.');
      }
      final sdkOutline = File(sdkOutlinePath);
      inputs.add(Input(
        path: sdkOutline.absolute.path,
        digest: sha256.convert(sdkOutline.readAsBytesSync()).bytes,
      ));
      final response = await worker.doWork(WorkRequest(
        arguments: compilerArgs,
        inputs: inputs,
      ));
      if (response.exitCode == EXIT_CODE_ERROR) {
        _workerDisabled = true;
        _workerDriver = null;
        await worker.terminateWorkers();
        return await runProcess(executable, oneShotArgs);
      }
      return ProcessResult(0, response.exitCode, response.output, '');
    } catch (_) {
      if (_workerDisabled) rethrow;
      // A worker can fail for unsupported SDKs or a protocol mismatch. Retire
      // it and fall back to DDC's regular one-shot invocation for this session.
      _workerDisabled = true;
      final worker = _workerDriver;
      _workerDriver = null;
      if (worker != null) {
        try {
          await worker.terminateWorkers();
        } catch (_) {}
      }
      return runProcess(executable, oneShotArgs);
    }
  }

  /// Stages [entryFile] and local `lib/` sources into a temporary build cache.
  /// Unchanged sources reuse their transformed staged copy; removed Dart files
  /// are removed from staging so a deleted import cannot compile from stale code.
  (File, File?, List<File>) _stageSourcesWithSignalKeys() {
    final stagingDir =
        Directory(p.join(toolchain.cacheDir.path, 'staged', moduleName));
    if (!stagingDir.existsSync()) {
      stagingDir.createSync(recursive: true);
    }

    Directory? projectRoot;
    var current = entryFile.parent;
    while (current.path != current.parent.path) {
      if (File(p.join(current.path, 'pubspec.yaml')).existsSync() ||
          Directory(p.join(current.path, '.dart_tool')).existsSync()) {
        projectRoot = current;
        break;
      }
      current = current.parent;
    }

    final sourceFiles = <File>[entryFile];
    if (projectRoot != null) {
      final libDir = Directory(p.join(projectRoot.path, 'lib'));
      if (libDir.existsSync()) {
        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              p.normalize(entity.path) != p.normalize(entryFile.path)) {
            sourceFiles.add(entity);
          }
        }
      }
    }

    final activeRelativePaths = <String>{};
    final stagedDartFiles = <File>[];
    for (final sourceFile in sourceFiles) {
      final relativePath = projectRoot == null
          ? p.basename(sourceFile.path)
          : p.relative(sourceFile.path, from: projectRoot.path);
      final normalizedRelativePath = p.normalize(relativePath);
      activeRelativePaths.add(normalizedRelativePath);

      final bytes = sourceFile.readAsBytesSync();
      final sourceHash = sha256.convert(bytes).toString();
      final stagedFile = File(p.join(stagingDir.path, relativePath));
      stagedDartFiles.add(stagedFile);
      if (stagedFile.existsSync() &&
          _stagedSourceHashes[normalizedRelativePath] == sourceHash) {
        continue;
      }

      stagedFile.parent.createSync(recursive: true);
      final source = utf8.decode(bytes);
      stagedFile.writeAsStringSync(transformSource(
        source,
        relativePath: relativePath,
      ));
      _stagedSourceHashes[normalizedRelativePath] = sourceHash;
    }

    for (final entity in stagingDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relativePath = p.normalize(
        p.relative(entity.path, from: stagingDir.path),
      );
      if (!activeRelativePaths.contains(relativePath)) {
        entity.deleteSync();
        _stagedSourceHashes.remove(relativePath);
      }
    }
    _stagedSourceHashes.removeWhere(
        (relativePath, _) => !activeRelativePaths.contains(relativePath));

    final stagedPackageConfig = _stagePackageConfig(projectRoot, stagingDir);
    final entryRelPath = projectRoot == null
        ? p.basename(entryFile.path)
        : p.relative(entryFile.path, from: projectRoot.path);
    final stagedEntry = File(p.join(stagingDir.path, entryRelPath));
    return (stagedEntry, stagedPackageConfig, stagedDartFiles);
  }

  /// Redirects imports of this package through the transformed staging tree.
  /// Package imports otherwise resolve against the original `lib/` files and
  /// silently skip signal-key injection, even though relative imports work.
  File? _stagePackageConfig(Directory? projectRoot, Directory stagingDir) {
    final sourceConfig = packageConfigFile;
    if (projectRoot == null ||
        sourceConfig == null ||
        !sourceConfig.existsSync()) {
      return null;
    }

    final config = jsonDecode(sourceConfig.readAsStringSync());
    if (config is! Map<String, dynamic> || config['packages'] is! List) {
      throw const FormatException('Invalid Dart package configuration.');
    }

    final configUri = Uri.file(sourceConfig.absolute.path);
    final projectPath = _canonicalPath(projectRoot.path);
    var foundProjectPackage = false;
    for (final package in config['packages'] as List) {
      if (package is! Map<String, dynamic> || package['rootUri'] is! String) {
        continue;
      }
      final rootUri = configUri.resolve(package['rootUri'] as String);
      if (rootUri.scheme != 'file' ||
          _canonicalPath(p.fromUri(rootUri)) != projectPath) {
        continue;
      }
      package['rootUri'] = Uri.directory(stagingDir.absolute.path).toString();
      foundProjectPackage = true;
    }
    if (!foundProjectPackage) return sourceConfig;

    final stagedConfig = File(p.join(stagingDir.path, 'package_config.json'));
    stagedConfig
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(config));
    return stagedConfig;
  }

  String _canonicalPath(String path) {
    final normalized = p.normalize(p.absolute(path));
    try {
      return p.normalize(Directory(normalized).resolveSymbolicLinksSync());
    } on FileSystemException {
      return normalized;
    }
  }
}
