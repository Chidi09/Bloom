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
class LocalDiskBackend implements BloomStorageBackend {
  /// The root directory on the local filesystem where files are stored.
  final String baseDirectory;

  /// Optional public URL prefix (e.g., `http://localhost:8080/uploads` or `/storage`).
  final String? publicUrlPrefix;

  /// Secret key used for signing local temporary URLs (dev mode).
  final String signingSecret;

  /// The canonical absolute path of [baseDirectory].
  late final String _canonicalBaseDir;

  /// Creates a [LocalDiskBackend] with root [baseDirectory].
  ///
  /// - [baseDirectory]: Root folder on disk where files are stored. Created automatically if missing.
  /// - [publicUrlPrefix]: Optional URL prefix for generated public file links.
  /// - [signingSecret]: HMAC secret used by [getSignedUrl] to sign local temporary access tokens.
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

  @override
  Future<bool> exists(String path) async {
    try {
      final resolvedPath = _resolveAndValidatePath(path);
      return await File(resolvedPath).exists();
    } on BloomStoragePathTraversalException {
      return false;
    }
  }

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

  /// Helper to verify a dev-signed URL generated by [getSignedUrl].
  ///
  /// - [path]: Storage relative path that was signed.
  /// - [expiresAtUnix]: Epoch timestamp (in seconds) when the signature expires.
  /// - [signature]: HMAC-SHA256 signature string to validate.
  ///
  /// Returns `true` if the signature matches and has not yet expired.
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
