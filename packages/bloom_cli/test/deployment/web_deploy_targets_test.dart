// test/deployment/web_deploy_targets_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/deployment/web_deploy_targets.dart';
import 'package:bloom_cli/src/utils/project.dart';

void main() {
  const deployer = BloomWebDeployer();
  late Directory tempProjectDir;
  late Directory tempOutputDir;

  setUp(() async {
    tempProjectDir = await Directory.systemTemp.createTemp('bloom_deploy_proj_');
    tempOutputDir = await Directory.systemTemp.createTemp('bloom_deploy_out_');

    // Create minimal bloom.yaml and pubspec.yaml
    final bloomYaml = File(p.join(tempProjectDir.path, 'bloom.yaml'));
    await bloomYaml.writeAsString('''
name: test_web_app
target: web
proxy:
  /api:
    target: "https://api.example.com"
    strip_prefix: true
''');

    final pubspecYaml = File(p.join(tempProjectDir.path, 'pubspec.yaml'));
    await pubspecYaml.writeAsString('''
name: test_web_app
version: 1.0.0
''');
  });

  tearDown(() async {
    if (tempProjectDir.existsSync()) {
      await tempProjectDir.delete(recursive: true);
    }
    if (tempOutputDir.existsSync()) {
      await tempOutputDir.delete(recursive: true);
    }
  });

  group('BloomWebDeployer', () {
    test('dry run writes NO files and returns exit code 0', () async {
      final project = BloomProject.fromDirectory(tempProjectDir);

      final exitCode = await deployer.run(
        project: project,
        target: BloomWebDeployTarget.static_,
        dryRun: true,
        formats: {BloomWebHostFormat.netlify, BloomWebHostFormat.vercel},
        outputDir: tempOutputDir,
      );

      expect(exitCode, 0);
      expect(tempOutputDir.listSync(), isEmpty);
    });

    test('real run writes exactly the requested formats and no others', () async {
      final project = BloomProject.fromDirectory(tempProjectDir);

      final exitCode = await deployer.run(
        project: project,
        target: BloomWebDeployTarget.static_,
        dryRun: false,
        formats: {BloomWebHostFormat.netlify},
        outputDir: tempOutputDir,
      );

      expect(exitCode, 0);
      expect(File(p.join(tempOutputDir.path, '_redirects')).existsSync(), isTrue);
      expect(File(p.join(tempOutputDir.path, 'vercel.json')).existsSync(), isFalse);
      expect(File(p.join(tempOutputDir.path, 'nginx.conf')).existsSync(), isFalse);
      expect(File(p.join(tempOutputDir.path, 'Dockerfile')).existsSync(), isFalse);
    });

    test('empty proxy rules still succeeds and writes default SPA fallback', () async {
      final noProxyProjDir = await Directory.systemTemp.createTemp('bloom_no_proxy_');
      try {
        final bloomYaml = File(p.join(noProxyProjDir.path, 'bloom.yaml'));
        await bloomYaml.writeAsString('''
name: no_proxy_app
target: web
''');
        final pubspec = File(p.join(noProxyProjDir.path, 'pubspec.yaml'));
        await pubspec.writeAsString('name: no_proxy_app\n');

        final project = BloomProject.fromDirectory(noProxyProjDir);

        final exitCode = await deployer.run(
          project: project,
          target: BloomWebDeployTarget.static_,
          dryRun: false,
          formats: {BloomWebHostFormat.netlify},
          outputDir: tempOutputDir,
        );

        expect(exitCode, 0);
        final redirectsFile = File(p.join(tempOutputDir.path, '_redirects'));
        expect(redirectsFile.existsSync(), isTrue);
        expect(redirectsFile.readAsStringSync().trim(), '/*  /index.html  200');
      } finally {
        if (noProxyProjDir.existsSync()) {
          await noProxyProjDir.delete(recursive: true);
        }
      }
    });
  });
}
