import 'dart:convert';

/// Declaration of an npm package dependency resolved via browser ESM import maps.
///
/// Encapsulates metadata required to generate standard W3C `<script type="importmap">`
/// entries so that browser JavaScript or JS interop can import npm packages directly.
///
/// Packages are resolved from an ESM CDN (defaulting to [cdn] = `'https://esm.sh'`)
/// or local vendored bundles. If [subPath] is specified (e.g. `'icons'` on `'lucide'`),
/// the import map will emit an ESM `scopes` block targeting the package base URL.
///
/// ```dart
/// // Declare and register an npm package
/// const zod = NpmDependency('zod', '^3.23.0');
/// NpmRegistry.register(zod);
///
/// // Custom alias and CDN subpath
/// const lucideIcons = NpmDependency(
///   'lucide',
///   '0.344.0',
///   importAs: 'lucide-icons',
///   subPath: 'icons',
/// );
/// NpmRegistry.register(lucideIcons);
/// ```
class NpmDependency {
  /// Package name in the npm registry, e.g. `'zod'`, `'date-fns'`, or `'lucide'`.
  final String name;

  /// Semver range or exact version string, e.g. `'^3.23.0'` or `'4.1.0'`.
  final String version;

  /// Custom import specifier alias override.
  ///
  /// When null, [specifier] defaults to [name].
  final String? importAs;

  /// CDN base URL provider. Defaults to `'https://esm.sh'`.
  final String cdn;

  /// Sub-Resource Integrity (SRI) hash, e.g. `'sha384-abc...'`.
  ///
  /// Included in the serialized JSON output when specified.
  final String? integrity;

  /// Optional package sub-path specifier, e.g. `'icons'` for a `lucide/icons` scoped import.
  final String? subPath;

  /// Creates an [NpmDependency] descriptor.
  const NpmDependency(
    this.name,
    this.version, {
    this.importAs,
    this.cdn = 'https://esm.sh',
    this.integrity,
    this.subPath,
  });

  /// The resolved import specifier key used in import statements and import maps.
  ///
  /// Returns [importAs] if specified; otherwise returns [name].
  String get specifier => importAs ?? name;

  /// The fully resolved ESM CDN URL, e.g. `'https://esm.sh/zod@^3.23.0'`.
  String get url => '$cdn/$name@$version${subPath != null ? '/$subPath' : ''}';

  /// Serializes dependency metadata to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'specifier': specifier,
        'url': url,
        if (integrity != null) 'integrity': integrity,
        if (subPath != null) 'subPath': subPath,
      };
}

/// In-memory registry collecting [NpmDependency] declarations and generating ESM import maps.
///
/// Collects dependencies declared during application initialization or build steps
/// and generates standard W3C browser import maps as JSON or HTML tags.
///
/// ### Specifier Resolution
/// When registering dependencies via [register] or [registerAll], if a specifier is
/// registered more than once, the latest registration silently replaces earlier ones.
///
/// ```dart
/// void main() {
///   NpmRegistry.registerAll([
///     const NpmDependency('canvas-confetti', '^1.9.2'),
///     const NpmDependency('dayjs', '^1.11.10'),
///   ]);
///
///   final importMapTag = NpmRegistry.generateImportMapTag(pretty: true);
/// }
/// ```
class NpmRegistry {
  NpmRegistry._();

  static final Map<String, NpmDependency> _deps = {};

  /// Registers a single [dep].
  ///
  /// If a dependency with the same [NpmDependency.specifier] already exists in the
  /// registry, the previous registration is replaced.
  static void register(NpmDependency dep) {
    _deps[dep.specifier] = dep;
  }

  /// Registers multiple dependencies sequentially via [register].
  static void registerAll(Iterable<NpmDependency> deps) {
    for (final d in deps) {
      register(d);
    }
  }

  /// Unmodifiable map view of all currently registered dependencies, keyed by specifier.
  static Map<String, NpmDependency> get all => Map.unmodifiable(_deps);

  /// Clears all registered dependencies from the registry.
  static void clear() => _deps.clear();

  /// Returns specifiers that were registered with conflicting versions.
  ///
  /// Since later registrations silently overwrite earlier ones, this returns an empty
  /// list in the current implementation. Reserved for future conflict detection.
  static List<String> conflicts() => const [];

  /// Generates a standard W3C Import Map JSON string with `imports` and `scopes`.
  ///
  /// When [pretty] is `true`, the output JSON string is indented with 2 spaces.
  ///
  /// ```json
  /// {
  ///   "imports": {
  ///     "zod": "https://esm.sh/zod@^3.23.0"
  ///   }
  /// }
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

  /// Generates an HTML `<script type="importmap">` tag containing the generated import map JSON.
  ///
  /// When [pretty] is `true`, formats the internal JSON with indentation.
  ///
  /// ```dart
  /// final scriptTag = NpmRegistry.generateImportMapTag();
  /// ```
  static String generateImportMapTag({bool pretty = false}) {
    final json = generateImportMapJson(pretty: pretty);
    return '<script type="importmap">$json</script>';
  }

  /// Returns the top-level import map as a Dart [Map] with an `'imports'` key.
  static Map<String, dynamic> toMap() => {
        'imports': {for (final e in _deps.entries) e.key: e.value.url},
      };
}
