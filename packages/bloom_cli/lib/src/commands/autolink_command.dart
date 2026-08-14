// lib/src/commands/autolink_command.dart
import 'package:args/command_runner.dart';
import '../native/autolink_engine.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class AutolinkCommand extends Command<int> {
  @override
  final String name = 'autolink';
  @override
  final String description = 'Discovers native Bloom modules and links Android & iOS build targets without manual edits.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
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
