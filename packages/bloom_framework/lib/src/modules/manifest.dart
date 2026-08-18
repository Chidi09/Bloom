// lib/src/modules/manifest.dart
import 'package:yaml/yaml.dart';

/// Represents a permission declared in bloom.module.yaml.
class BloomModulePermission {
  /// Permission name identifier.
  final String name;

  /// Android manifest permission string (e.g. `'android.permission.CAMERA'`).
  final String? androidPermission;

  /// iOS Info.plist usage description key (e.g. `'NSCameraUsageDescription'`).
  final String? iosPlistKey;

  /// Default prompt message shown to the user when requesting permission.
  final String defaultPrompt;

  /// Whether this permission is optional.
  final bool optional;

  /// Creates a [BloomModulePermission] descriptor.
  const BloomModulePermission({
    required this.name,
    this.androidPermission,
    this.iosPlistKey,
    this.defaultPrompt = '',
    this.optional = false,
  });

  /// Parses a [BloomModulePermission] from YAML.
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

  /// Serializes permission to JSON map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'android': androidPermission,
        'ios': iosPlistKey,
        'defaultPrompt': defaultPrompt,
        'optional': optional,
      };
}

/// Platform constraints and dependencies for a native module.
class BloomModulePlatformSpec {
  /// Minimum supported SDK version.
  final int? minSdk;

  /// Target SDK version.
  final int? targetSdk;

  /// Minimum iOS version string.
  final String? minVersion;

  /// External dependencies required by this module.
  final List<String> dependencies;

  /// Native iOS frameworks required by this module.
  final List<String> frameworks;

  /// Creates a [BloomModulePlatformSpec].
  const BloomModulePlatformSpec({
    this.minSdk,
    this.targetSdk,
    this.minVersion,
    this.dependencies = const [],
    this.frameworks = const [],
  });

  /// Parses a [BloomModulePlatformSpec] from YAML.
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

  /// Serializes spec to JSON map.
  Map<String, dynamic> toJson() => {
        'minSdk': minSdk,
        'targetSdk': targetSdk,
        'minVersion': minVersion,
        'dependencies': dependencies,
        'frameworks': frameworks,
      };
}

/// Strongly-typed manifest representation of bloom.module.yaml.
class BloomModuleManifest {
  /// Unique module identifier.
  final String name;

  /// Semantic version of the module.
  final String version;

  /// Description of the native module functionality.
  final String description;

  /// Android platform constraints and dependencies.
  final BloomModulePlatformSpec android;

  /// iOS platform constraints and dependencies.
  final BloomModulePlatformSpec ios;

  /// Declared native system permissions required by this module.
  final Map<String, BloomModulePermission> permissions;

  /// Config plugin class name if present.
  final String? configPluginClassName;

  /// Additional custom metadata.
  final Map<String, dynamic> customMetadata;

  /// Creates a [BloomModuleManifest].
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
