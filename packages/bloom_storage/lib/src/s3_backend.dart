import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'exceptions.dart';
import 's3_config.dart';
import 's3_signer.dart';
import 'storage_backend.dart';

/// S3-compatible implementation of [BloomStorageBackend].
///
/// Works seamlessly with AWS S3, Cloudflare R2, MinIO, Wasabi, Backblaze B2,
/// and Supabase Storage S3 APIs using standard AWS SigV4 request signing.
///
/// Example:
/// ```dart
/// final backend = S3Backend(
///   config: BloomS3Config(
///     accessKeyId: 'AWS_ACCESS_KEY_ID',
///     secretAccessKey: 'AWS_SECRET_ACCESS_KEY',
///     bucket: 'production-assets',
///     region: 'us-east-1',
///   ),
/// );
///
/// // Upload a file
/// final url = await backend.upload(
///   'documents/report.pdf',
///   pdfBytes,
///   contentType: 'application/pdf',
/// );
///
/// // Download a file
/// final bytes = await backend.download('documents/report.pdf');
///
/// // Generate a presigned URL
/// final presigned = await backend.getSignedUrl(
///   'documents/report.pdf',
///   expiry: const Duration(minutes: 30),
/// );
///
/// // Check existence and delete
/// if (await backend.exists('documents/report.pdf')) {
///   await backend.delete('documents/report.pdf');
/// }
/// ```
class S3Backend implements BloomStorageBackend {
  /// S3 configuration options for credentials, bucket, and endpoint.
  final BloomS3Config config;
  final http.Client _httpClient;
  final S3Signer _signer;

