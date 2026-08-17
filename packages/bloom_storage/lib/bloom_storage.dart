/// File storage abstraction library for Bloom applications.
///
/// Provides swappable backends for local disk storage ([LocalDiskBackend]) and S3-compatible
/// cloud object stores ([S3Backend]) such as AWS S3, Cloudflare R2, MinIO, Wasabi, and Supabase Storage S3.
/// Features canonical path traversal protection and pure-Dart AWS SigV4 request signing ([S3Signer]).
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
///   // 3. Upload a file using the abstraction
///   final avatarBytes = utf8.encode('pretend-image-binary-data');
///   final resultUrl = await BloomStorage.upload(
///     'avatars/user-123.png',
///     avatarBytes,
///     contentType: 'image/png',
///   );
///   print('Uploaded file URL: $resultUrl');
/// }
/// ```
library bloom_storage;

export 'src/exceptions.dart';
export 'src/local_disk_backend.dart';
export 'src/s3_backend.dart';
export 'src/s3_config.dart';
export 'src/s3_signer.dart';
export 'src/storage_backend.dart';
