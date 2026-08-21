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

  const NpmDependency(
    this.name,
    this.version, {
    this.importAs,
    this.cdn = 'https://esm.sh',
  });

  /// Resolved import specifier key in the import map.
  String get specifier => importAs ?? name;

  /// Resolved ESM URL, e.g. https://esm.sh/zod@^3.23.0
  String get url => '$cdn/$name@$version';

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'specifier': specifier,
        'url': url,
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

  /// Generate the raw import-map JSON string.
  ///
  /// ```json
  /// { "imports": { "zod": "https://esm.sh/zod@^3.23.0" } }
  /// ```
  static String generateImportMapJson({bool pretty = false}) {
    final imports = <String, String>{
      for (final e in _deps.entries) e.key: e.value.url,
    };
    final map = {'imports': imports};
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
