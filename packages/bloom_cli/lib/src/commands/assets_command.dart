// lib/src/commands/assets_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../assets/asset_analyzer.dart';
import '../assets/asset_generator.dart';
import '../assets/asset_optimizer.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class AssetsCommand extends Command<int> {
  @override
  final String name = 'assets';

  @override
  final String description =
      'Asset optimization, dead asset analysis, and type-safe asset code generation.';

  AssetsCommand() {
    addSubcommand(_OptimizeAssetsCommand());
    addSubcommand(_AnalyzeAssetsCommand());
    addSubcommand(_GenerateAssetsCommand());
  }
}

class _OptimizeAssetsCommand extends Command<int> {
  @override
  final String name = 'optimize';

  @override
  final String description =
      'Compresses PNG and JPEG image assets and generates WebP variants.';

  _OptimizeAssetsCommand() {
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

    final optimizer = AssetOptimizer(project: project);
    await optimizer.optimize();
    return 0;
  }
}

class _AnalyzeAssetsCommand extends Command<int> {
  @override
  final String name = 'analyze';

  @override
  final String description =
      'Scans Dart code and assets to identify unreferenced/orphaned files.';

  _AnalyzeAssetsCommand() {
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

    final analyzer = AssetAnalyzer(project: project);
    analyzer.analyze();
    return 0;
  }
}

class _GenerateAssetsCommand extends Command<int> {
  @override
  final String name = 'generate';

  @override
  final String description =
      'Generates strongly typed asset accessor classes in lib/generated/assets.g.dart.';

  _GenerateAssetsCommand() {
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

    final generator = AssetGenerator(project: project);
    generator.generate();
    return 0;
  }
}
