import 'package:bloom_server/bloom_server.dart';
import 'exceptions.dart';

/// Read-only storage interface following the Interface Segregation Principle.
///
/// Enables consumers to depend strictly on reading capabilities without requiring write or delete permissions.
///
/// Example:
/// ```dart
/// class AssetService {
///   final BloomStorageReader storage;
///   AssetService(this.storage);
///
///   Future<List<int>> loadAsset(String name) => storage.download('assets/$name');
/// }
/// ```
abstract class BloomStorageReader {
  /// Downloads binary file content from the specified storage [path].
  ///
  /// Returns the raw byte list of the requested file.
  /// Throws [BloomFileNotFoundException] if the file does not exist.
  /// Throws [BloomStoragePathTraversalException] if [path] attempts directory traversal.
  /// Throws [BloomStorageException] if downloading fails due to network or I/O errors.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await storage.download('documents/invoice-1001.pdf');
  /// ```
  Future<List<int>> download(String path);

  /// Checks if a file exists at the specified storage [path].
  ///
  /// Returns `true` if the file exists and is accessible, or `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (await storage.exists('avatars/user-42.png')) {
  ///   print('Avatar found');
  /// }
  /// ```
  Future<bool> exists(String path);

  /// Generates a time-limited signed URL for temporary read access to a private file.
  ///
  /// - [path]: Storage relative path of the file to presign.
  /// - [expiry]: Duration for which the signed URL remains valid (defaults to 15 minutes).
  ///
  /// Returns the complete presigned URL string.
  /// Throws [BloomStoragePathTraversalException] if [path] is invalid.
  ///
  /// Example:
  /// ```dart
  /// final downloadLink = await storage.getSignedUrl(
  ///   'reports/confidential.xlsx',
  ///   expiry: const Duration(hours: 1),
  /// );
  /// ```
  Future<String> getSignedUrl(
    String path, {
    Duration expiry = const Duration(minutes: 15),
  });
}

/// Write-only storage interface following the Interface Segregation Principle.
///
/// Enables consumers to depend strictly on upload and deletion capabilities.
///
/// Example:
/// ```dart
/// class ImageUploadService {
///   final BloomStorageWriter storage;
///   ImageUploadService(this.storage);
///
///   Future<String> saveImage(String key, List<int> bytes) =>
///       storage.upload(key, bytes, contentType: 'image/jpeg');
/// }
/// ```
abstract class BloomStorageWriter {
  /// Uploads binary [bytes] to the specified storage [path].
  ///
  /// - [path]: Destination storage path or key.
  /// - [bytes]: Raw file bytes to write or upload.
  /// - [contentType]: Optional MIME type header (e.g. `image/png`, `application/pdf`).
  ///
  /// Returns the resulting storage path or publicly accessible URL string.
  /// Throws [BloomStoragePathTraversalException] if [path] attempts traversal outside storage root.
  /// Throws [BloomStorageAuthException] if storage credentials are unauthorized.
  /// Throws [BloomStorageException] if writing or uploading fails.
  ///
  /// Example:
  /// ```dart
  /// final fileUrl = await storage.upload(
  ///   'uploads/photo.jpg',
  ///   imageBytes,
  ///   contentType: 'image/jpeg',
  /// );
  /// ```
  Future<String> upload(
    String path,
    List<int> bytes, {
    String? contentType,
  });

  /// Deletes the file at the specified storage [path].
  ///
  /// Throws [BloomFileNotFoundException] if the target file does not exist.
  /// Throws [BloomStoragePathTraversalException] if [path] is invalid.
  /// Throws [BloomStorageException] if deletion fails.
  ///
  /// Example:
  /// ```dart
  /// await storage.delete('temp/scratch.txt');
  /// ```
  Future<void> delete(String path);
}

/// Full abstract contract for Bloom storage backends composing read and write interfaces.
///
/// Application code can depend on this interface to allow seamless switching
/// between local filesystem storage and cloud providers (AWS S3, Cloudflare R2, MinIO, Wasabi, Supabase).
///
/// Example:
/// ```dart
/// class ProfileService {
///   final BloomStorageBackend storage;
///   ProfileService(this.storage);
///
///   Future<String> updateAvatar(String userId, List<int> bytes) async {
///     return storage.upload('avatars/$userId.png', bytes, contentType: 'image/png');
///   }
/// }
/// ```
abstract class BloomStorageBackend implements BloomStorageReader, BloomStorageWriter {
  @override
  Future<String> upload(
    String path,
    List<int> bytes, {
    String? contentType,
  });

