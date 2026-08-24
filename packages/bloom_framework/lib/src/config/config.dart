// lib/src/config/config.dart
import 'package:yaml/yaml.dart';

/// Configuration for a specific application build flavor (e.g. `staging`, `production`).
///
/// Flavors define environment-specific overrides for application name, bundle/package ID,
/// environment files, and custom configuration parameters.
///
/// Example:
/// ```dart
/// final stagingFlavor = BloomFlavorConfig(
///   name: 'staging',
///   appName: 'Bloom App (Staging)',
///   appId: 'com.example.bloom.staging',
///   envFile: '.env.staging',
///   custom: {'apiUrl': 'https://staging.api.example.com'},
/// );
/// ```
class BloomFlavorConfig {
  /// Unique flavor name identifier (e.g. `'staging'`, `'production'`).
  final String name;

  /// Display name override for this flavor displayed on user devices.
  final String? appName;

  /// Application bundle / package ID override for this flavor (e.g. `'com.example.app.staging'`).
  final String? appId;

  /// Path to the environment `.env` file loaded for this flavor (e.g. `'.env.staging'`).
  final String? envFile;

  /// Custom flavor-specific configuration key-value properties.
  final Map<String, dynamic> custom;

  /// Creates a [BloomFlavorConfig] instance.
  const BloomFlavorConfig({
    required this.name,
    this.appName,
    this.appId,
    this.envFile,
    this.custom = const {},
  });

  /// Constructs a [BloomFlavorConfig] from a parsed map and [name] identifier.
  ///
  /// Extracts known keys (`app_name`, `appName`, `app_id`, `appId`, `env_file`, `envFile`)
  /// and places all other key-value pairs into the [custom] map.
  factory BloomFlavorConfig.fromMap(String name, Map<dynamic, dynamic> map) {
    const knownKeys = {'app_name', 'appName', 'app_id', 'appId', 'env_file', 'envFile'};
    final customMap = <String, dynamic>{};
    map.forEach((k, v) {
      if (!knownKeys.contains(k.toString())) {
        customMap[k.toString()] = v;
      }
    });

    return BloomFlavorConfig(
      name: name,
      appName: map['app_name']?.toString() ?? map['appName']?.toString(),
      appId: map['app_id']?.toString() ?? map['appId']?.toString(),
      envFile: map['env_file']?.toString() ?? map['envFile']?.toString(),
      custom: customMap,
    );
  }
}

/// Deep link URL scheme and universal link domain configuration.
///
/// Defines the custom URI schemes, universal/app link domains, and route mappings
/// parsed from `bloom.yaml`.
///
/// Example:
/// ```dart
/// final deepLinks = BloomDeepLinksConfig(
///   enabled: true,
///   schemes: ['bloom', 'myapp'],
///   domains: ['app.example.com'],
///   routeMappings: {'/invite': '/auth/register'},
/// );
/// ```
class BloomDeepLinksConfig {
  /// Whether deep linking support is enabled for the application.
  final bool enabled;

  /// Custom URI schemes handled by the application (e.g. `['bloom', 'myapp']`).
  final List<String> schemes;

  /// Associated universal link HTTP/HTTPS domains (e.g. `['app.example.com']`).
  final List<String> domains;

  /// Route path mapping rules translating incoming link paths to internal routes.
  final Map<String, String> routeMappings;

  /// Creates a [BloomDeepLinksConfig] instance.
  const BloomDeepLinksConfig({
    this.enabled = false,
    this.schemes = const [],
    this.domains = const [],
    this.routeMappings = const {},
  });

  /// Constructs a [BloomDeepLinksConfig] from a configuration [map].
  factory BloomDeepLinksConfig.fromMap(Map<dynamic, dynamic> map) {
    final schemesList = map['schemes'] is List ? List<String>.from(map['schemes']) : <String>[];
    final domainsList = <String>[];
    if (map['domains'] is List) {
      for (final d in map['domains']) {
        if (d is String) domainsList.add(d);
        if (d is Map && d['host'] != null) domainsList.add(d['host'].toString());
      }
    }
    final mappings = <String, String>{};
    if (map['routes'] is Map) {
      map['routes'].forEach((k, v) => mappings[k.toString()] = v.toString());
    }

    return BloomDeepLinksConfig(
      enabled: map['enabled'] is bool ? map['enabled'] as bool : false,
      schemes: schemesList,
      domains: domainsList,
      routeMappings: mappings,
    );
  }
}

/// Shorebird OTA (Over-The-Air) deployment configuration declared in `bloom.yaml`.
///
/// Controls live code-push update behavior, application identifiers, and per-flavor mapping.
///
/// Example:
/// ```dart
/// final shorebird = BloomShorebirdConfig(
///   enabled: true,
///   appId: 'auto',
///   autoCheckUpdate: true,
///   flavors: {'production': 'shorebird-app-id-123'},
/// );
/// ```
class BloomShorebirdConfig {
  /// Whether Shorebird code-push updates are enabled.
  final bool enabled;

