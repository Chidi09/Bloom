// lib/src/server/bloom_request.dart
import 'dart:convert';
import 'dart:typed_data';

/// Represents an incoming HTTP request in Bloom API routes and full-stack SSR server.
class BloomRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, String> params;
  final Uint8List rawBody;

  BloomRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.params = const {},
    Uint8List? rawBody,
  }) : rawBody = rawBody ?? Uint8List(0);

  String get path => uri.path;
  Map<String, String> get queryParams => uri.queryParameters;

  /// Parses request body as UTF-8 string.
  String text() => utf8.decode(rawBody);

  /// Parses request body as decoded JSON.
  dynamic json() {
    final str = text();
    if (str.trim().isEmpty) return null;
    return jsonDecode(str);
  }

  /// Parses URL-encoded form data.
  Map<String, String> formData() {
    final str = text();
    if (str.trim().isEmpty) return {};
    return Uri.splitQueryString(str);
  }

  /// Creates a copy with modified properties (useful in middleware pipeline).
  BloomRequest copyWith({
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    Map<String, String>? params,
    Uint8List? rawBody,
  }) {
    return BloomRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      params: params ?? this.params,
      rawBody: rawBody ?? this.rawBody,
    );
  }
}
