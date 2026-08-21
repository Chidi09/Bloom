import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Represents live package metadata fetched from the official NPM Registry API.
class NpmPackageInfo {
  final String name;
  final String version;
  final String description;
  final String? license;
  final String? typesEntry;
  final String? homepage;

  const NpmPackageInfo({
    required this.name,
    required this.version,
    required this.description,
    this.license,
    this.typesEntry,
    this.homepage,
  });
}

/// Represents a search result from `https://registry.npmjs.org/-/v1/search`.
class NpmSearchResult {
  final String name;
  final String version;
  final String description;
  final String? author;
  final double score;

  const NpmSearchResult({
    required this.name,
    required this.version,
    required this.description,
    this.author,
    required this.score,
  });
}

/// Dynamic resolver and client for the official NPM Registry and ESM CDN endpoints.
///
/// Enables Bloom to install, search, and bind **ANY** of the 2.5M+ packages on the NPM registry dynamically
/// without hardcoded restrictions.
class NpmResolver {
  static const String _esmBase = 'https://esm.sh';
  static const String _npmRegistryBase = 'https://registry.npmjs.org';

  final http.Client _client;
  NpmResolver({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  /// Fetches comprehensive package metadata directly from the live NPM Registry API.
  Future<NpmPackageInfo?> fetchPackageMetadata(String packageName) async {
    try {
      // Scoped packages like @formkit/auto-animate are encoded as @formkit%2Fauto-animate
      final encodedName = packageName.startsWith('@')
          ? '@${Uri.encodeComponent(packageName.substring(1))}'
          : Uri.encodeComponent(packageName);

      final uri = Uri.parse('$_npmRegistryBase/$encodedName');
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Bloom-CLI/0.2.3',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final distTags = data['dist-tags'] as Map<String, dynamic>?;
        final latestVersion = distTags?['latest']?.toString() ?? 'latest';
        final description = data['description']?.toString() ?? '';
        final license = data['license']?.toString();
        final homepage = data['homepage']?.toString();

        // Check types entry from latest version manifest if available
        String? typesEntry;
        final versions = data['versions'] as Map<String, dynamic>?;
        if (versions != null && versions.containsKey(latestVersion)) {
          final verData = versions[latestVersion] as Map<String, dynamic>;
          typesEntry = verData['types']?.toString() ?? verData['typings']?.toString();
        }

        return NpmPackageInfo(
          name: packageName,
          version: latestVersion,
          description: description,
          license: license,
          typesEntry: typesEntry,
          homepage: homepage,
        );
      }
    } catch (_) {
      // Network or parsing failure
    }
    return null;
  }

  /// Searches the live NPM Registry API for packages matching [query].
  Future<List<NpmSearchResult>> search(String query, {int limit = 15}) async {
    try {
      final uri = Uri.parse('$_npmRegistryBase/-/v1/search?text=${Uri.encodeQueryComponent(query)}&size=$limit');
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Bloom-CLI/0.2.3',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final objects = data['objects'] as List<dynamic>? ?? [];

        return objects.map((obj) {
          final pkg = (obj as Map<String, dynamic>)['package'] as Map<String, dynamic>;
          final score = (obj['score'] as Map<String, dynamic>?)?['final'] as num? ?? 0.0;

          return NpmSearchResult(
            name: pkg['name']?.toString() ?? '',
            version: pkg['version']?.toString() ?? 'latest',
            description: pkg['description']?.toString() ?? '',
            author: (pkg['publisher'] as Map<String, dynamic>?)?['username']?.toString(),
            score: score.toDouble(),
          );
        }).toList();
      }
    } catch (_) {
      // Network failure
    }
    return [];
  }

  /// Resolves 'latest' or semver tags to an exact version via NPM registry.
  Future<String> resolveVersion(String packageName, String version) async {
    if (version != 'latest' && !version.contains('^') && !version.contains('~')) {
      return version;
    }
    final meta = await fetchPackageMetadata(packageName);
    if (meta != null && meta.version.isNotEmpty && meta.version != 'latest') {
      return meta.version;
    }
    return version == 'latest' ? 'latest' : version.replaceAll('^', '').replaceAll('~', '');
  }

  /// Downloads the ESM bundle from esm.sh CDN into web/vendor/.
  Future<String> downloadVendorBundle(
    String packageName,
    String version,
    String projectRoot,
    String vendorRelativePath,
  ) async {
    final String esmUrl = version == 'latest'
        ? '$_esmBase/$packageName'
        : '$_esmBase/$packageName@$version';

    final response = await _client.get(Uri.parse(esmUrl), headers: {
      'User-Agent': 'Bloom-CLI/0.2.3',
    });

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Failed to download from esm.sh: $esmUrl (HTTP ${response.statusCode})');
    }

    final outFile = File(p.join(projectRoot, vendorRelativePath));
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(response.bodyBytes);
    return esmUrl;
  }
}
