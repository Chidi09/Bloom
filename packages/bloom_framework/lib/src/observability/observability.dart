/// Core Error Observability, Crash Reporting, and Telemetry Engine for Bloom.
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' show ErrorCallback;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/logger.dart';
import '../core/platform_info.dart';
import '../updates/runtime_fingerprint.dart';
import 'breadcrumbs.dart';
import 'fingerprint.dart';
import 'models.dart';
import 'transport.dart';

/// Callback signature for intercepting, modifying, or dropping telemetry events before transmission.
///
/// Return `null` to drop the event, or return the original/modified [event] to proceed.
typedef BeforeSendCallback = BloomTelemetryEvent? Function(BloomTelemetryEvent event);

/// Configuration options for Bloom Error Observability and Telemetry SDK.
///
/// Example:
/// ```dart
/// final config = BloomObservabilityConfig(
///   enabled: true,
///   sampleRate: 1.0,
///   autoCaptureFlutterErrors: true,
///   autoCaptureZoneErrors: true,
///   transport: BloomHttpTelemetryTransport(
///     endpoint: Uri.parse('https://telemetry.example.com/events'),
///   ),
/// );
/// ```
class BloomObservabilityConfig {
  /// Whether observability telemetry capturing is enabled.
  final bool enabled;

  /// Sampling rate between 0.0 (0%) and 1.0 (100%).
  final double sampleRate;

  /// Whether to automatically capture Flutter widget framework errors.
  final bool autoCaptureFlutterErrors;

  /// Whether to automatically capture asynchronous zone errors via [PlatformDispatcher].
  final bool autoCaptureZoneErrors;

  /// Whether to capture native iOS/Android crashes via native channel bridge.
  final bool autoCaptureNativeCrashes;

  /// Maximum capacity of in-memory breadcrumbs ring buffer.
  final int maxBreadcrumbs;

  /// Telemetry transport used to transmit event payloads.
  final BloomTelemetryTransport transport;

  /// Optional filter / mutation callback invoked before sending an event.
  final BeforeSendCallback? beforeSend;

  /// Application metadata dictionary.
  final Map<String, dynamic> appInfo;

  /// Global tags attached to all captured events.
  final Map<String, dynamic> tags;

  /// Active runtime binary fingerprint hash override.
  final String? runtimeFingerprint;

  /// Bloom framework version string.
  final String? bloomVersion;

  /// Flutter runtime version string.
  final String? flutterVersion;

  /// Release deployment channel.
  final String? channel;

  /// Active Shorebird OTA patch identifier.
  final String? activePatchId;

  /// Application build number.
  final String? buildNumber;

  /// Creates a [BloomObservabilityConfig] options instance.
  BloomObservabilityConfig({
    this.enabled = true,
    double sampleRate = 1.0,
    this.autoCaptureFlutterErrors = true,
    this.autoCaptureZoneErrors = true,
    this.autoCaptureNativeCrashes = false,
    this.maxBreadcrumbs = 100,
    BloomTelemetryTransport? transport,
    this.beforeSend,
    this.appInfo = const {},
    this.tags = const {},
    this.runtimeFingerprint,
    this.bloomVersion,
    this.flutterVersion,
    this.channel,
    this.activePatchId,
    this.buildNumber,
  })  : sampleRate = sampleRate.clamp(0.0, 1.0),
        transport = transport ?? BloomMemoryTelemetryTransport();
}

/// Core Error Observability, Crash Reporting, and Telemetry Engine for Bloom.
///
/// Automatically hooks Flutter error handlers and provides manual APIs to record
/// breadcrumbs, capture exceptions, and dispatch telemetry payloads.
///
/// Example:
/// ```dart
/// await BloomObservability.initialize(
///   BloomObservabilityConfig(
///     transport: BloomHttpTelemetryTransport(endpoint: myUri),
///   ),
/// );
///
/// BloomObservability.addBreadcrumb(
///   category: 'auth',
///   message: 'User logged in',
/// );
/// ```
class BloomObservability {
  static BloomObservabilityConfig _config = BloomObservabilityConfig();
  static late BloomBreadcrumbRingBuffer _ringBuffer;
  static bool _isInitialized = false;

  static const MethodChannel _nativeChannel = MethodChannel('bloom/observability');

  static FlutterExceptionHandler? _originalFlutterOnError;
  static ErrorCallback? _originalPlatformOnError;
  static bool _flutterHookInstalled = false;
  static bool _platformHookInstalled = false;

  static final Random _random = Random();
  static int _eventCounter = 0;

