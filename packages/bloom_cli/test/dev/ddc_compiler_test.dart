import 'dart:io';
import 'dart:convert';
import 'package:bloom_cli/src/dev/ddc_dev_compiler.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'fixture_package_config.dart';

void main() {
  group('DdcDevCompiler & SDK Caching', () {
    late Directory tempDir;
    late DdcToolchain toolchain;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ddc_compiler_test_');
      toolchain = DdcToolchain.discover(projectRoot: tempDir);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('ensureSdkArtifacts generates and caches dart_sdk.js and require.js',
        () async {
      expect(toolchain.isAvailable, isTrue);

      final generated = await toolchain.ensureSdkArtifacts();
      expect(generated, isTrue);

      final cachedSdkJs = File(p.join(toolchain.cacheDir.path, 'dart_sdk.js'));
      final cachedRequireJs =
          File(p.join(toolchain.cacheDir.path, 'require.js'));
      final versionFile = File(p.join(toolchain.cacheDir.path, '.version'));

      expect(cachedSdkJs.existsSync(), isTrue);
      expect(cachedSdkJs.lengthSync(), greaterThan(1024 * 1024)); // > 1MB
      expect(cachedRequireJs.existsSync(), isTrue);
      expect(versionFile.existsSync(), isTrue);
      expect(versionFile.readAsStringSync().trim(),
          equals(toolchain.sdkVersion.trim()));

      // Subsequent call is a no-op cache hit
      final secondCall = await toolchain.ensureSdkArtifacts();
      expect(secondCall, isTrue);
    });

    test('failed SDK runtime builds preserve the previous artifact cache',
        () async {
      final cachedSdkJs = File(p.join(toolchain.cacheDir.path, 'dart_sdk.js'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('previous sdk runtime');
      final cachedRequireJs =
          File(p.join(toolchain.cacheDir.path, 'require.js'))
            ..writeAsStringSync('previous require runtime');
      final versionFile = File(p.join(toolchain.cacheDir.path, '.version'))
        ..writeAsStringSync('previous version');

      final failedRun = await toolchain.ensureSdkArtifacts(
        runProcess: (_, __) async => ProcessResult(1, 1, '', 'compile failed'),
      );
      expect(failedRun, isFalse);
      expect(cachedSdkJs.readAsStringSync(), equals('previous sdk runtime'));
      expect(cachedRequireJs.readAsStringSync(),
          equals('previous require runtime'));
      expect(versionFile.readAsStringSync(), equals('previous version'));

      final launchFailure = await toolchain.ensureSdkArtifacts(
        runProcess: (_, __) async => throw StateError('spawn failed'),
      );
      expect(launchFailure, isFalse);
      expect(cachedSdkJs.readAsStringSync(), equals('previous sdk runtime'));
      expect(versionFile.readAsStringSync(), equals('previous version'));
    });

    test('compiles a valid Dart entrypoint to AMD JavaScript module', () async {
      File(p.join(tempDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: cache_test\n');
      final libDir = Directory(p.join(tempDir.path, 'lib'))
        ..createSync(recursive: true);
      final entry = File(p.join(libDir.path, 'main.dart'))
        ..writeAsStringSync('''
void main() {
  print('Hello from DDC test!');
}
''');
      File(p.join(libDir.path, 'helper.dart'))
          .writeAsStringSync('String helper() => "unchanged";\n');
      final output = File(p.join(tempDir.path, 'main.js'));
      var transformCount = 0;

      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: output,
        moduleName: 'main',
        transformSource: (source, {required relativePath}) {
          transformCount++;
          if (transformCount == 1) sleep(const Duration(milliseconds: 80));
          return source;
        },
      );

      final result = await compiler.compile();
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.duration.inMilliseconds, greaterThan(0));
      expect(result.duration,
          greaterThanOrEqualTo(const Duration(milliseconds: 80)),
          reason: 'compile duration must include source staging');
      expect(output.existsSync(), isTrue);
      expect(transformCount, 2,
          reason: 'the entry and sibling source are initially staged');

      final jsContent = output.readAsStringSync();
      expect(jsContent, contains("define(['dart_sdk']"));
      expect(jsContent, contains('Hello from DDC test!'));

      final repeated = await compiler.compile();
      expect(repeated.success, isTrue);
      expect(transformCount, 2,
          reason: 'unchanged project sources should not be transformed again');

      entry.writeAsStringSync("void main() { print('Updated source'); }\n");
      final updated = await compiler.compile();
      expect(updated.success, isTrue);
      expect(transformCount, 3,
          reason: 'only the changed entry should be transformed again');
      expect(output.readAsStringSync(), contains('Updated source'));
    });

    test('DDC compiles auto-scoped stateful class constructor call sites',
        () async {
      final libDir = Directory(p.join(tempDir.path, 'lib'))
        ..createSync(recursive: true);
      File(p.join(libDir.path, 'store.dart')).writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';

class CounterStore {
  final count = signal(0);
}
''');
      final entry = File(p.join(libDir.path, 'main.dart'))
        ..writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'store.dart';

void main() {
  final left = CounterStore();
  final right = CounterStore();
  print(left.count.value + right.count.value);
}
''');
      final packageConfig = await createJsNativePackageConfig(tempDir);
      final output = File(p.join(tempDir.path, 'main.js'));
      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: output,
        packageConfigFile: packageConfig,
      );

      final result = await compiler.compile();
      expect(result.success, isTrue, reason: result.error);
      final stagedSource = File(p.join(
        toolchain.cacheDir.path,
        'staged',
        'main',
        'lib',
        'main.dart',
      )).readAsStringSync();
      expect(
        stagedSource,
        contains("bloomHmrScope('lib/main.dart#main#left#CounterStore'"),
      );
      expect(
        stagedSource,
        contains("bloomHmrScope('lib/main.dart#main#right#CounterStore'"),
      );
      final stagedStore = File(p.join(
        toolchain.cacheDir.path,
        'staged',
        'main',
        'lib',
        'store.dart',
      )).readAsStringSync();
      expect(
        stagedStore,
        contains("signal(0, key: 'lib/store.dart#CounterStore.count#0')"),
      );
    });

    test('removes staged Dart files after their source is deleted', () async {
      File(p.join(tempDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: staged_test\n');
      final libDir = Directory(p.join(tempDir.path, 'lib'))
        ..createSync(recursive: true);
      final entry = File(p.join(libDir.path, 'main.dart'))
        ..writeAsStringSync('void main() {}\n');
      final removedSource = File(p.join(libDir.path, 'removed.dart'))
        ..writeAsStringSync('void removed() {}\n');
      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: File(p.join(tempDir.path, 'main.js')),
      );

      expect((await compiler.compile()).success, isTrue);
      final stagedRemoved = File(p.join(
        toolchain.cacheDir.path,
        'staged',
        'main',
        'lib',
        'removed.dart',
      ));
      expect(stagedRemoved.existsSync(), isTrue);

      removedSource.deleteSync();
      expect((await compiler.compile()).success, isTrue);
      expect(stagedRemoved.existsSync(), isFalse,
          reason: 'deleted sources must not survive in the DDC staging tree');
    });

    test('package imports resolve through transformed staged sources',
        () async {
      File(p.join(tempDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: fixture_app\n');
      final libDir = Directory(p.join(tempDir.path, 'lib'))
        ..createSync(recursive: true);
      final entry = File(p.join(libDir.path, 'main.dart'))
        ..writeAsStringSync('''
import 'package:fixture_app/helper.dart';
void main() => print(helper());
''');
      File(p.join(libDir.path, 'helper.dart'))
          .writeAsStringSync('String helper() => "original";\n');
      final configDir = Directory(p.join(tempDir.path, '.dart_tool'))
        ..createSync(recursive: true);
      final packageConfig = File(p.join(configDir.path, 'package_config.json'))
        ..writeAsStringSync(jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'fixture_app',
              'rootUri': '../',
              'packageUri': 'lib/',
              'languageVersion': '3.3',
            },
          ],
        }));
      final output = File(p.join(tempDir.path, 'main.js'));
      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: output,
        packageConfigFile: packageConfig,
        transformSource: (source, {required relativePath}) =>
            source.replaceAll('original', 'transformed'),
      );

      final result = await compiler.compile();
      expect(result.success, isTrue, reason: result.error);
      expect(output.readAsStringSync(), contains('transformed'));

      final stagedConfig = File(p.join(
        toolchain.cacheDir.path,
        'staged',
        'main',
        'package_config.json',
      ));
      expect(stagedConfig.existsSync(), isTrue);
      final stagedPackages = (jsonDecode(stagedConfig.readAsStringSync())
          as Map)['packages'] as List;
      expect(stagedPackages.single['rootUri'],
          equals(Uri.directory(stagedConfig.parent.absolute.path).toString()));
    });

    test('incremental worker reuses one process and recompiles changed imports',
        () async {
      File(p.join(tempDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: incremental_fixture\n');
      final libDir = Directory(p.join(tempDir.path, 'lib'))
        ..createSync(recursive: true);
      final entry = File(p.join(libDir.path, 'main.dart'))
        ..writeAsStringSync(
            "import 'helper.dart';\nvoid main() => print(message());\n");
      final helper = File(p.join(libDir.path, 'helper.dart'))
        ..writeAsStringSync("String message() => 'before';\n");
      final output = File(p.join(tempDir.path, 'main.js'));
      var workerStarts = 0;
      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: output,
        useIncrementalWorker: true,
        spawnWorker: (executable, arguments) {
          workerStarts++;
          return Process.start(executable, arguments);
        },
        runProcess: (_, __) async =>
            throw StateError('incremental worker unexpectedly fell back'),
      );

      try {
        final initial = await compiler.compile();
        expect(initial.success, isTrue, reason: initial.error);
        expect(output.readAsStringSync(), contains('before'));

        helper.writeAsStringSync("String message() => 'after';\n");
        final updated = await compiler.compile();
        expect(updated.success, isTrue, reason: updated.error);
        expect(output.readAsStringSync(), contains('after'));

        helper.writeAsStringSync('String message() => ;\n');
        final invalid = await compiler.compile();
        expect(invalid.success, isFalse);
        expect(output.readAsStringSync(), contains('after'),
            reason:
                'a failed incremental compile must preserve the last bundle');

        helper.writeAsStringSync("String message() => 'recovered';\n");
        final recovered = await compiler.compile();
        expect(recovered.success, isTrue, reason: recovered.error);
        expect(output.readAsStringSync(), contains('recovered'));
        expect(workerStarts, equals(1),
            reason: 'consecutive edits should reuse the same DDC worker');
      } finally {
        await compiler.dispose();
      }
    });

    test('falls back to one-shot DDC when the worker protocol fails', () async {
      final entry = File(p.join(tempDir.path, 'main.dart'))
        ..writeAsStringSync('void main() => print("fallback");\n');
      var fallbackRuns = 0;
      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: File(p.join(tempDir.path, 'main.js')),
        useIncrementalWorker: true,
        spawnWorker: (_, __) =>
            Process.start(Platform.resolvedExecutable, ['--version']),
        runProcess: (executable, arguments) async {
          fallbackRuns++;
          return Process.run(executable, arguments);
        },
      );

      try {
        final result = await compiler.compile();
        expect(result.success, isTrue, reason: result.error);
        expect(fallbackRuns, equals(1));
      } finally {
        await compiler.dispose();
      }
    });

    test('handles compilation errors gracefully', () async {
      final entry = File(p.join(tempDir.path, 'bad.dart'))
        ..writeAsStringSync('''
void main() {
  this is invalid syntax !!!
}
''');
      final output = File(p.join(tempDir.path, 'bad.js'));

      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: output,
        moduleName: 'bad',
      );

      final result = await compiler.compile();
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('Error'));
    });

    test('reports process failures and preserves the last good output',
        () async {
      final entry = File(p.join(tempDir.path, 'main.dart'))
        ..writeAsStringSync('void main() {}\n');
      final output = File(p.join(tempDir.path, 'main.js'))
        ..writeAsStringSync('previous good output');

      final launchFailure = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: output,
        runProcess: (_, __) async => throw StateError('spawn failed'),
      );
      final launchResult = await launchFailure.compile();
      expect(launchResult.success, isFalse);
      expect(launchResult.error, contains('Failed to start DDC compiler'));
      expect(output.readAsStringSync(), equals('previous good output'));

      final missingOutput = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: output,
        runProcess: (_, __) async => ProcessResult(1, 0, '', ''),
      );
      final missingOutputResult = await missingOutput.compile();
      expect(missingOutputResult.success, isFalse);
      expect(
          missingOutputResult.error, contains('without producing JavaScript'));
      expect(output.readAsStringSync(), equals('previous good output'));
    });

    test('returns a structured error when an entry source disappears',
        () async {
      final missingEntry = File(p.join(tempDir.path, 'deleted.dart'));
      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: missingEntry,
        outputFile: File(p.join(tempDir.path, 'deleted.js')),
      );

      final result = await compiler.compile();
      expect(result.success, isFalse);
      expect(result.error, contains('Failed to stage Dart sources'));
    });
  });
}
