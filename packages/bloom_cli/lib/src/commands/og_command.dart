// lib/src/commands/og_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../assets/og_image_generator.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class OgCommand extends Command<int> {
  @override
  final String name = 'og';

  @override
  final String description =
      'Open Graph and social share image generation utilities.';

  OgCommand() {
    addSubcommand(_GenerateOgCommand());
  }
}

class _GenerateOgCommand extends Command<int> {
  @override
  final String name = 'generate';

  @override
  final String description =
      'Generates a static Open Graph social card PNG image.';

  _GenerateOgCommand() {
    argParser
      ..addOption(
        'title',
        help: 'Title text for the social card.',
        mandatory: true,
      )
      ..addOption(
        'subtitle',
        help: 'Subtitle or description text below the title.',
      )
      ..addOption(
        'eyebrow',
        help: 'Eyebrow or category label above the title.',
      )
      ..addOption(
        'theme',
        allowed: ['dark', 'light'],
        defaultsTo: 'dark',
        help: 'Color theme for the card (dark or light).',
      )
      ..addOption(
        'out',
        defaultsTo: 'lib/generated/og/social-card.png',
        help: 'Output file path for the generated PNG.',
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
      print(Ansi.error('Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }

    final title = argResults!['title'] as String;
    final subtitle = argResults?['subtitle'] as String?;
    final eyebrow = argResults?['eyebrow'] as String?;
    final themeStr = argResults?['theme'] as String? ?? 'dark';
    final theme = themeStr == 'light' ? BloomOgTheme.light : BloomOgTheme.dark;

    final outOption = argResults?['out'] as String? ?? 'lib/generated/og/social-card.png';
    final outFile = p.isAbsolute(outOption)
        ? File(outOption)
        : File(p.join(project.rootDir.path, outOption));

    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }

    final generator = BloomOgImageGenerator();
    final bytes = generator.generate(
      title: title,
      subtitle: subtitle,
      eyebrow: eyebrow,
      theme: theme,
    );

    outFile.writeAsBytesSync(bytes);

    final relPath = p.relative(outFile.path, from: project.rootDir.path);
    print(Ansi.success(
        'Generated Open Graph image: $relPath (${kOgImageWidth}x${kOgImageHeight}, ${(bytes.length / 1024).toStringAsFixed(1)} KB)'));

    return 0;
  }
}
