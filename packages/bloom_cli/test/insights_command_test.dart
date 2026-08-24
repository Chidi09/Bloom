// test/insights_command_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/commands/insights_command.dart';
import '../lib/src/dev/dev_server.dart';
import '../lib/src/utils/project.dart';

void main() {
  group('InsightsCommand CLI', () {
    late Directory tempDir;
    late BloomDevServer devServer;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('bloom_insights_cmd_test_');

      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: test_insights_cmd_app\nversion: 1.0.0\n');

      final project = BloomProject.fromDirectory(tempDir);
      devServer = BloomDevServer(project, preferredPort: 9480, enableDiscovery: false);
      await devServer.start();
    });

    tearDown(() async {
      await devServer.stop();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('returns 0 and prints JSON when --json and --url are passed', () async {
      // Make a sample request
      final res = await http.get(Uri.parse('${devServer.httpUrl}/health'));
      expect(res.statusCode, 200);

      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(InsightsCommand());

      final exitCode = await runZoned(
        () => runner.run(['insights', '--url', devServer.httpUrl, '--json']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, 0);
      final fullOutput = logs.join('\n');
      final parsed = jsonDecode(fullOutput) as Map<String, dynamic>;
      expect(parsed['project'], 'test_insights_cmd_app');
      expect(parsed['total'], 1);
      final reqs = parsed['requests'] as List;
      expect(reqs.length, 1);
      expect(reqs[0]['path'], '/health');
      expect(reqs[0]['statusCode'], 200);
      expect(reqs[0]['method'], 'GET');
    });

    test('returns 0 and prints formatted table for human-readable output', () async {
      // Make requests
      await http.get(Uri.parse('${devServer.httpUrl}/health'));
      await http.get(Uri.parse('${devServer.httpUrl}/not_found'));

      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(InsightsCommand());

      final exitCode = await runZoned(
        () => runner.run(['insights', '--url', devServer.httpUrl]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, 0);
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('Recent requests (showing 2 of 2):'));
      expect(fullOutput, contains('/not_found'));
      expect(fullOutput, contains('/health'));
      expect(fullOutput, contains('200'));
      expect(fullOutput, contains('404'));
    });

    test('respects --limit flag', () async {
      await http.get(Uri.parse('${devServer.httpUrl}/health'));
      await http.get(Uri.parse('${devServer.httpUrl}/not_found'));
      await http.get(Uri.parse('${devServer.httpUrl}/health'));

      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(InsightsCommand());

      final exitCode = await runZoned(
        () => runner.run(['insights', '--url', devServer.httpUrl, '--limit', '1']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, 0);
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('Recent requests (showing 1 of 3):'));
    });

    test('returns 1 when --url points to unreachable address', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(InsightsCommand());

      final exitCode = await runZoned(
        () => runner.run(['insights', '--url', 'http://127.0.0.1:59999']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, 1);
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('Failed to reach Bloom dev server'));
    });

    test('returns 1 when auto-discovery finds no dev server listening', () async {
      final emptyDir = Directory.systemTemp.createTempSync('bloom_empty_insights_');
      try {
        final logs = <String>[];
        final runner = CommandRunner<int>('bloom', 'Bloom CLI')
          ..addCommand(InsightsCommand());

        final exitCode = await runZoned(
          () => runner.run(['insights', '--project-dir', emptyDir.path]),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              logs.add(line);
            },
          ),
        );

        expect(exitCode, 1);
        final fullOutput = logs.join('\n');
        expect(
          fullOutput.contains('Could not connect to a running Bloom dev server') ||
              fullOutput.contains('Failed to reach Bloom dev server'),
          isTrue,
        );
      } finally {
        if (emptyDir.existsSync()) {
          try {
            emptyDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });
  });
}
