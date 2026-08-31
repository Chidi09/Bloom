// lib/src/server/bloom_request.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'bloom_multipart.dart';

/// Represents an incoming HTTP request in Bloom API routes, SSR endpoints, and middleware.
///
/// Encapsulates the HTTP [method], request [uri], incoming [headers], route [params],
/// [queryParams], binary [rawBody] (or streaming body for multipart uploads), and helper
/// accessors for parsing JSON, UTF-8 text, URL-encoded form data, and streaming multipart data.
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

  final Uint8List? _rawBody;
  final Stream<List<int>>? _streamBody;
  final int? _maxRequestBodyBytes;
  bool _bodyStreamTaken = false;

  /// Raw binary request payload bytes.
  ///
  /// Throws [StateError] if this request is a streaming request (e.g. multipart/form-data upload).
  /// To consume streaming bodies, use [multipart].
  Uint8List get rawBody {
    if (_streamBody != null) {
      throw StateError(
        'Cannot access rawBody on a streaming request body. '
        'Use multipart() to consume the multipart stream.',
      );
    }
    return _rawBody ?? Uint8List(0);
  }

  /// Whether this request's body is delivered via an unbuffered stream rather than pre-buffered bytes.
  bool get isStreaming => _streamBody != null;

  /// Whether the request was received over a secure HTTPS connection or behind an SSL proxy.
  final bool isSecure;

  /// Creates a [BloomRequest] instance.
  ///
  /// [body] can be a [Uint8List], `List<int>`, [String], or a JSON-encodable [Map]/[List].
  /// If [rawBody] is not provided directly and [streamBody] is null, it is automatically converted from [body].
  /// If [streamBody] is provided, the request body is treated as a stream and not pre-buffered.
  /// If [isSecure] is omitted, it is inferred from [uri.scheme].
  BloomRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    Map<String, String>? params,
    dynamic body,
    Uint8List? rawBody,
    Stream<List<int>>? streamBody,
    int? maxRequestBodyBytes,
    bool? isSecure,
  })  : params = params ?? <String, String>{},
        _streamBody = streamBody,
        _maxRequestBodyBytes = maxRequestBodyBytes,
        _rawBody = streamBody != null ? null : (rawBody ?? _convertBody(body)),
        isSecure = isSecure ?? (uri.scheme.toLowerCase() == 'https');

  static Uint8List _convertBody(dynamic body) {
    if (body == null) return Uint8List(0);
    if (body is Uint8List) return body;
    if (body is List<int>) return Uint8List.fromList(body);
    if (body is String) return Uint8List.fromList(utf8.encode(body));
    if (body is Map || body is List) {
      return Uint8List.fromList(utf8.encode(jsonEncode(body)));
    }
    return Uint8List(0);
  }

  /// The path component of the request URI (e.g. `'/api/tasks'`).
  String get path => uri.path;

  /// Map of query string parameters decoded from the request URI.
  Map<String, String> get queryParams => uri.queryParameters;

  /// Decodes and returns the raw request body as a UTF-8 string.
  ///
  /// Returns an empty string if [rawBody] is empty.
  /// Throws [StateError] if this request is a streaming request.
  String text() => utf8.decode(rawBody);

  /// Parses the request body as JSON.
  ///
  /// Returns `null` if the decoded body text is empty or whitespace-only.
  /// Throws [FormatException] if the body is not valid JSON.
  /// Throws [StateError] if this request is a streaming request.
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
  /// Throws [StateError] if this request is a streaming request.
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

  /// Parses the incoming streaming multipart/form-data request body.
  ///
  /// Yields each [BloomMultipartPart] ([BloomMultipartField] or [BloomMultipartFile])
  /// as it is parsed from the stream without buffering entire files into memory.
  ///
  /// Throws [StateError] if this request is not a streaming request or if the
  /// request body stream has already been consumed.
  /// Throws [FormatException] if the Content-Type header or multipart payload is malformed.
  ///
  /// ### Example
  /// ```dart
  /// await for (final part in request.multipart()) {
  ///   if (part is BloomMultipartField) {
  ///     print('${part.name}: ${part.value}');
  ///   } else if (part is BloomMultipartFile) {
  ///     await File('uploads/${part.filename}').openWrite().addStream(part.bytes);
  ///   }
  /// }
  /// ```
  Stream<BloomMultipartPart> multipart({int? maxBytes}) {
    if (_streamBody == null) {
      throw StateError(
        'BloomRequest.multipart() called on a non-streaming request. '
        'Ensure the request was sent with multipart/form-data and not pre-buffered.',
      );
    }
    if (_bodyStreamTaken) {
      throw StateError(
        'BloomRequest streaming body has already been consumed. '
        'A request stream may only be read once.',
      );
    }
    final contentType = headers['content-type'] ?? '';
    final boundary = extractMultipartBoundary(contentType);

    _bodyStreamTaken = true;
    return parseMultipartStream(
      stream: _streamBody,
      boundary: boundary,
      maxBytes: maxBytes ?? _maxRequestBodyBytes,
    );
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
    Stream<List<int>>? streamBody,
    int? maxRequestBodyBytes,
    bool? isSecure,
  }) {
    return BloomRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      params: params ?? this.params,
      rawBody: rawBody ?? _rawBody,
      streamBody: streamBody ?? _streamBody,
      maxRequestBodyBytes: maxRequestBodyBytes ?? _maxRequestBodyBytes,
      isSecure: isSecure ?? this.isSecure,
    );
  }
}
