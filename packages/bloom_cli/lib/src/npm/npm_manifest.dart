import 'package:yaml/yaml.dart';
import '../utils/project.dart';

/// A single installed NPM package entry from bloom.yaml.
class NpmManifestEntry {
  final String alias;       // The key in bloom.yaml (e.g. 'gsap', 'sonner')
  final String npmName;     // The real NPM package name (e.g. 'gsap', 'canvas-confetti')
  final String version;     // Resolved pinned version (e.g. '3.12.5')
  final String? esmUrl;     // Full esm.sh URL used to download
  final String vendorFile;  // Relative path: 'web/vendor/gsap.min.js'
  final String dartBinding; // Relative path: 'lib/src/plugins/gsap.dart'
  final String? jsGlobal;   // JS global name, or null for ESM-only packages

  const NpmManifestEntry({
    required this.alias,
    required this.npmName,
    required this.version,
    this.esmUrl,
    required this.vendorFile,
    required this.dartBinding,
    this.jsGlobal,
  });

  factory NpmManifestEntry.fromYaml(String alias, Map<dynamic, dynamic> map) {
    return NpmManifestEntry(
      alias: alias,
      npmName: map['npm_name']?.toString() ?? alias,
      version: map['version']?.toString() ?? 'latest',
      esmUrl: map['esm_url']?.toString(),
      vendorFile: map['vendor_file']?.toString() ?? 'web/vendor/$alias.min.js',
      dartBinding: map['dart_binding']?.toString() ?? 'lib/src/plugins/$alias.dart',
      jsGlobal: map['js_global']?.toString(),
    );
  }

  Map<String, dynamic> toYaml() => {
    'npm_name': npmName,
    'version': version,
    if (esmUrl != null) 'esm_url': esmUrl,
    'vendor_file': vendorFile,
    'dart_binding': dartBinding,
    if (jsGlobal != null) 'js_global': jsGlobal,
  };
}

/// Reads and exposes all declared npm_packages from bloom.yaml.
class NpmManifest {
  final List<NpmManifestEntry> packages;

  const NpmManifest(this.packages);

  static NpmManifest read(BloomProject project) {
    final config = project.loadBloomConfig();
    final npmPkgs = config['npm_packages'];
    if (npmPkgs is! Map && npmPkgs is! YamlMap) return const NpmManifest([]);

    final entries = <NpmManifestEntry>[];
    (npmPkgs as Map).forEach((key, value) {
      if (value is Map || value is YamlMap) {
        entries.add(NpmManifestEntry.fromYaml(key.toString(), value as Map));
      }
    });
    return NpmManifest(entries);
  }

  bool get isEmpty => packages.isEmpty;
  int get count => packages.length;
}
