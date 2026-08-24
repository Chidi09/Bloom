// lib/src/modules/exceptions.dart

/// Base exception for errors originating across the Bloom Native Module boundary.
///
/// Encapsulates machine-readable error codes, human-readable error messages,
/// platform-specific error detail payloads, and stack traces.
///
/// Example:
/// ```dart
/// try {
///   await cameraModule.invokeAsync('takePicture');
/// } on BloomNativeException catch (e) {
///   print('Native error [${e.code}]: ${e.message}');
/// }
/// ```
class BloomNativeException implements Exception {
  /// Machine-readable error code (e.g. `'PERMISSION_DENIED'`, `'HARDWARE_UNAVAILABLE'`).
  final String code;

  /// Human-readable error description.
  final String message;

  /// Optional platform-specific error payload or metadata dictionary.
  final dynamic details;

  /// Original stack trace from the host platform or Dart runtime.
  final StackTrace? stackTrace;

  /// Creates a [BloomNativeException] instance.
  const BloomNativeException({
    required this.code,
    required this.message,
    this.details,
    this.stackTrace,
  });

  @override
  String toString() => 'BloomNativeException[$code]: $message${details != null ? ' (Details: $details)' : ''}';
}

/// Thrown when a required native OS permission was denied, restricted, or permanently blocked.
///
/// Example:
/// ```dart
/// try {
///   await cameraModule.takePicture();
/// } on BloomNativePermissionDeniedException catch (e) {
///   print('Camera access denied for permission: ${e.permission}');
/// }
/// ```
class BloomNativePermissionDeniedException extends BloomNativeException {
  /// The permission name that was denied (e.g. `'camera'`, `'location'`).
  final String permission;

  /// Creates a [BloomNativePermissionDeniedException] with the denied [permission] name and [message].
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

/// Thrown when a hardware sensor, camera, or peripheral device is busy, absent, or disabled.
///
/// Example:
/// ```dart
/// try {
///   await bluetoothModule.scan();
/// } on BloomNativeHardwareUnavailableException catch (e) {
///   print('Hardware unavailable: ${e.hardware}');
/// }
/// ```
class BloomNativeHardwareUnavailableException extends BloomNativeException {
  /// The hardware device or sensor identifier that was unavailable (e.g. `'camera'`, `'bluetooth'`).
  final String hardware;

  /// Creates a [BloomNativeHardwareUnavailableException] with the missing [hardware] identifier and [message].
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

/// Thrown when a native module encounters invalid configuration or missing keys in `bloom.yaml` or module manifests.
///
/// Example:
/// ```dart
/// throw BloomNativeConfigurationException(
///   message: 'Missing API key in module configuration',
/// );
/// ```
class BloomNativeConfigurationException extends BloomNativeException {
  /// Creates a [BloomNativeConfigurationException] with an error [message] and optional [details].
  BloomNativeConfigurationException({
    required String message,
    dynamic details,
  }) : super(
          code: 'CONFIGURATION_ERROR',
          message: message,
          details: details,
        );
}

/// Thrown when an internal native SDK operation or bridge promise rejected on the host platform.
///
/// Example:
/// ```dart
/// try {
///   await audioModule.playAudio('track.mp3');
/// } on BloomNativeOperationFailedException catch (e) {
///   print('Native call failed: ${e.message}');
/// }
/// ```
class BloomNativeOperationFailedException extends BloomNativeException {
  /// Creates a [BloomNativeOperationFailedException] with an error [message], optional [details], and [stackTrace].
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
