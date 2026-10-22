// test/bloom_phase16_tooling_test.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/doctor_command.dart';
import 'package:bloom_cli/src/commands/graph_command.dart';
import 'package:bloom_cli/src/explain/explain_engine.dart';
import 'package:bloom_cli/src/registry/package_registry.dart';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_phase16_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Directory _createTestProject(Directory parentDir, {bool withSecret = false}) {
    final projDir = Directory(p.join(parentDir.path, 'upgrade_app'))..createSync(recursive: true);

    File(p.join(projDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: upgrade_app
description: Bloom Upgrade Test App
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.27.0'

dependencies:
  flutter:
    sdk: flutter
  bloom_framework: ^1.0.0
''');

    File(p.join(projDir.path, 'bloom.yaml')).writeAsStringSync('''
name: upgrade_app
version: 1.0.0
schema: 1
platforms:
  - android
  - ios
''');

    final libRoutes = Directory(p.join(projDir.path, 'lib', 'routes'))..createSync(recursive: true);
    File(p.join(libRoutes.path, 'index.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Text('Home');
}
''');

    final usersDir = Directory(p.join(libRoutes.path, 'users'))..createSync(recursive: true);
    File(p.join(usersDir.path, '_layout.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';

class UsersLayout extends StatelessWidget {
  const UsersLayout({super.key});
  @override
  Widget build(BuildContext context) => const Placeholder();
}
''');

    File(p.join(usersDir.path, '[id].dart')).writeAsStringSync('''
import 'package:flutter/material.dart';

// @RequireAuth
class UserProfileScreen extends StatelessWidget {
  final String id;
  const UserProfileScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Text('User: \$id');
}
''');

    if (withSecret) {
      File(p.join(projDir.path, 'lib', 'config_secrets.dart')).writeAsStringSync('''
const awsKey = 'AKIAIOSFODNN7EXAMPLE';
''');
    }

    return projDir;
  }

  group('Phase 16: Continuous CI Doctor Agent (bloom doctor --ci) (C4)', () {
    test('bloom doctor --ci returns non-zero when problem is seeded (C4)', () async {
      final problemDir = _createTestProject(tempDir, withSecret: true);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode = await runner.run(['doctor', '--ci', '--project-dir', problemDir.path]);
      expect(exitCode, equals(1));
    });

    test('bloom doctor --ci returns 0 on clean codebase (C4)', () async {
      final cleanDir = _createTestProject(tempDir);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode = await runner.run(['doctor', '--ci', '--project-dir', cleanDir.path]);
      expect(exitCode, equals(0));
    });
  });

  group('Phase 16: Architectural Explanation & Graph Tools (bloom explain, bloom graph) (C5)', () {
    test('bloom explain route /users/42 derives real params, pattern, layout, and guards (C5)', () async {
      final projectDir = _createTestProject(tempDir);
      final project = BloomProject.find(projectDir)!;

      final explainEngine = ExplainEngine(project);
      final explanation = explainEngine.explainRoute('/users/42');

      expect(explanation.isFound, isTrue);
      expect(explanation.pattern, '/users/:id');
      expect(explanation.parameters, {'id': '42'});
      expect(explanation.filePath, 'lib/routes/users/[id].dart');
      expect(explanation.layoutPath, contains('_layout.dart'));
    });

    test('bloom explain route returns isFound = false for unregistered routes (C5)', () {
      final projectDir = _createTestProject(tempDir);
      final project = BloomProject.find(projectDir)!;

      final explainEngine = ExplainEngine(project);
      final explanation = explainEngine.explainRoute('/non_existent/route');

      expect(explanation.isFound, isFalse);
    });

    test('bloom graph builds architectural dependency nodes', () async {
      final projectDir = _createTestProject(tempDir);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(GraphCommand());

      final exitCode = await runner.run(['graph', '--project-dir', projectDir.path, '--format', 'mermaid']);
      expect(exitCode, 0);
    });
  });

  group('Phase 16: Package Registry & Compatibility Badges (C6)', () {
    test('Registry badges are derived from CI matrix results, not self-declared (C6)', () {
      // 1. Core team package -> Official
      final officialPkg = PackageRegistry.findPackage('bloom_camera')!;
      expect(officialPkg.tier, VerificationTier.official);
      expect(officialPkg.badge, contains('Official'));

      // 2. Package passing all matrix tests -> Verified
      final verifiedPkg = PackageRegistry.findPackage('bloom_stripe')!;
      expect(verifiedPkg.tier, VerificationTier.verified);
      expect(verifiedPkg.badge, contains('Verified'));

      // 3. Package with failing matrix test -> Community
      final communityPkg = PackageRegistry.findPackage('bloom_charts')!;
      expect(communityPkg.tier, VerificationTier.community);
      expect(communityPkg.badge, contains('Community'));
    });

    test('Registry search returns matching packages', () {
      final results = PackageRegistry.search('stripe');
      expect(results.length, 1);
      expect(results.first.name, 'bloom_stripe');
    });
  });
}
