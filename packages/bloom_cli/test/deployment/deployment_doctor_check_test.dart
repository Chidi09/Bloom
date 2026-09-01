// test/deployment/deployment_doctor_check_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/deployment/deployment_doctor_check.dart';
import 'package:bloom_cli/src/utils/project.dart';

void main() {
  late Directory tempDir;
  const checker = DeploymentDoctorChecker();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_doctor_check_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DeploymentDoctorChecker', () {
    test('runs system Docker check without project', () async {
      final report = await checker.check();
      expect(report.items, isNotEmpty);
      expect(report.items.any((i) => i.title.contains('Docker')), isTrue);
    });

    test(
        'validates healthy project configuration with .dockerignore and .env.example',
        () async {
      final appDir = Directory(p.join(tempDir.path, 'healthy_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: healthy_app\nport: 8080\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: healthy_app\n');
      File(p.join(appDir.path, '.dockerignore'))
          .writeAsStringSync('.env\n.git\nbuild/\n');
      File(p.join(appDir.path, '.env.example'))
          .writeAsStringSync('PORT=8080\n');

      final project = BloomProject.fromDirectory(appDir);
      final report = await checker.check(project: project);

      expect(report.detectionResult, isNotNull);
      expect(report.items.any((i) => i.title == 'Application Target'), isTrue);
      expect(
          report.items
              .any((i) => i.title == 'Docker Secret Protection' && i.isHealthy),
          isTrue);
      expect(
          report.items
              .any((i) => i.title == 'Environment Template' && i.isHealthy),
          isTrue);
      expect(
          report.items
              .any((i) => i.title == 'Port Configuration' && i.isHealthy),
          isTrue);
    });

    test('flags missing server entrypoint for server target as failure',
        () async {
      final appDir = Directory(p.join(tempDir.path, 'broken_server_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: broken_server
deployment:
  target: server
''');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: broken_server\n');

      final project = BloomProject.fromDirectory(appDir);
      final report = await checker.check(project: project);

      expect(report.isPassed, isFalse);
      final entryItem =
          report.items.firstWhere((i) => i.title == 'Server Entrypoint');
      expect(entryItem.isHealthy, isFalse);
      expect(entryItem.details, contains('Missing required bin/server.dart'));
    });

    test('warns when .dockerignore does not exclude .env secrets', () async {
      final appDir = Directory(p.join(tempDir.path, 'insecure_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: insecure_app\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: insecure_app\n');
      File(p.join(appDir.path, '.dockerignore'))
          .writeAsStringSync('build/\nnode_modules/\n');

      final project = BloomProject.fromDirectory(appDir);
      final report = await checker.check(project: project);

      final secItem =
          report.items.firstWhere((i) => i.title == 'Docker Secret Protection');
      expect(secItem.isHealthy, isFalse);
      expect(secItem.details, contains('does not explicitly exclude .env'));
    });
  });
}
