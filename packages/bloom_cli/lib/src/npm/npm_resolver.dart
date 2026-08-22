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

  /// Matches esm.sh's thin re-export shim, e.g.
  /// `export * from "/gsap@3.15.0/es2022/gsap.mjs";` or
  /// `export { default } from "/pkg@1.0.0/es2022/pkg.mjs";`.
  static final RegExp _shimReexport = RegExp('''from\\s*["'](/[^"']+)["']''');

  /// Downloads the ESM bundle from esm.sh CDN into web/vendor/.
  ///
  /// esm.sh's package-root endpoint (and even its `?bundle` variant) returns
  /// a thin re-export shim like `export * from "/pkg@ver/es2022/pkg.mjs"` —
  /// those paths are root-relative to esm.sh itself. Vendoring that shim
  /// verbatim produces a file that 404s once self-hosted from a different
  /// origin (the browser resolves "/pkg@ver/..." against the local dev
  /// server, not esm.sh). So: follow the shim's own reference(s) and vendor
  /// the actual, self-contained module content instead.
  Future<String> downloadVendorBundle(
    String packageName,
    String version,
    String projectRoot,
    String vendorRelativePath,
  ) async {
    final String esmUrl = version == 'latest'
        ? '$_esmBase/$packageName?bundle'
        : '$_esmBase/$packageName@$version?bundle';

    final response = await _client.get(Uri.parse(esmUrl), headers: {
      'User-Agent': 'Bloom-CLI/0.2.3',
    });

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Failed to download from esm.sh: $esmUrl (HTTP ${response.statusCode})');
    }

    var body = response.body;
    final targets = _shimReexport.allMatches(body).map((m) => m.group(1)!).toSet();

    // If the response is (or starts with) a shim pointing elsewhere, follow
    // the first reference and vendor that content instead. esm.sh's shims
    // are a couple of forwarding lines total, so checking body length keeps
    // this from ever mistaking a real (large) bundle for a shim.
    if (targets.isNotEmpty && body.trim().length < 512) {
      final targetUrl = '$_esmBase${targets.first}';
      final targetResponse = await _client.get(Uri.parse(targetUrl), headers: {
        'User-Agent': 'Bloom-CLI/0.2.3',
      });
      if (targetResponse.statusCode == 200) {
        body = targetResponse.body;
      }
      // If the follow-up fetch fails, fall back to vendoring the shim as-is
      // rather than throwing — better than a hard install failure.
    }

    final outFile = File(p.join(projectRoot, vendorRelativePath));
    await outFile.parent.create(recursive: true);
    await outFile.writeAsString(body);
    return esmUrl;
  }
}
