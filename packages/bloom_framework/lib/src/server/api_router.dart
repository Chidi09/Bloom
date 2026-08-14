// lib/src/server/api_router.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'bloom_middleware.dart';
import 'bloom_request.dart';
import 'bloom_response.dart';

typedef BloomRouteHandler = FutureOr<BloomResponse> Function(BloomRequest request);

class _RouteEntry {
  final String method;
  final String pathPattern;
  final RegExp regex;
  final List<String> paramNames;
  final List<BloomMiddleware> middlewares;
  final BloomRouteHandler handler;

  _RouteEntry({
    required this.method,
    required this.pathPattern,
    required this.regex,
    required this.paramNames,
    required this.middlewares,
    required this.handler,
  });
}

/// High-performance server router for Bloom API routes and SSR endpoints.
class BloomApiRouter {
  final List<BloomMiddleware> _globalMiddlewares = [];
  final List<_RouteEntry> _routes = [];

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

    // Replace :param with regex capture group
    final paramRegex = RegExp(r':([a-zA-Z0-9_]+)');
    for (final match in paramRegex.allMatches(pattern)) {
      paramNames.add(match.group(1)!);
    }
    regexPattern = regexPattern.replaceAll(paramRegex, r'([^/]+)');

    // Normalize trailing slashes
    if (regexPattern != '/' && regexPattern.endsWith('/')) {
      regexPattern = regexPattern.substring(0, regexPattern.length - 1);
    }

    final regex = RegExp('^$regexPattern/?\$');

    _routes.add(_RouteEntry(
      method: method.toUpperCase(),
      pathPattern: pattern,
      regex: regex,
      paramNames: paramNames,
      middlewares: middlewares,
      handler: handler,
    ));
  }

  /// Dispatches and processes an incoming [BloomRequest].
  Future<BloomResponse> handleRequest(BloomRequest request) async {
    return _executePipeline(_globalMiddlewares, request, () async {
      final method = request.method.toUpperCase();
      final path = request.path;

      for (final route in _routes) {
        if (route.method != '*' && route.method != method) continue;

        final match = route.regex.firstMatch(path);
        if (match != null) {
          final params = <String, String>{};
          for (var i = 0; i < route.paramNames.length; i++) {
            params[route.paramNames[i]] = Uri.decodeComponent(match.group(i + 1)!);
          }

          final enrichedRequest = request.copyWith(params: params);
          return _executePipeline(route.middlewares, enrichedRequest, () async {
            return await route.handler(enrichedRequest);
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
  Future<HttpServer> serve({
    InternetAddress? address,
    int port = 8080,
  }) async {
    final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    server.listen((ioReq) async {
      await handleIoRequest(ioReq);
    });
    return server;
  }

  /// Bridges standard dart:io [HttpRequest] to [handleRequest].
  Future<void> handleIoRequest(HttpRequest ioReq) async {
    final bodyBytes = await _readStreamBytes(ioReq);
    final headers = <String, String>{};
    ioReq.headers.forEach((k, v) => headers[k] = v.join(', '));

    final bloomReq = BloomRequest(
      method: ioReq.method,
      uri: ioReq.uri,
      headers: headers,
      rawBody: bodyBytes,
    );

    final bloomRes = await handleRequest(bloomReq);

    ioReq.response.statusCode = bloomRes.statusCode;
    bloomRes.headers.forEach((k, v) => ioReq.response.headers.set(k, v));
    ioReq.response.add(bloomRes.body);
    await ioReq.response.close();
  }

  Future<Uint8List> _readStreamBytes(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
