// lib/src/commands/upgrade_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../upgrade/upgrade_engine.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Command that upgrades Bloom framework dependencies and schemas with automated AST migrations.
///
/// Example:
/// ```
/// bloom upgrade
/// bloom upgrade --target 2.0.0 --dry-run
/// bloom upgrade --project-dir ./my_app
/// ```
class UpgradeCommand extends Command<int> {
  @override
  final String name = 'upgrade';

  @override
  final String description =
      'Upgrades Bloom framework dependencies, schemas, and applies automated AST code migrations.';

  UpgradeCommand() {
    argParser.addFlag(
      'dry-run',
      help: 'Preview planned migrations and diffs without altering files.',
      defaultsTo: false,
    );
    argParser.addOption(
      'target',
      help: 'Target framework version to upgrade to.',
      defaultsTo: '2.0.0',
    );
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

    final isDryRun = argResults?['dry-run'] == true;
    final targetVersion = argResults?['target'] as String? ?? '2.0.0';

    final engine = UpgradeEngine(project);
    await engine.applyUpgrade(
      targetVersion: targetVersion,
      dryRun: isDryRun,
    );

    return 0;
  }
}
