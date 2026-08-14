// lib/src/data/http_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';
import '../core/logger.dart';

typedef RequestInterceptor = FutureOr<http.BaseRequest> Function(http.BaseRequest request);
typedef ResponseInterceptor = FutureOr<http.Response> Function(http.Response response);

/// HTTP client with environment base URL resolution, JSON codecs, Bearer auth token injection, and interceptors.
class BloomHttpClient {
  final String? baseUrl;
  final http.Client _innerClient;
  final Duration timeout;
  final List<RequestInterceptor> requestInterceptors = [];
  final List<ResponseInterceptor> responseInterceptors = [];

  String? authToken;
  String? Function()? authTokenProvider;

  BloomHttpClient({
    String? baseUrl,
    http.Client? innerClient,
    this.timeout = const Duration(seconds: 15),
    this.authToken,
    this.authTokenProvider,
  })  : baseUrl = baseUrl ?? BloomEnv.getOrNull('API_BASE_URL') ?? BloomEnv.getOrNull('API_URL'),
        _innerClient = innerClient ?? http.Client();

  /// Resolve URI supporting full URLs or relative path endpoints.
  Uri _resolveUri(String path, [Map<String, dynamic>? queryParameters]) {
    String fullUrl;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      fullUrl = path;
    } else {
      final base = (baseUrl != null && baseUrl!.isNotEmpty)
          ? (baseUrl!.endsWith('/') ? baseUrl!.substring(0, baseUrl!.length - 1) : baseUrl!)
          : 'http://localhost:8080';
      final cleanPath = path.startsWith('/') ? path : '/$path';
      fullUrl = '$base$cleanPath';
    }

    final parsed = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map((k, v) => MapEntry(k, v.toString()));
      return parsed.replace(queryParameters: {...parsed.queryParameters, ...stringParams});
    }
    return parsed;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
  }) async {
    final uri = _resolveUri(path, queryParameters);
    final request = http.Request(method, uri);

    // 1. Apply default headers
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'application/json';

    // 2. Inject Authorization Token
    final token = authTokenProvider != null ? authTokenProvider!() : authToken;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (headers != null) {
      request.headers.addAll(headers);
    }

    if (body != null) {
      if (body is String) {
        request.body = body;
      } else {
        request.body = jsonEncode(body);
      }
    }

    // 3. Request Interceptors
    http.BaseRequest finalReq = request;
    for (final interceptor in requestInterceptors) {
      finalReq = await interceptor(finalReq);
    }

    final streamedResponse = await _innerClient.send(finalReq).timeout(timeout);
    http.Response response = await http.Response.fromStream(streamedResponse);

    // 4. Response Interceptors
    for (final interceptor in responseInterceptors) {
      response = await interceptor(response);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    } else {
      logger.error('BloomHttpClient: Request failed with status ${response.statusCode} for $uri');
      throw http.ClientException(
        'HTTP ${response.statusCode}: ${response.body}',
        uri,
      );
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('GET', path, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  Future<T> post<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('POST', path, body: body, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  Future<T> put<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('PUT', path, body: body, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  Future<T> patch<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('PATCH', path, body: body, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  Future<T> delete<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('DELETE', path, body: body, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  void close() => _innerClient.close();
}
