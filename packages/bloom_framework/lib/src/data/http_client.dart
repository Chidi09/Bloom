// lib/src/data/http_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';
import '../core/logger.dart';

class BloomHttpResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;
  final Uri requestUri;

  const BloomHttpResponse({
    required this.statusCode,
    required this.data,
    required this.headers,
    required this.requestUri,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class BloomHttpException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final Uri? requestUri;

  BloomHttpException(this.message, {this.statusCode, this.data, this.requestUri});

  @override
  String toString() =>
      'BloomHttpException: $message (status: $statusCode, uri: $requestUri)';
}

abstract class BloomHttpInterceptor {
  FutureOr<void> onRequest(http.BaseRequest request) {}
  FutureOr<void> onResponse(BloomHttpResponse response) {}
  FutureOr<void> onError(BloomHttpException error) {}
}

/// High-level HTTP client with base URL resolution, JSON serialization, auth injection, and interceptors.
class BloomHttpClient {
  String? baseUrl;
  final Map<String, String> defaultHeaders;
  final Duration timeout;
  final List<BloomHttpInterceptor> interceptors = [];
  final http.Client _client;

  BloomHttpClient({
    String? baseUrl,
    Map<String, String>? defaultHeaders,
    this.timeout = const Duration(seconds: 15),
    http.Client? client,
  })  : baseUrl = baseUrl ?? BloomEnv.get('API_URL'),
        defaultHeaders = defaultHeaders ??
            {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
        _client = client ?? http.Client();

  Uri _resolveUri(String path, [Map<String, dynamic>? queryParameters]) {
    String resolvedPath = path;
    if (baseUrl != null && !path.startsWith('http://') && !path.startsWith('https://')) {
      final cleanBase = baseUrl!.endsWith('/') ? baseUrl!.substring(0, baseUrl!.length - 1) : baseUrl!;
      final cleanPath = path.startsWith('/') ? path : '/$path';
      resolvedPath = '$cleanBase$cleanPath';
    }

    final uri = Uri.parse(resolvedPath);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final queryMap = Map<String, String>.from(uri.queryParameters);
      queryParameters.forEach((k, v) => queryMap[k] = v.toString());
      return uri.replace(queryParameters: queryMap);
    }
    return uri;
  }

  Future<BloomHttpResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _send('GET', path, queryParameters: queryParameters, headers: headers);
  }

  Future<BloomHttpResponse> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _send('POST', path, data: data, queryParameters: queryParameters, headers: headers);
  }

  Future<BloomHttpResponse> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _send('PUT', path, data: data, queryParameters: queryParameters, headers: headers);
  }

  Future<BloomHttpResponse> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _send('PATCH', path, data: data, queryParameters: queryParameters, headers: headers);
  }

  Future<BloomHttpResponse> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _send('DELETE', path, queryParameters: queryParameters, headers: headers);
  }

  Future<BloomHttpResponse> _send(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _resolveUri(path, queryParameters);
    final requestHeaders = Map<String, String>.from(defaultHeaders);
    if (headers != null) requestHeaders.addAll(headers);

    final request = http.Request(method, uri);
    request.headers.addAll(requestHeaders);

    if (data != null) {
      if (data is String) {
        request.body = data;
      } else {
        request.body = jsonEncode(data);
      }
    }

    // Run interceptors onRequest
    for (final interceptor in interceptors) {
      await interceptor.onRequest(request);
    }

    try {
      final streamedResponse = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      dynamic parsedData;
      if (response.body.isNotEmpty) {
        try {
          parsedData = jsonDecode(response.body);
        } catch (_) {
          parsedData = response.body;
        }
      }

      final bloomResponse = BloomHttpResponse(
        statusCode: response.statusCode,
        data: parsedData,
        headers: response.headers,
        requestUri: uri,
      );

      // Run interceptors onResponse
      for (final interceptor in interceptors) {
        await interceptor.onResponse(bloomResponse);
      }

      if (!bloomResponse.isSuccess) {
        final err = BloomHttpException(
          'HTTP request failed with status ${response.statusCode}',
          statusCode: response.statusCode,
          data: parsedData,
          requestUri: uri,
        );
        for (final interceptor in interceptors) {
          await interceptor.onError(err);
        }
        throw err;
      }

      return bloomResponse;
    } catch (e) {
      if (e is! BloomHttpException) {
        final err = BloomHttpException('Network error: $e', requestUri: uri);
        for (final interceptor in interceptors) {
          await interceptor.onError(err);
        }
        throw err;
      }
      rethrow;
    }
  }

  void close() => _client.close();
}
