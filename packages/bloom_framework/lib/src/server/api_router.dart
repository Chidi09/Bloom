// lib/src/server/api_router.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'bloom_middleware.dart';
import 'bloom_request.dart';
import 'bloom_response.dart';

/// Handler function signature for Bloom server route endpoints.
typedef BloomRouteHandler = FutureOr<BloomResponse> Function(BloomRequest request);

class _PayloadTooLargeException implements Exception {
  final String message;
  _PayloadTooLargeException([this.message = 'Payload Too Large']);

  @override
  String toString() => '_PayloadTooLargeException: $message';
}

class _RouteEntry {
  final String method;
  final String pathPattern;
  final RegExp regex;
  final List<String> paramNames;
  final List<BloomMiddleware> middlewares;
  final BloomRouteHandler handler;
  final int specificity;

  _RouteEntry({
    required this.method,
    required this.pathPattern,
    required this.regex,
    required this.paramNames,
    required this.middlewares,
    required this.handler,
    required this.specificity,
  });
}

/// High-performance server router for Bloom API routes and SSR endpoints.
class BloomApiRouter {
  final List<BloomMiddleware> _globalMiddlewares = [];
  final List<_RouteEntry> _routes = [];
  final List<HttpServer> _servers = [];
  final Set<Completer<void>> _inFlightRequests = {};
  bool _isClosing = false;

  /// Adds a global middleware executed before all routes.
  void use(BloomMiddleware middleware) {
    _globalMiddlewares.add(middleware);
  }

