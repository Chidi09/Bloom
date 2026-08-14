// lib/src/core/boot.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../config/config.dart';
import '../di/container.dart';
import '../di/scope.dart';
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

  /// Whether Bloom has completed its boot sequence.
  static bool get isBooted => _isBooted;

  /// Active configuration instance.
  static BloomConfig get config => _config;

  /// Global dependency injection container.
  static BloomContainer get container => globalContainer;

  /// Main boot pipeline for Bloom applications.
  static Future<void> boot({
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

    // 3. Load environment variables
    if (envContent != null) {
      BloomEnv.loadContent(envContent);
    } else {
      // Auto-load from assets if bundled
      try {
        final assetEnv = await rootBundle.loadString('.env');
        BloomEnv.loadContent(assetEnv);
      } catch (_) {}
    }

    // 4. Configure logger
    logger.info('Booting Bloom application "${_config.name}" (v${_config.version})');

    // 5. Register core framework bindings in DI
    container.provideValue<BloomConfig>(_config);

    // 6. Execute user bootstrapper if provided
    if (bootstrapper != null) {
      await bootstrapper.onBoot(container);
    }

    _isBooted = true;
    logger.info('Bloom boot completed successfully.');
  }

  /// Create an isolated test scope for unit and widget testing.
  static BloomTestScope createTestScope({List<dynamic>? overrides}) {
    final scope = BloomTestScope(parent: container);
    return scope;
  }

  /// Reset Bloom runtime state (useful between tests).
  static void reset() {
    _isBooted = false;
    _config = const BloomConfig();
    BloomEnv.clear();
    container.reset();
  }
}
