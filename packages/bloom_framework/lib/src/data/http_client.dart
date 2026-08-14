// lib/src/data/http_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../core/env.dart';
import '../core/logger.dart';
import '../dev/bloom_dev.dart';
import '../devtools/network_inspector.dart';
import '../observability/models.dart';
import '../observability/observability.dart';

typedef RequestInterceptor = FutureOr<http.BaseRequest> Function(http.BaseRequest request);
typedef ResponseInterceptor = FutureOr<http.Response> Function(http.Response response);

/// HTTP client with environment base URL resolution, JSON codecs, Bearer auth token injection, DevTools tracing, and simulation hooks.
class BloomHttpClient {
  final String? baseUrl;
  final http.Client _innerClient;
  final Duration timeout;
  final List<RequestInterceptor> requestInterceptors = [];
  final List<ResponseInterceptor> responseInterceptors = [];
  static final Random _random = Random();
  static int _reqTraceCounter = 0;

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
      if (baseUrl == null || baseUrl!.isEmpty) {
        throw StateError(
          'BloomHttpClient: Cannot resolve relative endpoint "$path" because no baseUrl or API_BASE_URL environment variable was configured.',
        );
      }
      final base = baseUrl!.endsWith('/') ? baseUrl!.substring(0, baseUrl!.length - 1) : baseUrl!;
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
    final traceId = 'req_${++_reqTraceCounter}_${DateTime.now().millisecondsSinceEpoch}';
    final stopwatch = Stopwatch()..start();

    // 0a. Check BloomDev offline simulation
    if (BloomDev.isOffline) {
      final trace = BloomNetworkTrace(
        id: traceId,
        method: method,
        url: uri.toString(),
        headers: headers ?? {},
        body: body,
        timestamp: DateTime.now(),
        statusCode: 0,
        error: 'Device is offline (simulated).',
        latency: Duration.zero,
      );
      BloomNetworkInspector.recordTrace(trace);
      throw BloomOfflineException('Device is currently offline (simulated).', uri);
    }

    // 0b. Check BloomDev latency simulation
    if (BloomDev.latency != null) {
      await Future.delayed(BloomDev.latency!);
    }

    // 0c. Check BloomDev failure rate simulation
    if (BloomDev.failureRate > 0.0) {
      if (BloomDev.failureRate >= 1.0 || _random.nextDouble() < BloomDev.failureRate) {
        final status = BloomDev.failureStatusCode;
        final trace = BloomNetworkTrace(
          id: traceId,
          method: method,
          url: uri.toString(),
          headers: headers ?? {},
          body: body,
          timestamp: DateTime.now(),
          statusCode: status,
          error: 'Simulated network failure ($status)',
          latency: stopwatch.elapsed,
        );
        BloomNetworkInspector.recordTrace(trace);
        throw http.ClientException('HTTP $status: Simulated network failure', uri);
      }
    }

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

    http.Response response;
    try {
      final streamedResponse = await _innerClient.send(finalReq).timeout(timeout);
      response = await http.Response.fromStream(streamedResponse);
    } catch (e) {
      stopwatch.stop();
      final trace = BloomNetworkTrace(
        id: traceId,
        method: method,
        url: uri.toString(),
        headers: headers ?? {},
        body: body,
        timestamp: DateTime.now(),
        error: e.toString(),
        latency: stopwatch.elapsed,
      );
      BloomNetworkInspector.recordTrace(trace);
      rethrow;
    }
    stopwatch.stop();

    // 4. Response Interceptors
    for (final interceptor in responseInterceptors) {
      response = await interceptor(response);
    }

    // Record network trace
    final trace = BloomNetworkTrace(
      id: traceId,
      method: method,
      url: uri.toString(),
      headers: headers ?? {},
      body: body,
      timestamp: DateTime.now(),
      statusCode: response.statusCode,
      responseBody: response.body,
      latency: stopwatch.elapsed,
    );
    BloomNetworkInspector.recordTrace(trace);

    // Record network breadcrumb
    BloomObservability.addBreadcrumb(
      category: 'http',
      message: '$method ${uri.path} (${response.statusCode})',
      level: response.statusCode >= 400 ? BloomBreadcrumbLevel.warning : BloomBreadcrumbLevel.info,
      data: {
        'url': uri.toString(),
        'method': method,
        'statusCode': response.statusCode,
      },
    );

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
