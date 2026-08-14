// test/bloom_phase5_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Bloom.reset();
  });

  group('Phase 5: BloomGoClient URI Parser', () {
    test('parses bloom:// custom pairing URI', () {
      final uri = Uri.parse('bloom://dev-server?host=192.168.1.100&port=8080&id=my_flutter_app');
      final parsed = BloomGoClient.parseDevServerUri(uri);

      expect(parsed['host'], '192.168.1.100');
      expect(parsed['port'], 8080);
      expect(parsed['projectId'], 'my_flutter_app');
      expect(parsed['httpBaseUrl'], 'http://192.168.1.100:8080');
    });

    test('throws on non-bloom URI scheme', () {
      final uri = Uri.parse('https://example.com/dev');
      expect(
        () => BloomGoClient.parseDevServerUri(uri),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on empty host in URI', () {
      final uri = Uri.parse('bloom://dev-server?host=&port=8080');
      expect(
        () => BloomGoClient.parseDevServerUri(uri),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Phase 5: BloomProjectManifest Model', () {
    test('deserializes JSON manifest correctly', () {
      final json = {
        'project': 'counter_sample',
        'version': '2.0.0',
        'host': '10.0.0.5',
        'port': 9000,
        'devServerUri': 'bloom://dev-server?host=10.0.0.5&port=9000&id=counter_sample',
        'routes': [
          {'path': '/', 'file': 'index.dart'},
          {'path': '/settings', 'file': 'settings.dart'},
        ],
        'platforms': {'android': {'min_sdk': 26}},
        'features': {'routing': true, 'state': true},
      };

      final manifest = BloomProjectManifest.fromJson(json);
      expect(manifest.projectName, 'counter_sample');
      expect(manifest.version, '2.0.0');
      expect(manifest.host, '10.0.0.5');
      expect(manifest.port, 9000);
      expect(manifest.routes.length, 2);
      expect(manifest.routes.first['path'], '/');
      expect(manifest.platforms['android']['min_sdk'], 26);
    });
  });

  group('Phase 5: Discovery Listener', () {
    test('instantiates discovery listener', () {
      final listener = BloomDiscoveryListener();
      expect(listener, isNotNull);
      listener.stop();
    });
  });
}
