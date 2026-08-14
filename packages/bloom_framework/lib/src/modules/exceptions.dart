// lib/src/modules/exceptions.dart

/// Base exception for errors originating across the Bloom Native Module boundary.
class BloomNativeException implements Exception {
  /// Machine-readable error code (e.g. 'PERMISSION_DENIED', 'HARDWARE_UNAVAILABLE').
  final String code;

  /// Human-readable error description.
  final String message;

  /// Optional platform-specific error payload.
  final dynamic details;

  /// Original stack trace from the host platform or Dart runtime.
  final StackTrace? stackTrace;

  const BloomNativeException({
    required this.code,
    required this.message,
    this.details,
    this.stackTrace,
  });

  @override
  String toString() => 'BloomNativeException[$code]: $message${details != null ? ' (Details: $details)' : ''}';
}

/// Thrown when a required native OS permission was denied or restricted.
class BloomNativePermissionDeniedException extends BloomNativeException {
  final String permission;

  BloomNativePermissionDeniedException({
    required this.permission,
    required String message,
    dynamic details,
  }) : super(
          code: 'PERMISSION_DENIED',
          message: message,
          details: details ?? {'permission': permission},
        );
}

/// Thrown when hardware sensor, camera, or peripheral is busy, absent, or disabled.
class BloomNativeHardwareUnavailableException extends BloomNativeException {
  final String hardware;

  BloomNativeHardwareUnavailableException({
    required this.hardware,
    required String message,
    dynamic details,
  }) : super(
          code: 'HARDWARE_UNAVAILABLE',
          message: message,
          details: details ?? {'hardware': hardware},
        );
}

/// Thrown when a native module encounters invalid configuration or missing keys in bloom.yaml.
class BloomNativeConfigurationException extends BloomNativeException {
  BloomNativeConfigurationException({
    required String message,
    dynamic details,
  }) : super(
          code: 'CONFIGURATION_ERROR',
          message: message,
          details: details,
        );
}

/// Thrown when an internal native SDK operation or bridge promise rejected.
class BloomNativeOperationFailedException extends BloomNativeException {
  BloomNativeOperationFailedException({
    required String message,
    dynamic details,
    StackTrace? stackTrace,
  }) : super(
          code: 'OPERATION_FAILED',
          message: message,
          details: details,
          stackTrace: stackTrace,
        );
}
