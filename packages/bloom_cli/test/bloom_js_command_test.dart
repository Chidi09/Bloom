import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/js_command.dart';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('JsCommand', () {
    test('registers dev, build, and vendor subcommands', () {
      final cmd = JsCommand();
      expect(cmd.name, 'js');
      expect(cmd.subcommands.keys, containsAll(['dev', 'build', 'vendor']));
    });

    test('JsBuildCommand supports --analyze and --ssg flags', () {
      final cmd = JsBuildCommand();
      expect(cmd.argParser.options.containsKey('analyze'), isTrue);
      expect(cmd.argParser.options.containsKey('output'), isTrue);
      expect(cmd.argParser.options.containsKey('ssg'), isTrue);
      expect(cmd.argParser.options['ssg']!.isFlag, isTrue);
      expect(cmd.argParser.options['ssg']!.help,
          contains('Also render a static site into dist/ via bin/ssg.dart'));
    });

    test('JsDevCommand supports --port and --entry options', () {
      final cmd = JsDevCommand();
      expect(cmd.argParser.options.containsKey('port'), isTrue);
      expect(cmd.argParser.options.containsKey('entry'), isTrue);
      expect(cmd.argParser.parse([])['host'], '127.0.0.1');
      expect(cmd.argParser.parse(['--host', '0.0.0.0'])['host'], '0.0.0.0');
    });

    test(
        'JsBuildCommand with --ssg fails clearly when bin/ssg.dart does not exist',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('bloom_test_ssg_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      // Set up minimal bloom project structure
      File(p.join(tempDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: test_proj\n');
      final webDir = Directory(p.join(tempDir.path, 'web'))..createSync();
      File(p.join(webDir.path, 'index.html'))
          .writeAsStringSync('<html><body></body></html>');
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
      File(p.join(libDir.path, 'main.dart'))
          .writeAsStringSync('void main() {}');

      final project = BloomProject.fromDirectory(tempDir);
      final buildCmd = JsBuildCommand(project: project);
      final runner = CommandRunner<int>('test_runner', 'Test runner')
        ..addCommand(buildCmd);

      // We run the command with --ssg.
      // Notice: dart compile js -O4 on empty `void main() {}` succeeds and creates web/main.js,
      // and then the ssg step checks for bin/ssg.dart and fails with exit code 1.
      final exitCode = await runner.run(['build', '--ssg']);
      expect(exitCode, 1);
    });
  });
}
