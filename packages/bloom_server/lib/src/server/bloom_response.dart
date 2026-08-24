// lib/src/server/bloom_response.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Represents an HTTP response returned from a Bloom API route handler or middleware.
///
/// Supports both **buffered** in-memory payloads (JSON, HTML, plain text, binary) and
/// **streaming** responses ([BloomResponse.stream], [BloomResponse.file]) for large files,
/// Server-Sent Events (SSE), or proxied upstream streams.
///
/// ### Streaming Lifecycle & Consumption Contract
/// - **Single-Consumption Rule**: A streaming response's body stream can be consumed
///   exactly once via [takeBodyStream]. Attempting to call [takeBodyStream] a second time
///   or on a buffered response throws a [StateError].
/// - **Deferred Stream Consumption**: The body stream remains unconsumed until the router
///   writes bytes to the client socket. This enables downstream middleware to inspect and
///   mutate response [headers] even after the route handler has returned.
/// - **Mid-Stream Failure Behavior**: HTTP status code and initial headers are committed to
///   the socket when the first chunk is sent. If an unhandled error occurs mid-stream,
///   the socket connection is aborted/closed immediately. This ensures clients receive a
///   truncated chunked transfer rather than silently accepting corrupted data as successful.
/// - **Chunked Encoding vs Known Content-Length**: [BloomResponse.stream] omits `content-length`
///   and uses chunked transfer encoding. In contrast, [BloomResponse.file] computes file length
///   ahead of time and sets `content-length`, enabling download progress tracking.
///
/// ### Example
/// ```dart
/// // Standard JSON response
/// router.get('/api/users', (req) async {
///   return BloomResponse.json([{'id': 1, 'name': 'Alice'}]);
/// });
///
/// // File streaming response
/// router.get('/downloads/:filename', (req) async {
///   final file = File('public/${req.params['filename']}');
///   return BloomResponse.file(file, contentType: 'application/octet-stream');
/// });
///
/// // Custom chunked stream
/// router.get('/events', (req) async {
///   final stream = eventEmitter.stream.map((e) => utf8.encode('data: $e\n\n'));
///   return BloomResponse.stream(stream, contentType: 'text/event-stream');
/// });
/// ```
class BloomResponse {
  /// HTTP status code (e.g. `200`, `204`, `400`, `401`, `404`, `500`).
  final int statusCode;

  /// Response headers map (case-insensitive keys handled during transmission).
  final Map<String, String> headers;

  /// Response body binary payload for buffered responses.
  ///
  /// Always empty when [isStreaming] is `true` — streaming responses deliver
  /// their bytes through [takeBodyStream] instead.
  final Uint8List body;

  /// Incremental response body stream, or `null` for a buffered response.
  ///
  /// Held unconsumed until the router writes it, which is what allows
  /// middleware to keep mutating [headers] after the handler returns: no
  /// byte reaches the socket until the whole middleware chain has unwound.
  final Stream<List<int>>? _bodyStream;

  bool _streamTaken = false;

  /// Whether this response delivers its payload incrementally via a byte stream.
  bool get isStreaming => _bodyStream != null;

  /// Creates a buffered [BloomResponse] with an optional [statusCode], [headers], and binary [body].
  ///
  /// Defaults to HTTP 200 OK with an empty body.
  BloomResponse({
    this.statusCode = 200,
    Map<String, String>? headers,
    Uint8List? body,
  })  : headers = Map<String, String>.from(headers ?? {}),
        body = body ?? Uint8List(0),
        _bodyStream = null;

  /// Creates a streaming response whose body is written incrementally from [body].
  ///
  /// Use for large payloads, Server-Sent Events, proxied upstreams, and any response
  /// whose length is not known in advance. Omits `content-length` so the response
  /// is transmitted using HTTP chunked transfer encoding.
  ///
  /// If [contentType] is provided, it is added to [headers].
  ///
  /// ### Example
  /// ```dart
  /// BloomResponse.stream(
  ///   byteStream,
  ///   contentType: 'application/octet-stream',
  /// );
  /// ```
  BloomResponse.stream(
    Stream<List<int>> body, {
    this.statusCode = 200,
    Map<String, String>? headers,
    String? contentType,
  })  : headers = {
          if (contentType != null) 'content-type': contentType,
          ...?headers,
        },
        body = Uint8List(0),
        _bodyStream = body;

