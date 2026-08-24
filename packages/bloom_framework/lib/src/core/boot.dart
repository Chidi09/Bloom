// lib/src/core/boot.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../config/config.dart';
import '../config/env_schema.dart';
import '../data/cache.dart';
import '../deployment/bloom_ota.dart';
import '../devtools/devtools_service.dart';
import '../di/container.dart';
import '../di/scope.dart';
import '../features/feature_flags.dart';
import '../native/deep_links.dart';
import '../native/permissions.dart';
import '../modules/module_registry.dart';
import '../observability/models.dart';
import '../observability/observability.dart';
import '../updates/bloom_updates.dart';
import '../updates/runtime_fingerprint.dart';
import 'env.dart';
import 'logger.dart';

/// Contract for custom user bootstrapper code in `lib/app/boot.dart`.
///
/// Implement this class to register custom services, repositories, or runtime initialization
/// before the Flutter widget tree is mounted.
///
/// Example:
/// ```dart
/// class AppBootstrapper extends BloomBootstrapper {
///   const AppBootstrapper();
///
///   @override
///   Future<void> onBoot(BloomContainer container) async {
///     container.provideSingleton<AuthService>(() => AuthService());
///   }
/// }
/// ```
abstract class BloomBootstrapper {
  /// Creates a [BloomBootstrapper].
  const BloomBootstrapper();

  /// Invoked during the framework boot sequence before the widget tree is mounted.
  ///
  /// Receives the active [BloomContainer] to register dependencies and initialize plugins.
  FutureOr<void> onBoot(BloomContainer container);
}

/// The core Bloom framework controller and global entrypoint.
///
/// Manages application bootstrapping, runtime configuration, dependency injection,
/// feature flags, observability/crash telemetry, and test lifecycle resetting.
///
/// Example:
/// ```dart
/// void main() async {
///   await Bloom.boot(
///     bootstrapper: const AppBootstrapper(),
///   );
/// }
/// ```
class Bloom {
  static bool _isBooted = false;
  static BloomConfig _config = const BloomConfig();
  static String? _activeFlavor;
  static final BloomFeatureFlags _features = BloomFeatureFlags();

  /// Whether Bloom has completed its boot sequence.
  static bool get isBooted => _isBooted;

  /// Active configuration instance loaded during boot.
  static BloomConfig get config => _config;

  /// Currently active build flavor (e.g. `'development'`, `'staging'`, `'production'`), if specified.
  static String? get activeFlavor => _activeFlavor;

  /// Global dependency injection container.
  static BloomContainer get container => globalContainer;

  /// Dynamic feature flags management service.
  static BloomFeatureFlags get features => _features;

  /// Records a chronological breadcrumb in the observability buffer.
  ///
  /// Breadcrumbs provide context preceding captured errors.
  ///
  /// Example:
  /// ```dart
  /// Bloom.addBreadcrumb(
  ///   category: 'auth',
  ///   message: 'User initiated sign-in',
  ///   level: BloomBreadcrumbLevel.info,
  /// );
  /// ```
  static void addBreadcrumb({
    required String category,
    required String message,
    BloomBreadcrumbLevel level = BloomBreadcrumbLevel.info,
    Map<String, dynamic>? data,
  }) {
    BloomObservability.addBreadcrumb(
      category: category,
      message: message,
      level: level,
      data: data,
    );
  }

  /// Manually captures an exception with structured context and stack trace.
  ///
  /// Returns the generated [BloomTelemetryEvent] if captured, or `null` if dropped by sampling or beforeSend.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await syncData();
  /// } catch (e, stack) {
  ///   await Bloom.captureException(e, stackTrace: stack);
  /// }
  /// ```
  static Future<BloomTelemetryEvent?> captureException(
    dynamic exception, {
    dynamic stackTrace,
    Map<String, dynamic>? context,
    List<String>? fingerprint,
    String? exceptionType,
    BloomErrorLevel level = BloomErrorLevel.error,
  }) {
    return BloomObservability.captureException(
      exception,
      stackTrace: stackTrace,
      context: context,
      fingerprint: fingerprint,
      exceptionType: exceptionType,
      level: level,
    );
  }

  /// Manually captures a message telemetry event.
  ///
  /// Example:
  /// ```dart
  /// await Bloom.captureMessage('Order payment completed', level: BloomErrorLevel.info);
  /// ```
  static Future<BloomTelemetryEvent?> captureMessage(
    String message, {
    BloomErrorLevel level = BloomErrorLevel.info,
    Map<String, dynamic>? context,
    List<String>? fingerprint,
  }) {
    return BloomObservability.captureMessage(
      message,
      level: level,
      context: context,
      fingerprint: fingerprint,
    );
  }

