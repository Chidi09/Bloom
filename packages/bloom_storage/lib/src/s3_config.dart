import 'package:bloom_framework/bloom_server.dart';

/// Configuration options for S3 and S3-compatible object storage backends.
///
/// Compatible with AWS S3, Cloudflare R2, MinIO, Wasabi, Backblaze B2,
/// and Supabase Storage S3 APIs.
class BloomS3Config {
  /// AWS access key ID / S3 API key.
  final String accessKeyId;

  /// AWS secret access key / S3 API secret.
  final String secretAccessKey;

  /// The target object storage bucket name.
  final String bucket;

  /// The AWS region or provider region (e.g. `us-east-1`, `auto` for Cloudflare R2).
  final String region;

  /// Optional custom endpoint URL for S3-compatible providers
  /// (e.g. `https://<account_id>.r2.cloudflarestorage.com`, `http://127.0.0.1:9000`, `https://<project-ref>.supabase.co/storage/v1/s3`).
  /// If `null`, standard AWS S3 endpoint `https://s3.<region>.amazonaws.com` is used.
  final String? endpoint;

  /// Whether to force path-style addressing (`endpoint/bucket/key`) instead of
  /// virtual-hosted style (`bucket.endpoint/key`). Required for MinIO and local emulators.
  final bool forcePathStyle;

  /// Optional AWS STS session token for temporary credentials.
  final String? sessionToken;

  /// Optional public CDN or custom domain URL prefix for uploaded files
  /// (e.g. `https://cdn.example.com` or `https://pub-<hash>.r2.dev`).
  final String? publicUrlPrefix;

  /// Creates an S3 storage backend configuration.
  ///
  /// - [accessKeyId]: AWS access key or compatible S3 key ID.
  /// - [secretAccessKey]: AWS secret key or compatible S3 secret.
  /// - [bucket]: Object storage bucket name.
  /// - [region]: AWS region or provider region (defaults to `us-east-1`).
  /// - [endpoint]: Custom endpoint URL for providers like Cloudflare R2, MinIO, or Supabase Storage.
  /// - [forcePathStyle]: If `true`, addresses objects as `endpoint/bucket/key` rather than `bucket.endpoint/key`.
  /// - [sessionToken]: Optional AWS STS session token.
  /// - [publicUrlPrefix]: Optional CDN or custom domain prefix for generated file URLs.
  const BloomS3Config({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.bucket,
    this.region = 'us-east-1',
    this.endpoint,
    this.forcePathStyle = false,
    this.sessionToken,
    this.publicUrlPrefix,
  });

  /// Loads configuration automatically from [BloomEnv] environment variables.
  ///
  /// Supported environment variables:
  /// - `S3_ACCESS_KEY_ID` or `AWS_ACCESS_KEY_ID` (Required)
  /// - `S3_SECRET_ACCESS_KEY` or `AWS_SECRET_ACCESS_KEY` (Required)
  /// - `S3_BUCKET` or `AWS_BUCKET` (Required)
  /// - `S3_REGION` or `AWS_REGION` (Default: `us-east-1`)
  /// - `S3_ENDPOINT` or `AWS_ENDPOINT` (Optional)
  /// - `S3_FORCE_PATH_STYLE` or `AWS_FORCE_PATH_STYLE` (Optional boolean, default: `false`)
  /// - `S3_SESSION_TOKEN` or `AWS_SESSION_TOKEN` (Optional)
  /// - `S3_PUBLIC_URL_PREFIX` (Optional)
  factory BloomS3Config.fromEnv() {
    final accessKeyId = BloomEnv.getOrNull('S3_ACCESS_KEY_ID') ??
        BloomEnv.getOrNull('AWS_ACCESS_KEY_ID');
    if (accessKeyId == null || accessKeyId.isEmpty) {
      throw StateError(
        'BloomS3Config: Missing required environment variable "S3_ACCESS_KEY_ID" or "AWS_ACCESS_KEY_ID".',
      );
    }

    final secretAccessKey = BloomEnv.getOrNull('S3_SECRET_ACCESS_KEY') ??
        BloomEnv.getOrNull('AWS_SECRET_ACCESS_KEY');
    if (secretAccessKey == null || secretAccessKey.isEmpty) {
      throw StateError(
        'BloomS3Config: Missing required environment variable "S3_SECRET_ACCESS_KEY" or "AWS_SECRET_ACCESS_KEY".',
      );
    }

    final bucket = BloomEnv.getOrNull('S3_BUCKET') ??
        BloomEnv.getOrNull('AWS_BUCKET');
    if (bucket == null || bucket.isEmpty) {
      throw StateError(
        'BloomS3Config: Missing required environment variable "S3_BUCKET" or "AWS_BUCKET".',
      );
    }

    final region = BloomEnv.getOrNull('S3_REGION') ??
        BloomEnv.getOrNull('AWS_REGION') ??
        'us-east-1';

    final endpoint = BloomEnv.getOrNull('S3_ENDPOINT') ??
        BloomEnv.getOrNull('AWS_ENDPOINT');

    final forcePathStyle = BloomEnv.has('S3_FORCE_PATH_STYLE')
        ? BloomEnv.getBool('S3_FORCE_PATH_STYLE')
        : (BloomEnv.has('AWS_FORCE_PATH_STYLE')
            ? BloomEnv.getBool('AWS_FORCE_PATH_STYLE')
            : (endpoint != null && (endpoint.contains('localhost') || endpoint.contains('127.0.0.1'))));

    final sessionToken = BloomEnv.getOrNull('S3_SESSION_TOKEN') ??
        BloomEnv.getOrNull('AWS_SESSION_TOKEN');

    final publicUrlPrefix = BloomEnv.getOrNull('S3_PUBLIC_URL_PREFIX');

    return BloomS3Config(
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
      bucket: bucket,
      region: region,
      endpoint: endpoint,
      forcePathStyle: forcePathStyle,
      sessionToken: sessionToken,
      publicUrlPrefix: publicUrlPrefix,
    );
  }
}
