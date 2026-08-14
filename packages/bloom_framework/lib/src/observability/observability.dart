// lib/src/observability/observability.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' show ErrorCallback;
import 'package:flutter/foundation.dart';
import '../core/logger.dart';
import '../updates/runtime_fingerprint.dart';
import 'breadcrumbs.dart';
import 'fingerprint.dart';
import 'models.dart';
import 'transport.dart';

typedef BeforeSendCallback = BloomTelemetryEvent? Function(BloomTelemetryEvent event);

/// Configuration options for Bloom Error Observability and Telemetry SDK.
class BloomObservabilityConfig {
  final bool enabled;
  final double sampleRate;
  final bool autoCaptureFlutterErrors;
  final bool autoCaptureZoneErrors;
  final bool autoCaptureNativeCrashes;
  final int maxBreadcrumbs;
  final BloomTelemetryTransport transport;
  final BeforeSendCallback? beforeSend;
  final Map<String, dynamic> appInfo;
  final Map<String, dynamic> tags;
  final String? runtimeFingerprint;

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
  })  : sampleRate = sampleRate.clamp(0.0, 1.0),
        transport = transport ?? BloomMemoryTelemetryTransport();
}

/// Core Error Observability, Crash Reporting, and Telemetry Engine for Bloom.
class BloomObservability {
  static BloomObservabilityConfig _config = BloomObservabilityConfig();
  static late BloomBreadcrumbRingBuffer _ringBuffer;
  static bool _isInitialized = false;

  static FlutterExceptionHandler? _originalFlutterOnError;
  static ErrorCallback? _originalPlatformOnError;

  static final Random _random = Random();
  static int _eventCounter = 0;

  /// Whether observability is actively initialized and enabled.
  static bool get isInitialized => _isInitialized;

  /// The active configuration.
  static BloomObservabilityConfig get config => _config;

  /// Current chronological list of recorded breadcrumbs.
  static List<BloomBreadcrumb> get breadcrumbs => _ringBuffer.toList();

  /// Initializes the observability pipeline and attaches automated error hooks.
  static void initialize(BloomObservabilityConfig config) {
    if (_isInitialized) {
      reset();
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

    // 3. Native platform crash handler hook
    if (config.autoCaptureNativeCrashes) {
      // TODO(native): Register platform-channel signal handler for native Android/iOS crashes.
      logger.debug('BloomObservability: Native crash capture requested (platform channel bridge).');
    }

    logger.info('BloomObservability: Initialized (Sampling: ${(config.sampleRate * 100).toInt()}%, Ring Buffer: ${config.maxBreadcrumbs})');
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

    _eventCounter++;
    final eventId = 'err_${DateTime.now().millisecondsSinceEpoch}_$_eventCounter';

    // Assemble metadata payloads
    final appPayload = {
      'name': _config.appInfo['name'] ?? 'bloom_app',
      'version': _config.appInfo['version'] ?? '1.0.0',
      'buildNumber': _config.appInfo['buildNumber'] ?? '1',
      ..._config.appInfo,
    };

    final runtimePayload = {
      'bloomVersion': _config.appInfo['bloomVersion'] ?? _config.appInfo['version'] ?? '1.0.0',
      'dartVersion': kIsWeb ? 'web' : Platform.version.split(' ').first,
      'flutterVersion': _config.appInfo['flutterVersion'] ?? '3.27.0',
      'runtimeFingerprint': _config.runtimeFingerprint ??
          BloomRuntimeFingerprint.current().computeHash(),
      'channel': _config.appInfo['channel'] ?? 'production',
      if (_config.appInfo['activePatchId'] != null)
        'activePatchId': _config.appInfo['activePatchId'],
    };

    final devicePayload = {
      'isWeb': kIsWeb,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'osVersion': kIsWeb ? 'browser' : Platform.operatingSystemVersion,
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
      logger.info('BloomObservability: Captured $effectiveType [$eventId] (${event.breadcrumbs.length} breadcrumbs)');
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
  static void reset() {
    if (_originalFlutterOnError != null) {
      FlutterError.onError = _originalFlutterOnError;
      _originalFlutterOnError = null;
    }
    if (_originalPlatformOnError != null) {
      PlatformDispatcher.instance.onError = _originalPlatformOnError;
      _originalPlatformOnError = null;
    }

    _config.transport.close();
    _config = BloomObservabilityConfig();
    _ringBuffer = BloomBreadcrumbRingBuffer(maxCapacity: 100);
    _isInitialized = false;
  }
}
