// lib/src/commands/font_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../assets/font_optimizer.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Parent command to download, self-host, and optimize web fonts.
///
/// Provides the `optimize` subcommand to fetch Google Fonts at build time.
///
/// Example:
/// ```
/// bloom fonts optimize --family Inter --weight 400 --weight 700
/// ```
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
        help:
            'Google Font family name to download (can be specified multiple times).',
      )
      ..addMultiOption(
        'weight',
        abbr: 'w',
        defaultsTo: ['400', '700'],
        help: 'Font weights to download (e.g. 400, 700).',
      )
      ..addMultiOption(
        'style',
        abbr: 's',
        defaultsTo: ['normal'],
        help: 'Font styles to download (normal, italic).',
      )
      ..addMultiOption(
        'face',
        splitCommas: false,
        help:
            'Font face manifest spec in "Family:weights:styles" format (can be specified multiple times).',
      )
      ..addFlag(
        'require-all-faces',
        defaultsTo: false,
        help:
            'Require all requested family, weight, and style combinations to be downloaded successfully.',
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
      print(Ansi.error(
          '✖ Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }

    final faces = (argResults?['face'] as List<String>?) ?? [];
    final requireAllFaces =
        (argResults?['require-all-faces'] as bool?) ?? false;

    final optimizer = BloomFontOptimizer(project: project);
    final BloomFontOptimizeResult result;
    try {
      if (faces.isNotEmpty) {
        if (argResults?.wasParsed('family') == true ||
            argResults?.wasParsed('weight') == true ||
            argResults?.wasParsed('style') == true) {
          throw ArgumentError(
            'Cannot mix --face with explicit --family, --weight, or --style options.',
          );
        }

        final requests = faces.map(FontFaceRequest.parse).toList();
        result = await optimizer.optimizeManifest(
          requests,
          requireAllRequestedFaces: requireAllFaces,
        );
      } else {
        final families = (argResults?['family'] as List<String>?) ?? [];
        if (families.isEmpty) {
          print(Ansi.error('✖ At least one --family must be specified.'));
          return 1;
        }

        final weights =
            (argResults?['weight'] as List<String>?) ?? ['400', '700'];
        final styles = (argResults?['style'] as List<String>?) ?? ['normal'];

        result = await optimizer.optimize(
          families: families,
          weights: weights,
          styles: styles,
          requireAllRequestedFaces: requireAllFaces,
        );
      }
    } on ArgumentError catch (e) {
      print(Ansi.error('✖ ${e.message}'));
      return 1;
    }

    print(Ansi.boldText('\n🔤 Font Optimization Summary:'));
    print('  • Families processed: ${result.families.length}');
    print('  • Files written: ${result.filesWritten.length}');
    if (result.cssPath.isNotEmpty) {
      print(
          '  • CSS bundle: ${p.relative(result.cssPath, from: project.rootDir.path)}');
    }
    for (final warning in result.warnings) {
      print(Ansi.warn('  $warning'));
    }

    if ((result.filesWritten.isEmpty ||
            (requireAllFaces && result.cssPath.isEmpty)) &&
        result.warnings.isNotEmpty) {
      print(Ansi.error(
          '\n✖ Font optimization failed: requested faces could not be fully resolved.\n'));
      return 1;
    }

    print(Ansi.success('\n✔ Font optimization complete!\n'));
    return 0;
  }
}
