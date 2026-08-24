// lib/src/commands/test_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Command that runs unit, widget, and integration tests across the Bloom project.
///
/// Example:
/// ```
/// bloom test
/// bloom test --coverage
/// bloom test --name "auth"
/// ```
class TestCommand extends Command<int> {
  @override
  final String name = 'test';
  @override
  final String description = 'Runs unit, widget, and integration tests.';

  TestCommand() {
    argParser
      ..addFlag(
        'coverage',
        abbr: 'c',
        help: 'Whether to collect code coverage.',
        defaultsTo: false,
      )
      ..addOption(
        'name',
        abbr: 'n',
        help: 'A substring of the name of the test to run.',
      );
  }

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    final targetPath = project?.rootDir.path ?? Directory.current.path;

    print(Ansi.boldText('\n🧪 Running Bloom test suite...\n'));

    final args = ['test'];
    if (argResults?['coverage'] == true) {
      args.add('--coverage');
    }
    if (argResults?['name'] != null) {
      args.addAll(['--name', argResults!['name'] as String]);
    }
    final rest = argResults?.rest ?? [];
    args.addAll(rest);

    final res = await Process.run(
      'flutter',
      args,
      workingDirectory: targetPath,
    );

    print(res.stdout);
    if (res.stderr.toString().isNotEmpty) {
      print(res.stderr);
    }

    if (res.exitCode == 0) {
      print(Ansi.success('All Bloom test suites passed!\n'));
    }
    return res.exitCode;
  }
}
