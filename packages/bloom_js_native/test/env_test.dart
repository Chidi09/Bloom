import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomEnv', () {
    setUp(() => BloomEnv.clear());

    test('loadContent parses KEY=VALUE pairs', () {
      BloomEnv.loadContent('APP_ENV=production\nPORT=8080\n');
      expect(BloomEnv.get('APP_ENV'), 'production');
      expect(BloomEnv.get('PORT'), '8080');
    });

    test('loadContent strips surrounding quotes', () {
      BloomEnv.loadContent('SECRET="my_secret"\nOTHER=\'plain\'');
      expect(BloomEnv.get('SECRET'), 'my_secret');
      expect(BloomEnv.get('OTHER'), 'plain');
    });

    test('loadContent ignores comments and blank lines', () {
      BloomEnv.loadContent('# comment\n\nFOO=bar');
      expect(BloomEnv.get('FOO'), 'bar');
      expect(BloomEnv.has('# comment'), isFalse);
    });

    test('loadMap populates variables', () {
      BloomEnv.loadMap({'X': '1', 'Y': '2'});
      expect(BloomEnv.get('X'), '1');
      expect(BloomEnv.get('Y'), '2');
    });

    test('get returns defaultValue when key is absent', () {
      expect(BloomEnv.get('MISSING', defaultValue: 'fallback'), 'fallback');
    });

    test('get throws StateError when key absent and no default', () {
      expect(() => BloomEnv.get('NOPE'), throwsA(isA<StateError>()));
    });

    test('getOrNull returns null for missing key', () {
      expect(BloomEnv.getOrNull('NOPE'), isNull);
    });

    test('getInt parses valid int', () {
      BloomEnv.loadMap({'NUM': '42'});
      expect(BloomEnv.getInt('NUM'), 42);
    });

    test('getInt returns defaultValue when absent', () {
      expect(BloomEnv.getInt('NOPE', defaultValue: 99), 99);
    });

    test('getBool parses true values', () {
      BloomEnv.loadMap({'FLAG': 'true'});
      expect(BloomEnv.getBool('FLAG'), isTrue);
    });

    test('getBool parses false values', () {
      BloomEnv.loadMap({'FLAG': '0'});
      expect(BloomEnv.getBool('FLAG'), isFalse);
    });

    test('getDouble parses valid double', () {
      BloomEnv.loadMap({'PI': '3.14'});
      expect(BloomEnv.getDouble('PI'), 3.14);
    });

    test('overwrite=false does not overwrite existing keys', () {
      BloomEnv.loadMap({'KEY': 'original'});
      BloomEnv.loadMap({'KEY': 'new'}, overwrite: false);
      expect(BloomEnv.get('KEY'), 'original');
    });

    test('all returns unmodifiable snapshot', () {
      BloomEnv.loadMap({'A': '1', 'B': '2'});
      final all = BloomEnv.all;
      expect(all['A'], '1');
      expect(all['B'], '2');
      expect(() => (all as dynamic)['C'] = '3', throwsA(anything));
    });

    test('clear removes all variables', () {
      BloomEnv.loadMap({'K': 'v'});
      BloomEnv.clear();
      expect(BloomEnv.contains('K'), isFalse);
    });
  });

  group('BloomEnvironmentSchema', () {
    setUp(() => BloomEnv.clear());

    test('requireString returns value when present', () {
      BloomEnv.loadMap({'DB_URL': 'postgres://localhost'});
      final schema = _TestSchema();
      expect(schema.requireString('DB_URL'), 'postgres://localhost');
    });

    test('requireString throws when missing', () {
      final schema = _TestSchema();
      expect(
          () => schema.requireString('MISSING'), throwsA(isA<BloomEnvironmentException>()));
    });

    test('requireInt returns parsed int', () {
      BloomEnv.loadMap({'PORT': '3000'});
      final schema = _TestSchema();
      expect(schema.requireInt('PORT'), 3000);
    });

    test('requireInt throws for invalid value', () {
      BloomEnv.loadMap({'PORT': 'abc'});
      final schema = _TestSchema();
      expect(() => schema.requireInt('PORT'), throwsA(isA<BloomEnvironmentException>()));
    });

    test('requireBool returns true', () {
      BloomEnv.loadMap({'DEBUG': 'yes'});
      final schema = _TestSchema();
      expect(schema.requireBool('DEBUG'), isTrue);
    });

    test('requireBool throws for invalid', () {
      BloomEnv.loadMap({'DEBUG': 'maybe'});
      final schema = _TestSchema();
      expect(() => schema.requireBool('DEBUG'), throwsA(isA<BloomEnvironmentException>()));
    });

    test('requireUri returns parsed Uri', () {
      BloomEnv.loadMap({'API_URL': 'https://api.example.com'});
      final schema = _TestSchema();
      final uri = schema.requireUri('API_URL');
      expect(uri.host, 'api.example.com');
    });

    test('requireUri throws for non-absolute URI', () {
      BloomEnv.loadMap({'API_URL': 'not-a-uri'});
      final schema = _TestSchema();
      expect(() => schema.requireUri('API_URL'), throwsA(isA<BloomEnvironmentException>()));
    });

    test('optionalString returns default when missing', () {
      final schema = _TestSchema();
      expect(schema.optionalString('MISSING', defaultValue: 'default'), 'default');
    });

    test('optionalBool returns default when missing', () {
      final schema = _TestSchema();
      expect(schema.optionalBool('MISSING', defaultValue: true), isTrue);
    });

    test('BloomEnv.validate throws on failed schema', () {
      // No env vars loaded, _FailingSchema requires them
      expect(
          () => BloomEnv.validate(_FailingSchema()),
          throwsA(isA<BloomEnvironmentException>()));
    });
  });
}

class _TestSchema extends BloomEnvironmentSchema {}

class _FailingSchema extends BloomEnvironmentSchema {
  late final String required = requireString('REQUIRED_MISSING');

  @override
  void validate() {
    required; // trigger the late field evaluation
  }
}
