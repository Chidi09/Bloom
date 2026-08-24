// lib/src/config/typed_config.dart
import 'config.dart';

/// Native execution mode for Bloom projects.
///
/// Determines whether Bloom automatically generates and manages underlying native platform
/// project directories ([NativeMode.managed]) or exposes full platform project sources for
/// direct customization ([NativeMode.bare]).
///
/// Example:
/// ```dart
/// const mode = NativeMode.managed;
/// print(mode.toJson()); // 'managed'
/// ```
enum NativeMode {
  /// Managed execution mode where Bloom handles native build files and manifests automatically.
  managed,

  /// Bare execution mode where native iOS and Android projects are fully exposed and customized.
  bare;

  /// Serializes the native mode identifier to a JSON-compatible string.
  String toJson() => name;

  /// Parses a [NativeMode] from a string [value], defaulting to [NativeMode.managed] if unrecognized.
  static NativeMode fromString(String value) {
    return NativeMode.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => NativeMode.managed,
    );
  }
}

/// Android platform build configuration settings.
///
/// Controls Android minimum and target SDK versions, as well as the Android package identifier.
///
/// Example:
/// ```dart
/// const android = AndroidPlatform(
///   minSdk: 26,
///   targetSdk: 34,
///   package: 'com.example.bloomapp',
/// );
/// ```
class AndroidPlatform {
  /// Minimum supported Android SDK version (defaults to 24).
  final int minSdk;

  /// Target Android SDK compilation version (defaults to 34).
  final int targetSdk;

  /// Android application package name (e.g. `'com.example.app'`).
  final String? package;

  /// Creates an [AndroidPlatform] configuration instance.
  const AndroidPlatform({
    this.minSdk = 24,
    this.targetSdk = 34,
    this.package,
  });

  /// Serializes this configuration to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'minSdk': minSdk,
        'targetSdk': targetSdk,
        if (package != null) 'package': package,
      };

  /// Constructs an [AndroidPlatform] from a JSON [json] map.
  factory AndroidPlatform.fromJson(Map<String, dynamic> json) {
    return AndroidPlatform(
      minSdk: json['minSdk'] as int? ?? json['min_sdk'] as int? ?? 24,
      targetSdk: json['targetSdk'] as int? ?? json['target_sdk'] as int? ?? 34,
      package: json['package']?.toString(),
    );
  }
}

/// iOS platform build configuration settings.
///
/// Controls iOS minimum deployment target version and application bundle identifier.
///
/// Example:
/// ```dart
/// const ios = IosPlatform(
///   minVersion: '16.0',
///   bundleIdentifier: 'com.example.bloomapp',
/// );
/// ```
class IosPlatform {
  /// Minimum supported iOS version string (defaults to `'15.0'`).
  final String minVersion;

  /// iOS application bundle identifier (e.g. `'com.example.app'`).
  final String? bundleIdentifier;

  /// Creates an [IosPlatform] configuration instance.
  const IosPlatform({
    this.minVersion = '15.0',
    this.bundleIdentifier,
  });

  /// Serializes this configuration to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'minVersion': minVersion,
        if (bundleIdentifier != null) 'bundleIdentifier': bundleIdentifier,
      };

  /// Constructs an [IosPlatform] from a JSON [json] map.
  factory IosPlatform.fromJson(Map<String, dynamic> json) {
    return IosPlatform(
      minVersion: json['minVersion']?.toString() ?? json['minimum_version']?.toString() ?? '15.0',
      bundleIdentifier:
          json['bundleIdentifier']?.toString() ?? json['bundle_identifier']?.toString(),
    );
  }
}

/// Web platform build configuration settings.
///
/// Controls document title and browser-specific build parameters.
///
/// Example:
/// ```dart
/// const web = WebPlatform(title: 'Bloom App Portal');
/// ```
class WebPlatform {
  /// Default title for the web application document (defaults to `'Bloom App'`).
  final String title;

