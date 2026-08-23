// lib/src/http.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'env.dart';

/// Interceptor callback that transforms or inspects an outgoing [http.BaseRequest] before transmission.
///
/// Can asynchronously mutate request headers, inject tracing telemetry, or log outgoing calls.
/// Multiple interceptors execute sequentially in the order registered in [BloomHttpClient.requestInterceptors].
///
/// ```dart
/// client.requestInterceptors.add((request) async {
///   request.headers['X-Request-ID'] = generateUuid();
///   return request;
/// });
/// ```
typedef RequestInterceptor = FutureOr<http.BaseRequest> Function(
    http.BaseRequest request);

/// Interceptor callback that transforms or inspects an incoming [http.Response] before returning to callers.
///
/// Can inspect status codes, refresh expired authentication tokens, log response times, or rewrite bodies.
/// Multiple interceptors execute sequentially in the order registered in [BloomHttpClient.responseInterceptors].
///
/// ```dart
/// client.responseInterceptors.add((response) async {
///   if (response.statusCode == 401) {
///     // Handle token expiration or refresh
///   }
///   return response;
/// });
/// ```
typedef ResponseInterceptor = FutureOr<http.Response> Function(
    http.Response response);

/// High-level HTTP client with base URL resolution, JSON encoding/decoding, Bearer auth token injection,
/// request/response interceptors, and timeout handling.
///
/// [BloomHttpClient] wraps Dart's `package:http` with framework conventions for Bloom JS Native apps:
/// - **Base URL Resolution**: Relative paths (e.g. `'/tasks'`) are resolved against [baseUrl]. If [baseUrl]
///   is not explicitly passed, it automatically falls back to `BloomEnv.getOrNull('API_BASE_URL')`
///   or `'API_URL'`. Absolute URLs (starting with `http://` or `https://`) bypass [baseUrl].
/// - **Authentication**: Injects `Authorization: Bearer <token>` automatically on every request if
///   [authTokenProvider] or [authToken] is configured.
/// - **JSON Codecs**: Automatically sets `Content-Type: application/json` and `Accept: application/json`,
///   encodes Map/List request bodies to JSON strings, and decodes JSON response payloads into Dart objects.
/// - **Interceptors**: Supports pre-request and post-response processing pipelines via [requestInterceptors]
///   and [responseInterceptors].
/// - **Error Handling**: Non-2xx responses throw an [http.ClientException] containing the HTTP status code
///   and response body.
///
/// ### Backend Behavior
/// - **SSR & Dart VM**: Fully functional. Requests execute using Dart's native IO client.
/// - **Browser**: Fully functional. Requests execute using browser `Fetch` / `XMLHttpRequest` under the hood.
///
/// ### Example
/// ```dart
/// final client = BloomHttpClient(
///   baseUrl: 'https://api.example.com/v1',
///   authTokenProvider: () => authStore.token.value,
///   timeout: Duration(seconds: 10),
/// );
///
/// // Fetch JSON list
/// final List<dynamic> users = await client.get('/users');
///
/// // Post JSON payload
/// final Map<String, dynamic> newUser = await client.post(
///   '/users',
///   body: {'name': 'Alice', 'role': 'Admin'},
/// );
/// ```
///
/// See also:
/// - [BloomQuery], for caching and deduplicating HTTP GET requests.
/// - [BloomMutation], for executing HTTP POST/PUT/DELETE mutations with optimistic updates.
class BloomHttpClient {
  /// Base URL prefix prepended to relative request paths.
  ///
  /// Initialized from constructor argument or `API_BASE_URL` / `API_URL` environment variables.
  final String? baseUrl;
  final http.Client _innerClient;

  /// Network timeout duration applied to requests before throwing a [TimeoutException].
  final Duration timeout;

  /// Ordered list of interceptor callbacks executed sequentially prior to dispatching requests.
  ///
  /// Interceptors can modify headers, add telemetry, or mutate the request payload.
  final List<RequestInterceptor> requestInterceptors = [];

  /// Ordered list of interceptor callbacks executed sequentially upon receiving responses.
  ///
  /// Interceptors can log analytics, inspect headers, or transform response payloads.
  final List<ResponseInterceptor> responseInterceptors = [];

  /// Static Bearer authentication token attached to outgoing requests.
  ///
  /// When non-null, sets the `Authorization: Bearer <token>` header on all requests.
  /// If [authTokenProvider] is also set, [authTokenProvider] takes precedence.
  String? authToken;

  /// Dynamic provider callback resolving the current Bearer token at request time.
  ///
  /// Useful for reactive signal stores where tokens are refreshed asynchronously.
  /// Takes precedence over [authToken].
  ///
  /// ```dart
  /// client.authTokenProvider = () => sessionStore.token.value;
  /// ```
  String? Function()? authTokenProvider;

