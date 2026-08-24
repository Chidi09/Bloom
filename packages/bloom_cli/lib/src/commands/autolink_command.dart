// lib/src/commands/autolink_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../native/autolink_engine.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Command that discovers native Bloom modules and links Android and iOS platform targets.
///
/// Automatically generates platform bridge bindings and `bloom.lock` manifest
/// without requiring manual modifications to Gradle or Xcode project files.
///
/// Example:
/// ```
/// bloom autolink
/// bloom autolink --project-dir ./my_app
/// ```
class AutolinkCommand extends Command<int> {
  @override
  final String name = 'autolink';
  @override
  final String description = 'Discovers native Bloom modules and links Android & iOS build targets without manual edits.';

  AutolinkCommand() {
    argParser.addOption(
      'project-dir',
      help: 'Explicit path to the Bloom project directory.',
    );
  }

  @override
  Future<int> run() async {
    final explicitDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : null;

    final project = BloomProject.find(explicitDir);
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    print(Ansi.boldText('\n🔗 Running Bloom Autolinking Engine for "${project.projectName}"...\n'));
    final engine = AutolinkEngine(project);
    final modules = engine.discoverModules();

    print('Discovered ${modules.length} native module(s):');
    for (final m in modules) {
      final plat = [
        if (m.hasAndroid) 'Android',
        if (m.hasIos) 'iOS',
      ].join(', ');
      print('  • ${Ansi.boldText(m.name)} (v${m.version}) [Source: ${m.sourceType}] ➔ $plat');
    }

    final success = await engine.runAutolink();
    if (success) {
      print('\n${Ansi.success('Autolinking completed successfully! Generated bloom.lock and platform bindings.')}\n');
      return 0;
    } else {
      return 1;
    }
  }
}
