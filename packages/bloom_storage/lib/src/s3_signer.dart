import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Complete, standard AWS Signature Version 4 (SigV4) implementation for S3.
///
/// Implements full RFC-compliant request signing and presigned URL generation
/// for AWS S3, Cloudflare R2, MinIO, and Supabase Storage S3 APIs without external SDK dependencies.
///
/// Example:
/// ```dart
/// final signer = S3Signer(
///   accessKeyId: 'AKIAEXAMPLE',
///   secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
///   region: 'us-east-1',
/// );
///
/// // Sign an HTTP PUT request
/// final uri = Uri.parse('https://my-bucket.s3.us-east-1.amazonaws.com/image.png');
/// final payload = [1, 2, 3, 4];
/// final headers = signer.signRequest(
///   method: 'PUT',
///   uri: uri,
///   headers: {'content-type': 'image/png'},
///   payload: payload,
/// );
///
/// // Generate a presigned GET URL
/// final presignedUrl = signer.generatePresignedUrl(
///   uri: uri,
///   expiry: const Duration(minutes: 15),
/// );
/// ```
class S3Signer {
  /// AWS access key ID or compatible API key.
  final String accessKeyId;

  /// AWS secret access key or compatible API secret.
  final String secretAccessKey;

  /// Target AWS or provider region (e.g. `us-east-1`, `auto`).
  final String region;

  /// S3 service name used in the credential scope (defaults to `'s3'`).
  final String service;

  /// Optional AWS STS session token for temporary credentials.
  final String? sessionToken;

  /// Creates an [S3Signer] configured with AWS credentials and region.
  ///
  /// - [accessKeyId]: AWS access key identifier.
  /// - [secretAccessKey]: AWS secret access key.
  /// - [region]: Target AWS region name (e.g. `us-east-1`, `auto`).
  /// - [service]: Target AWS service identifier (defaults to `'s3'`).
  /// - [sessionToken]: Optional STS session token for temporary credentials.
  ///
  /// Example:
  /// ```dart
  /// final signer = S3Signer(
  ///   accessKeyId: 'KEY',
  ///   secretAccessKey: 'SECRET',
  ///   region: 'us-east-1',
  /// );
  /// ```
  const S3Signer({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.region,
    this.service = 's3',
    this.sessionToken,
  });

  /// Formats a [DateTime] [dt] into basic ISO 8601 format (`YYYYMMDDTHHMMSSZ`) required by AWS SigV4.
  ///
  /// Example:
  /// ```dart
  /// final amzDate = S3Signer.formatIso8601Basic(DateTime.utc(2026, 8, 24, 12, 0, 0));
  /// // Returns: '20260824T120000Z'
  /// ```
  static String formatIso8601Basic(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min${s}Z';
  }

