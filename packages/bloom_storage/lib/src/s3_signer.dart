import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Complete, standard AWS Signature Version 4 (SigV4) implementation for S3.
///
/// Implements full RFC-compliant request signing and presigned URL generation
/// for AWS S3, Cloudflare R2, MinIO, and Supabase Storage S3 APIs without external SDK dependencies.
class S3Signer {
  /// AWS access key ID or compatible API key.
  final String accessKeyId;

  /// AWS secret access key or compatible API secret.
  final String secretAccessKey;

  /// Target AWS or provider region (e.g. `us-east-1`, `auto`).
  final String region;

  /// S3 service name used in the credential scope (defaults to `'s3'`).
  final String service;

  /// Optional AWS STS session token.
  final String? sessionToken;

  /// Creates an [S3Signer] configured with AWS credentials and region.
  ///
  /// - [accessKeyId]: AWS access key identifier.
  /// - [secretAccessKey]: AWS secret access key.
  /// - [region]: Target AWS region name (e.g. `us-east-1`).
  /// - [service]: Target AWS service identifier (defaults to `'s3'`).
  /// - [sessionToken]: Optional STS session token for temporary credentials.
  const S3Signer({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.region,
    this.service = 's3',
    this.sessionToken,
  });

  /// Formats date to `YYYYMMDDTHHMMSSZ`.
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

  /// Formats date to `YYYYMMDD`.
  static String formatDateStamp(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// Encodes URI path segments per RFC 3986 for AWS SigV4.
  static String canonicalUriEncode(String path) {
    if (path.isEmpty || path == '/') return '/';
    final segments = path.split('/');
    final encoded = segments.map((seg) => Uri.encodeComponent(seg)).join('/');
    return encoded.startsWith('/') ? encoded : '/$encoded';
  }

  /// Signs an HTTP request and returns the map of headers including `Authorization`.
  ///
  /// - [method]: HTTP request method (`GET`, `PUT`, `DELETE`, etc.).
  /// - [uri]: Target object URI.
  /// - [headers]: Existing request headers to include in signing.
  /// - [payload]: Request body bytes used to compute SHA-256 payload hash.
  /// - [requestTime]: Optional explicit timestamp override for signing.
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

  /// Generates an AWS SigV4 presigned URL for GET access.
  ///
  /// - [uri]: Full target object URI to presign.
  /// - [expiry]: Duration for which the presigned URL remains valid.
  /// - [requestTime]: Optional explicit timestamp override for the signature date.
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
