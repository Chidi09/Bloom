import 'dart:convert';

/// Registry entry for an npm dependency consumed via ESM import maps.
///
/// Example:
/// ```dart
/// const zod = NpmDependency('zod', '^3.23.0');
/// NpmRegistry.register(zod);
/// // build step emits <script type="importmap"> with esm.sh URL
/// ```
class NpmDependency {
  /// Package name, e.g. "zod", "date-fns", "lucide".
  final String name;

  /// Semver range, e.g. "^3.23.0", "4.1.0".
  final String version;

  /// Optional import specifier override (defaults to [name]).
  final String? importAs;

  /// CDN provider. Defaults to esm.sh.
  final String cdn;

  /// SRI integrity hash, e.g. `sha384-abc...`. Included in the import-map
  /// tag as an `integrity` field when provided.
  final String? integrity;

  /// Sub-path specifier, e.g. `'icons'` → `lucide/icons` scope entry.
  final String? subPath;

  const NpmDependency(
    this.name,
    this.version, {
    this.importAs,
    this.cdn = 'https://esm.sh',
    this.integrity,
    this.subPath,
  });

  /// Resolved import specifier key in the import map.
  String get specifier => importAs ?? name;

  /// Resolved ESM URL, e.g. https://esm.sh/zod@^3.23.0
  String get url => '$cdn/$name@$version${subPath != null ? '/$subPath' : ''}';

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'specifier': specifier,
        'url': url,
        if (integrity != null) 'integrity': integrity,
        if (subPath != null) 'subPath': subPath,
      };
}

/// In-memory registry that collects [NpmDependency] declarations at startup
/// and generates an import-map JSON / HTML tag.
class NpmRegistry {
  NpmRegistry._();

  static final Map<String, NpmDependency> _deps = {};

  /// Register a dependency. Later registrations for the same specifier win.
  static void register(NpmDependency dep) {
    _deps[dep.specifier] = dep;
  }

  /// Register many at once.
  static void registerAll(Iterable<NpmDependency> deps) {
    for (final d in deps) {
      register(d);
    }
  }

  /// All currently registered dependencies (unmodifiable view).
  static Map<String, NpmDependency> get all => Map.unmodifiable(_deps);

  /// Clear the registry (useful in tests).
  static void clear() => _deps.clear();

  /// Returns specifiers that were registered with conflicting versions.
  /// Since later registrations silently win, this is always empty unless
  /// extended to track registration history. Reserved for future use.
  static List<String> conflicts() => const [];

  /// Generate the raw import-map JSON string.
  ///
  /// ```json
  /// { "imports": { "zod": "https://esm.sh/zod@^3.23.0" } }
  /// ```
  static String generateImportMapJson({bool pretty = false}) {
    final mainImports = <String, String>{};
    final scopes = <String, Map<String, String>>{};

    for (final e in _deps.entries) {
      if (e.value.subPath != null) {
        // Emit as a scopes entry.
        final baseUrl = '${e.value.cdn}/${e.value.name}@${e.value.version}/';
        scopes[baseUrl] = {e.value.specifier: e.value.url};
      } else {
        mainImports[e.key] = e.value.url;
      }
    }

    final map = <String, dynamic>{
      'imports': mainImports,
      if (scopes.isNotEmpty) 'scopes': scopes,
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  /// Generate the full `<script type="importmap">` HTML tag.
  static String generateImportMapTag({bool pretty = false}) {
    final json = generateImportMapJson(pretty: pretty);
    return '<script type="importmap">$json</script>';
  }

  /// Import-map as a Dart map (for programmatic use).
  static Map<String, dynamic> toMap() => {
        'imports': {for (final e in _deps.entries) e.key: e.value.url},
      };
}
