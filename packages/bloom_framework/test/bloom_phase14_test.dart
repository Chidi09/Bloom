// test/bloom_phase14_test.dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter_test/flutter_test.dart';

class TestConfigSchema extends BloomEnvironmentSchema {
  late final apiUrl = requireString('API_BASE_URL', description: 'Base API URL');
  late final stripeKey = requireString('STRIPE_KEY');
  late final maxRetries = optionalInt('MAX_RETRIES', defaultValue: 3);
  late final debugTelemetry = optionalBool('ENABLE_TELEMETRY', defaultValue: false);
  late final rateLimit = optionalDouble('RATE_LIMIT', defaultValue: 10.5);
  late final authEndpoint = optionalUri('AUTH_ENDPOINT');

  @override
  void validate() {
    apiUrl;
    stripeKey;
    maxRetries;
    debugTelemetry;
    rateLimit;
    authEndpoint;
  }
}

class MissingRequiredSchema extends BloomEnvironmentSchema {
  late final requiredSecret = requireString('SUPER_SECRET_KEY');

  @override
  void validate() {
    requiredSecret;
  }
}

class BadIntSchema extends BloomEnvironmentSchema {
  late final retries = requireInt('MAX_RETRIES');

  @override
  void validate() {
    retries;
  }
}

class BadUriSchema extends BloomEnvironmentSchema {
  late final uri = requireUri('INVALID_URI');

