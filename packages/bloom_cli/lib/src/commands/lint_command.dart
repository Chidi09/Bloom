// lib/src/commands/lint_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../lint/bloom_lint.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Lints Bloom project code for framework-specific anti-patterns and performance footguns.
///
/// Example:
/// ```bash
/// bloom lint
/// bloom lint --project-dir ./my_app
/// ```
class LintCommand extends Command<int> {
  @override
  final String name = 'lint';

  @override
  final String description =
      'Lints Bloom project code for framework-specific anti-patterns and performance footguns.';

  LintCommand() {
    argParser.addOption(
      'project-dir',
      help: 'Explicit path to the Bloom project directory.',
    );
  }

  @override
  Future<int> run() async {
    final projectDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : Directory.current;

    final project = BloomProject.find(projectDir);
    if (project == null) {
      print(Ansi.error('✖ Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }

    final linter = BloomLinter(project);
    final result = linter.lint();

    if (result.hasFindings) {
      print(Ansi.error('\n✖ Bloom Lint Issues Detected! Found ${result.findings.length} issue(s):'));

      // Group findings by file
      final byFile = <String, List<LintFinding>>{};
      for (final f in result.findings) {
        byFile.putIfAbsent(f.filePath, () => []).add(f);
      }

      for (final entry in byFile.entries) {
        print('\n📄 ${entry.key}:');
        for (final f in entry.value) {
          print(Ansi.warn('  • [${f.ruleName}] line ${f.lineNumber}: ${f.message}'));
          if (f.snippet.isNotEmpty) {
            print('    Line ${f.lineNumber}: ${f.snippet.length > 100 ? '${f.snippet.substring(0, 100)}...' : f.snippet}');
          }
        }
      }
      print('');
      return 1;
    }

    print(Ansi.success('✔ Clean! 0 Bloom lint issues found across ${result.scannedFilesCount} file(s).\n'));
    return 0;
  }
}
