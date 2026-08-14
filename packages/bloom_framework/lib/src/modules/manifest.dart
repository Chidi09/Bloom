// lib/src/modules/manifest.dart
import 'package:yaml/yaml.dart';

/// Represents a permission declared in bloom.module.yaml.
class BloomModulePermission {
  final String name;
  final String? androidPermission;
  final String? iosPlistKey;
  final String defaultPrompt;
  final bool optional;

  const BloomModulePermission({
    required this.name,
    this.androidPermission,
    this.iosPlistKey,
    this.defaultPrompt = '',
    this.optional = false,
  });

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
  final int? minSdk;
  final int? targetSdk;
  final String? minVersion;
  final List<String> dependencies;
  final List<String> frameworks;

  const BloomModulePlatformSpec({
    this.minSdk,
    this.targetSdk,
    this.minVersion,
    this.dependencies = const [],
    this.frameworks = const [],
  });

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
  final String name;
  final String version;
  final String description;
  final BloomModulePlatformSpec android;
  final BloomModulePlatformSpec ios;
  final Map<String, BloomModulePermission> permissions;
  final String? configPluginClassName;
  final Map<String, dynamic> customMetadata;

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
