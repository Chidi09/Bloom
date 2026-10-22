import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import '../utils/ansi.dart';
import 'agents_guide.dart';
import 'analyzer_issues.dart';
import 'migrations.dart';
import 'update_notifier.dart';

/// Runs a captured subprocess for upgrade operations.
typedef UpgradeProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// Fetches the latest version for a package name.
typedef UpgradeLatestVersionFetcher = Future<String?> Function(String package);

/// Injectable processes, network access, and output used by `bloom upgrade`.
///
/// Tests can provide fake functions and a [StringBuffer] without launching
/// tools or reaching the network.
class UpgradeEnvironment {
  final UpgradeProcessRunner runProcess;
  final Future<int> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) runInteractive;
  final UpgradeLatestVersionFetcher latestVersion;
  final StringSink out;

  const UpgradeEnvironment({
    required this.runProcess,
    required this.runInteractive,
    required this.latestVersion,
    required this.out,
  });

  /// Creates an environment backed by the local Dart process and pub.dev.
  factory UpgradeEnvironment.real() => UpgradeEnvironment(
        runProcess: Process.run,
        runInteractive: (executable, arguments, {workingDirectory}) async {
          final process = await Process.start(
            executable,
            arguments,
            workingDirectory: workingDirectory,
            mode: ProcessStartMode.inheritStdio,
          );
          return process.exitCode;
        },
        latestVersion: fetchLatestPubVersion,
        out: stdout,
      );
}

/// Result of upgrading a project's Bloom package dependencies.
class ProjectUpgradeResult {
  final bool success;
  final bool hasNewerVersion;

  const ProjectUpgradeResult({
    required this.success,
    required this.hasNewerVersion,
  });
}

/// Upgrades hosted Bloom dependencies and applies known analyzer fixes.
class ProjectUpgrader {
  final Directory rootDir;
  final UpgradeEnvironment env;

  ProjectUpgrader(this.rootDir, this.env);

