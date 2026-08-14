// test/bloom_phase17_samples_test.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/doctor_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Directory _findExamplesDir() {
  Directory dir = Directory.current.absolute;
  while (dir.path != dir.parent.path) {
    final candidate = Directory(p.join(dir.path, 'examples'));
    if (candidate.existsSync() && Directory(p.join(candidate.path, 'bloom_ecommerce')).existsSync()) {
      return candidate;
    }
    dir = dir.parent;
  }
  return Directory('/root/dev/Bloom/examples');
}

void main() {
  final examplesRoot = _findExamplesDir();

  group('Phase 17: Reference Sample Applications Validation (C1, C5)', () {
    test('bloom_ecommerce passes bloom doctor --ci diagnostics cleanly (C1, C5)', () async {
      final ecommerceDir = Directory(p.join(examplesRoot.path, 'bloom_ecommerce'));
      expect(ecommerceDir.existsSync(), isTrue);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode = await runner.run(['doctor', '--ci', '--project-dir', ecommerceDir.path]);
      expect(exitCode, 0);
    });

    test('bloom_social_feed passes bloom doctor --ci diagnostics cleanly (C1, C5)', () async {
      final socialDir = Directory(p.join(examplesRoot.path, 'bloom_social_feed'));
      expect(socialDir.existsSync(), isTrue);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode = await runner.run(['doctor', '--ci', '--project-dir', socialDir.path]);
      expect(exitCode, 0);
    });

    test('bloom_fullstack_api passes bloom doctor --ci diagnostics cleanly (C1, C5)', () async {
      final fullstackDir = Directory(p.join(examplesRoot.path, 'bloom_fullstack_api'));
      expect(fullstackDir.existsSync(), isTrue);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode = await runner.run(['doctor', '--ci', '--project-dir', fullstackDir.path]);
      expect(exitCode, 0);
    });
  });
}
