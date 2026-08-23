# Changelog

## 0.2.0 - 2026-08-23

### Breaking
- Now depends on `bloom_server` instead of `bloom_framework`. Imports change from
  `package:bloom_framework/bloom_server.dart` to `package:bloom_server/bloom_server.dart`.
- **No longer requires Flutter.** The package now resolves against the Flutter-free
  `bloom_server` core, so it can be used from a plain `dart run`/`dart compile` backend.

## 0.1.0

- Initial release of `bloom_storage`.
- Core abstract interface `BloomStorageBackend` with `upload`, `download`, `delete`, `exists`, and `getSignedUrl`.
- Global DI container integration via `BloomStorage` helper (`BloomStorage.register`, `BloomStorage.current`).
- `LocalDiskBackend` with strict canonical path traversal security checks and dev-only signed URLs.
- `S3Backend` supporting AWS S3, Cloudflare R2, MinIO, and Supabase Storage S3 APIs.
- Pure Dart AWS SigV4 (`S3Signer`) request signing and presigned URL generation.
- Typed exception hierarchy: `BloomStorageException`, `BloomFileNotFoundException`, `BloomStoragePathTraversalException`, `BloomStorageAuthException`, `BloomStorageServerException`.
- `BloomS3Config.fromEnv()` integration with `BloomEnv`.