  /// Resolves and upgrades Bloom packages in [rootDir].
  Future<ProjectUpgradeResult> run({required bool dryRun}) async {
    final pubspecFile = File(p.join(rootDir.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      env.out.writeln(Ansi.error('pubspec.yaml not found.'));
      return const ProjectUpgradeResult(success: false, hasNewerVersion: false);
    }
    final pubspec = _asMap(loadYaml(pubspecFile.readAsStringSync()));
    final dependencies = <String, dynamic>{
      ..._asMap(pubspec['dependencies']),
      ..._asMap(pubspec['dev_dependencies']),
    };
    final bloomPackages = <String>[];
    final skipped = <String>[];
    for (final entry in dependencies.entries) {
      if (!entry.key.startsWith('bloom_')) continue;
      final value = entry.value;
      if (value is String ||
          value == null ||
          (value is Map &&
              (value.containsKey('hosted') || value.containsKey('version')))) {
        bloomPackages.add(entry.key);
      } else if (value is Map &&
          (value.containsKey('path') ||
              value.containsKey('git') ||
              value.containsKey('sdk'))) {
        skipped.add(entry.key);
      }
    }
    bloomPackages.sort();
    for (final name in skipped) {
      env.out.writeln('  $name  skipped (path/git dependency)');
    }

    final tool = _usesFlutter(dependencies) ? 'flutter' : 'dart';
    final oldVersions = _readLockVersions();
    if (bloomPackages.isEmpty) {
      env.out.writeln('No hosted Bloom packages to upgrade.');
      await _refreshGuide(pubspec, dryRun: dryRun);
      return const ProjectUpgradeResult(
        success: true,
        hasNewerVersion: false,
      );
    }

    if (dryRun) {
      final result = await env.runProcess(
        tool,
        ['pub', 'outdated', '--json'],
        workingDirectory: rootDir.path,
      );
      final outdated = _parseOutdated(result.stdout.toString());
      var hasNewer = false;
      for (final name in bloomPackages) {
        final current = outdated[name]?['current'] ?? oldVersions[name];
        final resolvable = outdated[name]?['resolvable'];
        final latest = outdated[name]?['latest'];
        final target = resolvable ?? latest;
        final version = target ?? 'unknown';
        final same = current != null && current == version;
        hasNewer = hasNewer || _isNewer(current, version);
        env.out.writeln(same
            ? '  $name  $current (already latest)'
            : '  $name  ${current ?? 'unknown'} → $version');
        if (current != null && version != 'unknown') {
          _printPendingMigrations(name, current, version);
        }
      }
      await _refreshGuide(pubspec, dryRun: true);
      return ProjectUpgradeResult(success: true, hasNewerVersion: hasNewer);
    }

    final result = await env.runProcess(
      tool,
      ['pub', 'upgrade', '--major-versions', ...bloomPackages],
      workingDirectory: rootDir.path,
    );
    if (result.exitCode != 0) {
      env.out.write(result.stdout.toString());
      env.out.write(result.stderr.toString());
      env.out.writeln('Nothing was changed in your code.');
      return const ProjectUpgradeResult(success: false, hasNewerVersion: false);
    }

    final newVersions = _readLockVersions();
    for (final name in bloomPackages) {
      final oldVersion = oldVersions[name];
      final newVersion = newVersions[name];
      env.out.writeln(oldVersion != null && oldVersion == newVersion
          ? '  $name  $oldVersion (already latest)'
          : '  $name  ${oldVersion ?? 'unknown'} → ${newVersion ?? 'unknown'}');
    }

    final selected = <BloomMigration>[];
    for (final migration in bloomMigrations) {
      if (!bloomPackages.contains(migration.package)) continue;
      final oldVersion = _parseVersion(oldVersions[migration.package]);
      final newVersion = _parseVersion(newVersions[migration.package]);
      if (newVersion != null &&
          (oldVersion == null || migration.version > oldVersion) &&
          migration.version <= newVersion) {
        selected.add(migration);
      }
    }
    final changed =
        bloomPackages.any((name) => oldVersions[name] != newVersions[name]);
    if (selected.isNotEmpty || changed) await _applyMigrations(selected);
    await _refreshGuide(pubspec, dryRun: false);
    final upgraded = bloomPackages
        .where((name) => _isNewer(oldVersions[name], newVersions[name]));
    for (final name in upgraded) {
      env.out.writeln(Ansi.dimText(
          "What's new in $name: https://pub.dev/packages/$name/changelog"));
    }
    return ProjectUpgradeResult(
      success: true,
      hasNewerVersion: bloomPackages
          .any((name) => _isNewer(oldVersions[name], newVersions[name])),
    );
  }

  Map<String, String> _readLockVersions() {
    final lockFile = File(p.join(rootDir.path, 'pubspec.lock'));
    if (!lockFile.existsSync()) return {};
    try {
      final packages =
          _asMap(_asMap(loadYaml(lockFile.readAsStringSync()))['packages']);
      return {
        for (final entry in packages.entries)
          if (_asMap(entry.value)['version'] != null)
            entry.key: _asMap(entry.value)['version'].toString(),
      };
    } catch (_) {
      return {};
    }
  }

  bool _usesFlutter(Map<String, dynamic> dependencies) {
    final flutter = dependencies['flutter'];
    return flutter is Map && flutter['sdk'] == 'flutter';
  }

  /// Applies [migrations] to the files the analyzer flags, then reports the
  /// errors that remain. Always `dart analyze`: `flutter analyze` has no
  /// machine format, and the Dart analyzer handles Flutter projects too.
  Future<void> _applyMigrations(List<BloomMigration> migrations) async {
    final issues = migrations.isEmpty
        ? const <AnalyzerIssue>[]
        : parseMachineAnalyzerOutput((await env.runProcess(
            'dart',
            ['analyze', '--format=machine'],
            workingDirectory: rootDir.path,
          ))
            .stdout
            .toString());
    final files = <String, List<AnalyzerIssue>>{};
    for (final issue in issues) {
      files.putIfAbsent(issue.file, () => []).add(issue);
    }
    for (final entry in files.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) continue;
      final original = file.readAsStringSync();
      var source = original;
      final applied = <String>[];
      for (final migration in migrations) {
        final migrated = migration.apply(source, entry.value);
        if (migrated != null && migrated != source) {
          source = migrated;
          applied.add(migration.summary);
        }
      }
      if (source == original) continue;
      file.writeAsStringSync(source);
      final relative =
          p.relative(file.path, from: rootDir.path).replaceAll('\\', '/');
      final summaries = applied.join(', ');
      env.out.writeln(Ansi.success('$relative: $summaries'));
    }
    final after = await env.runProcess(
      'dart',
      ['analyze', '--format=machine'],
      workingDirectory: rootDir.path,
    );
    final errors = parseMachineAnalyzerOutput(after.stdout.toString())
        .where((issue) => issue.severity == 'ERROR')
        .length;
    env.out.writeln(errors == 0
        ? Ansi.success('No analyzer errors.')
        : Ansi.warn(
            '$errors analyzer error(s) remain — run `dart analyze` to see them.'));
  }