  /// Main boot pipeline for Bloom applications.
  ///
  /// Initializes Flutter bindings, loads and validates configuration and environment variables,
  /// registers DI bindings, configures deep links, starts devtools and observability,
  /// and runs the user [bootstrapper].
  ///
  /// Parameters:
  /// - [flavor]: Optional build flavor name.
  /// - [bootstrapper]: Optional custom bootstrap lifecycle handler.
  /// - [envContent]: Optional raw `.env` string to load directly without file I/O.
  /// - [configYaml]: Optional raw `bloom.yaml` string to load directly.
  /// - [observability]: Custom telemetry and crash reporting options.
  /// - [environmentSchema]: Strict schema validation rules for environment variables.
  static Future<void> boot({
    String? flavor,
    BloomBootstrapper? bootstrapper,
    String? envContent,
    String? configYaml,
    BloomObservabilityConfig? observability,
    BloomEnvironmentSchema? environmentSchema,
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

    // 4b. Enforce strict environment schema validation if specified
    if (environmentSchema != null) {
      BloomEnv.validate(environmentSchema);
    }

    // 4c. Register feature flags from config
    final customFlags = _config.custom['feature_flags'] ?? _config.custom['features'];
    if (customFlags is Map) {
      _features.registerAll(Map<String, dynamic>.from(customFlags));
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

    // 10. Initialize Error Observability & Telemetry SDK
    final runtimeFp = BloomRuntimeFingerprint.fromConfig(_config).computeHash();
    final obsConfig = observability != null
        ? BloomObservabilityConfig(
            enabled: observability.enabled,
            sampleRate: observability.sampleRate,
            autoCaptureFlutterErrors: observability.autoCaptureFlutterErrors,
            autoCaptureZoneErrors: observability.autoCaptureZoneErrors,
            autoCaptureNativeCrashes: observability.autoCaptureNativeCrashes,
            maxBreadcrumbs: observability.maxBreadcrumbs,
            transport: observability.transport,
            beforeSend: observability.beforeSend,
            appInfo: {
              'name': _config.name,
              'version': _config.version,
              'buildNumber': _config.buildNumber,
              ...observability.appInfo,
            },
            tags: observability.tags,
            runtimeFingerprint: observability.runtimeFingerprint ?? runtimeFp,
            bloomVersion: observability.bloomVersion ?? _config.version,
            flutterVersion: observability.flutterVersion ?? '3.27.0',
            channel: observability.channel ?? _activeFlavor ?? 'production',
            activePatchId: observability.activePatchId ??
                BloomOTA.activePatchId ??
                BloomUpdates.activePatchId,
            buildNumber: observability.buildNumber ?? _config.buildNumber,
          )
        : BloomObservabilityConfig(
            enabled: true,
            bloomVersion: _config.version,
            flutterVersion: '3.27.0',
            channel: _activeFlavor ?? 'production',
            activePatchId: BloomOTA.activePatchId ?? BloomUpdates.activePatchId,
            buildNumber: _config.buildNumber,
            runtimeFingerprint: runtimeFp,
            appInfo: {
              'name': _config.name,
              'version': _config.version,
              'buildNumber': _config.buildNumber,
            },
          );
    await BloomObservability.initialize(obsConfig);

    // 11. Execute user bootstrapper if provided
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

  /// Reset Bloom runtime state to a pristine baseline (useful between tests).
  ///
  /// Clears the global DI container, environment variables, feature flags, deep link subscriptions,
  /// simulated native permissions, query cache data & active subscriptions, OTA update states,
  /// registered dynamic modules, and observability ring buffers.
  ///
  /// Guarantees clean state isolation for test suites with zero cross-test state leakage.
  static Future<void> reset() async {
    _isBooted = false;
    _config = const BloomConfig();
    _activeFlavor = null;
    BloomEnv.clear();
    _features.reset();
    resetActiveContainer();
    BloomDeepLinks.dispose();
    BloomPermissions.resetSimulation();
    BloomData.stopGarbageCollector();
    BloomData.clear();
    BloomOTA.reset();
    BloomUpdates.reset();
    BloomModuleRegistry().resetSync();
    await BloomObservability.reset();
  }
}
