import 'dart:io';
import 'package:bloom_cli/src/dev/ddc_dev_compiler.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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

    test('ensureSdkArtifacts generates and caches dart_sdk.js and require.js', () async {
      expect(toolchain.isAvailable, isTrue);

      final generated = await toolchain.ensureSdkArtifacts();
      expect(generated, isTrue);

      final cachedSdkJs = File(p.join(toolchain.cacheDir.path, 'dart_sdk.js'));
      final cachedRequireJs = File(p.join(toolchain.cacheDir.path, 'require.js'));
      final versionFile = File(p.join(toolchain.cacheDir.path, '.version'));

      expect(cachedSdkJs.existsSync(), isTrue);
      expect(cachedSdkJs.lengthSync(), greaterThan(1024 * 1024)); // > 1MB
      expect(cachedRequireJs.existsSync(), isTrue);
      expect(versionFile.existsSync(), isTrue);
      expect(versionFile.readAsStringSync().trim(), equals(toolchain.sdkVersion.trim()));

      // Subsequent call is a no-op cache hit
      final secondCall = await toolchain.ensureSdkArtifacts();
      expect(secondCall, isTrue);
    });

    test('compiles a valid Dart entrypoint to AMD JavaScript module', () async {
      final entry = File(p.join(tempDir.path, 'main.dart'))..writeAsStringSync('''
void main() {
  print('Hello from DDC test!');
}
''');
      final output = File(p.join(tempDir.path, 'main.js'));

      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entry,
        outputFile: output,
        moduleName: 'main',
      );

      final result = await compiler.compile();
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.duration.inMilliseconds, greaterThan(0));
      expect(output.existsSync(), isTrue);

      final jsContent = output.readAsStringSync();
      expect(jsContent, contains("define(['dart_sdk']"));
      expect(jsContent, contains('Hello from DDC test!'));
    });

    test('handles compilation errors gracefully', () async {
      final entry = File(p.join(tempDir.path, 'bad.dart'))..writeAsStringSync('''
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
  });
}
