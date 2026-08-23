// test/deployment/proxy_config_loader_test.dart
import 'package:test/test.dart';
import 'package:bloom_cli/src/deployment/proxy_config_loader.dart';

void main() {
  group('loadProxyRules', () {
    test('absent proxy key returns empty list', () {
      final rules = loadProxyRules({});
      expect(rules, isEmpty);

      final rulesFromNull = loadProxyRules({'proxy': null});
      expect(rulesFromNull, isEmpty);
    });

    test('non-map proxy throws FormatException', () {
      expect(
        () => loadProxyRules({'proxy': 'not-a-map'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid "proxy" configuration in bloom.yaml: expected a YAML map.'),
          ),
        ),
      );

      expect(
        () => loadProxyRules({'proxy': ['list', 'of', 'items']}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rules are returned sorted longest-prefix-first', () {
      final config = {
        'proxy': {
          '/api': {
            'target': 'http://127.0.0.1:8090',
            'strip_prefix': false,
          },
          '/api/v2/auth': {
            'target': 'https://auth.example.com',
            'strip_prefix': true,
          },
          '/api/v2': {
            'target': 'https://v2.example.com',
            'strip_prefix': false,
          },
          '/gh': {
            'target': 'https://github.com',
            'strip_prefix': true,
          },
        },
      };

      final rules = loadProxyRules(config);

      expect(rules.length, 4);
      expect(rules[0].pathPrefix, '/api/v2/auth');
      expect(rules[1].pathPrefix, '/api/v2');
      expect(rules[2].pathPrefix, '/api');
      expect(rules[3].pathPrefix, '/gh');

      // Verify lengths are monotonically non-increasing
      for (var i = 0; i < rules.length - 1; i++) {
        expect(
          rules[i].pathPrefix.length >= rules[i + 1].pathPrefix.length,
          isTrue,
        );
      }
    });

    test('a malformed inner rule throws with the offending key named', () {
      final config = {
        'proxy': {
          '/api/valid': {
            'target': 'http://127.0.0.1:8090',
          },
          '/api/broken': {
            // Missing required target URL
            'strip_prefix': true,
          },
        },
      };

      expect(
        () => loadProxyRules(config),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('/api/broken'), contains('target')),
          ),
        ),
      );
    });
  });
}