  /// Shorebird application ID identifier or `'auto'`.
  final String appId;

  /// Whether to automatically check for OTA updates on application startup.
  final bool autoCheckUpdate;

  /// Flavor-specific Shorebird application ID mappings.
  final Map<String, String> flavors;

  /// Creates a [BloomShorebirdConfig] instance.
  const BloomShorebirdConfig({
    this.enabled = false,
    this.appId = 'auto',
    this.autoCheckUpdate = true,
    this.flavors = const {},
  });

  /// Constructs a [BloomShorebirdConfig] from a configuration [map].
  factory BloomShorebirdConfig.fromMap(Map<dynamic, dynamic> map) {
    final flavorsMap = <String, String>{};
    if (map['flavors'] is Map) {
      (map['flavors'] as Map).forEach((k, v) {
        flavorsMap[k.toString()] = v.toString();
      });
    }

    return BloomShorebirdConfig(
      enabled: map['enabled'] is bool ? map['enabled'] as bool : true,
      appId: map['app_id']?.toString() ?? map['appId']?.toString() ?? 'auto',
      autoCheckUpdate: map['auto_check_update'] is bool
          ? map['auto_check_update'] as bool
          : (map['autoCheckUpdate'] is bool ? map['autoCheckUpdate'] as bool : true),
      flavors: flavorsMap,
    );
  }
}

/// Deployment block configuration in `bloom.yaml`.
///
/// Encapsulates OTA update providers and cloud deployment parameters.
///
/// Example:
/// ```dart
/// final deployment = BloomDeploymentConfig(
///   shorebird: BloomShorebirdConfig(enabled: true),
/// );
/// ```
class BloomDeploymentConfig {
  /// Shorebird OTA code-push configuration settings.
  final BloomShorebirdConfig shorebird;

  /// Creates a [BloomDeploymentConfig] instance.
  const BloomDeploymentConfig({
    this.shorebird = const BloomShorebirdConfig(),
  });

  /// Constructs a [BloomDeploymentConfig] from a configuration [map].
  factory BloomDeploymentConfig.fromMap(Map<dynamic, dynamic> map) {
    final shorebirdMap = map['shorebird'] is Map ? map['shorebird'] as Map : {};
    return BloomDeploymentConfig(
      shorebird: BloomShorebirdConfig.fromMap(shorebirdMap),
    );
  }
}

/// Strongly typed configuration model mapping directly to `bloom.yaml`.
///
/// Defines project metadata, platform SDK versions, feature toggles, environment files,
/// deep linking, build flavors, and deployment options.
///
/// Example:
/// ```dart
/// const yamlContent = '''
/// name: my_bloom_app
/// version: 1.0.0
/// build_number: 42
/// mode: managed
/// ''';
/// final config = BloomConfig.fromYaml(yamlContent);
/// print(config.name); // 'my_bloom_app'
/// ```
class BloomConfig {
  /// Schema format version number (defaults to 1).
  final int schema;

  /// Application name identifier (e.g. `'bloom_app'`).
  final String name;

  /// Application version string (e.g. `'1.0.0'`).
  final String version;

  /// Build number string (e.g. `'1'`).
  final String buildNumber;

  /// Brief description of the application.
  final String description;

  /// Development execution mode: `'managed'` or `'bare'`.
  final String mode; // 'managed' or 'bare'

  /// Platform-specific build configuration settings.
  final BloomPlatforms platforms;

  /// Built-in framework features toggles.
  final BloomFeatures features;

  /// Deep link URL routing configuration.
  final BloomDeepLinksConfig deepLinks;

  /// Deployment and OTA update configuration.
  final BloomDeploymentConfig deployment;

  /// Ordered list of environment `.env` files to load on boot.
  final List<String> envFiles;

  /// Named build flavor configurations.
  final Map<String, BloomFlavorConfig> flavors;

  /// Registered native plugins configurations.
  final Map<String, dynamic> plugins;

  /// Additional custom user configuration parameters.
  final Map<String, dynamic> custom;

  /// Creates a [BloomConfig] instance with default values.
  const BloomConfig({
    this.schema = 1,
    this.name = 'bloom_app',
    this.version = '0.1.0',
    this.buildNumber = '1',
    this.description = '',
    this.mode = 'managed',
    this.platforms = const BloomPlatforms(),
    this.features = const BloomFeatures(),
    this.deepLinks = const BloomDeepLinksConfig(),
    this.deployment = const BloomDeploymentConfig(),
    this.envFiles = const ['.env', '.env.local'],
    this.flavors = const {},
    this.plugins = const {},
    this.custom = const {},
  });

  /// Parses a [BloomConfig] from a raw YAML string.
  ///
  /// Returns a default [BloomConfig] if [yamlString] is empty or does not represent a YAML map.
  factory BloomConfig.fromYaml(String yamlString) {
    if (yamlString.trim().isEmpty) return const BloomConfig();
    final doc = loadYaml(yamlString);
    if (doc is! Map) return const BloomConfig();
    return BloomConfig.fromMap(Map<String, dynamic>.from(doc));
  }

