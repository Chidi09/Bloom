import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'exceptions.dart';
import 'storage_backend.dart';

/// Local filesystem implementation of [BloomStorageBackend].
///
/// Intended for local development, tests, or self-hosted deployments with mounted storage volumes.
/// Enforces canonical path verification to prevent path traversal vulnerabilities.
///
/// Example:
/// ```dart
/// final backend = LocalDiskBackend(
///   baseDirectory: './storage/uploads',
///   publicUrlPrefix: 'http://localhost:8080/static/uploads',
/// );
///
/// // Upload a file
/// final url = await backend.upload(
///   'photos/avatar.png',
///   imageBytes,
///   contentType: 'image/png',
/// );
///
/// // Download a file
/// final bytes = await backend.download('photos/avatar.png');
///
/// // Generate and verify temporary signed URL
/// final signedUrl = await backend.getSignedUrl('photos/avatar.png');
/// final isValid = backend.verifySignedUrl('photos/avatar.png', expiresUnix, signature);
/// ```
class LocalDiskBackend implements BloomStorageBackend {
  /// The root directory on the local filesystem where files are stored.
  final String baseDirectory;

  /// Optional public URL prefix (e.g., `http://localhost:8080/uploads` or `/storage`).
  final String? publicUrlPrefix;

  /// Secret key used for signing local temporary URLs (dev mode).
  final String signingSecret;

  /// The canonical absolute path of [baseDirectory].
  late final String _canonicalBaseDir;

