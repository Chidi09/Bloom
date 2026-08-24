// lib/src/commands/font_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../assets/font_optimizer.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class FontCommand extends Command<int> {
  @override
  final String name = 'fonts';

  @override
  final String description =
      'Download, self-host, and generate optimized @font-face CSS for web fonts.';

  FontCommand() {
    addSubcommand(_OptimizeFontsCommand());
  }
}

class _OptimizeFontsCommand extends Command<int> {
  @override
  final String name = 'optimize';

  @override
  final String description =
      'Downloads Google Fonts for local self-hosting and generates fonts.g.css with CLS fallback rules.';

  _OptimizeFontsCommand() {
    argParser
      ..addMultiOption(
        'family',
        abbr: 'f',
        help: 'Google Font family name to download (can be specified multiple times).',
      )
      ..addMultiOption(
        'weight',
        abbr: 'w',
        defaultsTo: ['400', '700'],
        help: 'Font weights to download (e.g. 400, 700).',
      )
      ..addOption(
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

    final families = (argResults?['family'] as List<String>?) ?? [];
    if (families.isEmpty) {
      print(Ansi.error('✖ At least one --family must be specified.'));
      return 1;
    }

    final weights = (argResults?['weight'] as List<String>?) ?? ['400', '700'];

    final optimizer = BloomFontOptimizer(project: project);
    final result = await optimizer.optimize(
      families: families,
      weights: weights,
    );

    print(Ansi.boldText('\n🔤 Font Optimization Summary:'));
    print('  • Families processed: ${result.families.length}');
    print('  • Files written: ${result.filesWritten.length}');
    if (result.cssPath.isNotEmpty) {
      print('  • CSS bundle: ${p.relative(result.cssPath, from: project.rootDir.path)}');
    }
    for (final warning in result.warnings) {
      print(Ansi.warn('  $warning'));
    }

    if (result.filesWritten.isEmpty && result.warnings.isNotEmpty) {
      print(Ansi.error('\n✖ Font optimization failed: all requested families failed.\n'));
      return 1;
    }

    print(Ansi.success('\n✔ Font optimization complete!\n'));
    return 0;
  }
}
