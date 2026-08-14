// lib/src/commands/add_command.dart
import 'package:args/command_runner.dart';
import 'package:yaml_edit/yaml_edit.dart';
import '../native/prebuild_engine.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class AddCommand extends Command<int> {
  @override
  final String name = 'add';
  @override
  final String description = 'Adds and configures a Bloom plugin.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a plugin name (e.g. "camera", "notifications", "secure_storage").'));
      return 1;
    }

    final pluginName = rest.first.trim().toLowerCase();
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    print(Ansi.boldText('\n➕ Adding Bloom plugin: ${Ansi.cyan}$pluginName${Ansi.reset}\n'));

    // Update bloom.yaml
    final yamlContent = project.bloomYamlFile.readAsStringSync();
    final editor = YamlEditor(yamlContent);

    final config = project.loadBloomConfig();
    final plugins = config['plugins'] is List ? List.from(config['plugins'] as List) : [];

    bool alreadyPresent = false;
    for (final p in plugins) {
      if (p == pluginName || (p is Map && p.containsKey(pluginName))) {
        alreadyPresent = true;
        break;
      }
    }

    if (!alreadyPresent) {
      plugins.add(pluginName);
      editor.update(['plugins'], plugins);
      project.bloomYamlFile.writeAsStringSync(editor.toString());
      print(Ansi.success('Updated bloom.yaml with plugin "$pluginName".'));
    } else {
      print(Ansi.info('Plugin "$pluginName" already present in bloom.yaml.'));
    }

    // Run Prebuild synchronization
    final engine = PrebuildEngine(project);
    await engine.run();

    return 0;
  }
}