  /// Creates a [LocalDiskBackend] rooted at [baseDirectory].
  ///
  /// - [baseDirectory]: Root folder on disk where files are stored. Created automatically if missing.
  /// - [publicUrlPrefix]: Optional URL prefix for generated public file links.
  /// - [signingSecret]: HMAC secret used by [getSignedUrl] and [verifySignedUrl] to sign and validate local temporary access tokens.
  ///
  /// Example:
  /// ```dart
  /// final backend = LocalDiskBackend(
  ///   baseDirectory: '/var/data/uploads',
  ///   publicUrlPrefix: 'https://example.com/files',
  /// );
  /// ```
  LocalDiskBackend({
    required this.baseDirectory,
    this.publicUrlPrefix,
    this.signingSecret = 'bloom-dev-local-storage-secret-key',
  }) {
    final dir = Directory(baseDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _canonicalBaseDir = p.canonicalize(dir.absolute.path);
  }

  /// Resolves the storage [path] against [baseDirectory] and validates that
  /// the resolved canonical path does not escape [_canonicalBaseDir].
  ///
  /// Throws [BloomStoragePathTraversalException] if path traversal is detected.
  String _resolveAndValidatePath(String relativePath) {
    if (relativePath.contains('\x00')) {
      throw BloomStoragePathTraversalException(
        relativePath,
        'Path contains null bytes.',
      );
    }

    // Normalize slashes
    final normalized = p.normalize(relativePath.replaceAll(r'\', '/')).trim();

    // Prevent explicit root escapes
    final joined = p.join(_canonicalBaseDir, normalized.startsWith('/') ? normalized.substring(1) : normalized);
    final canonicalTarget = p.canonicalize(joined);

    final isWithinBase = canonicalTarget == _canonicalBaseDir ||
        canonicalTarget.startsWith('$_canonicalBaseDir${p.separator}');

    if (!isWithinBase) {
      throw BloomStoragePathTraversalException(
        relativePath,
        'Access denied: Path "$relativePath" resolves to "$canonicalTarget", which is outside base directory "$_canonicalBaseDir".',
      );
    }

    return canonicalTarget;
  }

  /// Writes binary [bytes] to the local filesystem at [path].
  ///
  /// Automatically creates missing intermediate directories.
  ///
  /// - [path]: Relative file path inside [baseDirectory].
  /// - [bytes]: File content to write.
  /// - [contentType]: Optional MIME type hint (ignored on local disk).
  ///
  /// Returns the relative [path] or a full public URL if [publicUrlPrefix] is configured.
  /// Throws [BloomStoragePathTraversalException] if [path] escapes [baseDirectory].
  /// Throws [BloomStorageException] if writing fails.
  ///
  /// Example:
  /// ```dart
  /// final fileUrl = await backend.upload(
  ///   'documents/summary.txt',
  ///   utf8.encode('Annual summary content'),
  /// );
  /// ```
  @override
  Future<String> upload(
    String path,
    List<int> bytes, {
    String? contentType,
  }) async {
    final resolvedPath = _resolveAndValidatePath(path);
    final file = File(resolvedPath);

    // Ensure parent directories exist
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await file.writeAsBytes(bytes, flush: true);

    if (publicUrlPrefix != null) {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final prefix = publicUrlPrefix!.endsWith('/')
          ? publicUrlPrefix!.substring(0, publicUrlPrefix!.length - 1)
          : publicUrlPrefix!;
      return '$prefix/$cleanPath';
    }

    return path;
  }

  /// Reads and returns binary content of the file at [path].
  ///
  /// - [path]: Relative file path inside [baseDirectory].
  ///
  /// Returns the raw byte list of the file.
  /// Throws [BloomFileNotFoundException] if the file does not exist.
  /// Throws [BloomStoragePathTraversalException] if [path] escapes [baseDirectory].
  /// Throws [BloomStorageException] if reading fails.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await backend.download('documents/summary.txt');
  /// ```
  @override
  Future<List<int>> download(String path) async {
    final resolvedPath = _resolveAndValidatePath(path);
    final file = File(resolvedPath);

    if (!await file.exists()) {
      throw BloomFileNotFoundException(path);
    }

    try {
      return await file.readAsBytes();
    } catch (e) {
      if (e is BloomStorageException) rethrow;
      throw BloomStorageException('Failed to read file at "$path"', e);
    }
  }

  /// Deletes the file at [path] from the local filesystem.
  ///
  /// - [path]: Relative file path inside [baseDirectory].
  ///
  /// Throws [BloomFileNotFoundException] if the file does not exist.
  /// Throws [BloomStoragePathTraversalException] if [path] escapes [baseDirectory].
  /// Throws [BloomStorageException] if deletion fails.
  ///
  /// Example:
  /// ```dart
  /// await backend.delete('temp/scratch.txt');
  /// ```
  @override
  Future<void> delete(String path) async {
    final resolvedPath = _resolveAndValidatePath(path);
    final file = File(resolvedPath);

    if (!await file.exists()) {
      throw BloomFileNotFoundException(path);
    }

    try {
      await file.delete();
    } catch (e) {
      if (e is BloomStorageException) rethrow;
      throw BloomStorageException('Failed to delete file at "$path"', e);
    }
  }

  /// Checks if a file exists at [path] on the local filesystem.
  ///
  /// Returns `true` if the file exists within [baseDirectory], or `false` if it does not
  /// exist or attempts directory traversal.
  ///
  /// Example:
  /// ```dart
  /// if (await backend.exists('documents/summary.txt')) {
  ///   print('File exists');
  /// }
  /// ```
  @override
  Future<bool> exists(String path) async {
    try {
      final resolvedPath = _resolveAndValidatePath(path);
      return await File(resolvedPath).exists();
    } on BloomStoragePathTraversalException {
      return false;
    }
  }

  /// Generates a time-limited signed URL for local development and testing.
  ///
  /// Signs the [path] and expiration timestamp with HMAC-SHA256 using [signingSecret].
  ///
  /// - [path]: Relative storage path to sign.
  /// - [expiry]: Duration before the signed link expires (defaults to 15 minutes).
  ///
  /// Returns the signed URL string containing `expires` and `signature` query parameters.
  /// Throws [BloomStoragePathTraversalException] if [path] escapes [baseDirectory].
  ///
  /// Example:
  /// ```dart
  /// final devUrl = await backend.getSignedUrl(
  ///   'reports/preview.pdf',
  ///   expiry: const Duration(minutes: 60),
  /// );
  /// ```
  @override
  Future<String> getSignedUrl(
    String path, {
    Duration expiry = const Duration(minutes: 15),
  }) async {
    // Validate path security first
    _resolveAndValidatePath(path);

    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final expiresAt = DateTime.now().toUtc().add(expiry).millisecondsSinceEpoch ~/ 1000;

    // HMAC-SHA256 signature for local dev URL validation
    final payload = '$cleanPath:$expiresAt';
    final hmac = Hmac(sha256, utf8.encode(signingSecret));
    final signature = hmac.convert(utf8.encode(payload)).toString();

    final base = publicUrlPrefix ?? '/local-storage';
    final prefix = base.endsWith('/') ? base.substring(0, base.length - 1) : base;

    return '$prefix/$cleanPath?expires=$expiresAt&signature=$signature';
  }

  /// Verifies a temporary signed URL generated by [getSignedUrl].
  ///
  /// - [path]: Storage relative path that was signed.
  /// - [expiresAtUnix]: Epoch timestamp (in seconds) when the signature expires.
  /// - [signature]: HMAC-SHA256 signature string to validate against [signingSecret].
  ///
  /// Returns `true` if the signature is valid and the timestamp has not expired; `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final valid = backend.verifySignedUrl('reports/preview.pdf', expiresUnix, signature);
  /// if (!valid) {
  ///   throw BloomStorageAuthException('Invalid or expired signature');
  /// }
  /// ```
  bool verifySignedUrl(String path, int expiresAtUnix, String signature) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    if (nowUnix > expiresAtUnix) {
      return false; // Expired
    }

    final payload = '$cleanPath:$expiresAtUnix';
    final hmac = Hmac(sha256, utf8.encode(signingSecret));
    final expectedSignature = hmac.convert(utf8.encode(payload)).toString();

    return signature == expectedSignature;
  }
}