  void _printPendingMigrations(String name, String old, String next) {
    final oldVersion = _parseVersion(old);
    final newVersion = _parseVersion(next);
    if (newVersion == null) return;
    for (final migration in bloomMigrations.where((migration) =>
        migration.package == name &&
        (oldVersion == null || migration.version > oldVersion) &&
        migration.version <= newVersion)) {
      env.out.writeln('    ${migration.id}: ${migration.summary}');
    }
  }

  Future<void> _refreshGuide(Map<String, dynamic> pubspec,
      {required bool dryRun}) async {
    final bloomYaml = File(p.join(rootDir.path, 'bloom.yaml'));
    final config = bloomYaml.existsSync()
        ? _asMap(loadYaml(bloomYaml.readAsStringSync()))
        : <String, dynamic>{};
    if (config['type'] != 'js_native' &&
        !_asMap(pubspec['dependencies']).containsKey('bloom_js_native') &&
        !_asMap(pubspec['dev_dependencies']).containsKey('bloom_js_native')) {
      return;
    }
    final name = pubspec['name']?.toString() ?? p.basename(rootDir.path);
    final result = refreshAgentsGuide(
      rootDir,
      projectName: name,
      dryRun: dryRun,
    );
    final backup = result.backupPath == null
        ? ''
        : ' (old copy: ${p.relative(result.backupPath!, from: rootDir.path)})';
    switch (result.status) {
      case AgentsGuideStatus.updated:
        env.out.writeln(dryRun
            ? '  AGENTS.md would be refreshed.'
            : '  ✔ AGENTS.md refreshed.');
        break;
      case AgentsGuideStatus.replacedLegacy:
        env.out.writeln(dryRun
            ? '  AGENTS.md would be replaced with the current guide$backup.'
            : Ansi.success('AGENTS.md replaced with the current guide$backup; '
                'move any notes of your own below its end marker.'));
        break;
      case AgentsGuideStatus.missing:
        env.out.writeln(dryRun
            ? '  AGENTS.md would be created.'
            : Ansi.success('AGENTS.md created.'));
        break;
      case AgentsGuideStatus.skippedUserFile:
        env.out.writeln('AGENTS.md is user-managed; ${result.message}');
        break;
      case AgentsGuideStatus.unchanged:
        break;
    }
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map)
    return value.map((key, value) => MapEntry(key.toString(), value));
  return <String, dynamic>{};
}

Map<String, Map<String, String?>> _parseOutdated(String output) {
  try {
    final decoded = jsonDecode(output);
    if (decoded is! Map || decoded['packages'] is! List) return {};
    final result = <String, Map<String, String?>>{};
    for (final item in decoded['packages'] as List) {
      if (item is! Map || item['package'] is! String) continue;
      String? version(String key) {
        final value = item[key];
        return value is Map ? value['version']?.toString() : null;
      }

      result[item['package'] as String] = {
        'current': version('current'),
        'resolvable': version('resolvable'),
        'latest': version('latest'),
      };
    }
    return result;
  } catch (_) {
    return {};
  }
}

Version? _parseVersion(String? value) {
  if (value == null) return null;
  try {
    return Version.parse(value);
  } catch (_) {
    return null;
  }
}

bool _isNewer(String? current, String? target) {
  final currentVersion = _parseVersion(current);
  final targetVersion = _parseVersion(target);
  return currentVersion != null &&
      targetVersion != null &&
      targetVersion > currentVersion;
}
