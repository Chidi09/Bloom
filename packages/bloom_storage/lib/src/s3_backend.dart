import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'exceptions.dart';
import 's3_config.dart';
import 's3_signer.dart';
import 'storage_backend.dart';

/// S3-compatible implementation of [BloomStorageBackend].
///
/// Compatible with AWS S3, Cloudflare R2, MinIO, Supabase Storage S3 API,
/// and other standard S3 object stores.
class S3Backend implements BloomStorageBackend {
  final BloomS3Config config;
  final http.Client _httpClient;
  final S3Signer _signer;

  /// Creates an [S3Backend] using the given [config] and optional [httpClient].
  ///
  /// - [config]: S3 connection and bucket options ([BloomS3Config]).
  /// - [httpClient]: Optional custom [http.Client] instance for making requests.
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

  /// Constructs an [S3Backend] by loading credentials from [BloomEnv].
  ///
  /// - [httpClient]: Optional custom [http.Client] instance.
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

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close();
  }
}
