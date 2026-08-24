// test/dev_server_insights_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/dev/dev_server.dart';
import '../lib/src/utils/project.dart';

void main() {
  group('BloomDevServer Request Insights', () {
    late Directory tempDir;
    late BloomDevServer devServer;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('bloom_insights_test_');

      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: test_insights_app\nversion: 1.0.0\n');

      final routesDir = Directory(p.join(tempDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('class IndexRoute {}');

      final project = BloomProject.fromDirectory(tempDir);
      devServer = BloomDevServer(project, preferredPort: 9380, enableDiscovery: false);
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

    test('captures requests with timing and exposes them on /__insights in reverse chronological order', () async {
      final baseUrl = devServer.httpUrl;

      // Make 3 requests
      final res1 = await http.get(Uri.parse('$baseUrl/health'));
      expect(res1.statusCode, 200);

      final res2 = await http.post(
        Uri.parse('$baseUrl/devices/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 'test_phone', 'name': 'Phone', 'os': 'Android'}),
      );
      expect(res2.statusCode, 200);

      final res3 = await http.get(Uri.parse('$baseUrl/nonexistent_path'));
      expect(res3.statusCode, 404);

      // Query /__insights
      final insightsRes = await http.get(Uri.parse('$baseUrl/__insights'));
      expect(insightsRes.statusCode, 200);

      final json = jsonDecode(insightsRes.body) as Map<String, dynamic>;
      expect(json['project'], 'test_insights_app');
      expect(json['total'], 3);

      final requests = json['requests'] as List;
      expect(requests.length, 3);

      // Most recent first: /nonexistent_path (404), /devices/pair (200), /health (200)
      final req0 = requests[0] as Map<String, dynamic>;
      expect(req0['method'], 'GET');
      expect(req0['path'], '/nonexistent_path');
      expect(req0['statusCode'], 404);
      expect(req0['durationMs'], isA<int>());
      expect(req0['durationMs'] as int, greaterThanOrEqualTo(0));
      expect(req0['timestamp'], isA<String>());

      final req1 = requests[1] as Map<String, dynamic>;
      expect(req1['method'], 'POST');
      expect(req1['path'], '/devices/pair');
      expect(req1['statusCode'], 200);
      expect(req1['durationMs'], isA<int>());

      final req2 = requests[2] as Map<String, dynamic>;
      expect(req2['method'], 'GET');
      expect(req2['path'], '/health');
      expect(req2['statusCode'], 200);
      expect(req2['durationMs'], isA<int>());

      // Ensure /__insights itself was NOT recorded
      for (final r in requests) {
        expect(r['path'], isNot('/__insights'));
      }

      // Querying /__insights again should not increase total
      final secondInsightsRes = await http.get(Uri.parse('$baseUrl/__insights'));
      final secondJson = jsonDecode(secondInsightsRes.body) as Map<String, dynamic>;
      expect(secondJson['total'], 3);
    });

    test('respects limit query parameter', () async {
      final baseUrl = devServer.httpUrl;

      // Make 4 requests
      await http.get(Uri.parse('$baseUrl/health'));
      await http.get(Uri.parse('$baseUrl/health'));
      await http.get(Uri.parse('$baseUrl/manifest.json'));
      await http.get(Uri.parse('$baseUrl/missing'));

      // Request limit=2
      final res = await http.get(Uri.parse('$baseUrl/__insights?limit=2'));
      expect(res.statusCode, 200);

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['total'], 4);

      final requests = json['requests'] as List;
      expect(requests.length, 2);

      // Most recent first: /missing then /manifest.json
      expect(requests[0]['path'], '/missing');
      expect(requests[1]['path'], '/manifest.json');
    });

    test('exposes requestLog public getter', () async {
      final baseUrl = devServer.httpUrl;
      await http.get(Uri.parse('$baseUrl/health'));

      expect(devServer.requestLog.length, 1);
      expect(devServer.requestLog.first['path'], '/health');
      expect(() => (devServer.requestLog as dynamic).add(<String, dynamic>{}), throwsUnsupportedError);
    });
  });
}