  /// Streams [file] from disk without loading its entire contents into memory.
  ///
  /// Unlike [BloomResponse.stream], sets `content-length` from [File.lengthSync],
  /// enabling clients to calculate download progress without chunked transfer overhead.
  ///
  /// Throws [FileSystemException] if [file] does not exist.
  ///
  /// ### Example
  /// ```dart
  /// final res = BloomResponse.file(File('assets/report.pdf'), contentType: 'application/pdf');
  /// ```
  factory BloomResponse.file(
    File file, {
    String? contentType,
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    if (!file.existsSync()) {
      throw FileSystemException('File not found', file.path);
    }
    return BloomResponse.stream(
      file.openRead(),
      statusCode: statusCode,
      contentType: contentType,
      headers: {
        'content-length': file.lengthSync().toString(),
        ...?headers,
      },
    );
  }

  /// Returns the underlying body stream, marking it as consumed.
  ///
  /// Throws [StateError] if this response is buffered ([isStreaming] is `false`),
  /// or if [takeBodyStream] has already been called on this instance.
  Stream<List<int>> takeBodyStream() {
    final stream = _bodyStream;
    if (stream == null) {
      throw StateError(
        'BloomResponse.takeBodyStream() called on a buffered response. '
        'Check isStreaming before calling.',
      );
    }
    if (_streamTaken) {
      throw StateError(
        'BloomResponse body stream has already been taken. A response body '
        'may only be consumed once.',
      );
    }
    _streamTaken = true;
    return stream;
  }

  /// Helper factory constructor for JSON responses.
  ///
  /// Encodes [data] with [jsonEncode] and sets `Content-Type: application/json; charset=utf-8`.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.json({'status': 'success', 'count': 42});
  /// ```
  factory BloomResponse.json(
    dynamic data, {
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    final encoded = jsonEncode(data);
    final finalHeaders = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'content-type': 'application/json; charset=utf-8',
      ...?headers,
    };
    return BloomResponse(
      statusCode: statusCode,
      headers: finalHeaders,
      body: Uint8List.fromList(utf8.encode(encoded)),
    );
  }

  /// Helper factory constructor for HTML responses.
  ///
  /// Sets `Content-Type: text/html; charset=utf-8` and encodes [html] as UTF-8 bytes.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.html('<h1>Hello Bloom</h1>');
  /// ```
  factory BloomResponse.html(
    String html, {
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    final finalHeaders = <String, String>{
      'content-type': 'text/html; charset=utf-8',
      ...?headers,
    };
    return BloomResponse(
      statusCode: statusCode,
      headers: finalHeaders,
      body: Uint8List.fromList(utf8.encode(html)),
    );
  }

  /// Helper factory constructor for plain text responses.
  ///
  /// Sets `Content-Type: text/plain; charset=utf-8` and encodes [text] as UTF-8 bytes.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.text('pong');
  /// ```
  factory BloomResponse.text(
    String text, {
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    final finalHeaders = <String, String>{
      'content-type': 'text/plain; charset=utf-8',
      ...?headers,
    };
    return BloomResponse(
      statusCode: statusCode,
      headers: finalHeaders,
      body: Uint8List.fromList(utf8.encode(text)),
    );
  }

  /// Helper factory constructor for HTTP 204 No Content responses.
  ///
  /// Carries an empty body payload.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.noContent();
  /// ```
  factory BloomResponse.noContent({Map<String, String>? headers}) {
    return BloomResponse(
      statusCode: 204,
      headers: headers,
      body: Uint8List(0),
    );
  }

  /// Helper factory constructor for HTTP redirects.
  ///
  /// Sets the `Location: [location]` header with the specified [statusCode] (default 302 Found).
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.redirect('/login', statusCode: 303);
  /// ```
  factory BloomResponse.redirect(String location, {int statusCode = 302}) {
    return BloomResponse(
      statusCode: statusCode,
      headers: {'location': location},
      body: Uint8List(0),
    );
  }

  /// Helper factory constructor for HTTP 401 Unauthorized JSON error responses.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.unauthorized('Invalid bearer token');
  /// ```
  factory BloomResponse.unauthorized([String message = 'Unauthorized']) {
    return BloomResponse.json({'error': message, 'statusCode': 401}, statusCode: 401);
  }

  /// Helper factory constructor for HTTP 403 Forbidden JSON error responses.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.forbidden('Access denied for role: viewer');
  /// ```
  factory BloomResponse.forbidden([String message = 'Forbidden']) {
    return BloomResponse.json({'error': message, 'statusCode': 403}, statusCode: 403);
  }

  /// Helper factory constructor for HTTP 404 Not Found JSON error responses.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.notFound('User not found');
  /// ```
  factory BloomResponse.notFound([String message = 'Not Found']) {
    return BloomResponse.json({'error': message, 'statusCode': 404}, statusCode: 404);
  }

  /// Helper factory constructor for HTTP 413 Payload Too Large JSON error responses.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.payloadTooLarge('Upload exceeds 10MB limit');
  /// ```
  factory BloomResponse.payloadTooLarge([String message = 'Payload Too Large']) {
    return BloomResponse.json({'error': message, 'statusCode': 413}, statusCode: 413);
  }

  /// Helper factory constructor for HTTP 500 Internal Server Error (or custom [statusCode]) JSON error responses.
  ///
  /// ### Example
  /// ```dart
  /// return BloomResponse.error('Database connection timeout', statusCode: 503);
  /// ```
  factory BloomResponse.error(String message, {int statusCode = 500}) {
    return BloomResponse.json({'error': message, 'statusCode': statusCode}, statusCode: statusCode);
  }

  /// Decodes and returns the buffered [body] as a UTF-8 string.
  String get bodyText => utf8.decode(body);

  /// Decodes and returns the buffered [body] as JSON, or `null` if decoding fails.
  dynamic get bodyJson {
    try {
      return jsonDecode(bodyText);
    } catch (_) {
      return null;
    }
  }
}

