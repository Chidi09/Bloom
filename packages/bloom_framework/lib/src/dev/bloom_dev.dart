// lib/src/dev/bloom_dev.dart
import '../core/logger.dart';

/// Exception thrown when a simulated offline network call is executed.
class BloomOfflineException implements Exception {
  final String message;
  final Uri? uri;

  BloomOfflineException([this.message = 'Device is offline (simulated).', this.uri]);

  @override
  String toString() => 'BloomOfflineException: $message${uri != null ? ' (URI: $uri)' : ''}';
}

/// Developer tooling harness for simulating network latency, outages, and failure rates.
class BloomDev {
  static bool _isOffline = false;
  static Duration? _latency;
  static double _failureRate = 0.0;
  static int _failureStatusCode = 500;

  /// Whether the device is currently in a simulated offline state.
  static bool get isOffline => _isOffline;

  /// Artificial latency injected into network requests.
  static Duration? get latency => _latency;

  /// Simulated network failure probability (0.0 = 0%, 1.0 = 100%).
  static double get failureRate => _failureRate;

  /// HTTP status code returned during simulated failures.
  static int get failureStatusCode => _failureStatusCode;

  /// Simulates degraded network conditions with latency and probabilistic failures.
  static void simulateNetwork({
    Duration? latency,
    double failureRate = 0.0,
    int failureStatusCode = 500,
  }) {
    _latency = latency;
    _failureRate = failureRate.clamp(0.0, 1.0);
    _failureStatusCode = failureStatusCode;
    logger.warn('BloomDev: Network simulation active (Latency: ${latency?.inMilliseconds ?? 0}ms, FailureRate: ${(_failureRate * 100).toStringAsFixed(1)}%)');
  }

  /// Toggles device offline network state.
  static void setOffline(bool offline) {
    _isOffline = offline;
    logger.warn('BloomDev: Simulated offline state set to: $offline');
  }

  /// Resets all network simulation parameters to normal defaults.
  static void reset() {
    _isOffline = false;
    _latency = null;
    _failureRate = 0.0;
    _failureStatusCode = 500;
  }
}
