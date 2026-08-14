// test/bloom_phase14_tooling_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:image/image.dart' as img;
import 'package:bloom_cli/src/assets/asset_analyzer.dart';
import 'package:bloom_cli/src/assets/asset_generator.dart';
import 'package:bloom_cli/src/commands/assets_command.dart';
import 'package:bloom_cli/src/commands/audit_command.dart';
import 'package:bloom_cli/src/commands/security_command.dart';
import 'package:bloom_cli/src/provenance/provenance_generator.dart';
import 'package:bloom_cli/src/security/secret_scanner.dart';
import 'package:bloom_cli/src/security/vulnerability_db.dart';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_phase14_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  BloomProject _createMockProject(Directory dir, {String version = '1.0.0'}) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    pubspec.writeAsStringSync('''
name: test_tooling_app
description: Test Application for Bloom Tooling
version: $version

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
''');

    final bloomYaml = File(p.join(dir.path, 'bloom.yaml'));
    bloomYaml.writeAsStringSync('''
name: test_tooling_app
version: $version
mode: managed
''');

    final libDir = Directory(p.join(dir.path, 'lib'))..createSync(recursive: true);
    File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: Scaffold()));
}
''');

    return BloomProject.find(dir)!;
  }

  group('Phase 14: Security & Dependency Audit (bloom audit) (C2)', () {
    test('Detects known vulnerable package in pubspec.lock and returns exit code 1', () async {
      final project = _createMockProject(tempDir);

      // Seed pubspec.lock with a known vulnerable version of archive (< 3.3.0)
      final lockFile = File(p.join(project.rootDir.path, 'pubspec.lock'));
      lockFile.writeAsStringSync('''
packages:
  archive:
    dependency: "direct main"
    description:
      name: archive
      url: "https://pub.dev"
    source: hosted
    version: "3.1.2"
  http:
    dependency: "direct main"
    description:
      name: http
      url: "https://pub.dev"
    source: hosted
    version: "0.13.6"
''');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(AuditCommand());

      final exitCode = await runner.run(['audit', '--project-dir', project.rootDir.path]);

      expect(exitCode, 1);

      // Check report details
      final report = AuditCommand.runAudit(project);
      expect(report.hasVulnerabilities, isTrue);
      expect(report.findings.length, 1);
      expect(report.findings.first.package, 'archive');
      expect(report.findings.first.vulnerability.cveId, 'CVE-2023-39017');
      expect(report.findings.first.vulnerability.severity, VulnerabilitySeverity.critical);
    });

    test('Returns exit code 0 when all dependencies are secure', () async {
      final project = _createMockProject(tempDir);

      final lockFile = File(p.join(project.rootDir.path, 'pubspec.lock'));
      lockFile.writeAsStringSync('''
packages:
  archive:
    dependency: "direct main"
    description:
      name: archive
      url: "https://pub.dev"
    source: hosted
    version: "3.4.0"
  http:
    dependency: "direct main"
    description:
      name: http
      url: "https://pub.dev"
    source: hosted
    version: "1.2.0"
''');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(AuditCommand());

      final exitCode = await runner.run(['audit', '--project-dir', project.rootDir.path]);

      expect(exitCode, 0);

      final report = AuditCommand.runAudit(project);
      expect(report.hasVulnerabilities, isFalse);
    });
  });

  group('Phase 14: Secret Detection & Sanitization (bloom security scan) (C3)', () {
    test('Flags seeded hardcoded secrets with file:line and returns exit code 1', () async {
      final project = _createMockProject(tempDir);

      // Seed a secret in a Dart file
      final secretFile = File(p.join(project.rootDir.path, 'lib', 'secrets_service.dart'));
      secretFile.writeAsStringSync('''
