/// Base exception for all storage-related errors in Bloom.
class BloomStorageException implements Exception {
  /// Description of the storage error.
  final String message;

  /// Underlying cause or root exception, if any.
  final dynamic cause;

  /// Creates a [BloomStorageException] with an error [message] and optional [cause].
  const BloomStorageException(this.message, [this.cause]);

  @override
  String toString() =>
      cause != null ? 'BloomStorageException: $message (Cause: $cause)' : 'BloomStorageException: $message';
}

/// Thrown when an operation targets a file or storage key that does not exist.
class BloomFileNotFoundException extends BloomStorageException {
  /// The missing storage path.
  final String path;

  /// Creates a [BloomFileNotFoundException] for the given storage [path].
  const BloomFileNotFoundException(this.path, [String? message])
      : super(message ?? 'File not found at storage path: "$path"');

  @override
  String toString() => 'BloomFileNotFoundException: File not found at path "$path"';
}

/// Thrown when an illegal path traversal attempt is detected.
class BloomStoragePathTraversalException extends BloomStorageException {
  /// The illegal storage path that attempted traversal.
  final String path;

  /// Creates a [BloomStoragePathTraversalException] for the given [path].
  const BloomStoragePathTraversalException(this.path, [String? message])
      : super(message ?? 'Path traversal detected for storage path: "$path"');

  @override
  String toString() => 'BloomStoragePathTraversalException: $message';
}

/// Thrown when storage authentication or credential verification fails.
class BloomStorageAuthException extends BloomStorageException {
  /// Creates a [BloomStorageAuthException] with an error [message] and optional [cause].
  const BloomStorageAuthException(super.message, [super.cause]);

  @override
  String toString() => 'BloomStorageAuthException: $message';
}

/// Thrown when a remote storage service encounters an unexpected server error or status code.
class BloomStorageServerException extends BloomStorageException {
  /// HTTP status code returned by the storage server.
  final int statusCode;

  /// Optional HTTP response body from the storage server.
  final String? responseBody;

  /// Creates a [BloomStorageServerException] with [statusCode], [message], and optional [responseBody].
  const BloomStorageServerException(
    String message, {
    required this.statusCode,
    this.responseBody,
    dynamic cause,
  }) : super(message, cause);

  @override
  String toString() =>
      'BloomStorageServerException(HTTP $statusCode): $message${responseBody != null ? '\nResponse: $responseBody' : ''}';
}
