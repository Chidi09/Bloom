// lib/src/native/plugin_catalog.dart
/// Shared catalog of Bloom native plugins and the managed platform
/// transformations each one requires during prebuild.
///
/// This is the single source of truth read by both the Android and iOS
/// prebuild engines, as well as the `bloom add` / `bloom remove` commands.
class BloomPluginDescriptor {
  final String id;
  final List<String> androidPermissions;
  final Map<String, String> iosUsageDescriptions;

  const BloomPluginDescriptor({
    required this.id,
    this.androidPermissions = const [],
    this.iosUsageDescriptions = const {},
  });
}

class BloomPluginCatalog {
  static const Map<String, BloomPluginDescriptor> plugins = {
    'camera': BloomPluginDescriptor(
      id: 'camera',
      androidPermissions: [
        'android.permission.CAMERA',
        'android.permission.RECORD_AUDIO',
      ],
      iosUsageDescriptions: {
        'NSCameraUsageDescription':
            'This application requires camera access to take photos.',
        'NSMicrophoneUsageDescription':
            'This application requires microphone access to record audio.',
      },
    ),
    'notifications': BloomPluginDescriptor(
      id: 'notifications',
      androidPermissions: [
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.VIBRATE',
      ],
    ),
    'location': BloomPluginDescriptor(
      id: 'location',
      androidPermissions: [
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
      ],
      iosUsageDescriptions: {
        'NSLocationWhenInUseUsageDescription':
            'This application requires location access to provide location services.',
      },
    ),
    'background_tasks': BloomPluginDescriptor(
      id: 'background_tasks',
      androidPermissions: [
        'android.permission.WAKE_LOCK',
        'android.permission.FOREGROUND_SERVICE',
      ],
    ),
    'secure_storage': BloomPluginDescriptor(
      id: 'secure_storage',
    ),
    'deep_links': BloomPluginDescriptor(
      id: 'deep_links',
    ),
    // `auth` and `storage` are framework-level features (BloomAuth, BloomStorage)
    // rather than native plugins, so they carry no platform transformations. They
    // are catalogued because `bloom add auth` is documented in docs/cli/commands.md
    // and existing project configs (examples/bloom_ecommerce) declare `storage`;
    // omitting them would make those spellings fail validation.
    'auth': BloomPluginDescriptor(
      id: 'auth',
    ),
    'storage': BloomPluginDescriptor(
      id: 'storage',
    ),
  };

  /// Normalizes a raw plugin spelling into its canonical id form: trimmed,
  /// lowercased, and with every `-` replaced by `_`.
  static String canonicalize(String raw) {
    return raw.trim().toLowerCase().replaceAll('-', '_');
  }

  /// Resolves `raw` against the catalog, or returns `null` when unknown.
  static BloomPluginDescriptor? resolve(String raw) {
    return plugins[canonicalize(raw)];
  }

  /// The catalog keys, sorted alphabetically.
  static List<String> get supportedIds {
    final ids = plugins.keys.toList()..sort();
    return ids;
  }
}
