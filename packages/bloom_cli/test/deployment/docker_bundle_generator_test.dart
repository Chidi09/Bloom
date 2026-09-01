// test/deployment/docker_bundle_generator_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/deployment/deployment_target_detector.dart';
import 'package:bloom_cli/src/deployment/docker_bundle_generator.dart';
import 'package:bloom_cli/src/templates/deployment_templates.dart';
import 'package:bloom_cli/src/utils/project.dart';

void main() {
  late Directory tempDir;
  const generator = BloomDockerGenerator();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_docker_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BloomDockerGenerator bundle generation', () {
    test('generates complete Flutter web bundle with health check and Nginx',
        () {
      final appDir = Directory(p.join(tempDir.path, 'flutter_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: flutter_shop\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: flutter_shop\n');

      final project = BloomProject.fromDirectory(appDir);
      final bundle = generator.generate(
        project: project,
        target: BloomDeploymentTarget.flutter,
      );

      expect(bundle.target, BloomDeploymentTarget.flutter);
      expect(bundle.appName, 'flutter_shop');
      expect(bundle.containsFile('Dockerfile'), isTrue);
      expect(bundle.containsFile('.dockerignore'), isTrue);
      expect(bundle.containsFile('docker-compose.yml'), isTrue);
      expect(bundle.containsFile('.env.example'), isTrue);
      expect(bundle.containsFile('nginx.conf'), isTrue);

      final dockerfile = bundle.getFileContent('Dockerfile')!;
      expect(dockerfile,
          contains('FROM ghcr.io/cirruslabs/flutter:stable AS build'));
      expect(dockerfile, contains('flutter build web --release'));
      expect(dockerfile, contains('FROM nginx:alpine'));
      expect(dockerfile, contains('HEALTHCHECK'));
      expect(dockerfile, contains('EXPOSE 8080'));

      final compose = bundle.getFileContent('docker-compose.yml')!;
      expect(compose, contains('web:'));
      expect(compose, contains('healthcheck:'));
      expect(compose, contains('8080:8080'));

      final env = bundle.getFileContent('.env.example')!;
      expect(env, contains('APP_NAME=flutter_shop'));
      expect(env, contains('BLOOM_PUBLIC_API_URL='));
      // Verify no secrets embedded
      expect(env, isNot(contains('sk_live_')));
      expect(env, isNot(contains('AWS_SECRET_ACCESS_KEY')));
    });

    test('generates JS Native bundle (static and SSR profiles)', () {
      final appDir = Directory(p.join(tempDir.path, 'js_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: js_web_app\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: js_web_app\n');

      final project = BloomProject.fromDirectory(appDir);

      // Static profile
      final staticBundle = generator.generate(
        project: project,
        target: BloomDeploymentTarget.jsNative,
        hasSsr: false,
      );
      expect(staticBundle.getFileContent('Dockerfile'),
          contains('dart compile js'));
      expect(staticBundle.getFileContent('Dockerfile'),
          contains('FROM nginx:alpine'));

      // SSR profile
      final ssrBundle = generator.generate(
        project: project,
        target: BloomDeploymentTarget.jsNative,
        hasSsr: true,
      );
      expect(ssrBundle.getFileContent('Dockerfile'),
          contains('dart compile exe bin/server.dart'));
      expect(ssrBundle.getFileContent('Dockerfile'), contains('FROM scratch'));
    });

    test(
        'generates Bloom Server bundle with multi-stage scratch and Compose database service',
        () {
      final appDir = Directory(p.join(tempDir.path, 'server_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: api_backend\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: api_backend\n');

      final project = BloomProject.fromDirectory(appDir);
      final bundle = generator.generate(
        project: project,
        target: BloomDeploymentTarget.server,
      );

      final dockerfile = bundle.getFileContent('Dockerfile')!;
      expect(dockerfile, contains('FROM dart:stable AS build'));
      expect(dockerfile,
          contains('dart compile exe bin/server.dart -o bin/server'));
      expect(dockerfile, contains('FROM scratch'));
      expect(dockerfile, contains('ENTRYPOINT ["/app/bin/server"]'));

      final compose = bundle.getFileContent('docker-compose.yml')!;
      expect(compose, contains('server:'));
      expect(compose, contains('db:'));
      expect(compose, contains('image: postgres:16-alpine'));
      expect(compose, contains('condition: service_healthy'));

      final env = bundle.getFileContent('.env.example')!;
      expect(env, contains('DB_HOST=127.0.0.1'));
      expect(env, contains('BLOOM_AUTH_SECRET='));
      // Template only: safe dummy placeholders
      expect(
          env, contains('change-this-to-a-secure-random-32-character-secret'));
    });

    test(
        'generates Hybrid bundle with both web and server compose services sharing profiles',
        () {
      final appDir = Directory(p.join(tempDir.path, 'hybrid_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: fullstack_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: fullstack_demo\n');

      final project = BloomProject.fromDirectory(appDir);
      final bundle = generator.generate(
        project: project,
        target: BloomDeploymentTarget.hybrid,
      );

      final compose = bundle.getFileContent('docker-compose.yml')!;
      expect(compose, contains('server:'));
      expect(compose, contains('web:'));
      expect(compose, contains('db:'));
      expect(compose, contains('depends_on:'));
      expect(compose, contains('API_URL=http://server:8080'));
    });

    test('honors productionOnly flag by completely omitting docker-compose.yml',
        () {
      final appDir = Directory(p.join(tempDir.path, 'prod_only_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: prod_app\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: prod_app\n');

      final project = BloomProject.fromDirectory(appDir);
      final bundle = generator.generate(
        project: project,
        target: BloomDeploymentTarget.server,
        productionOnly: true,
      );

      expect(bundle.productionOnly, isTrue);
      expect(bundle.containsFile('docker-compose.yml'), isFalse);
      expect(bundle.containsFile('Dockerfile'), isTrue);
      expect(bundle.containsFile('.dockerignore'), isTrue);
      expect(bundle.containsFile('.env.example'), isTrue);
    });

    test('.dockerignore strictly ignores .env and sensitive credential files',
        () {
      final ignore = BloomDeploymentTemplates.dockerIgnore();
      expect(ignore, contains('.env'));
      expect(ignore, contains('.env.*'));
      expect(ignore, contains('!.env.example'));
      expect(ignore, contains('.git/'));
      expect(ignore, contains('.dart_tool/'));
      expect(ignore, contains('*.key'));
      expect(ignore, contains('*.pem'));
    });

    test('writeBundle writes all files to target directory', () {
      final appDir = Directory(p.join(tempDir.path, 'write_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: write_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: write_demo\n');

      final project = BloomProject.fromDirectory(appDir);
      final bundle = generator.generate(
        project: project,
        target: BloomDeploymentTarget.flutter,
      );

      final outDir = Directory(p.join(tempDir.path, 'out_dir'));
      final written = generator.writeBundle(bundle: bundle, targetDir: outDir);

      expect(written.length, bundle.files.length);
      expect(File(p.join(outDir.path, 'Dockerfile')).existsSync(), isTrue);
      expect(File(p.join(outDir.path, '.dockerignore')).existsSync(), isTrue);
      expect(
          File(p.join(outDir.path, 'docker-compose.yml')).existsSync(), isTrue);
      expect(File(p.join(outDir.path, '.env.example')).existsSync(), isTrue);
    });
  });
}
