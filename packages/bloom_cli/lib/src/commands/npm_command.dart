import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../npm/npm_manifest.dart';
import '../npm/npm_resolver.dart';
import '../npm/npm_vendor_assembler.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Parent command to manage and discover NPM web packages for Bloom JS Native projects.
///
/// Provides subcommands: `list`, `sync`, and `search`.
///
/// Example:
/// ```
/// bloom npm list
/// bloom npm sync
/// bloom npm search chart.js
/// ```
class NpmCommand extends Command<int> {
  @override
  final String name = 'npm';
  @override
  final String description = 'Manage and discover NPM web packages for your BloomJS Native project.';

  NpmCommand() {
    addSubcommand(NpmListCommand());
    addSubcommand(NpmSyncCommand());
    addSubcommand(NpmSearchCommand());
  }

  @override
  Future<int> run() async {
    printUsage();
    return 0;
  }
}

/// Subcommand that searches the live NPM registry for packages to install with `bloom add`.
///
/// Example:
/// ```
/// bloom npm search three
/// ```
class NpmSearchCommand extends Command<int> {
  @override
  final String name = 'search';
  @override
  final String description = 'Search the live NPM registry for packages to install with bloom add.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a search query. Example: bloom npm search chart'));
      return 1;
    }

    final query = rest.join(' ');
    print(Ansi.boldText('\n🔍 Searching official NPM Registry for: ${Ansi.cyan}$query${Ansi.reset}...\n'));

    final resolver = NpmResolver();
    final results = await resolver.search(query, limit: 12);

    if (results.isEmpty) {
      print(Ansi.info('No matching packages found on npmjs.org for "$query".'));
      return 0;
    }

    print('  ${'Package Name'.padRight(32)} ${'Version'.padRight(12)} Description');
    print('  ${'─' * 32} ${'─' * 12} ${'─' * 36}');

    for (final r in results) {
      final desc = r.description.length > 45 ? '${r.description.substring(0, 42)}...' : r.description;
      print('  ${r.name.padRight(32)} ${r.version.padRight(12)} $desc');
    }

    print('\n💡 Install any package above with:');
    print('   ${Ansi.green}bloom add <package-name>${Ansi.reset}\n');
    return 0;
  }
}

/// Subcommand that lists all installed NPM packages and their vendor file sizes.
///
/// Example:
/// ```
/// bloom npm list
/// ```
class NpmListCommand extends Command<int> {
  @override
  final String name = 'list';
  @override
  final String description = 'List all installed NPM packages and their vendor file sizes.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory.'));
      return 1;
    }

    final manifest = NpmManifest.read(project);
    if (manifest.isEmpty) {
      print(Ansi.info('No NPM packages installed. Add one with: bloom add <package>'));
      return 0;
    }

    print(Ansi.boldText('\n📦 Installed NPM Packages (${manifest.count})\n'));
    print('  ${'Alias'.padRight(16)} ${'NPM Package'.padRight(32)} ${'Version'.padRight(12)} Size');
    print('  ${'─' * 16} ${'─' * 32} ${'─' * 12} ────');

    for (final entry in manifest.packages) {
      final vendorFile = File(p.join(project.rootDir.path, entry.vendorFile));
      final size = vendorFile.existsSync()
          ? '${(vendorFile.lengthSync() / 1024).toStringAsFixed(1)}kB'
          : 'missing';

      print('  ${entry.alias.padRight(16)} ${entry.npmName.padRight(32)} ${entry.version.padRight(12)} $size');
    }
    print('');
    return 0;
  }
}

/// Subcommand that re-downloads missing vendor files and rebuilds the importmap in `web/index.html`.
///
/// Example:
/// ```
/// bloom npm sync
/// ```
class NpmSyncCommand extends Command<int> {
  @override
  final String name = 'sync';
  @override
  final String description = 'Re-download any missing vendor files and rebuild the web/index.html importmap.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory.'));
      return 1;
    }

    final assembler = NpmVendorAssembler(project);
    await assembler.assemble();
    return 0;
  }
}
