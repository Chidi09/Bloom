// test/commands/build_command_web_dom_test.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/build_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('BuildCommand web_dom target', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_web_dom_test_');
      final pubspec = File(p.join(tempDir.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync('name: web_dom_test_app\n');
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync(recursive: true);
      File(p.join(libDir.path, 'main.dart')).writeAsStringSync('void main() {}');
      Directory(p.join(tempDir.path, 'web'))..createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    CommandRunner<int> createRunner({bool compileSucceeds = true}) {
      return CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(BuildCommand(
          processRunner: (exec, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false, mode = ProcessStartMode.normal}) async {
            if (exec == 'dart' && args.contains('compile')) {
              if (compileSucceeds) {
                // Simulate output file creation
                final outIdx = args.indexOf('-o');
                if (outIdx != -1 && outIdx + 1 < args.length) {
                  final outFile = File(p.join(workingDirectory ?? tempDir.path, args[outIdx + 1]));
                  outFile.parent.createSync(recursive: true);
                  outFile.writeAsStringSync('// compiled js');
                }
                return ProcessResult(101, 0, 'Compiled JS', '');
              } else {
                return ProcessResult(102, 1, '', 'Compilation error');
              }
            }
            return Process.run(
              exec,
              args,
              workingDirectory: workingDirectory,
              environment: environment,
              includeParentEnvironment: includeParentEnvironment,
              runInShell: runInShell,
            );
          },
        ));
    }

    test('recursively copies source web/ static assets into build/web/', () async {
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('''
name: static_assets_app
target: web_dom
proxy:
  /api:
    target: "https://api.example.com"
''');

      // Create static files and nested directories in source web/
      File(p.join(tempDir.path, 'web', 'favicon.ico')).writeAsStringSync('FAVICON_DATA');
      final logoDir = Directory(p.join(tempDir.path, 'web', 'assets', 'images'))..createSync(recursive: true);
      File(p.join(logoDir.path, 'logo.svg')).writeAsStringSync('<svg>logo</svg>');
      final vendorDir = Directory(p.join(tempDir.path, 'web', 'vendor'))..createSync(recursive: true);
      File(p.join(vendorDir.path, 'analytics.js')).writeAsStringSync('console.log("analytics");');
      File(p.join(tempDir.path, 'web', 'index.html')).writeAsStringSync('<html><body>Source</body></html>');

      final runner = createRunner();
      final exitCode = await runner.run(['build', 'web_dom', '--project-dir', tempDir.path]);

      expect(exitCode, 0);

      // Verify build/web/ contains all copied assets
      expect(File(p.join(tempDir.path, 'build', 'web', 'favicon.ico')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'build', 'web', 'favicon.ico')).readAsStringSync(), 'FAVICON_DATA');

      expect(File(p.join(tempDir.path, 'build', 'web', 'assets', 'images', 'logo.svg')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'build', 'web', 'assets', 'images', 'logo.svg')).readAsStringSync(), '<svg>logo</svg>');

      expect(File(p.join(tempDir.path, 'build', 'web', 'vendor', 'analytics.js')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'build', 'web', 'vendor', 'analytics.js')).readAsStringSync(), 'console.log("analytics");');

      expect(File(p.join(tempDir.path, 'build', 'web', 'index.html')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'build', 'web', 'main.dart.js')).existsSync(), isTrue);

      // Verify proxy rules host config was written to build/web/_redirects
      final redirects = File(p.join(tempDir.path, 'build', 'web', '_redirects'));
      expect(redirects.existsSync(), isTrue);
      expect(redirects.readAsStringSync(), contains('/api/*'));

      // Verify source web/ does NOT contain main.dart.js or _redirects
      expect(File(p.join(tempDir.path, 'web', 'main.dart.js')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'web', '_redirects')).existsSync(), isFalse);
    });

    test('cleans stale files from build/web/ across consecutive builds', () async {
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('''
name: stale_cleanup_app
target: web_dom
''');

      File(p.join(tempDir.path, 'web', 'index.html')).writeAsStringSync('<html><body>Source</body></html>');

      final runner = createRunner();

      // First build
      final exitCode1 = await runner.run(['build', 'web_dom', '--project-dir', tempDir.path]);
      expect(exitCode1, 0);

      // Add a sentinel file directly into build/web/ (not present in source web/)
      final sentinelFile = File(p.join(tempDir.path, 'build', 'web', 'stale_old_artifact.txt'));
      sentinelFile.writeAsStringSync('STALE_DATA');
      expect(sentinelFile.existsSync(), isTrue);

      // Second build
      final exitCode2 = await runner.run(['build', 'web_dom', '--project-dir', tempDir.path]);
      expect(exitCode2, 0);

      // Verify the sentinel file is GONE after second build
      expect(sentinelFile.existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'build', 'web', 'index.html')).existsSync(), isTrue);
    });

    test('preserves source web/index.html byte-for-byte and mtime unmodified', () async {
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('''
name: immutability_test_app
target: web_dom
''');

      const originalHtml = '<!DOCTYPE html><html><head><title>Immutability</title></head><body><p>Hello</p></body></html>';
      final sourceIndexHtml = File(p.join(tempDir.path, 'web', 'index.html'))..writeAsStringSync(originalHtml);

      final originalBytes = sourceIndexHtml.readAsBytesSync();
      final originalMtime = sourceIndexHtml.lastModifiedSync();

      final runner = createRunner();
      final exitCode = await runner.run(['build', 'web_dom', '--project-dir', tempDir.path]);
      expect(exitCode, 0);

      // Verify byte-for-byte equality
      final afterBytes = sourceIndexHtml.readAsBytesSync();
      expect(afterBytes, equals(originalBytes));
      expect(sourceIndexHtml.readAsStringSync(), equals(originalHtml));
      expect(sourceIndexHtml.lastModifiedSync(), equals(originalMtime));
    });

    test('returns exit code 1 if dart compile js fails', () async {
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('''
name: failing_compile_app
target: web_dom
''');

      File(p.join(tempDir.path, 'web', 'index.html')).writeAsStringSync('<html><body>Source</body></html>');

      final runner = createRunner(compileSucceeds: false);
      final exitCode = await runner.run(['build', 'web_dom', '--project-dir', tempDir.path]);

      expect(exitCode, 1);
    });
  });
}
