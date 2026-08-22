// lib/src/server/bloom_response.dart
import 'dart:convert';
import 'dart:typed_data';

/// Represents an HTTP response returned from a Bloom API route or middleware.
class BloomResponse {
  /// HTTP status code (e.g. 200, 404, 500).
  final int statusCode;

  /// Response headers map.
  final Map<String, String> headers;

  /// Response body binary payload.
  final Uint8List body;

  /// Creates a [BloomResponse] with an optional [statusCode], [headers], and [body].
  BloomResponse({
    this.statusCode = 200,
    Map<String, String>? headers,
    Uint8List? body,
  })  : headers = Map<String, String>.from(headers ?? {}),
        body = body ?? Uint8List(0);

  /// Helper constructor for JSON payloads.
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

  /// Helper constructor for HTML responses.
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

  /// Helper constructor for Plain Text responses.
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

  /// Helper constructor for 204 No Content.
  factory BloomResponse.noContent({Map<String, String>? headers}) {
    return BloomResponse(
      statusCode: 204,
      headers: headers,
      body: Uint8List(0),
    );
  }

  /// Helper constructor for HTTP redirects.
  factory BloomResponse.redirect(String location, {int statusCode = 302}) {
    return BloomResponse(
      statusCode: statusCode,
      headers: {'location': location},
      body: Uint8List(0),
    );
  }

  /// Helper constructor for 401 Unauthorized.
  factory BloomResponse.unauthorized([String message = 'Unauthorized']) {
    return BloomResponse.json({'error': message, 'statusCode': 401}, statusCode: 401);
  }

  /// Helper constructor for 403 Forbidden.
  factory BloomResponse.forbidden([String message = 'Forbidden']) {
    return BloomResponse.json({'error': message, 'statusCode': 403}, statusCode: 403);
  }

  /// Helper constructor for 404 Not Found.
  factory BloomResponse.notFound([String message = 'Not Found']) {
    return BloomResponse.json({'error': message, 'statusCode': 404}, statusCode: 404);
  }

  /// Helper constructor for 413 Payload Too Large.
  factory BloomResponse.payloadTooLarge([String message = 'Payload Too Large']) {
    return BloomResponse.json({'error': message, 'statusCode': 413}, statusCode: 413);
  }

  /// Helper constructor for 500 Internal Server Error.
  factory BloomResponse.error(String message, {int statusCode = 500}) {
    return BloomResponse.json({'error': message, 'statusCode': statusCode}, statusCode: statusCode);
  }

  /// Decodes body as UTF-8 string.
  String get bodyText => utf8.decode(body);

  /// Decodes body as JSON if possible.
  dynamic get bodyJson {
    try {
      return jsonDecode(bodyText);
    } catch (_) {
      return null;
    }
  }
}
