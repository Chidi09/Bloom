import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../upgrade/self_upgrade.dart';
import '../upgrade/upgrade_engine.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Upgrades the Bloom CLI and a project's Bloom packages.
///
/// Example:
/// ```
/// bloom upgrade
/// bloom upgrade --dry-run
/// bloom upgrade --skip-cli --project-dir ./my_app
/// ```
class UpgradeCommand extends Command<int> {
  final UpgradeEnvironment? _environment;

  @override
  final String name = 'upgrade';

  @override
  final String description =
      "Upgrade the Bloom CLI and this project's Bloom packages, then fix code for breaking changes.";

  UpgradeCommand({UpgradeEnvironment? environment})
      : _environment = environment {
    argParser
      ..addFlag(
        'dry-run',
        help: 'Preview planned upgrades and migrations without changing files.',
        defaultsTo: false,
      )
      ..addFlag(
        'skip-cli',
        help: 'Upgrade this project without checking the CLI.',
        defaultsTo: false,
      )
      ..addOption(
        'project-dir',
        help: 'Explicit path to the Bloom project directory.',
      );
  }

  @override
  Future<int> run() async {
    final env = _environment ?? UpgradeEnvironment.real();
    final dryRun = argResults?['dry-run'] == true;
    final skipCli = argResults?['skip-cli'] == true;
    final explicitPath = argResults?['project-dir'] as String?;
    final dir =
        explicitPath == null ? Directory.current : Directory(explicitPath);

    env.out.writeln(Ansi.boldText(dryRun
        ? 'Bloom upgrade (dry run: nothing will change)'
        : 'Bloom upgrade'));
    var cliWasChecked = false;
    if (!skipCli) {
      cliWasChecked = true;
      final cliResult = await upgradeCli(env, dryRun: dryRun);
      final project = _findProject(dir);
      if (cliResult.upgraded && project != null) {
        final args = <String>[
          'pub',
          'global',
          'run',
          'bloom_cli:bloom',
          'upgrade',
          '--skip-cli'
        ];
        if (explicitPath != null) args.addAll(['--project-dir', explicitPath]);
        return env.runInteractive('dart', args);
      }
    }

    final project = _findProject(dir);
    if (project == null) {
      if (cliWasChecked) {
        env.out.writeln('No Bloom project here — only the CLI was checked.');
        return 0;
      }
      env.out.writeln(Ansi.error('No Bloom project found in ${dir.path}.'));
      return 1;
    }

    env.out.writeln(Ansi.boldText(
        'Project ${project.projectName}'));
    final result = await ProjectUpgrader(project.rootDir, env).run(
      dryRun: dryRun,
    );
    if (!result.success) return 1;
    env.out.writeln(dryRun
        ? Ansi.dimText('Nothing was changed. Run `bloom upgrade` to apply.')
        : Ansi.success('Upgrade complete.'));
    return 0;
  }

  BloomProject? _findProject(Directory dir) {
    final project = BloomProject.find(dir);
    if (project != null) return project;
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    try {
      final root = loadYaml(pubspec.readAsStringSync());
      if (root is! Map) return null;
      for (final section in ['dependencies', 'dev_dependencies']) {
        final dependencies = root[section];
        if (dependencies is Map &&
            dependencies.keys
                .any((key) => key.toString().startsWith('bloom_'))) {
          return BloomProject.fromDirectory(dir);
        }
      }
    } catch (_) {}
    return null;
  }
}