  @override
  Future<List<int>> download(String path);

  @override
  Future<void> delete(String path);

  @override
  Future<bool> exists(String path);

  @override
  Future<String> getSignedUrl(
    String path, {
    Duration expiry = const Duration(minutes: 15),
  });
}

/// Convenience static accessor for the active [BloomStorageBackend] in Bloom's DI container.
///
/// Uses Bloom's built-in dependency injection (`provideValue` / `inject`) so that
/// any layer in the server application can access the configured storage backend
/// without passing references manually.
///
/// Example:
/// ```dart
/// // Setup during server bootstrap
/// BloomStorage.register(LocalDiskBackend(baseDirectory: './uploads'));
///
/// // Usage in route handlers or services
/// final url = await BloomStorage.upload('files/hello.txt', [104, 101, 108, 108, 111]);
/// final content = await BloomStorage.download('files/hello.txt');
/// final exists = await BloomStorage.exists('files/hello.txt');
/// await BloomStorage.delete('files/hello.txt');
/// ```
class BloomStorage {
  BloomStorage._();

  /// Registers a [backend] as the singleton [BloomStorageBackend] in Bloom's DI container.
  ///
  /// Example:
  /// ```dart
  /// BloomStorage.register(LocalDiskBackend(baseDirectory: './storage'));
  /// ```
  static void register(BloomStorageBackend backend) {
    provideValue<BloomStorageBackend>(backend);
  }

  /// Resolves the currently registered [BloomStorageBackend] from the active DI container.
  ///
  /// Throws a [StateError] if no [BloomStorageBackend] has been registered.
  ///
  /// Example:
  /// ```dart
  /// final backend = BloomStorage.current;
  /// ```
  static BloomStorageBackend get current => inject<BloomStorageBackend>();

  /// Resolves the currently registered [BloomStorageBackend] or returns `null` if none is registered.
  ///
  /// Example:
  /// ```dart
  /// final backend = BloomStorage.currentOrNull;
  /// if (backend != null) {
  ///   // Storage is configured
  /// }
  /// ```
  static BloomStorageBackend? get currentOrNull => injectOrNull<BloomStorageBackend>();

  /// Uploads binary [bytes] to [path] using the currently registered backend.
  ///
  /// - [path]: Destination storage path or key.
  /// - [bytes]: Raw file bytes to write or upload.
  /// - [contentType]: Optional MIME content type (e.g. `image/png`).
  ///
  /// Returns the resulting storage path or publicly accessible URL.
  ///
  /// Example:
  /// ```dart
  /// final url = await BloomStorage.upload('docs/readme.txt', utf8.encode('Hello'));
  /// ```
  static Future<String> upload(
    String path,
    List<int> bytes, {
    String? contentType,
  }) =>
      current.upload(path, bytes, contentType: contentType);

  /// Downloads binary file content from [path] using the currently registered backend.
  ///
  /// Throws [BloomFileNotFoundException] if the file does not exist.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await BloomStorage.download('docs/readme.txt');
  /// ```
  static Future<List<int>> download(String path) => current.download(path);

  /// Deletes the file at [path] using the currently registered backend.
  ///
  /// Throws [BloomFileNotFoundException] if the file does not exist.
  ///
  /// Example:
  /// ```dart
  /// await BloomStorage.delete('docs/readme.txt');
  /// ```
  static Future<void> delete(String path) => current.delete(path);

  /// Checks if a file exists at [path] using the currently registered backend.
  ///
  /// Returns `true` if the file exists, or `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (await BloomStorage.exists('docs/readme.txt')) {
  ///   print('File exists');
  /// }
  /// ```
  static Future<bool> exists(String path) => current.exists(path);

  /// Generates a time-limited signed URL for [path] using the currently registered backend.
  ///
  /// - [path]: Storage relative path to sign.
  /// - [expiry]: Validity duration for the signed link (defaults to 15 minutes).
  ///
  /// Returns the presigned URL string.
  ///
  /// Example:
  /// ```dart
  /// final presignedUrl = await BloomStorage.getSignedUrl(
  ///   'exports/report.csv',
  ///   expiry: const Duration(minutes: 30),
  /// );
  /// ```
  static Future<String> getSignedUrl(
    String path, {
    Duration expiry = const Duration(minutes: 15),
  }) =>
      current.getSignedUrl(path, expiry: expiry);
}