  /// Creates a [BloomHttpClient] configured with an optional [baseUrl], [timeout], and auth tokens.
  ///
  /// If [baseUrl] is omitted, attempts to read `API_BASE_URL` or `API_URL` via [BloomEnv.getOrNull].
  /// If [innerClient] is omitted, instantiates a default [http.Client].
  ///
  /// ```dart
  /// final client = BloomHttpClient(
  ///   baseUrl: 'https://api.bloom.dev',
  ///   timeout: Duration(seconds: 30),
  /// );
  /// ```
  BloomHttpClient({
    String? baseUrl,
    http.Client? innerClient,
    this.timeout = const Duration(seconds: 15),
    this.authToken,
    this.authTokenProvider,
  })  : baseUrl = baseUrl ??
            BloomEnv.getOrNull('API_BASE_URL') ??
            BloomEnv.getOrNull('API_URL'),
        _innerClient = innerClient ?? http.Client();

  /// Resolve URI supporting full URLs or relative path endpoints.
  Uri _resolveUri(String path, [Map<String, dynamic>? queryParameters]) {
    String fullUrl;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      fullUrl = path;
    } else {
      if (baseUrl == null || baseUrl!.isEmpty) {
        throw StateError(
          'BloomHttpClient: Cannot resolve relative endpoint "$path" because no '
          'baseUrl or API_BASE_URL environment variable was configured.',
        );
      }
      final base = baseUrl!.endsWith('/')
          ? baseUrl!.substring(0, baseUrl!.length - 1)
          : baseUrl!;
      final cleanPath = path.startsWith('/') ? path : '/$path';
      fullUrl = '$base$cleanPath';
    }

    final parsed = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams =
          queryParameters.map((k, v) => MapEntry(k, v.toString()));
      return parsed
          .replace(queryParameters: {...parsed.queryParameters, ...stringParams});
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

    final streamedResponse =
        await _innerClient.send(finalReq).timeout(timeout);
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
      throw http.ClientException(
        'HTTP ${response.statusCode}: ${response.body}',
        uri,
      );
    }
  }

  /// Sends an HTTP GET request to [path] and decodes the JSON response as [T].
  ///
  /// Relative paths are joined with [baseUrl]. Optional [queryParameters] are converted
  /// to string query parameters and appended to the URI.
  ///
  /// Throws an [http.ClientException] if the HTTP status code is outside `200..299`,
  /// or a [TimeoutException] if the request exceeds [timeout].
  ///
  /// ```dart
  /// final task = await client.get<Map<String, dynamic>>('/tasks/123');
  /// ```
  Future<T> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res =
        await _send('GET', path, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  /// Sends an HTTP POST request to [path] with optional [body] and decodes the JSON response as [T].
  ///
  /// If [body] is not a [String], it is automatically serialized to JSON via [jsonEncode].
  ///
  /// Throws an [http.ClientException] if the server returns a non-2xx status code.
  ///
  /// ```dart
  /// final created = await client.post<Map<String, dynamic>>(
  ///   '/tasks',
  ///   body: {'title': 'Write docs', 'completed': false},
  /// );
  /// ```
  Future<T> post<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('POST', path,
        body: body, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  /// Sends an HTTP PUT request to [path] with optional [body] and decodes the JSON response as [T].
  ///
  /// If [body] is not a [String], it is automatically serialized to JSON via [jsonEncode].
  ///
  /// Throws an [http.ClientException] on HTTP error responses.
  ///
  /// ```dart
  /// final updated = await client.put<Map<String, dynamic>>(
  ///   '/tasks/123',
  ///   body: {'title': 'Updated title', 'completed': true},
  /// );
  /// ```
  Future<T> put<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('PUT', path,
        body: body, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  /// Sends an HTTP PATCH request to [path] with optional [body] and decodes the JSON response as [T].
  ///
  /// If [body] is not a [String], it is serialized via [jsonEncode].
  ///
  /// Throws an [http.ClientException] on non-2xx responses.
  ///
  /// ```dart
  /// final patched = await client.patch<Map<String, dynamic>>(
  ///   '/tasks/123',
  ///   body: {'completed': true},
  /// );
  /// ```
  Future<T> patch<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('PATCH', path,
        body: body, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  /// Sends an HTTP DELETE request to [path] with optional [body] and decodes the JSON response as [T].
  ///
  /// Throws an [http.ClientException] on non-2xx responses.
  ///
  /// ```dart
  /// await client.delete('/tasks/123');
  /// ```
  Future<T> delete<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _send('DELETE', path,
        body: body, headers: headers, queryParameters: queryParameters);
    return res as T;
  }

  /// Closes the underlying HTTP client and releases active socket connections.
  ///
  /// After calling [close], no further HTTP requests may be sent with this instance.
  ///
  /// ```dart
  /// client.close();
  /// ```
  void close() => _innerClient.close();
}
