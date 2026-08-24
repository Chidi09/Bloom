// lib/src/modules/manifest.dart
import 'package:yaml/yaml.dart';

/// Represents a permission declared in `bloom.module.yaml`.
///
/// Encapsulates platform-specific permission keys for Android manifest and iOS `Info.plist`,
/// as well as the default rationale prompt and whether the permission is optional.
///
/// Example:
/// ```dart
/// const cameraPerm = BloomModulePermission(
///   name: 'camera',
///   androidPermission: 'android.permission.CAMERA',
///   iosPlistKey: 'NSCameraUsageDescription',
///   defaultPrompt: 'Allow camera access to capture photos',
/// );
/// ```
class BloomModulePermission {
  /// Permission name identifier (e.g. `'camera'`, `'location'`).
  final String name;

  /// Android manifest permission string (e.g. `'android.permission.CAMERA'`).
  final String? androidPermission;

  /// iOS `Info.plist` usage description key (e.g. `'NSCameraUsageDescription'`).
  final String? iosPlistKey;

  /// Default prompt message shown to the user when requesting permission.
  final String defaultPrompt;

  /// Whether this permission is optional for the module's core functionality.
  final bool optional;

  /// Creates a [BloomModulePermission] descriptor.
  const BloomModulePermission({
    required this.name,
    this.androidPermission,
    this.iosPlistKey,
    this.defaultPrompt = '',
    this.optional = false,
  });

  /// Parses a [BloomModulePermission] from a YAML map or dynamic [value].
  factory BloomModulePermission.fromYaml(String name, dynamic value) {
    if (value is Map || value is YamlMap) {
      return BloomModulePermission(
        name: name,
        androidPermission: value['android']?.toString(),
        iosPlistKey: value['ios']?.toString(),
        defaultPrompt: value['default_prompt']?.toString() ?? '',
        optional: value['optional'] == true,
      );
    }
    return BloomModulePermission(name: name);
  }

  /// Serializes this permission definition to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'android': androidPermission,
        'ios': iosPlistKey,
        'defaultPrompt': defaultPrompt,
        'optional': optional,
      };
}

/// Platform constraints, dependencies, and native frameworks for a Bloom Native Module.
///
/// Specifies minimum/target SDKs and required third-party native libraries.
///
/// Example:
/// ```dart
/// const iosSpec = BloomModulePlatformSpec(
///   minVersion: '15.0',
///   dependencies: ['CocoaLumberjack ~> 3.8'],
///   frameworks: ['AVFoundation.framework'],
/// );
/// ```
class BloomModulePlatformSpec {
  /// Minimum supported SDK version (Android API level).
  final int? minSdk;

  /// Target SDK version (Android API level).
  final int? targetSdk;

  /// Minimum iOS version string (e.g. `'15.0'`).
  final String? minVersion;

  /// External dependencies (e.g. Gradle artifacts or CocoaPods) required by this module.
  final List<String> dependencies;

  /// Native iOS system frameworks required by this module (e.g. `['AVFoundation.framework']`).
  final List<String> frameworks;

  /// Creates a [BloomModulePlatformSpec] configuration.
  const BloomModulePlatformSpec({
    this.minSdk,
    this.targetSdk,
    this.minVersion,
    this.dependencies = const [],
    this.frameworks = const [],
  });

  /// Parses a [BloomModulePlatformSpec] from a YAML node or map [value].
  factory BloomModulePlatformSpec.fromYaml(dynamic value) {
    if (value is Map || value is YamlMap) {
      final deps = <String>[];
      if (value['dependencies'] is List) {
        for (final d in value['dependencies']) {
          deps.add(d.toString());
        }
      }
      final fws = <String>[];
      if (value['frameworks'] is List) {
        for (final f in value['frameworks']) {
          fws.add(f.toString());
        }
      }

      return BloomModulePlatformSpec(
        minSdk: value['min_sdk'] is int ? value['min_sdk'] as int : int.tryParse(value['min_sdk']?.toString() ?? ''),
        targetSdk: value['target_sdk'] is int ? value['target_sdk'] as int : int.tryParse(value['target_sdk']?.toString() ?? ''),
        minVersion: value['min_version']?.toString(),
        dependencies: deps,
        frameworks: fws,
      );
    }
    return const BloomModulePlatformSpec();
  }

