import 'package:args/command_runner.dart';
import 'package:yaml_edit/yaml_edit.dart';
import '../native/prebuild_engine.dart';
import '../native/plugin_catalog.dart';
import '../npm/npm_resolver.dart';
import '../npm/dts_codegen.dart';
import '../npm/importmap_manager.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Command that adds and configures Bloom plugins or NPM web packages.
///
/// Resolves native mobile plugins from the catalog or downloads NPM ESM packages,
/// generates Dart interop bindings, and updates project configuration.
///
/// Example:
/// ```
/// bloom add camera
/// bloom add npm:three
/// bloom add npm:gsap@3.12.5
/// ```
class AddCommand extends Command<int> {
  @override
  final String name = 'add';
  @override
  final String description = 'Adds and configures a Bloom plugin or native NPM web package.\n'
      'Usage:\n'
      '  bloom add camera             # Native mobile plugin\n'
      '  bloom add motion             # Curated web plugin alias (@formkit/auto-animate)\n'
      '  bloom add npm:three          # Raw NPM package\n'
      '  bloom add npm:gsap@3.12.5    # Pinned NPM version';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a plugin or package name (e.g. "motion", "camera", "npm:three").'));
      return 1;
    }

    final input = rest.first.trim();
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory tree.'));
      return 1;
    }

    final config = project.loadBloomConfig();
    final isWebProject = config['target'] == 'web_dom' ||
        config['target'] == 'web' ||
        (config['platforms'] is Map && (config['platforms'] as Map).containsKey('web'));

    final isNpmRequest = input.startsWith('npm:') || isWebProject;

    if (isNpmRequest || isWebProject) {
      return await _addNpmPackage(project, input, config);
    } else {
      return await _addNativePlugin(project, input, config);
    }
  }

  /// Adds a native mobile plugin via prebuild engine.
  Future<int> _addNativePlugin(BloomProject project, String input, Map config) async {
    final pluginName = input.toLowerCase();
    final descriptor = BloomPluginCatalog.resolve(pluginName);
    if (descriptor == null) {
      print(Ansi.error('Unknown native plugin: "$pluginName".'));
      print(Ansi.error('Supported native plugins: ${BloomPluginCatalog.supportedIds.join(', ')}.'));
      print(Ansi.info('To add an NPM web package, use: bloom add npm:$input'));
      return 1;
    }

    final canonicalName = descriptor.id;
    print(Ansi.boldText('\n➕ Adding Bloom native plugin: ${Ansi.cyan}$canonicalName${Ansi.reset}\n'));

    final yamlContent = project.bloomYamlFile.readAsStringSync();
    final editor = YamlEditor(yamlContent);

    final plugins = config['plugins'] is List ? List.from(config['plugins'] as List) : [];

    bool alreadyPresent = false;
    for (final p in plugins) {
      if (p == canonicalName || (p is Map && p.containsKey(canonicalName))) {
        alreadyPresent = true;
        break;
      }
    }

    if (!alreadyPresent) {
      plugins.add(canonicalName);
      editor.update(['plugins'], plugins);
      project.bloomYamlFile.writeAsStringSync(editor.toString());
      print(Ansi.success('Updated bloom.yaml with plugin "$canonicalName".'));
    } else {
      print(Ansi.info('Plugin "$canonicalName" already present in bloom.yaml.'));
    }

    final engine = PrebuildEngine(project);
    await engine.run();
    return 0;
  }

  /// Adds an NPM package dynamically from the official live NPM registry,
  /// downloads vendor ESM bundle, generates Dart @JS() interop, and updates importmap.
  Future<int> _addNpmPackage(BloomProject project, String input, Map config) async {
    final String packageSpec = input.startsWith('npm:') ? input.substring(4) : input;

    final String pkgName;
    final String pkgVersion;

    if (packageSpec.startsWith('@')) {
      final subParts = packageSpec.substring(1).split('@');
      pkgName = '@${subParts[0]}';
      pkgVersion = subParts.length > 1 ? subParts[1] : 'latest';
    } else {
      final parts = packageSpec.split('@');
      pkgName = parts[0];
      pkgVersion = parts.length > 1 ? parts[1] : 'latest';
    }

    print(Ansi.boldText('\n📦 Resolving NPM package: ${Ansi.cyan}$pkgName${Ansi.reset} ($pkgVersion)...\n'));

    final resolver = NpmResolver();
    final meta = await resolver.fetchPackageMetadata(pkgName);
    if (meta != null && meta.description.isNotEmpty) {
      print(Ansi.info('ℹ ${meta.description}'));
    }

    final resolvedVersion = meta?.version ?? await resolver.resolveVersion(pkgName, pkgVersion);
    final vendorFileName = _toVendorFilename(pkgName);
    final vendorPath = 'web/vendor/$vendorFileName';

    print(Ansi.info('⬇️  Downloading ESM bundle ($resolvedVersion) into $vendorPath...'));
    final esmUrl = await resolver.downloadVendorBundle(
      pkgName,
      resolvedVersion,
      project.rootDir.path,
      vendorPath,
    );
    print(Ansi.success('✓ ESM bundle ready: $vendorPath'));

    final dartBindingPath = _toDartBindingPath(pkgName);
    print(Ansi.info('⚡ Generating Dart 3.5+ @JS() extension types into $dartBindingPath...'));
    final codegen = DtsCodegen();
    await codegen.generate(
      packageName: pkgName,
      version: resolvedVersion,
      outputPath: '${project.rootDir.path}/$dartBindingPath',
    );
    print(Ansi.success('✓ Dart interop binding generated: $dartBindingPath'));

    final importmapManager = ImportMapManager(project.rootDir.path);
    await importmapManager.addEntry(
      packageName: pkgName,
      vendorPath: vendorPath,
    );
    print(Ansi.success('✓ Updated <script type="importmap"> in web/index.html'));

    _updateBloomYaml(project, pkgName, resolvedVersion, esmUrl, vendorPath, dartBindingPath);
    print(Ansi.success('✓ Recorded in bloom.yaml'));

    print(Ansi.boldText('\n🚀 Successfully installed $pkgName! Import in Dart:'));
    print('   import \'$dartBindingPath\';\n');
    return 0;
  }

  String _toVendorFilename(String pkg) =>
      '${pkg.replaceAll('@', '').replaceAll('/', '-').replaceAll(' ', '-').replaceAll('.', '-')}.min.js';

  String _toDartBindingPath(String pkg) {
    final clean = pkg.replaceAll('@', '').replaceAll('/', '_').replaceAll('-', '_').replaceAll('.', '_');
    return 'lib/src/plugins/$clean.dart';
  }

  void _updateBloomYaml(BloomProject project, String pkg, String version,
      String esmUrl, String vendorPath, String dartBinding) {
    try {
      final yamlContent = project.bloomYamlFile.readAsStringSync();
      final editor = YamlEditor(yamlContent);
      final config = project.loadBloomConfig();
      final npmPackages = config['npm_packages'] is Map
          ? Map<String, dynamic>.from(config['npm_packages'] as Map)
          : <String, dynamic>{};

      npmPackages[pkg] = {
        'version': version,
        'esm_url': esmUrl,
        'vendor_file': vendorPath,
        'dart_binding': dartBinding,
      };

      editor.update(['npm_packages'], npmPackages);
      project.bloomYamlFile.writeAsStringSync(editor.toString());
    } catch (_) {
      // Non-fatal if yaml editor fails
    }
  }
}