  /// Whether observability is actively initialized and enabled.
  static bool get isInitialized => _isInitialized;

  /// The active configuration.
  static BloomObservabilityConfig get config => _config;

  /// Current chronological list of recorded breadcrumbs.
  static List<BloomBreadcrumb> get breadcrumbs => _ringBuffer.toList();

  /// Method channel for native crash bridge (used for testing or custom native hooks).
  @visibleForTesting
  static MethodChannel get nativeChannel => _nativeChannel;

  /// Initializes the observability pipeline and attaches automated error hooks.
  static Future<void> initialize(BloomObservabilityConfig config) async {

    if (_isInitialized) {
      await reset();
    }

    _config = config;
    _ringBuffer = BloomBreadcrumbRingBuffer(maxCapacity: config.maxBreadcrumbs);
    _isInitialized = true;

    if (!config.enabled) {
      logger.info('BloomObservability: Disabled by configuration.');
      return;
    }

    // 1. Hook Flutter widget error pipeline
    if (config.autoCaptureFlutterErrors) {
      _originalFlutterOnError = FlutterError.onError;
      _flutterHookInstalled = true;
      FlutterError.onError = (FlutterErrorDetails details) {
        captureException(
          details.exception,
          stackTrace: details.stack,
          context: {
            'library': details.library ?? 'flutter_framework',
            'context': details.context?.toDescription() ?? 'rendering',
            ..._config.tags,
          },
          level: BloomErrorLevel.error,
        );

        if (_originalFlutterOnError != null) {
          _originalFlutterOnError!(details);
        }
      };
    }

    // 2. Hook PlatformDispatcher asynchronous unhandled errors
    if (config.autoCaptureZoneErrors) {
      _originalPlatformOnError = PlatformDispatcher.instance.onError;
      _platformHookInstalled = true;
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        captureException(
          error,
          stackTrace: stack,
          context: {
            'origin': 'platform_dispatcher_async',
            ..._config.tags,
          },
          level: BloomErrorLevel.fatal,
        );

        if (_originalPlatformOnError != null) {
          return _originalPlatformOnError!(error, stack);
        }
        return true;
      };
    }

    // 3. Native platform crash handler hook (Android/iOS)
    if (config.autoCaptureNativeCrashes && !kIsWeb) {
      try {
        await _nativeChannel.invokeMethod<void>('enableNativeCrashReporting');
        final pendingCrashes =
            await _nativeChannel.invokeListMethod<dynamic>('getPendingNativeCrashes');
        if (pendingCrashes != null && pendingCrashes.isNotEmpty) {
          for (final crash in pendingCrashes) {
            if (crash is Map) {
              await captureException(
                crash['message'] ?? 'Native Crash',
                exceptionType: crash['exceptionType']?.toString() ?? 'NativeCrash',
                stackTrace: crash['stackTrace']?.toString(),
                context: {
                  'native': true,
                  if (crash['signal'] != null) 'signal': crash['signal'],
                  if (crash['context'] is Map)
                    ...Map<String, dynamic>.from(crash['context'] as Map),
                  ..._config.tags,
                },
                level: BloomErrorLevel.fatal,
              );
            }
          }
          await _nativeChannel.invokeMethod<void>('clearPendingNativeCrashes');
        }
      } catch (e) {
        logger.debug('BloomObservability: Native crash bridge unhandled or stubbed: $e');
      }
    }

