// lib/src/upgrade/upgrade_engine.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

class UpgradeDiff {
  final String filePath;
  final String description;
  final String originalContent;
  final String newContent;

  UpgradeDiff({
    required this.filePath,
    required this.description,
    required this.originalContent,
    required this.newContent,
  });

  bool get isModified => originalContent != newContent;
}

class UpgradePlan {
  final String currentVersion;
  final String targetVersion;
  final List<UpgradeDiff> diffs;

  UpgradePlan({
    required this.currentVersion,
    required this.targetVersion,
    required this.diffs,
  });

  bool get hasChanges => diffs.any((d) => d.isModified);
  List<UpgradeDiff> get modifiedDiffs => diffs.where((d) => d.isModified).toList();
}

/// Automated framework upgrade and AST code migration engine.
class UpgradeEngine {
  final BloomProject project;

  UpgradeEngine(this.project);

  /// Computes the complete upgrade plan and code migrations without altering files.
  UpgradePlan planUpgrade({String targetVersion = '2.0.0'}) {
    final diffs = <UpgradeDiff>[];

    final bloomConfig = project.loadBloomConfig();
    final currentVersion = bloomConfig['version']?.toString() ?? '1.0.0';

    // 1. Migrate pubspec.yaml dependencies
    final pubspecFile = File(p.join(project.rootDir.path, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      final origPubspec = pubspecFile.readAsStringSync();
      var newPubspec = origPubspec;

      // Update bloom_framework dependency constraint
      newPubspec = newPubspec.replaceAllMapped(
        RegExp(r'(bloom_framework:\s*[\^~]?)[\d\.]+'),
        (m) => '${m.group(1)}$targetVersion',
      );
      // Update bloom version field in pubspec
      newPubspec = newPubspec.replaceAllMapped(
        RegExp(r'(version:\s*)[\d\.]+'),
        (m) => '${m.group(1)}$targetVersion',
      );

      diffs.add(UpgradeDiff(
        filePath: p.relative(pubspecFile.path, from: project.rootDir.path),
        description: 'Update bloom_framework dependency to ^$targetVersion in pubspec.yaml',
        originalContent: origPubspec,
        newContent: newPubspec,
      ));
    }

    // 2. Migrate bloom.yaml configuration
    final bloomYamlFile = File(p.join(project.rootDir.path, 'bloom.yaml'));
    if (bloomYamlFile.existsSync()) {
      final origYaml = bloomYamlFile.readAsStringSync();
      var newYaml = origYaml;

      // Bump version in bloom.yaml
      newYaml = newYaml.replaceAllMapped(
        RegExp(r'(version:\s*)[\d\.]+'),
        (m) => '${m.group(1)}$targetVersion',
      );
      // Bump schema version if present
      newYaml = newYaml.replaceAllMapped(
        RegExp(r'(schema:\s*)\d+'),
        (m) => '${m.group(1)}2',
      );

      diffs.add(UpgradeDiff(
        filePath: p.relative(bloomYamlFile.path, from: project.rootDir.path),
        description: 'Upgrade bloom.yaml schema and target version to $targetVersion',
        originalContent: origYaml,
        newContent: newYaml,
      ));
    }

    // 3. AST code refactorings across lib/
    final libDir = Directory(p.join(project.rootDir.path, 'lib'));
    if (libDir.existsSync()) {
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)); // Deterministic order

      for (final file in dartFiles) {
        final origCode = file.readAsStringSync();
        var migratedCode = origCode;

        // Rule A: BloomAuth.currentUser -> Bloom.auth.currentUser (or BloomAuth.instance.currentUser)
        migratedCode = migratedCode.replaceAll(
          'BloomAuth.currentUser',
          'Bloom.auth.currentUser',
        );

        // Rule B: BloomRouter.pushNamed(...) -> BloomRouter.go(...)
        migratedCode = migratedCode.replaceAll(
          'BloomRouter.pushNamed(',
          'BloomRouter.go(',
        );

        // Rule C: Legacy Route Guard inheritance
        migratedCode = migratedCode.replaceAllMapped(
          RegExp(r'class\s+([a-zA-Z0-9_]+)\s+extends\s+RouteGuard'),
          (m) => 'class ${m.group(1)} implements BloomGuard',
        );

        if (origCode != migratedCode) {
          diffs.add(UpgradeDiff(
            filePath: p.relative(file.path, from: project.rootDir.path),
            description: 'Refactor deprecated API calls and migrate AST signatures',
            originalContent: origCode,
            newContent: migratedCode,
          ));
        }
      }
    }

    return UpgradePlan(
      currentVersion: currentVersion,
      targetVersion: targetVersion,
      diffs: diffs,
    );
  }

  /// Executes the upgrade plan, applying file changes unless dryRun is true.
  Future<UpgradePlan> applyUpgrade({
    String targetVersion = '2.0.0',
    bool dryRun = false,
  }) async {
    final plan = planUpgrade(targetVersion: targetVersion);

    print(Ansi.boldText('\n🔄 Bloom Automated Framework Upgrade (${plan.currentVersion} ➔ ${plan.targetVersion})'));

    if (dryRun) {
      print(Ansi.warn('  [DRY-RUN MODE] Previewing planned migrations without modifying disk:\n'));
    }

    if (!plan.hasChanges) {
      print(Ansi.success('✔ Project is already fully up-to-date with version $targetVersion.\n'));
      return plan;
    }

    for (final diff in plan.modifiedDiffs) {
      print('  • ${Ansi.cyan}${diff.filePath}${Ansi.reset}: ${diff.description}');
      if (!dryRun) {
        final targetFile = File(p.join(project.rootDir.path, diff.filePath));
        targetFile.writeAsStringSync(diff.newContent);
      }
    }

    if (dryRun) {
      print(Ansi.dimText('\nTo apply these migrations permanently, run: bloom upgrade\n'));
    } else {
      print(Ansi.success('\n✔ Successfully migrated ${plan.modifiedDiffs.length} file(s) to Bloom $targetVersion!\n'));
    }

    return plan;
  }
}
