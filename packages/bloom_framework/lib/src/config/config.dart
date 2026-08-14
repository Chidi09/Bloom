// lib/src/config/config.dart
import 'package:yaml/yaml.dart';

class BloomFlavorConfig {
  final String name;
  final String? appName;
  final String? appId;
  final String? envFile;
  final Map<String, dynamic> custom;

  const BloomFlavorConfig({
    required this.name,
    this.appName,
    this.appId,
    this.envFile,
    this.custom = const {},
  });

  factory BloomFlavorConfig.fromMap(String name, Map<dynamic, dynamic> map) {
    return BloomFlavorConfig(
      name: name,
      appName: map['app_name']?.toString() ?? map['appName']?.toString(),
      appId: map['app_id']?.toString() ?? map['appId']?.toString(),
      envFile: map['env_file']?.toString() ?? map['envFile']?.toString(),
      custom: Map<String, dynamic>.from(map),
    );
  }
}

/// Strongly typed configuration model mapping directly to `bloom.yaml`.
class BloomConfig {
  final int schema;
  final String name;
  final String version;
  final String description;
  final BloomPlatforms platforms;
  final BloomFeatures features;
  final List<String> envFiles;
  final Map<String, BloomFlavorConfig> flavors;
  final Map<String, dynamic> plugins;
  final Map<String, dynamic> custom;

  const BloomConfig({
    this.schema = 1,
    this.name = 'bloom_app',
    this.version = '0.1.0',
    this.description = '',
    this.platforms = const BloomPlatforms(),
    this.features = const BloomFeatures(),
    this.envFiles = const ['.env', '.env.local'],
    this.flavors = const {},
    this.plugins = const {},
    this.custom = const {},
  });

  /// Parse from YAML string.
  factory BloomConfig.fromYaml(String yamlString) {
    if (yamlString.trim().isEmpty) return const BloomConfig();
    final doc = loadYaml(yamlString);
    if (doc is! Map) return const BloomConfig();
    return BloomConfig.fromMap(Map<String, dynamic>.from(doc));
  }

  /// Parse from Map.
  factory BloomConfig.fromMap(Map<dynamic, dynamic> map) {
    final platformsMap = map['platforms'] is Map ? map['platforms'] as Map : {};
    final featuresMap = map['features'] is Map ? map['features'] as Map : {};
    
    final envList = <String>[];
    if (map['environment'] is Map && map['environment']['files'] is List) {
      for (final item in map['environment']['files']) {
        envList.add(item.toString());
      }
    } else if (map['envFiles'] is List) {
      for (final item in map['envFiles']) {
        envList.add(item.toString());
      }
    } else {
      envList.addAll(['.env', '.env.local']);
    }

    final flavorsMap = <String, BloomFlavorConfig>{};
    if (map['flavors'] is Map) {
      map['flavors'].forEach((k, v) {
        if (v is Map) {
          flavorsMap[k.toString()] = BloomFlavorConfig.fromMap(k.toString(), v);
        }
      });
    }

    final pluginsMap = <String, dynamic>{};
    if (map['plugins'] is List) {
      for (final item in map['plugins']) {
        if (item is String) {
          pluginsMap[item] = <String, dynamic>{'enabled': true};
        } else if (item is Map) {
          item.forEach((k, v) => pluginsMap[k.toString()] = v);
        }
      }
    } else if (map['plugins'] is Map) {
      map['plugins'].forEach((k, v) => pluginsMap[k.toString()] = v);
    }

    const knownKeys = {
      'schema',
      'name',
      'version',
      'description',
      'platforms',
      'features',
      'environment',
      'envFiles',
      'flavors',
      'plugins',
      'deep_links',
      'deepLinks',
    };

    final customMap = <String, dynamic>{};
    map.forEach((k, v) {
      if (!knownKeys.contains(k.toString())) {
        customMap[k.toString()] = v;
      }
    });

    return BloomConfig(
      schema: map['schema'] is int ? map['schema'] as int : 1,
      name: map['name']?.toString() ?? 'bloom_app',
      version: map['version']?.toString() ?? '0.1.0',
      description: map['description']?.toString() ?? '',
      platforms: BloomPlatforms.fromMap(platformsMap),
      features: BloomFeatures.fromMap(featuresMap),
      envFiles: envList,
      flavors: flavorsMap,
      plugins: pluginsMap,
      custom: customMap,
    );
  }
}

class BloomPlatforms {
  final int androidMinSdk;
  final int androidTargetSdk;
  final String? androidPackage;
  final String iosMinVersion;
  final String? iosBundleIdentifier;
  final String webTitle;

  const BloomPlatforms({
    this.androidMinSdk = 24,
    this.androidTargetSdk = 34,
    this.androidPackage,
    this.iosMinVersion = '15.0',
    this.iosBundleIdentifier,
    this.webTitle = 'Bloom App',
  });

  factory BloomPlatforms.fromMap(Map<dynamic, dynamic> map) {
    final android = map['android'] is Map ? map['android'] as Map : {};
    final ios = map['ios'] is Map ? map['ios'] as Map : {};
    final web = map['web'] is Map ? map['web'] as Map : {};

    return BloomPlatforms(
      androidMinSdk: android['min_sdk'] is int
          ? android['min_sdk'] as int
          : (android['minSdk'] is int ? android['minSdk'] as int : 24),
      androidTargetSdk: android['target_sdk'] is int
          ? android['target_sdk'] as int
          : (android['targetSdk'] is int ? android['targetSdk'] as int : 34),
      androidPackage: android['package']?.toString(),
      iosMinVersion: ios['minimum_version']?.toString() ??
          ios['minVersion']?.toString() ??
          '15.0',
      iosBundleIdentifier: ios['bundle_identifier']?.toString() ??
          ios['bundleIdentifier']?.toString(),
      webTitle: web['title']?.toString() ?? 'Bloom App',
    );
  }
}

class BloomFeatures {
  final bool routing;
  final bool state;
  final bool data;
  final bool native;

  const BloomFeatures({
    this.routing = true,
    this.state = true,
    this.data = false,
    this.native = false,
  });

  factory BloomFeatures.fromMap(Map<dynamic, dynamic> map) {
    return BloomFeatures(
      routing: map['routing'] is bool ? map['routing'] as bool : true,
      state: map['state'] is bool ? map['state'] as bool : true,
      data: map['data'] is bool ? map['data'] as bool : false,
      native: map['native'] is bool ? map['native'] as bool : false,
    );
  }
}
