// lib/src/server/bloom_request.dart
import 'dart:convert';
import 'dart:typed_data';

/// Represents an incoming HTTP request in Bloom API routes and full-stack SSR server.
class BloomRequest {
  /// HTTP method string in uppercase (e.g. `'GET'`, `'POST'`).
  final String method;

  /// Full request URI.
  final Uri uri;

  /// Request header key-value map.
  final Map<String, String> headers;

  /// URL path parameters extracted by the router.
  final Map<String, String> params;

  /// Raw binary body bytes.
  final Uint8List rawBody;

  /// Whether the request was received over a secure HTTPS connection.
  final bool isSecure;

  /// Creates a [BloomRequest] instance.
  BloomRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    Map<String, String>? params,
    dynamic body,
    Uint8List? rawBody,
    bool? isSecure,
  })  : params = params ?? <String, String>{},
        rawBody = rawBody ?? _convertBody(body),
        isSecure = isSecure ?? (uri.scheme.toLowerCase() == 'https');

  static Uint8List _convertBody(dynamic body) {
    if (body == null) return Uint8List(0);
    if (body is Uint8List) return body;
    if (body is List<int>) return Uint8List.fromList(body);
    if (body is String) return Uint8List.fromList(utf8.encode(body));
    if (body is Map || body is List) return Uint8List.fromList(utf8.encode(jsonEncode(body)));
    return Uint8List(0);
  }

  /// Request URI path component.
  String get path => uri.path;

  /// Map of query parameters extracted from the URI.
  Map<String, String> get queryParams => uri.queryParameters;

  /// Parses request body as UTF-8 string.
  String text() => utf8.decode(rawBody);

  /// Parses request body as decoded JSON.
  dynamic json() {
    final str = text();
    if (str.trim().isEmpty) return null;
    return jsonDecode(str);
  }

  /// Convenient getter for JSON body.
  dynamic get bodyJson => json();

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
    bool? isSecure,
  }) {
    return BloomRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      params: params ?? this.params,
      rawBody: rawBody ?? this.rawBody,
      isSecure: isSecure ?? this.isSecure,
    );
  }
}
