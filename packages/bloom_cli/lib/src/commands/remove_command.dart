// lib/src/commands/remove_command.dart
import 'package:args/command_runner.dart';
import 'package:yaml_edit/yaml_edit.dart';
import '../native/prebuild_engine.dart';
import '../native/plugin_catalog.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class RemoveCommand extends Command<int> {
  @override
  final String name = 'remove';
  @override
  final String description = 'Removes a Bloom plugin from configuration.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a plugin name to remove.'));
      return 1;
    }

    final pluginName = rest.first.trim().toLowerCase();
    final descriptor = BloomPluginCatalog.resolve(pluginName);
    if (descriptor == null) {
      print(Ansi.error('Unknown plugin: "$pluginName".'));
      print(Ansi.error('Supported plugins: ${BloomPluginCatalog.supportedIds.join(', ')}.'));
      return 1;
    }

    final canonicalName = descriptor.id;

    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    print(Ansi.boldText('\n➖ Removing Bloom plugin: ${Ansi.cyan}$canonicalName${Ansi.reset}\n'));

    // Update bloom.yaml
    final yamlContent = project.bloomYamlFile.readAsStringSync();
    final editor = YamlEditor(yamlContent);

    final config = project.loadBloomConfig();
    final plugins = config['plugins'] is List ? List.from(config['plugins'] as List) : [];

    plugins.removeWhere((p) => p == canonicalName || (p is Map && p.containsKey(canonicalName)));
    editor.update(['plugins'], plugins);
    project.bloomYamlFile.writeAsStringSync(editor.toString());
    print(Ansi.success('Removed plugin "$canonicalName" from bloom.yaml.'));

    // Run Prebuild synchronization
    final engine = PrebuildEngine(project);
    await engine.run();

    return 0;
  }
}
