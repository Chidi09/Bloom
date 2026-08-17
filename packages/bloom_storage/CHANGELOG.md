# Changelog

## 0.1.0

- Initial release of `bloom_storage`.
- Core abstract interface `BloomStorageBackend` with `upload`, `download`, `delete`, `exists`, and `getSignedUrl`.
- Global DI container integration via `BloomStorage` helper (`BloomStorage.register`, `BloomStorage.current`).
- `LocalDiskBackend` with strict canonical path traversal security checks and dev-only signed URLs.
- `S3Backend` supporting AWS S3, Cloudflare R2, MinIO, and Supabase Storage S3 APIs.
- Pure Dart AWS SigV4 (`S3Signer`) request signing and presigned URL generation.
- Typed exception hierarchy: `BloomStorageException`, `BloomFileNotFoundException`, `BloomStoragePathTraversalException`, `BloomStorageAuthException`, `BloomStorageServerException`.
- `BloomS3Config.fromEnv()` integration with `BloomEnv`.
