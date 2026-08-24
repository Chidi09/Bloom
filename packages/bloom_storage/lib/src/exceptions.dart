/// Base exception for all storage-related errors in Bloom.
///
/// Thrown when an underlying storage operation fails, such as filesystem I/O errors,
/// network timeouts, or unhandled backend exceptions.
///
/// Example:
/// ```dart
/// try {
///   await BloomStorage.download('reports/annual.pdf');
/// } on BloomStorageException catch (e) {
///   print('Storage operation failed: ${e.message}');
///   if (e.cause != null) print('Cause: ${e.cause}');
/// }
/// ```
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
///
/// Typically thrown by [BloomStorageReader.download] or [BloomStorageWriter.delete]
/// when the specified storage key is not found on disk or in the remote bucket.
///
/// Example:
/// ```dart
/// try {
///   await BloomStorage.download('missing-file.txt');
/// } on BloomFileNotFoundException catch (e) {
///   print('File not found at path: ${e.path}');
/// }
/// ```
class BloomFileNotFoundException extends BloomStorageException {
  /// The missing storage path.
  final String path;

  /// Creates a [BloomFileNotFoundException] for the given storage [path] with an optional custom [message].
  const BloomFileNotFoundException(this.path, [String? message])
      : super(message ?? 'File not found at storage path: "$path"');

  @override
  String toString() => 'BloomFileNotFoundException: File not found at path "$path"';
}

/// Thrown when an illegal path traversal attempt is detected.
///
/// Occurs when a storage path contains relative navigation components (such as `../`)
/// or null bytes that would resolve outside the configured storage base directory.
///
/// Example:
/// ```dart
/// try {
///   await localBackend.download('../../etc/passwd');
/// } on BloomStoragePathTraversalException catch (e) {
///   print('Path traversal blocked for: ${e.path}');
/// }
/// ```
class BloomStoragePathTraversalException extends BloomStorageException {
  /// The illegal storage path that attempted traversal.
  final String path;

  /// Creates a [BloomStoragePathTraversalException] for the given [path] with an optional custom [message].
  const BloomStoragePathTraversalException(this.path, [String? message])
      : super(message ?? 'Path traversal detected for storage path: "$path"');

  @override
  String toString() => 'BloomStoragePathTraversalException: $message';
}

/// Thrown when storage authentication or credential verification fails.
///
/// Occurs when remote S3 credentials (Access Key, Secret Key, or STS Token)
/// are invalid or lack permissions (HTTP 401 Unauthorized or HTTP 403 Forbidden).
///
/// Example:
/// ```dart
/// try {
///   await s3Backend.upload('doc.pdf', bytes);
/// } on BloomStorageAuthException catch (e) {
///   print('Storage auth error: ${e.message}');
/// }
/// ```
class BloomStorageAuthException extends BloomStorageException {
  /// Creates a [BloomStorageAuthException] with an error [message] and optional underlying [cause].
  const BloomStorageAuthException(super.message, [super.cause]);

  @override
  String toString() => 'BloomStorageAuthException: $message';
}

/// Thrown when a remote storage service encounters an unexpected server error or non-2xx status code.
///
/// Captures the HTTP [statusCode] and optional [responseBody] returned by the object store.
///
/// Example:
/// ```dart
/// try {
///   await s3Backend.upload('doc.pdf', bytes);
/// } on BloomStorageServerException catch (e) {
///   print('S3 error HTTP ${e.statusCode}: ${e.message}');
///   if (e.responseBody != null) print('Body: ${e.responseBody}');
/// }
/// ```
class BloomStorageServerException extends BloomStorageException {
  /// HTTP status code returned by the storage server.
  final int statusCode;

  /// Optional HTTP response body from the storage server.
  final String? responseBody;

  /// Creates a [BloomStorageServerException] with [statusCode], error [message],
  /// and optional [responseBody] or underlying [cause].
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
