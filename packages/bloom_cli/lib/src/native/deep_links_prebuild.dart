// lib/src/native/deep_links_prebuild.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';

class DeepLinksPrebuild {
  final Directory rootDir;

  DeepLinksPrebuild(this.rootDir);

  /// Generates domain verification configuration files (.well-known/assetlinks.json and apple-app-site-association).
  Future<bool> synchronize({
    required Map<dynamic, dynamic>? deepLinks,
    required String? packageName,
    required String? iosBundleId,
  }) async {
    if (deepLinks == null || deepLinks['enabled'] != true) {
      return true;
    }

    final rawDomains = deepLinks['domains'] is List ? deepLinks['domains'] as List : [];
    if (rawDomains.isEmpty) return true;

    print(Ansi.step('  Deep Links: Generating .well-known domain verification configuration...'));

    final wellKnownDir = Directory(p.join(rootDir.path, 'web', '.well-known'))..createSync(recursive: true);

    final assetLinksJson = <Map<String, dynamic>>[];
    final aasaDetails = <Map<String, dynamic>>[];

    for (final item in rawDomains) {
      final domain = item is String ? item : (item is Map ? item['host']?.toString() ?? 'example.com' : 'example.com');
      final fingerprints = (item is Map && item['sha256_cert_fingerprints'] is List)
          ? List<String>.from(item['sha256_cert_fingerprints'] as List)
          : ((item is Map && item['fingerprints'] is List)
              ? List<String>.from(item['fingerprints'] as List)
              : <String>[]);

      final teamId = item is Map
          ? (item['ios_team_id']?.toString() ?? item['team_id']?.toString() ?? 'TEAMID')
          : 'TEAMID';

      if (fingerprints.isEmpty) {
        print(Ansi.warn('    Notice: No sha256_cert_fingerprints specified for "$domain". Adding dev placeholder.'));
        fingerprints.add('00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00');
      }

      assetLinksJson.add({
        "relation": ["delegate_permission/common.handle_all_urls"],
        "target": {
          "namespace": "android_app",
          "package_name": packageName ?? "com.example.bloom",
          "sha256_cert_fingerprints": fingerprints,
        }
      });

      aasaDetails.add({
        "appID": "$teamId.${iosBundleId ?? "com.example.bloom"}",
        "paths": ["*"],
      });
    }

    // 1. Android assetlinks.json
    final assetLinksFile = File(p.join(wellKnownDir.path, 'assetlinks.json'));
    assetLinksFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(assetLinksJson));
    print('    ${Ansi.dim}+ Generated: web/.well-known/assetlinks.json${Ansi.reset}');

    // 2. iOS apple-app-site-association (AASA)
    final aasaFile = File(p.join(wellKnownDir.path, 'apple-app-site-association'));
    final aasaJson = {
      "applinks": {
        "apps": [],
        "details": aasaDetails,
      }
    };
    aasaFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(aasaJson));
    print('    ${Ansi.dim}+ Generated: web/.well-known/apple-app-site-association${Ansi.reset}');

    return true;
  }
}