  /// Serializes this platform specification to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'minSdk': minSdk,
        'targetSdk': targetSdk,
        'minVersion': minVersion,
        'dependencies': dependencies,
        'frameworks': frameworks,
      };
}

/// Strongly typed manifest representation of `bloom.module.yaml`.
///
/// Encapsulates the module's identity, version, Android and iOS platform specifications,
/// declared permissions, and config plugins.
///
/// Example:
/// ```dart
/// const yamlContent = '''
/// name: BloomCamera
/// version: 1.0.0
/// description: Native hardware camera module
/// ''';
/// final manifest = BloomModuleManifest.fromYaml(yamlContent);
/// print(manifest.name); // 'BloomCamera'
/// ```
class BloomModuleManifest {
  /// Unique module identifier (e.g. `'BloomCamera'`).
  final String name;

  /// Semantic version string of the module contract (e.g. `'1.0.0'`).
  final String version;

  /// Human-readable description of the native module functionality.
  final String description;

  /// Android platform constraints, SDK levels, and Gradle dependencies.
  final BloomModulePlatformSpec android;

  /// iOS platform constraints, minimum deployment target, and CocoaPods/frameworks.
  final BloomModulePlatformSpec ios;

  /// Declared native system permissions required by this module.
  final Map<String, BloomModulePermission> permissions;

  /// Config plugin class name if this module supplies an Expo/Bloom configuration plugin.
  final String? configPluginClassName;

  /// Additional custom metadata key-value dictionary.
  final Map<String, dynamic> customMetadata;

  /// Creates a [BloomModuleManifest] instance.
  const BloomModuleManifest({
    required this.name,
    this.version = '1.0.0',
    this.description = '',
    this.android = const BloomModulePlatformSpec(),
    this.ios = const BloomModulePlatformSpec(),
    this.permissions = const {},
    this.configPluginClassName,
    this.customMetadata = const {},
  });

  /// Parses a [BloomModuleManifest] from a raw YAML string.
  ///
  /// Throws [FormatException] if [yamlString] cannot be parsed into a YAML map.
  factory BloomModuleManifest.fromYaml(String yamlString) {
    final doc = loadYaml(yamlString);
    if (doc is! YamlMap && doc is! Map) {
      throw FormatException('bloom.module.yaml must be a valid YAML map');
    }

    final name = doc['name']?.toString() ?? '';
    final version = doc['version']?.toString() ?? '1.0.0';
    final description = doc['description']?.toString() ?? '';

    final platformsMap = doc['platforms'] is Map || doc['platforms'] is YamlMap ? doc['platforms'] : {};
    final androidSpec = BloomModulePlatformSpec.fromYaml(platformsMap['android']);
    final iosSpec = BloomModulePlatformSpec.fromYaml(platformsMap['ios']);

    final permissionsMap = <String, BloomModulePermission>{};
    if (doc['permissions'] is Map || doc['permissions'] is YamlMap) {
      final perms = doc['permissions'] as Map;
      perms.forEach((k, v) {
        permissionsMap[k.toString()] = BloomModulePermission.fromYaml(k.toString(), v);
      });
    }

    String? pluginClass;
    if (doc['config_plugin'] is Map || doc['config_plugin'] is YamlMap) {
      pluginClass = doc['config_plugin']['class_name']?.toString();
    }

    return BloomModuleManifest(
      name: name,
      version: version,
      description: description,
      android: androidSpec,
      ios: iosSpec,
      permissions: permissionsMap,
      configPluginClassName: pluginClass,
    );
  }

  /// Serializes this manifest to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'description': description,
        'android': android.toJson(),
        'ios': ios.toJson(),
        'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
        'configPluginClassName': configPluginClassName,
      };
}
