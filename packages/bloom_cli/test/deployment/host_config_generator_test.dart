// test/deployment/host_config_generator_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/deployment/host_config_generator.dart';
import 'package:bloom_cli/src/deployment/web_deploy_targets.dart';
import 'package:bloom_cli/src/dev/dev_proxy.dart';

void main() {
  const generator = BloomHostConfigGenerator();

  group('Netlify Redirects Generation', () {
    test('uses status 200 and :splat, and ends with the SPA fallback', () {
      final rules = [
        BloomDevProxyRule(
          pathPrefix: '/gh',
          targetUri: Uri.parse('https://github.com'),
          stripPrefix: true,
        ),
      ];

      final output = generator.generateNetlifyRedirects(rules);
      final lines = output.trim().split('\n');

      expect(lines.first, '/gh/*  https://github.com/:splat  200');
      expect(lines.last, '/*  /index.html  200');
    });

    test('stripPrefix true vs false produce different upstream paths', () {
      final ruleStrip = BloomDevProxyRule(
        pathPrefix: '/api',
        targetUri: Uri.parse('https://api.example.com'),
        stripPrefix: true,
      );

      final ruleKeep = BloomDevProxyRule(
        pathPrefix: '/api',
        targetUri: Uri.parse('https://api.example.com'),
        stripPrefix: false,
      );

      final outputStrip = generator.generateNetlifyRedirects([ruleStrip]);
      final outputKeep = generator.generateNetlifyRedirects([ruleKeep]);

      expect(outputStrip, contains('/api/*  https://api.example.com/:splat  200'));
      expect(outputKeep, contains('/api/*  https://api.example.com/api/:splat  200'));
      expect(outputStrip, isNot(equals(outputKeep)));
    });
  });

  group('Vercel JSON Generation', () {
    test('parses as valid JSON and contains rewrites key with SPA fallback', () {
      final rules = [
        BloomDevProxyRule(
          pathPrefix: '/api',
          targetUri: Uri.parse('https://api.example.com'),
          stripPrefix: true,
        ),
        BloomDevProxyRule(
          pathPrefix: '/auth',
          targetUri: Uri.parse('https://auth.example.com'),
          stripPrefix: false,
        ),
      ];

      final jsonStr = generator.generateVercelJson(rules);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded.containsKey('rewrites'), isTrue);
      final rewrites = decoded['rewrites'] as List<dynamic>;

      expect(rewrites.length, 3);
      expect(rewrites[0], {
        'source': '/api/:path*',
        'destination': 'https://api.example.com/:path*',
      });
      expect(rewrites[1], {
        'source': '/auth/:path*',
        'destination': 'https://auth.example.com/auth/:path*',
      });
      expect(rewrites[2], {
        'source': '/(.*)',
        'destination': '/index.html',
      });
    });
  });

  group('Nginx Conf Generation', () {
    test('contains proxy_pass, four proxy_set_header lines, and try_files fallback', () {
      final rules = [
        BloomDevProxyRule(
          pathPrefix: '/api',
          targetUri: Uri.parse('http://127.0.0.1:8090'),
          stripPrefix: false,
        ),
      ];

      final output = generator.generateNginxConf(rules, root: '/var/www/html');

      expect(output, contains('root /var/www/html;'));
      expect(output, contains('proxy_pass http://127.0.0.1:8090;'));
      expect(output, contains('proxy_set_header Host 127.0.0.1;'));
      expect(output, contains(r'proxy_set_header X-Real-IP $remote_addr;'));
      expect(output, contains(r'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;'));
      expect(output, contains(r'proxy_set_header X-Forwarded-Proto $scheme;'));
      expect(output, contains(r'try_files $uri $uri/ /index.html;'));
    });

    test('nginx trailing-slash differs between stripPrefix true and false', () {
      final ruleStrip = BloomDevProxyRule(
        pathPrefix: '/api',
        targetUri: Uri.parse('http://127.0.0.1:8090'),
        stripPrefix: true,
      );

      final ruleKeep = BloomDevProxyRule(
        pathPrefix: '/api',
        targetUri: Uri.parse('http://127.0.0.1:8090'),
        stripPrefix: false,
      );

      final confStrip = generator.generateNginxConf([ruleStrip], root: '/app');
      final confKeep = generator.generateNginxConf([ruleKeep], root: '/app');

      expect(confStrip, contains('proxy_pass http://127.0.0.1:8090/;'));
      expect(confKeep, contains('proxy_pass http://127.0.0.1:8090;'));
      expect(confStrip, isNot(equals(confKeep)));
    });
  });

  group('Dockerfile & Compose Generation', () {
    test('Dockerfile contains expected stages and EXPOSE for static and server cases', () {
      final staticDocker = generator.generateDockerfile(appName: 'my_app', includeServer: false);
      // The static image is single-stage: the bundle is already built by the
      // CLI before this Dockerfile runs, so there is no Dart build stage.
      expect(staticDocker, contains('FROM nginx:alpine'));
      expect(staticDocker, isNot(contains('FROM dart:stable AS build')));
      expect(staticDocker, contains('EXPOSE 8080'));

      final serverDocker = generator.generateDockerfile(appName: 'my_app', includeServer: true);
      expect(serverDocker, contains('FROM dart:stable AS build'));
      expect(serverDocker, contains('FROM scratch'));
      expect(serverDocker, contains('dart compile exe bin/server.dart'));
      expect(serverDocker, contains('EXPOSE 8080'));
    });

    test('Docker compose contains service definition and healthcheck', () {
      final compose = generator.generateDockerCompose(appName: 'my_app');
      expect(compose, contains('services:'));
      expect(compose, contains('image: my_app:latest'));
      expect(compose, contains('PORT=8080'));
      expect(compose, contains('healthcheck:'));
    });
  });

  group('writeAll', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bloom_host_write_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes only requested formats and creates files properly', () {
      final rules = [
        BloomDevProxyRule(
          pathPrefix: '/api',
          targetUri: Uri.parse('https://api.example.com'),
          stripPrefix: true,
        ),
      ];

      final files = generator.writeAll(
        outputDir: tempDir,
        rules: rules,
        appName: 'test_bloom',
        formats: {BloomWebHostFormat.netlify, BloomWebHostFormat.vercel},
      );

      expect(files.length, 2);
      expect(File(p.join(tempDir.path, '_redirects')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'vercel.json')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'nginx.conf')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'Dockerfile')).existsSync(), isFalse);
    });
  });

  // Regression tests for defects found by running the generated configuration
  // against a real nginx container rather than only inspecting the text.
  group('BloomHostConfigGenerator regressions', () {
    const generator = BloomHostConfigGenerator();

    test('enlarges proxy header buffers so large upstream headers do not 502', () {
      // nginx defaults to a 4k/8k header buffer. GitHub's Set-Cookie and CSP
      // headers exceed it, and nginx then answers 502 "upstream sent too big
      // header" -- verified live before this fix.
      final conf = generator.generateNginxConf(
        [
          BloomDevProxyRule(
            pathPrefix: '/gh',
            targetUri: Uri.parse('https://github.com'),
            stripPrefix: true,
          ),
        ],
        root: '/usr/share/nginx/html',
      );

      expect(conf, contains('proxy_buffer_size 16k;'));
      expect(conf, contains('proxy_buffers 8 16k;'));
      expect(conf, contains('proxy_busy_buffers_size 32k;'));
    });

    test('sends TLS SNI only for https upstreams', () {
      final httpsConf = generator.generateNginxConf(
        [
          BloomDevProxyRule(
            pathPrefix: '/gh',
            targetUri: Uri.parse('https://github.com'),
          ),
        ],
        root: '/srv',
      );
      expect(httpsConf, contains('proxy_ssl_server_name on;'));

      final httpConf = generator.generateNginxConf(
        [
          BloomDevProxyRule(
            pathPrefix: '/api',
            targetUri: Uri.parse('http://127.0.0.1:8090'),
          ),
        ],
        root: '/srv',
      );
      expect(httpConf, isNot(contains('proxy_ssl_server_name')));
    });

    test('static Dockerfile copies the prebuilt bundle and never compiles Dart', () {
      final dockerfile = generator.generateDockerfile(
        appName: 'demo',
        includeServer: false,
        staticSourceDir: 'web',
      );

      expect(dockerfile, contains('FROM nginx:alpine'));
      expect(dockerfile, contains('COPY web /usr/share/nginx/html'));
      // The bundle is already built by the CLI; a Dart build stage here would
      // only copy a directory that does not exist yet for web_dom projects.
      expect(dockerfile, isNot(contains('dart pub get')));
      expect(dockerfile, isNot(contains('dart compile')));
    });

    test('server Dockerfile compiles the server entrypoint', () {
      final dockerfile = generator.generateDockerfile(
        appName: 'demo',
        includeServer: true,
      );

      expect(dockerfile, contains('dart compile exe bin/server.dart'));
      expect(dockerfile, contains('FROM scratch'));
      expect(dockerfile, contains('EXPOSE 8080'));
    });
  });
}
