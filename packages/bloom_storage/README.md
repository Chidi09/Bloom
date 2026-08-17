# bloom_storage

Swappable file storage abstraction for Bloom server applications. Allows seamless switching between local disk storage and any S3-compatible cloud object store (AWS S3, Cloudflare R2, MinIO, Wasabi, Supabase Storage S3) without coupling application code to vendor-specific SDKs.

## Features

- **Swappable Backend Architecture**: Application services depend on `BloomStorageBackend` interface or `BloomStorage` static accessor, never a concrete backend directly.
- **Bloom DI Integration**: Register backends into Bloom's built-in dependency injection container.
- **Local Disk Backend**: Ideal for local development, unit tests, and self-hosted deployments. Includes strict canonical path traversal protection.
- **S3-Compatible Backend**: Works out of the box with AWS S3, Cloudflare R2, MinIO, Supabase Storage, and Backblaze B2.
- **Zero Heavy SDK Dependencies**: Pure Dart AWS Signature Version 4 (SigV4) implementation for signing HTTP requests and generating temporary signed URLs.
- **Environment-Driven Configuration**: Automatically configures S3 credentials via `BloomEnv`.
- **Strict Typed Exceptions**: Standardized `BloomFileNotFoundException`, `BloomStoragePathTraversalException`, `BloomStorageAuthException`, and `BloomStorageServerException`.

---

## Installation

Add `bloom_storage` to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_storage:
    path: ../bloom_storage # or from git / pub
```

---

## Usage Examples

### 1. Uploading a File via `LocalDiskBackend` (Dev Mode)

In development, configure `LocalDiskBackend` pointing to a local directory.

```dart
import 'dart:convert';
import 'package:bloom_storage/bloom_storage.dart';

void main() async {
  // 1. Initialize local disk backend rooted at ./storage/uploads
  final localBackend = LocalDiskBackend(
    baseDirectory: './storage/uploads',
    publicUrlPrefix: 'http://localhost:8080/files',
  );

  // 2. Register into Bloom DI container
  BloomStorage.register(localBackend);

  // 3. Upload a file using the abstraction
  final avatarBytes = utf8.encode('pretend-image-binary-data');
  final resultUrl = await BloomStorage.upload(
    'avatars/user-123.png',
    avatarBytes,
    contentType: 'image/png',
  );

  print('Uploaded file URL: $resultUrl');
  // Output: http://localhost:8080/files/avatars/user-123.png
}
```

> **Note on Local Signed URLs**: `LocalDiskBackend.getSignedUrl` generates an HMAC-SHA256 token in query parameters (`?expires=...&signature=...`). This is designed for local development testing. In production, local storage should be served behind an authenticating web server, reverse proxy (e.g. Caddy/Nginx), or CDN.

---

### 2. Uploading via `S3Backend` with Custom Endpoint (Cloudflare R2 / MinIO)

To connect to Cloudflare R2, MinIO, or Supabase Storage, supply a custom `endpoint` and credentials in `BloomS3Config` (or load them from `.env` via `BloomEnv`):

```dart
import 'dart:convert';
import 'package:bloom_storage/bloom_storage.dart';

void main() async {
  // Option A: Explicit Configuration for Cloudflare R2
  final r2Config = BloomS3Config(
    accessKeyId: 'your-r2-access-key-id',
    secretAccessKey: 'your-r2-secret-access-key',
    bucket: 'bloom-media',
    region: 'auto',
    endpoint: 'https://<account-id>.r2.cloudflarestorage.com',
    publicUrlPrefix: 'https://cdn.example.com',
  );

  final storageBackend = S3Backend(config: r2Config);
  BloomStorage.register(storageBackend);

  // Option B: Automatically load from BloomEnv (.env file)
  // final storageBackend = S3Backend.fromEnv();
  // BloomStorage.register(storageBackend);

  // Upload file
  final pdfBytes = utf8.encode('%PDF-1.4 ...');
  final fileUrl = await BloomStorage.upload(
    'documents/invoices/inv_2026_001.pdf',
    pdfBytes,
    contentType: 'application/pdf',
  );

  print('Uploaded to S3-compatible backend: $fileUrl');
}
```

#### MinIO / Local S3 Emulator Example

For MinIO or local emulators running on `localhost:9000`, enable `forcePathStyle: true`:

```dart
final minioConfig = BloomS3Config(
  accessKeyId: 'minioadmin',
  secretAccessKey: 'minioadmin',
  bucket: 'local-bucket',
  endpoint: 'http://127.0.0.1:9000',
  forcePathStyle: true,
);

final minioBackend = S3Backend(config: minioConfig);
BloomStorage.register(minioBackend);
```

---

### 3. Generating a Time-Limited Signed URL (Private Files)

Generate secure, expiring URLs for private downloads without making the bucket or directory public:

```dart
import 'package:bloom_storage/bloom_storage.dart';

void main() async {
  // Generates an AWS SigV4 presigned URL valid for 30 minutes
  final signedUrl = await BloomStorage.getSignedUrl(
    'documents/invoices/inv_2026_001.pdf',
    expiry: const Duration(minutes: 30),
  );

  print('Presigned Download URL: $signedUrl');
  // Returns: https://<endpoint>/<bucket>/documents/invoices/inv_2026_001.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...&X-Amz-Date=...&X-Amz-Expires=1800&X-Amz-SignedHeaders=host&X-Amz-Signature=...
}
```

---

### 4. Downloading, Checking Existence, and Deleting

```dart
import 'package:bloom_storage/bloom_storage.dart';

Future<void> handleFileOperations() async {
  const path = 'reports/quarterly.pdf';

  // Check existence
  if (await BloomStorage.exists(path)) {
    // Download
    final bytes = await BloomStorage.download(path);
    print('Downloaded ${bytes.length} bytes');

    // Delete
    await BloomStorage.delete(path);
    print('File deleted');
  } else {
    print('File does not exist');
  }
}
```

---

## Environment Variables Configuration

When using `BloomS3Config.fromEnv()` or `S3Backend.fromEnv()`, define the following variables in your `.env` file:

```bash
# AWS S3 / Cloudflare R2 / MinIO Credentials
S3_ACCESS_KEY_ID=your_access_key
S3_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET=your_bucket_name
S3_REGION=us-east-1 # or 'auto' for Cloudflare R2
S3_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com # Optional, omit for AWS S3
S3_FORCE_PATH_STYLE=false # Set to true for MinIO
S3_PUBLIC_URL_PREFIX=https://cdn.example.com # Optional
```

*(Aliases with `AWS_` prefix like `AWS_ACCESS_KEY_ID` are also supported).*

---

## Security & Path Traversal Protection

`LocalDiskBackend` strictly validates all incoming storage paths using canonical path resolution:
1. Normalizes and strips leading slashes.
2. Combines the relative path with the canonical base directory.
3. Canonicalizes the final path (resolving all `.` and `..` segments and symlinks).
4. Verifies that the resulting canonical path starts with `<canonicalBaseDir>/` or equals `<canonicalBaseDir>`.
5. Throws `BloomStoragePathTraversalException` immediately if an escape attempt is detected.

---

## Current Scope & Limitations

- **Single-shot uploads**: Current implementation performs single-shot HTTP `PUT` and local file writes. Chunked/multipart uploads for multi-gigabyte files are planned for a subsequent release.