class SecretsService {
  final awsKey = "AKIA1234567890ABCDEF";
  final openAiToken = "sk-1234567890abcdef1234567890abcdef1234";
}
''');

      final scanner = SecretScanner(project);
      final result = scanner.scan();

      expect(result.hasSecrets, isTrue);
      expect(result.findings.length, 2);
      expect(result.findings.any((f) => f.ruleName == 'AWS Access Key ID'), isTrue);
      expect(result.findings.any((f) => f.ruleName == 'OpenAI / SaaS API Key'), isTrue);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(SecurityCommand());

      final exitCode = await runner.run(['security', 'scan', '--project-dir', project.rootDir.path]);
      expect(exitCode, 1);
    });

    test('Returns exit code 0 when codebase is clean of secrets', () async {
      final project = _createMockProject(tempDir);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(SecurityCommand());

      final exitCode = await runner.run(['security', 'scan', '--project-dir', project.rootDir.path]);
      expect(exitCode, 0);
    });
  });

  group('Phase 14: Asset Optimization Pipeline (bloom assets) (C4, C6)', () {
    test('bloom assets optimize re-encodes valid images to an optimized PNG (C4)', () async {
      final project = _createMockProject(tempDir);

      final assetsDir = Directory(p.join(project.rootDir.path, 'assets', 'images'))..createSync(recursive: true);
      final samplePng = File(p.join(assetsDir.path, 'logo.png'));

      // Write a real decodable PNG.
      final image = img.Image(width: 16, height: 16);
      img.fill(image, color: img.ColorRgb8(120, 60, 30));
      final realPngBytes = img.encodePng(image);
      samplePng.writeAsBytesSync(realPngBytes);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(AssetsCommand());

      final exitCode = await runner.run(['assets', 'optimize', '--project-dir', project.rootDir.path]);
      expect(exitCode, 0);

      final optimizedFile = File(p.join(assetsDir.path, 'logo.optimized.png'));
      expect(optimizedFile.existsSync(), isTrue);

      final optimizedBytes = optimizedFile.readAsBytesSync();
      // Must be a valid PNG signature (0x89 'PNG'), not a fabricated RIFF/VP8 blob.
      expect(optimizedBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('bloom assets analyze identifies unused assets', () async {
      final project = _createMockProject(tempDir);

      final assetsDir = Directory(p.join(project.rootDir.path, 'assets', 'images'))..createSync(recursive: true);
      File(p.join(assetsDir.path, 'used_logo.png')).writeAsStringSync('png_data');
      File(p.join(assetsDir.path, 'orphaned_banner.png')).writeAsStringSync('banner_data');

      // Reference only used_logo.png in lib/main.dart
      final mainFile = File(p.join(project.rootDir.path, 'lib', 'main.dart'));
      mainFile.writeAsStringSync('''
import 'package:flutter/material.dart';

void main() {
  runApp(Image.asset('assets/images/used_logo.png'));
}
''');

      final analyzer = AssetAnalyzer(project: project);
      final result = analyzer.analyze();

      expect(result.allAssets.length, 2);
      expect(result.unusedAssets.length, 1);
      expect(result.unusedAssets.first.relativePath, contains('orphaned_banner.png'));
    });

    test('bloom assets generate produces strongly-typed assets.g.dart (C6)', () async {
      final project = _createMockProject(tempDir);

      final imagesDir = Directory(p.join(project.rootDir.path, 'assets', 'images'))..createSync(recursive: true);
      final iconsDir = Directory(p.join(project.rootDir.path, 'assets', 'icons'))..createSync(recursive: true);

      File(p.join(imagesDir.path, 'brand_logo.png')).writeAsStringSync('img');
      File(p.join(iconsDir.path, 'shopping_cart.svg')).writeAsStringSync('icon');

      final generator = AssetGenerator(project: project);
      final generatedFile = generator.generate();

      expect(generatedFile.existsSync(), isTrue);
      final content = generatedFile.readAsStringSync();

      expect(content, contains('abstract class Assets'));
      expect(content, contains('class _AssetsImages'));
      expect(content, contains('class _AssetsIcons'));
      expect(content, contains("final String brandLogo = 'assets/images/brand_logo.png';"));
      expect(content, contains("final String shoppingCart = 'assets/icons/shopping_cart.svg';"));

      // Verify the generated file compiles cleanly with dart analyze
      final analyzeResult = Process.runSync(
        'dart',
        ['analyze', generatedFile.path],
        workingDirectory: project.rootDir.path,
      );
      expect(analyzeResult.exitCode, 0, reason: analyzeResult.stdout.toString());
    });
  });

  group('Phase 14: Build Provenance & Reproducibility (C5)', () {
    test('Build provenance sourceHash is byte-identical across runs on identical source (C5)', () {
      final project = _createMockProject(tempDir, version: '2.5.0');

      final gen = ProvenanceGenerator(project);
      final hash1 = gen.computeSourceHash();
      final hash2 = gen.computeSourceHash();

      expect(hash1, equals(hash2));
      expect(hash1, startsWith('sha256:'));

      final fixedTimestamp = DateTime.utc(2026, 8, 14, 12, 0, 0);
      final prov1 = gen.generateProvenance(
        builder: 'TestRunner',
        commit: 'a1b2c3d',
        timestamp: fixedTimestamp,
      );

      expect(prov1.toolchain['bloomVersion'], '2.5.0');
      expect(prov1.toolchain['dartVersion'], equals(Platform.version.split(' ').first));
      expect(prov1.sourceHash, equals(hash1));
      expect(prov1.commit, 'a1b2c3d');

      final provFile = File(p.join(project.rootDir.path, 'build', 'provenance.json'));
      expect(provFile.existsSync(), isTrue);
      final json = jsonDecode(provFile.readAsStringSync()) as Map<String, dynamic>;
      expect(json['sourceHash'], equals(hash1));
    });
  });
}
