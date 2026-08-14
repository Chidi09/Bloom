// test/bloom_dev_server_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/dev/dev_server.dart';
import '../lib/src/dev/mdns_discovery.dart';
import '../lib/src/dev/qr_renderer.dart';
import '../lib/src/utils/project.dart';

void main() {
  group('Phase 5: QR Terminal Renderer', () {
    test('renders high-contrast ANSI string with Unicode half blocks', () {
      final qrText = QrTerminalRenderer.render('bloom://dev-server?host=127.0.0.1&port=8080&id=test');
      expect(qrText, isNotEmpty);
      expect(qrText.contains('\x1B['), true); // Has ANSI escape codes
      expect(qrText.contains('█') || qrText.contains('▀') || qrText.contains('▄'), true);
    });
  });

  group('Phase 5: Local Network Discovery', () {
    test('resolves local IPv4 network address', () async {
      final ip = await MdnsDiscovery.getLocalIp();
      expect(ip, isNotEmpty);
      expect(RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(ip), true);
    });
  });

  group('Phase 5: BloomDevServer Endpoints', () {
    late Directory tempDir;
    late BloomDevServer devServer;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('bloom_dev_server_test_');

      // Create dummy bloom.yaml and routes directory
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: dev_test_app\nversion: 1.2.3\n');

      final routesDir = Directory(p.join(tempDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('class IndexRoute {}');
      File(p.join(routesDir.path, 'profile.dart')).writeAsStringSync('class ProfileRoute {}');

      final project = BloomProject.fromDirectory(tempDir);
      devServer = BloomDevServer(project, preferredPort: 9190);
      await devServer.start();
    });

    tearDown(() async {
      await devServer.stop();
      tempDir.deleteSync(recursive: true);
    });

    test('serves health status on /health', () async {
      final res = await http.get(Uri.parse('${devServer.httpUrl}/health'));
      expect(res.statusCode, 200);

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['status'], 'ok');
      expect(json['project'], 'dev_test_app');
      expect(json['hotReloadActive'], true);
    });

    test('serves project manifest on /manifest.json', () async {
      final res = await http.get(Uri.parse('${devServer.httpUrl}/manifest.json'));
      expect(res.statusCode, 200);

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['project'], 'dev_test_app');
      expect(json['version'], '1.2.3');
      expect(json['routes'], isList);

      final routes = json['routes'] as List;
      expect(routes.length, 2);
    });

    test('registers paired device on POST /devices/pair', () async {
      final res = await http.post(
        Uri.parse('${devServer.httpUrl}/devices/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': 'pixel_8_pro',
          'name': 'Google Pixel 8 Pro',
          'os': 'Android 14',
          'model': 'Pixel 8 Pro',
        }),
      );

      expect(res.statusCode, 200);
      expect(devServer.pairedDevices.length, 1);
      expect(devServer.pairedDevices.first['name'], 'Google Pixel 8 Pro');
    });
  });
}
