// lib/src/commands/registry_command.dart
import 'dart:convert';
import 'package:args/command_runner.dart';
import '../registry/package_registry.dart';
import '../utils/ansi.dart';

class RegistryCommand extends Command<int> {
  @override
  final String name = 'registry';

  @override
  final String description = 'Search, discover, and inspect verified Bloom ecosystem packages and plugins.';

  RegistryCommand() {
    addSubcommand(_RegistrySearchCommand());
    addSubcommand(_RegistryInfoCommand());
  }
}

class _RegistrySearchCommand extends Command<int> {
  @override
  final String name = 'search';

  @override
  final String description = 'Search for modules and plugins in the Bloom Package Registry.';

  _RegistrySearchCommand() {
    argParser.addFlag(
      'json',
      help: 'Output search results in JSON format.',
      defaultsTo: false,
    );
  }

  @override
  Future<int> run() async {
    final query = argResults?.rest.isNotEmpty == true ? argResults!.rest.join(' ') : '';
    final results = PackageRegistry.search(query);
    final asJson = argResults?['json'] == true;

    if (asJson) {
      final jsonList = results.map((p) => {
            'name': p.name,
            'version': p.version,
            'description': p.description,
            'tier': p.tier.name,
            'badge': p.badge,
            'publisher': p.publisher,
            'platforms': p.platformSupport,
          }).toList();
      print(const JsonEncoder.withIndent('  ').convert(jsonList));
      return 0;
    }

    print(Ansi.boldText('\n🏛️  Bloom Package Registry Search (${results.length} results):\n'));

    for (final pkg in results) {
      print('  • ${Ansi.cyan}${pkg.name}${Ansi.reset} ${Ansi.dimText('(v${pkg.version})')} ${pkg.badge}');
      print('    ${pkg.description}');
      print('    Publisher: ${pkg.publisher} | Platforms: ${pkg.platformSupport.keys.join(', ')}\n');
    }

    print(Ansi.dimText('To add a package: bloom add <package_name>\n'));
    return 0;
  }
}

class _RegistryInfoCommand extends Command<int> {
  @override
  final String name = 'info';

  @override
  final String description = 'Displays detailed verification status and compatibility matrix for a package.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('✖ Please specify a package name to inspect.'));
      return 1;
    }

    try {
      final pkg = PackageRegistry.findPackage(rest.first);
      if (pkg == null) {
        print(Ansi.error('✖ Package "${rest.first}" not found.'));
        return 1;
      }

      print(Ansi.boldText('\n📦 Package Details: ${pkg.name}\n'));
      print('  • Version:      ${pkg.version}');
      print('  • Status:       ${pkg.badge}');
      print('  • Description:  ${pkg.description}');
      print('  • Publisher:    ${pkg.publisher}');
      print('  • Platforms:    ${pkg.platformSupport}');
      print('  • CI Matrix:    ${pkg.matrixResults.length} test suite(s) recorded');
      for (final r in pkg.matrixResults) {
        final icon = r.isSuccess ? '${Ansi.green}✔ PASS${Ansi.reset}' : '${Ansi.red}✖ FAIL${Ansi.reset}';
        print('    - [${r.platform} / Flutter ${r.flutterVersion}]: $icon ${r.error ?? ''}');
      }
      print('');
      return 0;
    } catch (e) {
      print(Ansi.error('✖ $e'));
      return 1;
    }
  }
}