    logger.info(
        'BloomObservability: Initialized (Sampling: ${(config.sampleRate * 100).toInt()}%, Ring Buffer: ${config.maxBreadcrumbs})');
  }

  /// Records a new breadcrumb in the in-memory timeline.
  static void addBreadcrumb({
    required String category,
    required String message,
    BloomBreadcrumbLevel level = BloomBreadcrumbLevel.info,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized || !_config.enabled) return;

    final breadcrumb = BloomBreadcrumb(
      category: category,
      message: message,
      level: level,
      data: data,
    );

    _ringBuffer.add(breadcrumb);
    logger.debug('[BREADCRUMB] [$category] $message');
  }

  /// Captures a handled or unhandled exception with context and breadcrumbs.
  static Future<BloomTelemetryEvent?> captureException(
    dynamic exception, {
    dynamic stackTrace,
    Map<String, dynamic>? context,
    List<String>? fingerprint,
    String? exceptionType,
    BloomErrorLevel level = BloomErrorLevel.error,
  }) async {
    if (!_isInitialized || !_config.enabled) return null;

    // Apply client-side sample rate evaluation
    if (_config.sampleRate < 1.0 && _random.nextDouble() > _config.sampleRate) {
      return null;
    }

    final effectiveType = exceptionType ?? exception.runtimeType.toString();
    final message = exception.toString();
    final stackStr = stackTrace?.toString() ?? StackTrace.current.toString();

    // Compute deterministic crash fingerprint
    final computedFingerprint = BloomCrashFingerprint.compute(
      exceptionType: effectiveType,
      message: message,
      stackTrace: stackStr,
      customFingerprint: fingerprint,
    );
    final fingerprintHash = BloomCrashFingerprint.hashTokens(computedFingerprint);

    _eventCounter++;
    final eventId = 'err_${DateTime.now().millisecondsSinceEpoch}_$_eventCounter';

    // Assemble metadata payloads
    final appPayload = {
      'name': _config.appInfo['name'] ?? 'bloom_app',
      'version': _config.bloomVersion ?? _config.appInfo['version'] ?? '1.0.0',
      'buildNumber': _config.buildNumber ?? _config.appInfo['buildNumber'] ?? '1',
      ..._config.appInfo,
    };

    final runtimePayload = {
      'bloomVersion': _config.bloomVersion ??
          _config.appInfo['bloomVersion'] ??
          _config.appInfo['version'] ??
          '1.0.0',
      'dartVersion': kIsWeb ? 'web' : getDartSdkVersion(),
      'flutterVersion': _config.flutterVersion ?? _config.appInfo['flutterVersion'] ?? '3.27.0',
      'runtimeFingerprint': _config.runtimeFingerprint ??
          BloomRuntimeFingerprint.current().computeHash(),
      'channel': _config.channel ?? _config.appInfo['channel'] ?? 'production',
      if (_config.activePatchId != null || _config.appInfo['activePatchId'] != null)
        'activePatchId': _config.activePatchId ?? _config.appInfo['activePatchId'],
    };

    final devicePayload = {
      'isWeb': kIsWeb,
      'platform': kIsWeb ? 'web' : getOperatingSystem(),
      'osVersion': kIsWeb ? 'browser' : getOperatingSystemVersion(),
    };

    final eventContext = {
      ..._config.tags,
      if (context != null) ...context,
    };

    var event = BloomTelemetryEvent(
      eventId: eventId,
      timestamp: DateTime.now().toUtc(),
      level: level,
      exceptionType: effectiveType,
      message: message,
      stackTrace: stackStr,
      fingerprint: computedFingerprint,
      fingerprintHash: fingerprintHash,
      context: eventContext,
      breadcrumbs: _ringBuffer.toList(),
      app: appPayload,
      runtime: runtimePayload,
      device: devicePayload,
    );

    // Apply beforeSend mutation/filter hook
    if (_config.beforeSend != null) {
      final modifiedEvent = _config.beforeSend!(event);
      if (modifiedEvent == null) {
        logger.debug('BloomObservability: Event $eventId dropped by beforeSend filter.');
        return null;
      }
      event = modifiedEvent;
    }

    // Transmit via configured transport
    try {
      await _config.transport.send(event);
      logger.info(
          'BloomObservability: Captured $effectiveType [$eventId] (${event.breadcrumbs.length} breadcrumbs)');
    } catch (e, stack) {
      logger.error('BloomObservability: Failed to transmit event: $e', stack);
    }

    return event;
  }

  /// Captures a structured log message as a telemetry event.
  static Future<BloomTelemetryEvent?> captureMessage(
    String message, {
    BloomErrorLevel level = BloomErrorLevel.info,
    Map<String, dynamic>? context,
    List<String>? fingerprint,
  }) async {
    return captureException(
      message,
      context: context,
      fingerprint: fingerprint,
      exceptionType: 'message',
      level: level,
    );
  }

  /// Clears in-memory breadcrumbs.
  static void clearBreadcrumbs() {
    if (_isInitialized) {
      _ringBuffer.clear();
    }
  }

  /// Resets the observability subsystem and restores original error handlers.
  static Future<void> reset() async {
    if (_flutterHookInstalled) {
      FlutterError.onError = _originalFlutterOnError;
      _originalFlutterOnError = null;
      _flutterHookInstalled = false;
    }
    if (_platformHookInstalled) {
      PlatformDispatcher.instance.onError = _originalPlatformOnError;
      _originalPlatformOnError = null;
      _platformHookInstalled = false;
    }

    await _config.transport.close();
    _config = BloomObservabilityConfig();
    _ringBuffer = BloomBreadcrumbRingBuffer(maxCapacity: 100);
    _isInitialized = false;
  }
}