  /// Creates a [WebPlatform] configuration instance.
  const WebPlatform({
    this.title = 'Bloom App',
  });

  /// Serializes this configuration to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'title': title,
      };

  /// Constructs a [WebPlatform] from a JSON [json] map.
  factory WebPlatform.fromJson(Map<String, dynamic> json) {
    return WebPlatform(
      title: json['title']?.toString() ?? 'Bloom App',
    );
  }
}

/// Combined platforms configuration block aggregating Android, iOS, and Web settings.
///
/// Example:
/// ```dart
/// const platforms = PlatformsConfig(
///   android: AndroidPlatform(minSdk: 24),
///   ios: IosPlatform(minVersion: '15.0'),
///   web: WebPlatform(title: 'My App'),
/// );
/// ```
class PlatformsConfig {
  /// Android platform build settings.
  final AndroidPlatform android;

  /// iOS platform build settings.
  final IosPlatform ios;

  /// Web platform build settings.
  final WebPlatform web;

  /// Creates a [PlatformsConfig] instance.
  const PlatformsConfig({
    this.android = const AndroidPlatform(),
    this.ios = const IosPlatform(),
    this.web = const WebPlatform(),
  });

  /// Serializes this configuration to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'android': android.toJson(),
        'ios': ios.toJson(),
        'web': web.toJson(),
      };

  /// Constructs a [PlatformsConfig] from a JSON [json] map.
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

/// A strongly typed plugin reference declared in `bloom.config.dart`.
///
/// Encapsulates the plugin name and custom configuration properties passed to that plugin.
///
/// Example:
/// ```dart
/// const cameraPlugin = BloomPlugin(
///   'bloom_camera',
///   config: {'enableHighResolution': true},
/// );
/// ```
class BloomPlugin {
  /// Unique plugin name identifier.
  final String name;

  /// Plugin-specific configuration settings map.
  final Map<String, dynamic> config;

  /// Creates a [BloomPlugin] reference with an optional [config] map.
  const BloomPlugin(
    this.name, {
    this.config = const {},
  });

  /// Serializes this plugin configuration to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'config': config,
      };
}

/// Strongly typed application configuration model for `bloom.config.dart`.
///
/// Serves as the primary type-safe entry point for configuring Bloom applications in Dart code,
/// supporting conversion to and from the internal [BloomConfig] YAML representation.
///
/// Example:
/// ```dart
/// final appConfig = BloomAppConfig(
///   name: 'my_app',
///   version: '1.0.0',
///   mode: NativeMode.managed,
///   platforms: const PlatformsConfig(
///     android: AndroidPlatform(package: 'com.example.myapp'),
///     ios: IosPlatform(bundleIdentifier: 'com.example.myapp'),
///   ),
/// );
/// ```
class BloomAppConfig {
  /// Schema version number (defaults to 1).
  final int schema;

  /// Application name identifier.
  final String name;

  /// Application version string (defaults to `'0.1.0'`).
  final String version;

  /// Build number string (defaults to `'1'`).
  final String buildNumber;

  /// Brief human-readable description of the application.
  final String description;

  /// Native build execution mode ([NativeMode.managed] or [NativeMode.bare]).
  final NativeMode mode;

  /// Platform build target settings for Android, iOS, and Web.
  final PlatformsConfig platforms;

  /// List of registered Bloom plugins.
  final List<BloomPlugin> plugins;

  /// List of environment `.env` files loaded on application boot.
  final List<String> envFiles;

  /// Initial feature flag key-value map.
  final Map<String, dynamic> featureFlags;

  /// Additional custom configuration properties.
  final Map<String, dynamic> custom;

  /// Creates a [BloomAppConfig] instance.
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

  /// Serializes this configuration to a JSON-compatible map.
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

  /// Converts this typed app configuration to the internal [BloomConfig] model.
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

  /// Converts from an internal [BloomConfig] to a typed [BloomAppConfig].
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
