import 'package:bloom_framework/bloom_server.dart';

/// Abstract contract for Bloom storage backends.
///
/// Application code should depend exclusively on this interface rather than
/// concrete storage implementations, allowing seamless switching between local
/// filesystem, AWS S3, Cloudflare R2, MinIO, or Supabase Storage S3.
abstract class BloomStorageBackend {
  /// Uploads binary [bytes] to the specified storage [path].
  ///
  /// Optionally accepts a MIME [contentType] (e.g. `image/png`, `application/pdf`).
  /// Returns the storage key or a publicly accessible URL.
  Future<String> upload(
    String path,
    List<int> bytes, {
    String? contentType,
  });

  /// Downloads binary file content from the specified storage [path].
  ///
  /// Throws [BloomFileNotFoundException] if the file does not exist.
  Future<List<int>> download(String path);

  /// Deletes the file at the specified storage [path].
  ///
  /// Throws [BloomFileNotFoundException] if the file does not exist.
  Future<void> delete(String path);

  /// Checks if a file exists at the specified storage [path].
  Future<bool> exists(String path);

  /// Generates a time-limited signed URL for temporary read access to a private file.
  ///
  /// [expiry] defaults to 15 minutes if not specified.
  Future<String> getSignedUrl(
    String path, {
    Duration expiry = const Duration(minutes: 15),
  });
}

/// Convenience static accessor for the active storage backend in Bloom DI container.
class BloomStorage {
  BloomStorage._();

  /// Registers a [backend] as the singleton storage backend in Bloom's DI container.
  static void register(BloomStorageBackend backend) {
    provideValue<BloomStorageBackend>(backend);
  }

  /// Resolves the currently registered [BloomStorageBackend] from the active DI container.
  static BloomStorageBackend get current => inject<BloomStorageBackend>();

  /// Resolves the currently registered [BloomStorageBackend] or returns `null`.
  static BloomStorageBackend? get currentOrNull => injectOrNull<BloomStorageBackend>();

  /// Uploads file using current registered backend.
  static Future<String> upload(
    String path,
    List<int> bytes, {
    String? contentType,
  }) =>
      current.upload(path, bytes, contentType: contentType);

  /// Downloads file using current registered backend.
  static Future<List<int>> download(String path) => current.download(path);

  /// Deletes file using current registered backend.
  static Future<void> delete(String path) => current.delete(path);

  /// Checks file existence using current registered backend.
  static Future<bool> exists(String path) => current.exists(path);

  /// Generates signed URL using current registered backend.
  static Future<String> getSignedUrl(
    String path, {
    Duration expiry = const Duration(minutes: 15),
  }) =>
      current.getSignedUrl(path, expiry: expiry);
}