  @override
  void validate() {
    uri;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Bloom.reset();
  });

  tearDown(() async {
    await Bloom.reset();
  });

  group('Phase 14: Validated Environment Schemas (C1)', () {
    test('Validates complete schema successfully with typed fields', () {
      BloomEnv.loadMap({
        'API_BASE_URL': 'https://api.bloom.dev',
        'STRIPE_KEY': 'pk_live_123456789',
        'MAX_RETRIES': '5',
        'ENABLE_TELEMETRY': 'true',
        'RATE_LIMIT': '42.0',
        'AUTH_ENDPOINT': 'https://auth.bloom.dev/oauth',
      });

      final schema = BloomEnv.validate(TestConfigSchema());

      expect(schema.apiUrl, 'https://api.bloom.dev');
      expect(schema.stripeKey, 'pk_live_123456789');
      expect(schema.maxRetries, 5);
      expect(schema.debugTelemetry, isTrue);
      expect(schema.rateLimit, 42.0);
      expect(schema.authEndpoint, Uri.parse('https://auth.bloom.dev/oauth'));
    });

    test('Fails fast on missing required string key with descriptive exception', () {
      BloomEnv.clear();

      expect(
        () => BloomEnv.validate(MissingRequiredSchema()),
        throwsA(isA<BloomEnvironmentException>().having(
          (e) => e.message,
          'message',
          contains('SUPER_SECRET_KEY'),
        )),
      );
    });

    test('Bloom.boot() fails immediately when environmentSchema has missing keys (C1)', () async {
      BloomEnv.clear();

      expect(
        () => Bloom.boot(
          environmentSchema: MissingRequiredSchema(),
        ),
        throwsA(isA<BloomEnvironmentException>().having(
          (e) => e.message,
          'message',
          contains('SUPER_SECRET_KEY'),
        )),
      );

      // Verify boot did not mark as booted
      expect(Bloom.isBooted, isFalse);
    });

    test('Throws on invalid integer format', () {
      BloomEnv.loadMap({
        'MAX_RETRIES': 'not_a_number',
      });

      expect(
        () => BloomEnv.validate(BadIntSchema()),
        throwsA(isA<BloomEnvironmentException>().having(
          (e) => e.message,
          'message',
          contains('not a valid integer'),
        )),
      );
    });

    test('Throws on invalid URI format in requireUri', () {
      BloomEnv.loadMap({
        'INVALID_URI': 'not a uri at all %%%',
      });

      expect(
        () => BloomEnv.validate(BadUriSchema()),
        throwsA(isA<BloomEnvironmentException>().having(
          (e) => e.message,
          'message',
          contains('not a valid absolute URI'),
        )),
      );
    });
  });

  group('Phase 14: Dynamic Feature Flags', () {
    test('Registers, checks, and updates feature flags dynamically', () {
      Bloom.features.register('new_checkout_flow', defaultValue: false);
      Bloom.features.register('beta_search', defaultValue: true);

      expect(Bloom.features.isEnabled('new_checkout_flow'), isFalse);
      expect(Bloom.features.isEnabled('beta_search'), isTrue);
      expect(Bloom.features.isEnabled('unregistered_flag', defaultValue: true), isTrue);

      Bloom.features.setOverride('new_checkout_flow', true);
      expect(Bloom.features.isEnabled('new_checkout_flow'), isTrue);

      Bloom.features.clearOverrides();
      expect(Bloom.features.isEnabled('new_checkout_flow'), isFalse);
    });

    test('Provides signals reactivity on watch()', () {
      final flagSignal = Bloom.features.watch('dark_mode_v2', defaultValue: false);
      expect(flagSignal.value, isFalse);

      var observedValue = false;
      final unwatch = effect(() {
        observedValue = flagSignal.value;
      });

      expect(observedValue, isFalse);

      Bloom.features.setOverride('dark_mode_v2', true);
      expect(observedValue, isTrue);

      unwatch();
    });

    test('Initializes feature flags from config on Bloom.boot()', () async {
      const configYaml = '''
name: test_app
version: 1.0.0
custom:
  feature_flags:
    flag_a: true
    flag_b: false
''';

      await Bloom.boot(configYaml: configYaml);

      expect(Bloom.features.isEnabled('flag_a'), isTrue);
      expect(Bloom.features.isEnabled('flag_b'), isFalse);
    });
  });

  group('Phase 14: Type-Safe Configuration (bloom.config.dart)', () {
    test('Constructs and converts BloomAppConfig to BloomConfig', () {
      const appConfig = BloomAppConfig(
        name: 'bloom_shop',
        version: '1.2.0',
        buildNumber: '42',
        description: 'Bloom Shop Mobile',
        mode: NativeMode.managed,
        platforms: PlatformsConfig(
          android: AndroidPlatform(minSdk: 24, targetSdk: 34, package: 'dev.bloom.shop'),
          ios: IosPlatform(minVersion: '15.0', bundleIdentifier: 'dev.bloom.shop'),
        ),
        plugins: [
          BloomPlugin('secure-storage'),
          BloomPlugin('camera', config: {'quality': 'high'}),
        ],
        featureFlags: {
          'promo_banners': true,
        },
      );

      final bloomConfig = appConfig.toBloomConfig();

      expect(bloomConfig.name, 'bloom_shop');
      expect(bloomConfig.version, '1.2.0');
      expect(bloomConfig.buildNumber, '42');
      expect(bloomConfig.platforms.androidMinSdk, 24);
      expect(bloomConfig.platforms.androidTargetSdk, 34);
      expect(bloomConfig.platforms.androidPackage, 'dev.bloom.shop');
      expect(bloomConfig.platforms.iosMinVersion, '15.0');
      expect(bloomConfig.platforms.iosBundleIdentifier, 'dev.bloom.shop');
      expect(bloomConfig.plugins.containsKey('secure-storage'), isTrue);
      expect(bloomConfig.plugins.containsKey('camera'), isTrue);
      expect(bloomConfig.custom['feature_flags']['promo_banners'], isTrue);

      // Round trip back to BloomAppConfig
      final roundTrip = BloomAppConfig.fromBloomConfig(bloomConfig);
      expect(roundTrip.name, 'bloom_shop');
      expect(roundTrip.version, '1.2.0');
      expect(roundTrip.mode, NativeMode.managed);
      expect(roundTrip.platforms.android.minSdk, 24);
      expect(roundTrip.plugins.length, 2);
    });
  });
}
