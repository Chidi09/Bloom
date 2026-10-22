import 'dart:io';
import 'dart:isolate';

import 'package:bloom_cli/src/version.dart';
import 'package:test/test.dart';

void main() {
  test('bloomCliVersion matches the package version in pubspec.yaml', () {
    // Other tests change Directory.current, so resolve pubspec.yaml from the
    // package location instead of the working directory.
    final versionFile = Isolate.resolvePackageUriSync(
        Uri.parse('package:bloom_cli/src/version.dart'))!;
    final pubspec = File.fromUri(versionFile.resolve('../../pubspec.yaml'))
        .readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(
      pubspec,
    );

    expect(match, isNotNull);
    expect(bloomCliVersion, match!.group(1));
  });
}
