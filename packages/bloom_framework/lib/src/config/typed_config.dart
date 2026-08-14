// lib/src/config/typed_config.dart
import 'config.dart';

/// Native execution mode for Bloom projects.
enum NativeMode {
  managed,
  bare;

  String toJson() => name;

  static NativeMode fromString(String value) {
    return NativeMode.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => NativeMode.managed,
    );
  }
}

/// Android platform build configuration.
class AndroidPlatform {
  final int minSdk;
  final int targetSdk;
  final String? package;

  const AndroidPlatform({
    this.minSdk = 24,
    this.targetSdk = 34,
    this.package,
  });

  Map<String, dynamic> toJson() => {
        'minSdk': minSdk,
        'targetSdk': targetSdk,
        if (package != null) 'package': package,
      };

  factory AndroidPlatform.fromJson(Map<String, dynamic> json) {
    return AndroidPlatform(
      minSdk: json['minSdk'] as int? ?? json['min_sdk'] as int? ?? 24,
      targetSdk: json['targetSdk'] as int? ?? json['target_sdk'] as int? ?? 34,
      package: json['package']?.toString(),
    );
  }
}

/// iOS platform build configuration.
class IosPlatform {
  final String minVersion;
  final String? bundleIdentifier;

  const IosPlatform({
    this.minVersion = '15.0',
    this.bundleIdentifier,
  });

  Map<String, dynamic> toJson() => {
        'minVersion': minVersion,
        if (bundleIdentifier != null) 'bundleIdentifier': bundleIdentifier,
      };

  factory IosPlatform.fromJson(Map<String, dynamic> json) {
    return IosPlatform(
      minVersion: json['minVersion']?.toString() ?? json['minimum_version']?.toString() ?? '15.0',
      bundleIdentifier:
          json['bundleIdentifier']?.toString() ?? json['bundle_identifier']?.toString(),
    );
  }
}

/// Web platform build configuration.
class WebPlatform {
  final String title;

  const WebPlatform({
    this.title = 'Bloom App',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
      };

  factory WebPlatform.fromJson(Map<String, dynamic> json) {
    return WebPlatform(
      title: json['title']?.toString() ?? 'Bloom App',
    );
  }
}

/// Combined platforms configuration block.
class PlatformsConfig {
  final AndroidPlatform android;
  final IosPlatform ios;
  final WebPlatform web;

  const PlatformsConfig({
    this.android = const AndroidPlatform(),
    this.ios = const IosPlatform(),
    this.web = const WebPlatform(),
  });

  Map<String, dynamic> toJson() => {
        'android': android.toJson(),
        'ios': ios.toJson(),
        'web': web.toJson(),
      };

  factory PlatformsConfig.fromJson(Map<String, dynamic> json) {
    return PlatformsConfig(
      android: json['android'] is Map
          ? AndroidPlatform.fromJson(Map<String, dynamic>.from(json['android'] as Map))
          : const AndroidPlatform(),
      ios: json['ios'] is Map
          ? IosPlatform.fromJson(Map<String, dynamic>.from(json['ios'] as Map))
          : const IosPlatform(),
      web: json['web'] is Map
          ? WebPlatform.fromJson(Map<String, dynamic>.from(json['web'] as Map))
          : const WebPlatform(),
    );
  }
}

/// A strongly typed plugin reference in `bloom.config.dart`.
class BloomPlugin {
  final String name;
  final Map<String, dynamic> config;

  const BloomPlugin(
    this.name, {
    this.config = const {},
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'config': config,
      };
}

/// Strongly typed application configuration model for `bloom.config.dart`.
class BloomAppConfig {
  final int schema;
  final String name;
  final String version;
  final String buildNumber;
  final String description;
  final NativeMode mode;
  final PlatformsConfig platforms;
  final List<BloomPlugin> plugins;
  final List<String> envFiles;
  final Map<String, dynamic> featureFlags;
  final Map<String, dynamic> custom;

  const BloomAppConfig({
    this.schema = 1,
    required this.name,
    this.version = '0.1.0',
    this.buildNumber = '1',
    this.description = '',
    this.mode = NativeMode.managed,
    this.platforms = const PlatformsConfig(),
    this.plugins = const [],
    this.envFiles = const ['.env', '.env.local'],
    this.featureFlags = const {},
    this.custom = const {},
  });

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'name': name,
        'version': version,
        'buildNumber': buildNumber,
        'description': description,
        'mode': mode.toJson(),
        'platforms': platforms.toJson(),
        'plugins': plugins.map((p) => p.toJson()).toList(),
        'envFiles': envFiles,
        'featureFlags': featureFlags,
        'custom': custom,
      };

  /// Converts this typed app configuration to the internal [BloomConfig].
  BloomConfig toBloomConfig() {
    final pluginsMap = <String, dynamic>{};
    for (final plugin in plugins) {
      pluginsMap[plugin.name] = plugin.config.isNotEmpty ? plugin.config : {'enabled': true};
    }

    return BloomConfig(
      schema: schema,
      name: name,
      version: version,
      buildNumber: buildNumber,
      description: description,
      mode: mode.name,
      platforms: BloomPlatforms(
        androidMinSdk: platforms.android.minSdk,
        androidTargetSdk: platforms.android.targetSdk,
        androidPackage: platforms.android.package,
        iosMinVersion: platforms.ios.minVersion,
        iosBundleIdentifier: platforms.ios.bundleIdentifier,
        webTitle: platforms.web.title,
      ),
      envFiles: envFiles,
      plugins: pluginsMap,
      custom: {
        'feature_flags': featureFlags,
        ...custom,
      },
    );
  }

  /// Converts from [BloomConfig] to [BloomAppConfig].
  factory BloomAppConfig.fromBloomConfig(BloomConfig config) {
    final pluginsList = <BloomPlugin>[];
    config.plugins.forEach((key, val) {
      pluginsList.add(BloomPlugin(
        key,
        config: val is Map ? Map<String, dynamic>.from(val) : {},
      ));
    });

    final flags = config.custom['feature_flags'] is Map
        ? Map<String, dynamic>.from(config.custom['feature_flags'] as Map)
        : <String, dynamic>{};

    return BloomAppConfig(
      schema: config.schema,
      name: config.name,
      version: config.version,
      buildNumber: config.buildNumber,
      description: config.description,
      mode: NativeMode.fromString(config.mode),
      platforms: PlatformsConfig(
        android: AndroidPlatform(
          minSdk: config.platforms.androidMinSdk,
          targetSdk: config.platforms.androidTargetSdk,
          package: config.platforms.androidPackage,
        ),
        ios: IosPlatform(
          minVersion: config.platforms.iosMinVersion,
          bundleIdentifier: config.platforms.iosBundleIdentifier,
        ),
        web: WebPlatform(
          title: config.platforms.webTitle,
        ),
      ),
      plugins: pluginsList,
      envFiles: config.envFiles,
      featureFlags: flags,
      custom: config.custom,
    );
  }
}