  /// Constructs a [BloomConfig] from a configuration [map].
  factory BloomConfig.fromMap(Map<dynamic, dynamic> map) {
    final platformsMap = map['platforms'] is Map ? map['platforms'] as Map : {};
    final featuresMap = map['features'] is Map ? map['features'] as Map : {};
    final deepLinksMap = map['deep_links'] is Map
        ? map['deep_links'] as Map
        : (map['deepLinks'] is Map ? map['deepLinks'] as Map : {});
    final deploymentMap = map['deployment'] is Map ? map['deployment'] as Map : {};
    
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
      'build_number',
      'buildNumber',
      'description',
      'mode',
      'platforms',
      'features',
      'environment',
      'envFiles',
      'flavors',
      'plugins',
      'deep_links',
      'deepLinks',
      'deployment',
    };

    final customMap = <String, dynamic>{};
    if (map['custom'] is Map) {
      (map['custom'] as Map).forEach((k, v) {
        customMap[k.toString()] = v;
      });
    }
    map.forEach((k, v) {
      if (!knownKeys.contains(k.toString()) && k.toString() != 'custom') {
        customMap[k.toString()] = v;
      }
    });

    return BloomConfig(
      schema: map['schema'] is int ? map['schema'] as int : 1,
      name: map['name']?.toString() ?? 'bloom_app',
      version: map['version']?.toString() ?? '0.1.0',
      buildNumber: map['build_number']?.toString() ?? map['buildNumber']?.toString() ?? '1',
      description: map['description']?.toString() ?? '',
      mode: map['mode']?.toString().toLowerCase() ?? 'managed',
      platforms: BloomPlatforms.fromMap(platformsMap),
      features: BloomFeatures.fromMap(featuresMap),
      deepLinks: BloomDeepLinksConfig.fromMap(deepLinksMap),
      deployment: BloomDeploymentConfig.fromMap(deploymentMap),
      envFiles: envList,
      flavors: flavorsMap,
      plugins: pluginsMap,
      custom: customMap,
    );
  }
}

/// Target platforms configuration declared in `bloom.yaml`.
///
/// Contains SDK targets, package identifiers, and platform metadata for Android, iOS, and Web.
///
/// Example:
/// ```dart
/// final platforms = BloomPlatforms(
///   androidMinSdk: 24,
///   androidTargetSdk: 34,
///   androidPackage: 'com.example.app',
///   iosMinVersion: '15.0',
///   iosBundleIdentifier: 'com.example.app',
///   webTitle: 'Bloom App',
/// );
/// ```
class BloomPlatforms {
  /// Android minimum supported SDK version (defaults to 24).
  final int androidMinSdk;

  /// Android target SDK compilation version (defaults to 34).
  final int androidTargetSdk;

  /// Android application package name (e.g. `'com.example.app'`).
  final String? androidPackage;

  /// iOS minimum deployment target version (defaults to `'15.0'`).
  final String iosMinVersion;

  /// iOS application bundle identifier (e.g. `'com.example.app'`).
  final String? iosBundleIdentifier;

  /// Default document title for web application builds.
  final String webTitle;

  /// Creates a [BloomPlatforms] configuration with platform defaults.
  const BloomPlatforms({
    this.androidMinSdk = 24,
    this.androidTargetSdk = 34,
    this.androidPackage,
    this.iosMinVersion = '15.0',
    this.iosBundleIdentifier,
    this.webTitle = 'Bloom App',
  });

  /// Constructs a [BloomPlatforms] configuration from a parsed [map].
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

/// Feature flags and subsystem toggles declared in `bloom.yaml`.
///
/// Controls which core framework modules (routing, signals state, data queries, native plugins)
/// are enabled for the application build.
///
/// Example:
/// ```dart
/// final features = BloomFeatures(
///   routing: true,
///   state: true,
///   data: true,
///   native: true,
/// );
/// ```
class BloomFeatures {
  /// Whether the declarative routing module is enabled.
  final bool routing;

  /// Whether the reactive signals state module is enabled.
  final bool state;

  /// Whether the data querying and caching module is enabled.
  final bool data;

  /// Whether the native hardware bridge module is enabled.
  final bool native;

  /// Creates a [BloomFeatures] configuration.
  const BloomFeatures({
    this.routing = true,
    this.state = true,
    this.data = false,
    this.native = false,
  });

  /// Constructs a [BloomFeatures] configuration from a parsed [map].
  factory BloomFeatures.fromMap(Map<dynamic, dynamic> map) {
    return BloomFeatures(
      routing: map['routing'] is bool ? map['routing'] as bool : true,
      state: map['state'] is bool ? map['state'] as bool : true,
      data: map['data'] is bool ? map['data'] as bool : false,
      native: map['native'] is bool ? map['native'] as bool : false,
    );
  }
}
