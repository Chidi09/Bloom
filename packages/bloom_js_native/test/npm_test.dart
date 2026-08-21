import 'dart:convert';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('NpmDependency + NpmRegistry', () {
    setUp(() => NpmRegistry.clear());

    test('registers and generates import map JSON', () {
      NpmRegistry.register(const NpmDependency('zod', '^3.23.0'));
      NpmRegistry.register(const NpmDependency('date-fns', '3.6.0'));
      final json = NpmRegistry.generateImportMapJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final imports = decoded['imports'] as Map<String, dynamic>;
      expect(imports['zod'], 'https://esm.sh/zod@^3.23.0');
      expect(imports['date-fns'], 'https://esm.sh/date-fns@3.6.0');
    });

    test('generates importmap tag', () {
      NpmRegistry.register(const NpmDependency('zod', '^3.23.0'));
      final tag = NpmRegistry.generateImportMapTag();
      expect(tag, startsWith('<script type="importmap">'));
      expect(tag, endsWith('</script>'));
      expect(tag, contains('zod'));
    });

    test('custom importAs specifier', () {
      NpmRegistry.register(const NpmDependency('lodash', '^4.17.0', importAs: 'lodash-es'));
      final map = NpmRegistry.toMap()['imports'] as Map<String, dynamic>;
      expect(map.containsKey('lodash-es'), isTrue);
      expect(map['lodash-es'], contains('lodash@'));
    });

    test('custom cdn', () {
      const dep = NpmDependency('zod', '^3.23.0', cdn: 'https://cdn.jsdelivr.net/npm');
      expect(dep.url, 'https://cdn.jsdelivr.net/npm/zod@^3.23.0');
    });

    test('clear removes all', () {
      NpmRegistry.register(const NpmDependency('zod', '^3.23.0'));
      NpmRegistry.clear();
      expect(NpmRegistry.all, isEmpty);
    });

    test('overwrite same specifier wins', () {
      NpmRegistry.register(const NpmDependency('zod', '^3.23.0'));
      NpmRegistry.register(const NpmDependency('zod', '^3.24.0'));
      expect(NpmRegistry.all['zod']!.version, '^3.24.0');
    });

    test('integrity field round-trips through toJson', () {
      final dep = NpmDependency('zod', '^3.23.0', integrity: 'sha384-abc123');
      expect(dep.toJson()['integrity'], 'sha384-abc123');
    });

    test('subPath entry appears in scopes block', () {
      NpmRegistry.clear();
      NpmRegistry.register(const NpmDependency('lucide', '^0.460.0'));
      NpmRegistry.register(const NpmDependency('lucide', '^0.460.0', subPath: 'icons', importAs: 'lucide/icons'));
      final json = NpmRegistry.generateImportMapJson();
      expect(json, contains('"scopes"'));
      NpmRegistry.clear();
    });

    test('conflicts() returns empty list by default', () {
      NpmRegistry.clear();
      NpmRegistry.register(const NpmDependency('zod', '^3.23.0'));
      expect(NpmRegistry.conflicts(), isEmpty);
      NpmRegistry.clear();
    });
  });
}
