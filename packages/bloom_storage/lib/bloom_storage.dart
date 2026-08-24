/// File storage abstraction library for Bloom applications.
///
/// Provides swappable backends for local disk storage ([LocalDiskBackend]) and S3-compatible
/// cloud object stores ([S3Backend]) such as AWS S3, Cloudflare R2, MinIO, Wasabi, and Supabase Storage S3.
/// Features canonical path traversal protection and pure-Dart AWS SigV4 request signing ([S3Signer]).
///
/// ## Features
///
/// - **Swappable Backends**: Uniform interface ([BloomStorageBackend], [BloomStorageReader], [BloomStorageWriter])
///   for local filesystem and S3-compatible object stores.
/// - **Dependency Injection**: Static helper [BloomStorage] integrates with Bloom DI (`provideValue` / `inject`).
/// - **Pure-Dart SigV4 Signing**: Built-in [S3Signer] signs AWS S3 requests and generates presigned URLs
///   without requiring heavy third-party AWS SDKs.
/// - **Path Traversal Protection**: [LocalDiskBackend] validates and canonicalizes paths to prevent directory
///   traversal attacks outside the designated storage root.
/// - **Configuration from Environment**: [BloomS3Config.fromEnv] loads S3 configuration directly from standard
///   environment variables.
///
/// ## Quick Start
///
/// ### Local Filesystem Storage
///
/// ```dart
/// import 'dart:convert';
/// import 'package:bloom_storage/bloom_storage.dart';
///
/// void main() async {
///   // 1. Initialize local disk backend rooted at ./storage/uploads
///   final localBackend = LocalDiskBackend(
///     baseDirectory: './storage/uploads',
///     publicUrlPrefix: 'http://localhost:8080/files',
///   );
///
///   // 2. Register into Bloom DI container
///   BloomStorage.register(localBackend);
///
///   // 3. Upload a file using the static abstraction
///   final avatarBytes = utf8.encode('image-binary-data');
///   final resultUrl = await BloomStorage.upload(
///     'avatars/user-123.png',
///     avatarBytes,
///     contentType: 'image/png',
///   );
///   print('Uploaded file URL: $resultUrl');
///
///   // 4. Download file content
///   final downloaded = await BloomStorage.download('avatars/user-123.png');
///   print('Downloaded ${downloaded.length} bytes');
///
///   // 5. Generate a temporary signed access URL
///   final signedUrl = await BloomStorage.getSignedUrl(
///     'avatars/user-123.png',
///     expiry: const Duration(minutes: 30),
///   );
///   print('Signed URL: $signedUrl');
/// }
/// ```
///
/// ### S3 / Cloudflare R2 / MinIO Storage
///
/// ```dart
/// import 'package:bloom_storage/bloom_storage.dart';
///
/// void main() async {
///   // Configure S3 or Cloudflare R2
///   final s3Config = BloomS3Config(
///     accessKeyId: 'MY_ACCESS_KEY',
///     secretAccessKey: 'MY_SECRET_KEY',
///     bucket: 'my-app-uploads',
///     region: 'auto', // or 'us-east-1'
///     endpoint: 'https://<account_id>.r2.cloudflarestorage.com',
///     publicUrlPrefix: 'https://cdn.example.com',
///   );
///
///   final s3Backend = S3Backend(config: s3Config);
///   BloomStorage.register(s3Backend);
/// }
/// ```
library;

export 'src/exceptions.dart';
export 'src/local_disk_backend.dart';
export 'src/s3_backend.dart';
export 'src/s3_config.dart';
export 'src/s3_signer.dart';
export 'src/storage_backend.dart';
