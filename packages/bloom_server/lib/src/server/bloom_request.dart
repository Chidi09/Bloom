// lib/src/server/bloom_request.dart
import 'dart:convert';
import 'dart:typed_data';

/// Represents an incoming HTTP request in Bloom API routes, SSR endpoints, and middleware.
///
/// Encapsulates the HTTP [method], request [uri], incoming [headers], route [params],
/// [queryParams], binary [rawBody], and helper accessors for parsing JSON, UTF-8 text,
/// and URL-encoded form data.
///
/// ### Example
/// ```dart
/// router.post('/api/users/:orgId', (request) async {
///   final orgId = request.params['orgId'];
///   final role = request.queryParams['role'] ?? 'member';
///   final data = request.json() as Map<String, dynamic>?;
///   final authHeader = request.headers['authorization'];
///
///   return BloomResponse.json({
///     'orgId': orgId,
///     'role': role,
///     'name': data?['name'],
///     'isSecure': request.isSecure,
///   });
/// });
/// ```
class BloomRequest {
  /// HTTP method string in uppercase (e.g. `'GET'`, `'POST'`, `'PUT'`, `'DELETE'`).
  final String method;

  /// Full request URI including scheme, host, path, and query parameters.
  final Uri uri;

  /// Map of incoming HTTP request headers with lowercase keys.
  final Map<String, String> headers;

  /// URL path parameters extracted by the router regex matching (e.g. `{'id': '123'}`).
  final Map<String, String> params;

  /// Raw binary request payload bytes.
  final Uint8List rawBody;

  /// Whether the request was received over a secure HTTPS connection or behind an SSL proxy.
  final bool isSecure;

  /// Creates a [BloomRequest] instance.
  ///
  /// [body] can be a [Uint8List], `List<int>`, [String], or a JSON-encodable [Map]/[List].
  /// If [rawBody] is not provided directly, it is automatically converted from [body].
  /// If [isSecure] is omitted, it is inferred from [uri.scheme].
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

  /// The path component of the request URI (e.g. `'/api/tasks'`).
  String get path => uri.path;

  /// Map of query string parameters decoded from the request URI.
  Map<String, String> get queryParams => uri.queryParameters;

  /// Decodes and returns the raw request body as a UTF-8 string.
  ///
  /// Returns an empty string if [rawBody] is empty.
  String text() => utf8.decode(rawBody);

  /// Parses the request body as JSON.
  ///
  /// Returns `null` if the decoded body text is empty or whitespace-only.
  /// Throws [FormatException] if the body is not valid JSON.
  ///
  /// ### Example
  /// ```dart
  /// final data = request.json() as Map<String, dynamic>?;
  /// ```
  dynamic json() {
    final str = text();
    if (str.trim().isEmpty) return null;
    return jsonDecode(str);
  }

  /// Convenient getter for decoded JSON body payload.
  ///
  /// Equivalent to calling [json()].
  dynamic get bodyJson => json();

  /// Parses the request body as URL-encoded form data (`application/x-www-form-urlencoded`).
  ///
  /// Returns an empty map if the body is empty.
  ///
  /// ### Example
  /// ```dart
  /// final fields = request.formData();
  /// final username = fields['username'];
  /// ```
  Map<String, String> formData() {
    final str = text();
    if (str.trim().isEmpty) return {};
    return Uri.splitQueryString(str);
  }

  /// Creates a copy of this request with the specified fields replaced.
  ///
  /// Useful in middleware pipelines for mutating request context, headers, or parameters.
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

