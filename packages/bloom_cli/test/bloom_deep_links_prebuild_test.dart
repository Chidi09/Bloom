// test/bloom_deep_links_prebuild_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/native/deep_links_prebuild.dart';

void main() {
  group('Phase 4: Deep Links Prebuild Engine', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_deeplinks_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('generates .well-known/assetlinks.json and apple-app-site-association', () async {
      final prebuild = DeepLinksPrebuild(tempDir);

      final success = await prebuild.synchronize(
        deepLinks: {
          'enabled': true,
          'domains': ['app.bloom.dev'],
        },
        packageName: 'dev.bloom.app',
        iosBundleId: 'dev.bloom.app',
      );

      expect(success, true);

      final assetLinksFile = File(p.join(tempDir.path, 'web', '.well-known', 'assetlinks.json'));
      expect(assetLinksFile.existsSync(), true);

      final assetLinksContent = jsonDecode(assetLinksFile.readAsStringSync()) as List;
      expect(assetLinksContent.first['target']['package_name'], 'dev.bloom.app');

      final aasaFile = File(p.join(tempDir.path, 'web', '.well-known', 'apple-app-site-association'));
      expect(aasaFile.existsSync(), true);

      final aasaContent = jsonDecode(aasaFile.readAsStringSync()) as Map;
      expect(aasaContent['applinks']['details'][0]['appID'], 'TEAMID.dev.bloom.app');
    });
  });
}
