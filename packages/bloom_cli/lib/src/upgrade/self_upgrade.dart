import 'package:pub_semver/pub_semver.dart';
import '../utils/ansi.dart';
import 'upgrade_engine.dart';

/// Result of checking or installing a newer global Bloom CLI.
class SelfUpgradeResult {
  final bool upgraded;
  final String? fromVersion;
  final String? toVersion;

  const SelfUpgradeResult({
    required this.upgraded,
    this.fromVersion,
    this.toVersion,
  });
}

/// Checks the CLI installation source and upgrades hosted global installs.
Future<SelfUpgradeResult> upgradeCli(
  UpgradeEnvironment env, {
  required bool dryRun,
}) async {
  final listed = await env.runProcess('dart', ['pub', 'global', 'list']);
  final matchingLines = listed.stdout
      .toString()
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().startsWith('bloom_cli '))
      .toList();
  final line = matchingLines.isEmpty ? null : matchingLines.first;
  if (line == null) {
    env.out
        .writeln('bloom CLI is not globally activated; skipping CLI upgrade.');
    return const SelfUpgradeResult(upgraded: false);
  }
  final current = RegExp(r'^bloom_cli\s+(\S+)').firstMatch(line.trim());
  final installed = current?.group(1);
  if (line.contains(' at path ')) {
    final path = RegExp(r'at path "([^"]+)"').firstMatch(line)?.group(1) ??
        'unknown path';
    env.out.writeln(
        'bloom CLI runs from a source checkout ($path); update it with git pull.');
    return SelfUpgradeResult(upgraded: false, fromVersion: installed);
  }
  if (line.contains(' from Git repository ')) {
    env.out.writeln(
        'bloom CLI is installed from git; reinstall it with `dart pub global activate bloom_cli --source git ...`.');
    return SelfUpgradeResult(upgraded: false, fromVersion: installed);
  }
  if (installed == null || line.trim() != 'bloom_cli $installed') {
    env.out.writeln(
        'bloom CLI install source is not a hosted global install; skipping CLI upgrade.');
    return SelfUpgradeResult(upgraded: false, fromVersion: installed);
  }

  final latest = await env.latestVersion('bloom_cli');
  if (latest == null) {
    env.out.writeln("Couldn't reach pub.dev; skipped the CLI check.");
    return SelfUpgradeResult(upgraded: false, fromVersion: installed);
  }
  final oldVersion = _version(installed);
  final latestVersion = _version(latest);
  if (oldVersion == null || latestVersion == null) {
    env.out.writeln(
        "Couldn't parse the bloom CLI version; skipped the CLI check.");
    return SelfUpgradeResult(upgraded: false, fromVersion: installed);
  }
  if (latestVersion <= oldVersion) {
    env.out.writeln(Ansi.success('bloom CLI $installed is up to date'));
    return SelfUpgradeResult(
      upgraded: false,
      fromVersion: installed,
      toVersion: latest,
    );
  }
  if (dryRun) {
    env.out.writeln('Would upgrade bloom CLI $installed → $latest');
    return SelfUpgradeResult(
      upgraded: false,
      fromVersion: installed,
      toVersion: latest,
    );
  }
  final activation = await env.runProcess(
    'dart',
    ['pub', 'global', 'activate', 'bloom_cli'],
  );
  if (activation.exitCode != 0) {
    env.out.write(activation.stderr.toString());
    env.out.writeln(
        'Run `dart pub global activate bloom_cli` manually to update.');
    return SelfUpgradeResult(
      upgraded: false,
      fromVersion: installed,
      toVersion: latest,
    );
  }
  env.out.writeln(Ansi.success('bloom CLI $installed → $latest'));
  return SelfUpgradeResult(
    upgraded: true,
    fromVersion: installed,
    toVersion: latest,
  );
}

Version? _version(String? value) {
  if (value == null) return null;
  try {
    return Version.parse(value);
  } catch (_) {
    return null;
  }
}
