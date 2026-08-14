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

    final domains = deepLinks['domains'] is List ? List<String>.from(deepLinks['domains']) : <String>[];
    if (domains.isEmpty) return true;

    print(Ansi.step('  Deep Links: Generating .well-known domain verification templates...'));

    final wellKnownDir = Directory(p.join(rootDir.path, 'web', '.well-known'))..createSync(recursive: true);

    // 1. Android assetlinks.json
    final assetLinksFile = File(p.join(wellKnownDir.path, 'assetlinks.json'));
    final assetLinksJson = [
      {
        "relation": ["delegate_permission/common.handle_all_urls"],
        "target": {
          "namespace": "android_app",
          "package_name": packageName ?? "com.example.bloom",
          "sha256_cert_fingerprints": [
            "14:6D:E9:01:C3:59:E1:9F:8B:24:99:99:99:99:99:99:99:99:99:99:99:99:99:99:99:99:99:99:99:99:99:99"
          ]
        }
      }
    ];
    assetLinksFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(assetLinksJson));
    print('    ${Ansi.dim}+ Generated: web/.well-known/assetlinks.json${Ansi.reset}');

    // 2. iOS apple-app-site-association (AASA)
    final aasaFile = File(p.join(wellKnownDir.path, 'apple-app-site-association'));
    final aasaJson = {
      "applinks": {
        "apps": [],
        "details": [
          {
            "appID": "TEAMID.${iosBundleId ?? "com.example.bloom"}",
            "paths": ["*"]
          }
        ]
      }
    };
    aasaFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(aasaJson));
    print('    ${Ansi.dim}+ Generated: web/.well-known/apple-app-site-association${Ansi.reset}');

    return true;
  }
}