  /// Registers a GET route.
  void get(String path, BloomRouteHandler handler, {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('GET', path, handler, middlewares);
  }

  /// Registers a POST route.
  void post(String path, BloomRouteHandler handler, {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('POST', path, handler, middlewares);
  }

  /// Registers a PUT route.
  void put(String path, BloomRouteHandler handler, {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('PUT', path, handler, middlewares);
  }

  /// Registers a DELETE route.
  void delete(String path, BloomRouteHandler handler, {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('DELETE', path, handler, middlewares);
  }

  /// Registers a PATCH route.
  void patch(String path, BloomRouteHandler handler, {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('PATCH', path, handler, middlewares);
  }

  /// Registers a route matching all HTTP methods.
  void all(String path, BloomRouteHandler handler, {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('*', path, handler, middlewares);
  }

  void _addRoute(String method, String pattern, BloomRouteHandler handler, List<BloomMiddleware> middlewares) {
    final paramNames = <String>[];
    var regexPattern = pattern;

    RegExp regex;
    int specificity = 100;

    if (pattern == '*' || pattern == '/*') {
      regex = RegExp(r'^.*$');
      specificity = 0;
    } else {
      // Replace :param with regex capture group
      final paramRegex = RegExp(r':([a-zA-Z0-9_]+)');
      for (final match in paramRegex.allMatches(pattern)) {
        paramNames.add(match.group(1)!);
      }
      regexPattern = regexPattern.replaceAll(paramRegex, r'([^/]+)');
      regexPattern = regexPattern.replaceAll('*', r'.*');

      // Normalize trailing slashes
      if (regexPattern != '/' && regexPattern.endsWith('/')) {
        regexPattern = regexPattern.substring(0, regexPattern.length - 1);
      }

      if (regexPattern == '/' || regexPattern.isEmpty) {
        regex = RegExp(r'^/?$');
      } else {
        regex = RegExp('^$regexPattern/?\$');
      }

      if (pattern.contains('*')) {
        specificity = 10 + pattern.length;
      } else if (paramNames.isNotEmpty) {
        specificity = 50 + pattern.length;
      } else {
        specificity = 100 + pattern.length;
      }
    }

    _routes.add(_RouteEntry(
      method: method.toUpperCase(),
      pathPattern: pattern,
      regex: regex,
      paramNames: paramNames,
      middlewares: middlewares,
      handler: handler,
      specificity: specificity,
    ));

    _routes.sort((a, b) => b.specificity.compareTo(a.specificity));
  }

  /// Dispatches and processes an incoming [BloomRequest].
  Future<BloomResponse> handle(BloomRequest request) => handleRequest(request);

  /// Dispatches and processes an incoming [BloomRequest].
  Future<BloomResponse> handleRequest(BloomRequest request) async {
    return _executePipeline(_globalMiddlewares, request, () async {
      final method = request.method.toUpperCase();
      final path = request.path;

      for (final route in _routes) {
        final matchesMethod = route.method == '*' || route.method == method || (method == 'HEAD' && route.method == 'GET');
        if (!matchesMethod) continue;

        final match = route.regex.firstMatch(path);
        if (match != null) {
          for (var i = 0; i < route.paramNames.length; i++) {
            request.params[route.paramNames[i]] = Uri.decodeComponent(match.group(i + 1)!);
          }

          return _executePipeline(route.middlewares, request, () async {
            final res = await route.handler(request);
            if (method == 'HEAD') {
              return BloomResponse(
                statusCode: res.statusCode,
                headers: res.headers,
                body: null,
              );
            }
            return res;
          });
        }
      }

      return BloomResponse.notFound('Cannot ${request.method} ${request.path}');
    });
  }

  Future<BloomResponse> _executePipeline(
    List<BloomMiddleware> middlewares,
    BloomRequest request,
    Future<BloomResponse> Function() finalHandler,
  ) async {
    int index = 0;

    Future<BloomResponse> next() async {
      if (index < middlewares.length) {
        final middleware = middlewares[index++];
        final res = await middleware.handle(request, next);
        return res ?? await next();
      } else {
        return await finalHandler();
      }
    }

    return await next();
  }

  /// Binds to a real dart:io [HttpServer] and serves API / SSR requests.
  ///
  /// Supports optional [securityContext] for TLS/HTTPS binding via [HttpServer.bindSecure],
  /// and optional [maxRequestBodyBytes] to enforce streaming request body size limits.
  Future<HttpServer> serve({
    InternetAddress? address,
    int port = 8080,
    SecurityContext? securityContext,
    int? maxRequestBodyBytes,
  }) async {
    final bindAddress = address ?? InternetAddress.anyIPv4;
    final server = securityContext != null
        ? await HttpServer.bindSecure(bindAddress, port, securityContext)
        : await HttpServer.bind(bindAddress, port);

    _servers.add(server);

    server.listen((ioReq) async {
      if (_isClosing) {
        try {
          ioReq.response.statusCode = HttpStatus.serviceUnavailable;
          ioReq.response.headers.contentType = ContentType.json;
          ioReq.response.add(utf8.encode(jsonEncode({
            'error': 'Server is shutting down',
            'statusCode': HttpStatus.serviceUnavailable,
          })));
          await ioReq.response.close();
        } catch (_) {}
        return;
      }

      final completer = Completer<void>();
      _inFlightRequests.add(completer);
      try {
        await handleIoRequest(ioReq, maxRequestBodyBytes: maxRequestBodyBytes);
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
        _inFlightRequests.remove(completer);
      }
    });

    return server;
  }

  /// Gracefully closes active HTTP server(s) and drains in-flight requests.
  ///
  /// Stops accepting new connections immediately, waits up to [gracePeriod]
  /// (default 30 seconds) for in-flight requests to complete, and then force-closes
  /// any remaining active connections.
  Future<void> close({Duration gracePeriod = const Duration(seconds: 30)}) async {
    _isClosing = true;

    // 1. Stop accepting new connections on all listening servers.
    for (final server in _servers) {
      try {
        await server.close(force: false);
      } catch (_) {}
    }

    // 2. Wait up to gracePeriod for in-flight requests to finish.
    if (_inFlightRequests.isNotEmpty) {
      try {
        await Future.wait(
          _inFlightRequests.map((c) => c.future),
        ).timeout(gracePeriod);
      } on TimeoutException {
        // Grace period expired with unfinished requests; proceed to force close.
      } catch (_) {}
    }

    // 3. Force-close any remaining active sockets.
    for (final server in _servers) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }

    _servers.clear();
    _inFlightRequests.clear();
    _isClosing = false;
  }

  /// Bridges standard dart:io [HttpRequest] to [handleRequest].
  ///
  /// Rejects requests exceeding [maxRequestBodyBytes] with a 413 Payload Too Large
  /// response before buffering the entire body into memory.
  Future<void> handleIoRequest(HttpRequest ioReq, {int? maxRequestBodyBytes}) async {
    try {
      final bodyBytes = await _readStreamBytes(ioReq, maxBytes: maxRequestBodyBytes);
      final headers = <String, String>{};
      ioReq.headers.forEach((k, v) => headers[k] = v.join(', '));

      final isSecure = ioReq.certificate != null ||
          ioReq.requestedUri.scheme.toLowerCase() == 'https' ||
          ioReq.uri.scheme.toLowerCase() == 'https' ||
          headers['x-forwarded-proto']?.toLowerCase() == 'https' ||
          headers['x-forwarded-ssl']?.toLowerCase() == 'on';

      final bloomReq = BloomRequest(
        method: ioReq.method,
        uri: ioReq.requestedUri,
        headers: headers,
        rawBody: bodyBytes,
        isSecure: isSecure,
      );

      final bloomRes = await handleRequest(bloomReq);

      ioReq.response.statusCode = bloomRes.statusCode;
      bloomRes.headers.forEach((k, v) => ioReq.response.headers.set(k, v));
      ioReq.response.add(bloomRes.body);
      await ioReq.response.close();
    } on _PayloadTooLargeException catch (e) {
      try {
        final payloadRes = BloomResponse.payloadTooLarge(e.message);
        ioReq.response.statusCode = payloadRes.statusCode;
        payloadRes.headers.forEach((k, v) => ioReq.response.headers.set(k, v));
        ioReq.response.add(payloadRes.body);
        await ioReq.response.close();
      } catch (_) {}
    } catch (e) {
      try {
        final errRes = BloomResponse.error('Internal Server Error: $e');
        ioReq.response.statusCode = errRes.statusCode;
        errRes.headers.forEach((k, v) => ioReq.response.headers.set(k, v));
        ioReq.response.add(errRes.body);
        await ioReq.response.close();
      } catch (_) {}
    }
  }

  Future<Uint8List> _readStreamBytes(Stream<List<int>> stream, {int? maxBytes}) async {
    final builder = BytesBuilder(copy: false);
    int bytesRead = 0;
    await for (final chunk in stream) {
      bytesRead += chunk.length;
      if (maxBytes != null && bytesRead > maxBytes) {
        throw _PayloadTooLargeException(
          'Request body exceeded maximum allowed size of $maxBytes bytes.',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Automatically generates an OpenAPI 3.1 specification and mounts interactive
  /// Scalar and Swagger UI documentation endpoints.
  void enableOpenApi({
    String title = 'Bloom API',
    String version = '1.0.0',
    String description = 'Full-stack Bloom Server API',
    String schemaPath = '/api/openapi.json',
    String docsPath = '/api/docs',
    String swaggerPath = '/api/swagger',
  }) {
    get(schemaPath, (req) async => BloomResponse.json(toOpenApiSpec(
      title: title,
      version: version,
      description: description,
    )));

    get(docsPath, (req) async => BloomResponse.html(_renderScalarHtml(title, schemaPath)));
    get(swaggerPath, (req) async => BloomResponse.html(_renderSwaggerHtml(title, schemaPath)));
  }

  /// Generates an OpenAPI 3.1 specification map from all registered routes.
  Map<String, dynamic> toOpenApiSpec({
    String title = 'Bloom API',
    String version = '1.0.0',
    String description = 'Full-stack Bloom Server API',
  }) {
    final paths = <String, Map<String, dynamic>>{};

    for (final route in _routes) {
      if (route.method == '*' || route.pathPattern.isEmpty) continue;
      if (route.pathPattern.startsWith('/api/openapi') ||
          route.pathPattern.startsWith('/api/docs') ||
          route.pathPattern.startsWith('/api/swagger') ||
          route.pathPattern == '/' ||
          route.pathPattern.endsWith('.js') ||
          route.pathPattern.endsWith('.json')) {
        continue;
      }

      // Convert /api/tasks/:id to /api/tasks/{id}
      var openApiPath = route.pathPattern;
      for (final param in route.paramNames) {
        openApiPath = openApiPath.replaceAll(':$param', '{$param}');
      }

      final methodLower = route.method.toLowerCase();
      paths.putIfAbsent(openApiPath, () => <String, dynamic>{});

      // Derive tag from path segment (e.g. /api/tasks -> Tasks)
      final segments = openApiPath.split('/').where((s) => s.isNotEmpty && s != 'api').toList();
      final tag = segments.isNotEmpty
          ? segments.first.substring(0, 1).toUpperCase() + segments.first.substring(1)
          : 'General';

      final operation = <String, dynamic>{
        'tags': [tag],
        'summary': '${route.method} $openApiPath',
        'responses': {
          '200': {'description': 'Successful response'},
        },
      };

      if (route.paramNames.isNotEmpty) {
        operation['parameters'] = route.paramNames.map((p) => {
          'name': p,
          'in': 'path',
          'required': true,
          'schema': {'type': 'string'},
        }).toList();
      }

      if (methodLower == 'post' || methodLower == 'put' || methodLower == 'patch') {
        operation['requestBody'] = {
          'required': true,
          'content': {
            'application/json': {
              'schema': {'type': 'object'},
            },
          },
        };
      }

      paths[openApiPath]![methodLower] = operation;
    }

    return {
      'openapi': '3.1.0',
      'info': {
        'title': title,
        'version': version,
        'description': description,
      },
      'paths': paths,
    };
  }

  static String _renderScalarHtml(String title, String schemaUrl) {
    return '''
<!doctype html>
<html>
  <head>
    <title>$title • API Reference</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Cpath d='M16 6C16 11.5 11.5 16 6 16C11.5 16 16 20.5 16 26C16 20.5 20.5 16 26 16C20.5 16 16 11.5 16 6Z' fill='%236366F1'/%3E%3C/svg%3E" />
    <style>
      body { margin: 0; background-color: #09090B; }
      .scalar-custom-header {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 12px 24px;
        background: #0E0E12;
        border-bottom: 1px solid #1E1E24;
      }
      .scalar-custom-header span {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-weight: 700;
        font-size: 14px;
        color: #FFF;
        letter-spacing: -0.3px;
      }
    </style>
  </head>
  <body>
    <div class="scalar-custom-header">
      <svg width="22" height="22" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M16 6C16 11.5228 11.5228 16 6 16C11.5228 16 16 20.4772 16 26C16 20.4772 20.4772 16 26 16C20.4772 16 16 11.5228 16 6Z" fill="url(#bGrad)"/>
        <defs>
          <linearGradient id="bGrad" x1="6" y1="6" x2="26" y2="26" gradientUnits="userSpaceOnUse">
            <stop stop-color="#818CF8"/>
            <stop offset="0.5" stop-color="#6366F1"/>
            <stop offset="1" stop-color="#EC4899"/>
          </linearGradient>
        </defs>
      </svg>
      <span>Bloom API Explorer</span>
    </div>
    <script
      id="api-reference"
      data-url="$schemaUrl"
      data-configuration='{"theme":"purple","darkMode":true,"layout":"modern","showSidebar":true}'
    ></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
</html>''';
  }

  static String _renderSwaggerHtml(String title, String schemaUrl) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>$title • Swagger UI</title>
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Cpath d='M16 6C16 11.5 11.5 16 6 16C11.5 16 16 20.5 16 26C16 20.5 20.5 16 26 16C20.5 16 16 11.5 16 6Z' fill='%236366F1'/%3E%3C/svg%3E" />
  <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  <style>
    body { margin: 0; background: #09090B; color: #FFF; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
    .bloom-swagger-bar {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 14px 24px;
      background: #0E0E12;
      border-bottom: 1px solid #1E1E24;
    }
    .bloom-swagger-bar .title { font-weight: 700; font-size: 15px; color: #FFF; }
    .bloom-swagger-bar .badge {
      background: rgba(99, 102, 241, 0.15);
      color: #818CF8;
      border: 1px solid rgba(99, 102, 241, 0.3);
      padding: 2px 8px;
      border-radius: 100px;
      font-size: 11px;
      font-weight: 600;
    }
    .swagger-ui .topbar { display: none; }
  </style>
</head>
<body>
  <div class="bloom-swagger-bar">
    <svg width="22" height="22" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M16 6C16 11.5228 11.5228 16 6 16C11.5228 16 16 20.4772 16 26C16 20.4772 20.4772 16 26 16C20.4772 16 16 11.5228 16 6Z" fill="url(#bGrad)"/>
      <defs>
        <linearGradient id="bGrad" x1="6" y1="6" x2="26" y2="26" gradientUnits="userSpaceOnUse">
          <stop stop-color="#818CF8"/>
          <stop offset="0.5" stop-color="#6366F1"/>
          <stop offset="1" stop-color="#EC4899"/>
        </linearGradient>
      </defs>
    </svg>
    <span class="title">Bloom Interactive Console</span>
    <span class="badge">OpenAPI 3.1</span>
  </div>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: "$schemaUrl",
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIBundle.SwaggerUIStandalonePreset
        ],
      });
    };
  </script>
</body>
</html>''';
  }
}
