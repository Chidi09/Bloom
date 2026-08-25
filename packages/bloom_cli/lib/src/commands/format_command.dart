// lib/src/commands/format_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../format/bloom_formatter.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Formats a Bloom project's Dart sources using `BloomFormatter`:
/// - Runs official `dart_style` tall-style formatting.
/// - Performs an AST pre-pass to wrap long named-argument string literals (e.g. `className: '...'`).
/// - Formats embedded raw CSS strings (`const fooCss = r'''...''';` and `Style(r'''...''')`).
/// - Automatically skips generated bindings in `lib/src/plugins/`, `.dart_tool/`, and `build/`.
class FormatCommand extends Command<int> {
  @override
  final String name = 'format';

  @override
  final String description =
      "Formats a Bloom project's Dart source (lib/, test/, bin/), skipping generated bindings.";

  FormatCommand() {
    argParser
      ..addOption(
        'project-dir',
        help: 'Explicit path to the Bloom project directory.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help: 'Report files that would change without writing them (CI mode).',
      );
  }

  static const List<String> _excludedDirs = [
    'lib/src/plugins', // bloom add npm:<pkg> generated @JS() bindings
    '.dart_tool',
    'build',
  ];

  @override
  Future<int> run() async {
    final projectDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : Directory.current;

    final project = BloomProject.find(projectDir);
    if (project == null) {
      print(Ansi.error('Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }

    final root = project.rootDir.path;
    final targets = <String>[];
    for (final dirName in ['lib', 'test', 'bin']) {
      final dir = Directory(p.join(root, dirName));
      if (dir.existsSync()) targets.add(dir.path);
    }

    if (targets.isEmpty) {
      print(Ansi.warn('No lib/, test/, or bin/ directories found to format.'));
      return 0;
    }

    final checkMode = argResults?['check'] as bool? ?? false;
    final excluded = _excludedDirs.map((d) => p.join(root, d)).toList();

    final filesToFormat = <String>[];
    for (final target in targets) {
      final dir = Directory(target);
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (excluded.any((ex) => p.isWithin(ex, entity.path) || entity.path == ex)) continue;
        filesToFormat.add(entity.path);
      }
    }

    if (filesToFormat.isEmpty) {
      print(Ansi.info('No formattable .dart files found.'));
      return 0;
    }

    final formatter = BloomFormatter();
    final changedFiles = <String>[];
    var reformattedCount = 0;
    var unchangedCount = 0;
    var errorCount = 0;

    for (final filePath in filesToFormat) {
      final file = File(filePath);
      final content = file.readAsStringSync();
      final result = formatter.format(content);

      if (result.hasError) {
        final rel = p.relative(filePath, from: root).replaceAll('\\', '/');
        print(Ansi.error('Error formatting $rel: ${result.errorMessage}'));
        errorCount++;
        continue;
      }

      final rel = p.relative(filePath, from: root).replaceAll('\\', '/');
      if (result.changed) {
        changedFiles.add(rel);
        if (!checkMode) {
          file.writeAsStringSync(result.formatted);
          reformattedCount++;
        }
      } else {
        unchangedCount++;
      }
    }

    if (checkMode) {
      if (changedFiles.isNotEmpty) {
        for (final file in changedFiles) {
          print('Would reformat: $file');
        }
        print(Ansi.warn('Some files are not formatted. Run `bloom format` to fix.'));
        return 1;
      }
      print(Ansi.success('All files formatted correctly.'));
      return 0;
    }

    if (errorCount > 0) {
      return 1;
    }

    print(Ansi.success('$reformattedCount file(s) reformatted, $unchangedCount unchanged.'));
    return 0;
  }
}
