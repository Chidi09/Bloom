import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/js_command.dart';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('JsBuildCommand --wasm', () {
    test('registers --wasm flag', () {
      final cmd = JsBuildCommand();
      expect(cmd.argParser.options.containsKey('wasm'), isTrue);
      expect(cmd.argParser.defaultFor('wasm'), isFalse);
    });

    test('compiles a minimal Dart entry to main.wasm and main.mjs', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('bloom_js_build_wasm_test_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: wasm_fixture
environment:
  sdk: '>=3.4.0 <4.0.0'
''');
      File(p.join(tempDir.path, 'bloom.yaml')).writeAsStringSync('''
name: wasm_fixture
target: web_dom
''');
      Directory(p.join(tempDir.path, 'lib')).createSync();
      Directory(p.join(tempDir.path, 'web')).createSync();
      File(p.join(tempDir.path, 'lib', 'main.dart')).writeAsStringSync('''
void main() {
  print('bloom-wasm-ok');
}
''');

      final project = BloomProject.find(tempDir)!;
      final runner = CommandRunner<int>('bloom', 'test')
        ..addCommand(JsBuildCommand(project: project));

      final exitCode = await runner.run(['build', '--wasm', '--analyze']);
      expect(exitCode, 0);
      expect(File(p.join(tempDir.path, 'web', 'main.wasm')).existsSync(),
          isTrue);
      expect(
          File(p.join(tempDir.path, 'web', 'main.mjs')).existsSync(), isTrue);
    });
  });
}