  /// Formats a [DateTime] [dt] into date stamp format (`YYYYMMDD`) used in the AWS SigV4 credential scope.
  ///
  /// Example:
  /// ```dart
  /// final dateStamp = S3Signer.formatDateStamp(DateTime.utc(2026, 8, 24));
  /// // Returns: '20260824'
  /// ```
  static String formatDateStamp(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// Encodes URI [path] segments per RFC 3986 for AWS SigV4 canonical requests.
  ///
  /// Ensures each path segment is properly percent-encoded while preserving slashes.
  ///
  /// Example:
  /// ```dart
  /// final encoded = S3Signer.canonicalUriEncode('photos/summer vacation/1.png');
  /// // Returns: '/photos/summer%20vacation/1.png'
  /// ```
  static String canonicalUriEncode(String path) {
    if (path.isEmpty || path == '/') return '/';
    final segments = path.split('/');
    final encoded = segments.map((seg) => Uri.encodeComponent(seg)).join('/');
    return encoded.startsWith('/') ? encoded : '/$encoded';
  }

  /// Signs an HTTP request and returns a complete map of headers including `Authorization`,
  /// `x-amz-date`, and `x-amz-content-sha256`.
  ///
  /// - [method]: HTTP request method (`GET`, `PUT`, `DELETE`, `HEAD`, etc.).
  /// - [uri]: Target object [Uri].
  /// - [headers]: Existing request headers to include in signing.
  /// - [payload]: Request body bytes used to compute the SHA-256 payload hash.
  /// - [requestTime]: Optional explicit timestamp override for signing (defaults to `DateTime.now().toUtc()`).
  ///
  /// Returns a map of HTTP headers with AWS SigV4 authorization headers attached.
  ///
  /// Example:
  /// ```dart
  /// final signedHeaders = signer.signRequest(
  ///   method: 'PUT',
  ///   uri: Uri.parse('https://mybucket.s3.amazonaws.com/doc.pdf'),
  ///   headers: {'content-type': 'application/pdf'},
  ///   payload: pdfBytes,
  /// );
  /// ```
  Map<String, String> signRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required List<int> payload,
    DateTime? requestTime,
  }) {
    final now = requestTime ?? DateTime.now().toUtc();
    final amzDate = formatIso8601Basic(now);
    final dateStamp = formatDateStamp(now);
    final payloadHash = sha256.convert(payload).toString();

    final signedHeadersMap = <String, String>{...headers};
    signedHeadersMap['x-amz-date'] = amzDate;
    signedHeadersMap['x-amz-content-sha256'] = payloadHash;
    signedHeadersMap['host'] = uri.hasPort && uri.port != 80 && uri.port != 443
        ? '${uri.host}:${uri.port}'
        : uri.host;

    if (sessionToken != null) {
      signedHeadersMap['x-amz-security-token'] = sessionToken!;
    }

    // Sort header keys
    final sortedHeaderKeys = signedHeadersMap.keys.map((k) => k.toLowerCase()).toList()..sort();
    final canonicalHeaders = StringBuffer();
    for (final key in sortedHeaderKeys) {
      // Find corresponding value
      final entry = signedHeadersMap.entries.firstWhere((e) => e.key.toLowerCase() == key);
      canonicalHeaders.write('$key:${entry.value.trim().replaceAll(RegExp(r'\s+'), ' ')}\n');
    }
    final signedHeadersList = sortedHeaderKeys.join(';');

    // Canonical Query String
    final canonicalQueryString = _buildCanonicalQueryString(uri.queryParameters);

    // Canonical Request
    final canonicalRequest = [
      method.toUpperCase(),
      canonicalUriEncode(uri.path),
      canonicalQueryString,
      canonicalHeaders.toString(),
      signedHeadersList,
      payloadHash,
    ].join('\n');

    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();
    final credentialScope = '$dateStamp/$region/$service/aws4_request';

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    final signingKey = _deriveSigningKey(secretAccessKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/$credentialScope, SignedHeaders=$signedHeadersList, Signature=$signature';

    return {
      ...signedHeadersMap,
      'Authorization': authorization,
    };
  }

  /// Generates an AWS SigV4 presigned URL for `GET` access without exposing credentials.
  ///
  /// - [uri]: Full target object [Uri] to presign.
  /// - [expiry]: [Duration] for which the presigned URL remains valid.
  /// - [requestTime]: Optional explicit timestamp override for the signature date.
  ///
  /// Returns the complete URL string containing AWS SigV4 authentication query parameters.
  ///
  /// Example:
  /// ```dart
  /// final url = signer.generatePresignedUrl(
  ///   uri: Uri.parse('https://mybucket.s3.amazonaws.com/private/report.pdf'),
  ///   expiry: const Duration(hours: 1),
  /// );
  /// ```
  String generatePresignedUrl({
    required Uri uri,
    required Duration expiry,
    DateTime? requestTime,
  }) {
    final now = requestTime ?? DateTime.now().toUtc();
    final amzDate = formatIso8601Basic(now);
    final dateStamp = formatDateStamp(now);
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final hostHeader = uri.hasPort && uri.port != 80 && uri.port != 443
        ? '${uri.host}:${uri.port}'
        : uri.host;

    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    queryParams['X-Amz-Credential'] = '$accessKeyId/$credentialScope';
    queryParams['X-Amz-Date'] = amzDate;
    queryParams['X-Amz-Expires'] = expiry.inSeconds.toString();
    queryParams['X-Amz-SignedHeaders'] = 'host';
    if (sessionToken != null) {
      queryParams['X-Amz-Security-Token'] = sessionToken!;
    }

    final canonicalQueryString = _buildCanonicalQueryString(queryParams);
    final canonicalHeaders = 'host:$hostHeader\n';
    const signedHeaders = 'host';
    const payloadHash = 'UNSIGNED-PAYLOAD';

    final canonicalRequest = [
      'GET',
      canonicalUriEncode(uri.path),
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    final signingKey = _deriveSigningKey(secretAccessKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    return uri.replace(query: '$canonicalQueryString&X-Amz-Signature=$signature').toString();
  }

  String _buildCanonicalQueryString(Map<String, String> queryParameters) {
    if (queryParameters.isEmpty) return '';
    final sortedKeys = queryParameters.keys.toList()..sort();
    return sortedKeys.map((key) {
      final value = queryParameters[key]!;
      return '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}';
    }).join('&');
  }

  List<int> _deriveSigningKey(
    String secret,
    String dateStamp,
    String regionName,
    String serviceName,
  ) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$secret')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }
}
