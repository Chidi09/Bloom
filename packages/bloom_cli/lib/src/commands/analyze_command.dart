// lib/src/commands/analyze_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class AnalyzeCommand extends Command<int> {
  @override
  final String name = 'analyze';
  @override
  final String description = 'Performs static analysis and convention checks across the project.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    final targetPath = project?.rootDir.path ?? Directory.current.path;

    print(Ansi.boldText('\n🔍 Analyzing Bloom project code quality...\n'));

    final res = await Process.run(
      'flutter',
      ['analyze', targetPath],
      workingDirectory: targetPath,
    );

    if (res.exitCode == 0) {
      print(Ansi.success('No issues found! Project adheres to Bloom quality conventions.\n'));
      return 0;
    } else {
      print(res.stdout);
      print(res.stderr);
      return res.exitCode;
    }
  }
}
