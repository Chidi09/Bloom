// lib/src/backend.dart
import 'message.dart';

/// Exception thrown by Bloom mail backends upon configuration or delivery failure.
class BloomMailException implements Exception {
  /// Description of the error.
  final String message;

  /// Underlying error cause, if any.
  final Object? cause;

  /// Stack trace of the underlying error, if any.
  final StackTrace? stackTrace;

  /// Creates a [BloomMailException].
  const BloomMailException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    if (cause != null) {
      return 'BloomMailException: $message (Caused by: $cause)';
    }
    return 'BloomMailException: $message';
  }
}

/// Abstract interface defining a pluggable email delivery backend for Bloom applications.
///
/// Implementations deliver emails via SMTP, local console logs, file writes,
/// or in-memory recording. Backends should be registered with [BloomContainer]
/// and injected into services to maintain testability and provider-independence.
abstract interface class BloomMailBackend {
  /// Delivers the specified email [message].
  ///
  /// Throws [BloomMailException] if sending fails.
  Future<void> send(BloomMailMessage message);
}

/// Alias for [BloomMailBackend].
typedef MailBackend = BloomMailBackend;

/// Alias for [BloomMailException].
typedef MailException = BloomMailException;

