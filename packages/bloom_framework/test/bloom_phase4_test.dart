// test/bloom_phase4_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Bloom.reset();
  });

  group('Phase 4: BloomFlavors Configuration', () {
    test('parses multi-environment flavors from bloom.yaml', () {
      const sampleYaml = '''
schema: 1
name: my_app
version: 1.0.0
flavors:
  development:
    app_name: "My App (Dev)"
    app_id: "com.example.myapp.dev"
    env_file: ".env.development"
  production:
    app_name: "My App"
    app_id: "com.example.myapp"
    env_file: ".env.production"
''';

      final config = BloomConfig.fromYaml(sampleYaml);
      expect(config.flavors.length, 2);

      final devFlavor = config.flavors['development'];
      expect(devFlavor, isNotNull);
      expect(devFlavor!.appName, 'My App (Dev)');
      expect(devFlavor.appId, 'com.example.myapp.dev');
      expect(devFlavor.envFile, '.env.development');

      final prodFlavor = config.flavors['production'];
      expect(prodFlavor, isNotNull);
      expect(prodFlavor!.appName, 'My App');
      expect(prodFlavor.appId, 'com.example.myapp');
      expect(prodFlavor.envFile, '.env.production');
    });
  });

  group('Phase 4: BloomDeepLinks', () {
    test('dispatches deep links to custom handler', () async {
      Uri? handledUri;
      await BloomDeepLinks.initialize(
        onLink: (uri) {
          handledUri = uri;
        },
      );

      final testUri = Uri.parse('https://example.com/products/42?ref=bloom');
      BloomDeepLinks.dispatch(testUri);

      expect(handledUri, testUri);
      expect(handledUri?.path, '/products/42');
      expect(handledUri?.queryParameters['ref'], 'bloom');

      BloomDeepLinks.dispose();
    });
  });

  group('Phase 4: BloomBackground', () {
    test('registers and executes background tasks', () async {
      bool taskExecuted = false;
      Map<String, dynamic>? receivedData;

      BloomBackground.registerTask('sync_data', (data) {
        taskExecuted = true;
        receivedData = data;
        return true;
      });

      final success = await BloomBackground.executeTask('sync_data', {'batch': 1});
      expect(success, true);
      expect(taskExecuted, true);
      expect(receivedData?['batch'], 1);
    });

    test('returns false for unregistered tasks', () async {
      final success = await BloomBackground.executeTask('unregistered_task');
      expect(success, false);
    });
  });
}
