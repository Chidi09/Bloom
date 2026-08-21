import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';
import '../native/prebuild_engine.dart';
import '../native/plugin_catalog.dart';
import '../npm/npm_manifest.dart';
import '../npm/importmap_manager.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class RemoveCommand extends Command<int> {
  @override
  final String name = 'remove';
  @override
  final String description = 'Removes a Bloom native plugin or NPM web package.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a plugin or package name to remove (e.g. "camera", "gsap").'));
      return 1;
    }

    final input = rest.first.trim().toLowerCase();
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory tree.'));
      return 1;
    }

    final config = project.loadBloomConfig();
    final isNpmPackage = (config['npm_packages'] is Map &&
        (config['npm_packages'] as Map).containsKey(input));

    if (isNpmPackage) {
      return await _removeNpmPackage(project, input, config);
    } else {
      return await _removeNativePlugin(project, input, config);
    }
  }

  /// Removes an NPM package, deletes its vendor bundle and Dart binding, and updates importmap.
  Future<int> _removeNpmPackage(BloomProject project, String alias, Map config) async {
    final npmPkgs = config['npm_packages'] as Map;
    final entry = NpmManifestEntry.fromYaml(alias, npmPkgs[alias] as Map);

    print(Ansi.boldText('\n➖ Removing NPM package: ${Ansi.cyan}$alias${Ansi.reset}\n'));

    // 1. Delete vendor file
    final vendorFile = File(p.join(project.rootDir.path, entry.vendorFile));
    if (vendorFile.existsSync()) {
      vendorFile.deleteSync();
      print(Ansi.success('  Deleted: ${entry.vendorFile}'));
    }

    // 2. Delete Dart binding
    final dartFile = File(p.join(project.rootDir.path, entry.dartBinding));
    if (dartFile.existsSync()) {
      dartFile.deleteSync();
      print(Ansi.success('  Deleted: ${entry.dartBinding}'));
    }

    // 3. Remove from importmap
    final importmapManager = ImportMapManager(project.rootDir.path);
    await importmapManager.removeEntry(packageName: entry.npmName);
    print(Ansi.success('  Removed from web/index.html importmap'));

    // 4. Remove from bloom.yaml
    try {
      final yamlContent = project.bloomYamlFile.readAsStringSync();
      final editor = YamlEditor(yamlContent);
      final updatedPkgs = Map<String, dynamic>.from(npmPkgs)..remove(alias);
      if (updatedPkgs.isEmpty) {
        editor.remove(['npm_packages']);
      } else {
        editor.update(['npm_packages'], updatedPkgs);
      }
      project.bloomYamlFile.writeAsStringSync(editor.toString());
      print(Ansi.success('  Removed from bloom.yaml\n'));
    } catch (_) {}

    return 0;
  }

  /// Removes a native mobile plugin via prebuild engine.
  Future<int> _removeNativePlugin(BloomProject project, String input, Map config) async {
    final descriptor = BloomPluginCatalog.resolve(input);
    if (descriptor == null) {
      print(Ansi.error('Unknown plugin or NPM package: "$input".'));
      print(Ansi.error('Supported native plugins: ${BloomPluginCatalog.supportedIds.join(', ')}.'));
      return 1;
    }

    final canonicalName = descriptor.id;
    print(Ansi.boldText('\n➖ Removing Bloom native plugin: ${Ansi.cyan}$canonicalName${Ansi.reset}\n'));

    final yamlContent = project.bloomYamlFile.readAsStringSync();
    final editor = YamlEditor(yamlContent);

    final plugins = config['plugins'] is List ? List.from(config['plugins'] as List) : [];
    plugins.removeWhere((p) => p == canonicalName || (p is Map && p.containsKey(canonicalName)));
    editor.update(['plugins'], plugins);
    project.bloomYamlFile.writeAsStringSync(editor.toString());
    print(Ansi.success('Removed plugin "$canonicalName" from bloom.yaml.'));

    final engine = PrebuildEngine(project);
    await engine.run();
    return 0;
  }
}
