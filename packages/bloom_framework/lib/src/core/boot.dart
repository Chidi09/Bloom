// lib/src/core/boot.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../config/config.dart';
import '../data/cache.dart';
import '../deployment/bloom_ota.dart';
import '../devtools/devtools_service.dart';
import '../di/container.dart';
import '../di/scope.dart';
import '../native/deep_links.dart';
import '../modules/module_registry.dart';
import 'env.dart';
import 'logger.dart';

/// Contract for custom user bootstrapper code in `lib/app/boot.dart`.
abstract class BloomBootstrapper {
  const BloomBootstrapper();

  /// Invoked during framework boot sequence before widget tree is mounted.
  FutureOr<void> onBoot(BloomContainer container);
}

/// The core Bloom framework controller.
class Bloom {
  static bool _isBooted = false;
  static BloomConfig _config = const BloomConfig();
  static String? _activeFlavor;

  /// Whether Bloom has completed its boot sequence.
  static bool get isBooted => _isBooted;

  /// Active configuration instance.
  static BloomConfig get config => _config;

  /// Currently active build flavor (if specified).
  static String? get activeFlavor => _activeFlavor;

  /// Global dependency injection container.
  static BloomContainer get container => globalContainer;

  /// Main boot pipeline for Bloom applications.
  static Future<void> boot({
    String? flavor,
    BloomBootstrapper? bootstrapper,
    String? envContent,
    String? configYaml,
  }) async {
    if (_isBooted) {
      logger.warn('Bloom.boot() was called multiple times. Skipping duplicate initialization.');
      return;
    }

    // 1. Ensure Flutter binding is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Parse configuration
    if (configYaml != null) {
      _config = BloomConfig.fromYaml(configYaml);
    } else {
      try {
        final assetConfig = await rootBundle.loadString('bloom.yaml');
        _config = BloomConfig.fromYaml(assetConfig);
      } catch (_) {
        _config = const BloomConfig();
      }
    }

    // 3. Resolve active flavor
    _activeFlavor = flavor ??
        (const bool.hasEnvironment('BLOOM_FLAVOR')
            ? const String.fromEnvironment('BLOOM_FLAVOR')
            : null);

    // 4. Load environment variables (.env, .env.local, and flavor-specific envFiles in order)
    if (envContent != null) {
      BloomEnv.loadContent(envContent);
    } else {
      final envFilesToLoad = <String>[];
      if (_config.envFiles.isNotEmpty) {
        envFilesToLoad.addAll(_config.envFiles);
      } else {
        envFilesToLoad.addAll(['.env', '.env.local']);
      }

      // Add flavor-specific env file if active
      if (_activeFlavor != null && _config.flavors.containsKey(_activeFlavor)) {
        final flavorEnv = _config.flavors[_activeFlavor]!.envFile ?? '.env.$_activeFlavor';
        if (!envFilesToLoad.contains(flavorEnv)) {
          envFilesToLoad.add(flavorEnv);
        }
      }

      for (final envFile in envFilesToLoad) {
        try {
          final assetEnv = await rootBundle.loadString(envFile);
          if (assetEnv.isNotEmpty) {
            BloomEnv.loadContent(assetEnv, overwrite: true);
            logger.debug('BloomEnv: Loaded environment file: $envFile');
          }
        } catch (_) {}
      }
    }

    // 5. Configure logger
    logger.info('Booting Bloom application "${_config.name}" (v${_config.version})${_activeFlavor != null ? ' [Flavor: $_activeFlavor]' : ''}');

    // 6. Register core framework bindings in DI
    container.provideValue<BloomConfig>(_config);

    // 7. Initialize Deep Links listener
    if (_config.deepLinks.enabled) {
      await BloomDeepLinks.initialize(
        routeMappings: _config.deepLinks.routeMappings,
      );
    }

    // 8. Auto-register VM DevTools Service extensions & start cache GC
    BloomDevToolsService.register();
    BloomData.startGarbageCollector();

    // 9. Initialize OTA Code-Push if enabled
    if (_config.deployment.shorebird.enabled) {
      await BloomOTA.initialize();
      if (_config.deployment.shorebird.autoCheckUpdate) {
        unawaited(BloomOTA.checkForUpdate());
      }
    }

    // 10. Execute user bootstrapper if provided
    if (bootstrapper != null) {
      await bootstrapper.onBoot(container);
    }

    _isBooted = true;
    logger.info('Bloom boot completed successfully.');
  }

  /// Create an isolated test scope for unit and widget testing with optional dependency overrides.
  static BloomTestScope createTestScope({List<BloomTestOverride<dynamic>>? overrides}) {
    return BloomTestScope(parent: container, overrides: overrides);
  }

  /// Reset Bloom runtime state (useful between tests).
  static void reset() {
    _isBooted = false;
    _config = const BloomConfig();
    _activeFlavor = null;
    BloomEnv.clear();
    resetActiveContainer();
    BloomDeepLinks.dispose();
    BloomData.stopGarbageCollector();
    BloomOTA.reset();
    BloomModuleRegistry().reset();
  }
}