  /// Creates an [S3Backend] using the given [config] and optional [httpClient].
  ///
  /// - [config]: S3 connection and bucket options ([BloomS3Config]).
  /// - [httpClient]: Optional custom [http.Client] instance for making HTTP requests (useful for mocking/testing).
  ///
  /// Example:
  /// ```dart
  /// final backend = S3Backend(
  ///   config: BloomS3Config(
  ///     accessKeyId: 'KEY',
  ///     secretAccessKey: 'SECRET',
  ///     bucket: 'my-bucket',
  ///   ),
  /// );
  /// ```
  S3Backend({
    required this.config,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _signer = S3Signer(
          accessKeyId: config.accessKeyId,
          secretAccessKey: config.secretAccessKey,
          region: config.region,
          service: 's3',
          sessionToken: config.sessionToken,
        );

  /// Constructs an [S3Backend] by loading credentials from [BloomEnv] environment variables.
  ///
  /// - [httpClient]: Optional custom [http.Client] instance.
  ///
  /// Throws [StateError] if required environment variables are not set.
  ///
  /// Example:
  /// ```dart
  /// final backend = S3Backend.fromEnv();
  /// ```
  factory S3Backend.fromEnv({http.Client? httpClient}) {
    return S3Backend(
      config: BloomS3Config.fromEnv(),
      httpClient: httpClient,
    );
  }

  /// Builds the full [Uri] targeting the bucket and storage [path].
  Uri _buildObjectUri(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    if (config.endpoint != null) {
      final endpointUri = Uri.parse(config.endpoint!);
      if (config.forcePathStyle) {
        final basePath = endpointUri.path.endsWith('/')
            ? endpointUri.path.substring(0, endpointUri.path.length - 1)
            : endpointUri.path;
        return endpointUri.replace(
          path: '$basePath/${config.bucket}/$cleanPath',
        );
      } else {
        final host = '${config.bucket}.${endpointUri.host}';
        return endpointUri.replace(
          host: host,
          path: '${endpointUri.path}/$cleanPath'.replaceAll('//', '/'),
        );
      }
    }

    // Default AWS S3 addressing
    if (config.forcePathStyle) {
      return Uri.https('s3.${config.region}.amazonaws.com', '/${config.bucket}/$cleanPath');
    } else {
      return Uri.https('${config.bucket}.s3.${config.region}.amazonaws.com', '/$cleanPath');
    }
  }

  /// Uploads binary [bytes] to the S3 bucket at the specified [path].
  ///
  /// - [path]: Remote object key (e.g. `images/profile.png`).
  /// - [bytes]: Binary content to upload.
  /// - [contentType]: Optional MIME type header (defaults to `application/octet-stream`).
  ///
  /// Returns the target URL string (prefixed with [BloomS3Config.publicUrlPrefix] if configured, or the S3 URI).
  /// Throws [BloomStorageAuthException] on HTTP 401 or 403 responses.
  /// Throws [BloomStorageServerException] on unexpected server response status codes.
  ///
  /// Example:
  /// ```dart
  /// final url = await backend.upload(
  ///   'avatars/u100.png',
  ///   imageBytes,
  ///   contentType: 'image/png',
  /// );
  /// ```
  @override
  Future<String> upload(
    String path,
    List<int> bytes, {
    String? contentType,
  }) async {
    final uri = _buildObjectUri(path);
    final payloadBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    final requestHeaders = <String, String>{
      'content-type': contentType ?? 'application/octet-stream',
      'content-length': payloadBytes.length.toString(),
    };

    final signedHeaders = _signer.signRequest(
      method: 'PUT',
      uri: uri,
      headers: requestHeaders,
      payload: payloadBytes,
    );

    final response = await _httpClient.put(
      uri,
      headers: signedHeaders,
      body: payloadBytes,
    );

    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
      if (config.publicUrlPrefix != null) {
        final cleanPath = path.startsWith('/') ? path.substring(1) : path;
        final prefix = config.publicUrlPrefix!.endsWith('/')
            ? config.publicUrlPrefix!.substring(0, config.publicUrlPrefix!.length - 1)
            : config.publicUrlPrefix!;
        return '$prefix/$cleanPath';
      }
      return uri.toString();
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw BloomStorageAuthException(
        'S3 authentication failed during upload to "$path" (HTTP ${response.statusCode}).',
        response.body,
      );
    }

    throw BloomStorageServerException(
      'Failed to upload file to "$path"',
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  /// Downloads binary file content from the S3 bucket at the specified [path].
  ///
  /// - [path]: Remote object key to download.
  ///
  /// Returns the raw byte list of the object.
  /// Throws [BloomFileNotFoundException] if the object does not exist (HTTP 404).
  /// Throws [BloomStorageAuthException] on HTTP 401 or 403 responses.
  /// Throws [BloomStorageServerException] on other non-200 HTTP responses.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await backend.download('exports/report.csv');
  /// ```
  @override
  Future<List<int>> download(String path) async {
    final uri = _buildObjectUri(path);
    const payloadBytes = <int>[];

    final signedHeaders = _signer.signRequest(
      method: 'GET',
      uri: uri,
      headers: {},
      payload: payloadBytes,
    );

    final response = await _httpClient.get(
      uri,
      headers: signedHeaders,
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    if (response.statusCode == 404) {
      throw BloomFileNotFoundException(path);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw BloomStorageAuthException(
        'S3 access denied downloading "$path" (HTTP ${response.statusCode}).',
        response.body,
      );
    }

    throw BloomStorageServerException(
      'Failed to download file from "$path"',
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  /// Deletes the object at [path] from the S3 bucket.
  ///
  /// - [path]: Remote object key to delete.
  ///
  /// Throws [BloomFileNotFoundException] if the object does not exist (HTTP 404).
  /// Throws [BloomStorageAuthException] on HTTP 401 or 403 responses.
  /// Throws [BloomStorageServerException] on other non-2xx responses.
  ///
  /// Example:
  /// ```dart
  /// await backend.delete('temp/temp_123.tmp');
  /// ```
  @override
  Future<void> delete(String path) async {
    final uri = _buildObjectUri(path);
    const payloadBytes = <int>[];

    final signedHeaders = _signer.signRequest(
      method: 'DELETE',
      uri: uri,
      headers: {},
      payload: payloadBytes,
    );

    final response = await _httpClient.delete(
      uri,
      headers: signedHeaders,
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 404) {
      throw BloomFileNotFoundException(path);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw BloomStorageAuthException(
        'S3 access denied deleting "$path" (HTTP ${response.statusCode}).',
        response.body,
      );
    }

    throw BloomStorageServerException(
      'Failed to delete file at "$path"',
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  /// Checks if an object exists at [path] in the S3 bucket using an HTTP `HEAD` request.
  ///
  /// - [path]: Remote object key to check.
  ///
  /// Returns `true` if the object exists (HTTP 200), or `false` if missing (HTTP 404).
  /// Throws [BloomStorageAuthException] on HTTP 401 or 403 responses.
  /// Throws [BloomStorageServerException] on other non-200 responses.
  ///
  /// Example:
  /// ```dart
  /// if (await backend.exists('avatars/user-99.png')) {
  ///   print('Avatar exists');
  /// }
  /// ```
  @override
  Future<bool> exists(String path) async {
    final uri = _buildObjectUri(path);
    const payloadBytes = <int>[];

    final signedHeaders = _signer.signRequest(
      method: 'HEAD',
      uri: uri,
      headers: {},
      payload: payloadBytes,
    );

    final response = await _httpClient.head(
      uri,
      headers: signedHeaders,
    );

    if (response.statusCode == 200) {
      return true;
    }

    if (response.statusCode == 404) {
      return false;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw BloomStorageAuthException(
        'S3 access denied checking existence of "$path" (HTTP ${response.statusCode}).',
      );
    }

    throw BloomStorageServerException(
      'Failed to check existence for "$path"',
      statusCode: response.statusCode,
    );
  }

  /// Generates an AWS SigV4 presigned URL allowing time-limited `GET` access to [path].
  ///
  /// - [path]: Remote object key to presign.
  /// - [expiry]: Duration for which the presigned URL is valid (defaults to 15 minutes).
  ///
  /// Returns the complete presigned URL string with signature query parameters.
  ///
  /// Example:
  /// ```dart
  /// final presignedUrl = await backend.getSignedUrl(
  ///   'private/contracts/contract_42.pdf',
  ///   expiry: const Duration(hours: 2),
  /// );
  /// ```
  @override
  Future<String> getSignedUrl(
    String path, {
    Duration expiry = const Duration(minutes: 15),
  }) async {
    final uri = _buildObjectUri(path);
    return _signer.generatePresignedUrl(
      uri: uri,
      expiry: expiry,
    );
  }

  /// Closes the underlying HTTP client and frees network resources.
  ///
  /// Example:
  /// ```dart
  /// backend.close();
  /// ```
  void close() {
    _httpClient.close();
  }
}
