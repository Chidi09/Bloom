// lib/src/server/api_router.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'bloom_middleware.dart';
import 'bloom_multipart.dart';
import 'bloom_request.dart';
import 'bloom_response.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';

/// Handler function signature for Bloom server route endpoints.
///
/// Accepts an incoming [request] and asynchronously produces a [BloomResponse].
///
/// ### Example
/// ```dart
/// BloomRouteHandler healthHandler = (request) async {
///   return BloomResponse.json({'status': 'healthy'});
/// };
/// ```
typedef BloomRouteHandler = FutureOr<BloomResponse> Function(
    BloomRequest request);

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

String _joinPaths(String parent, String child) {
  var p = parent.trim();
  var c = child.trim();

  if (p.isNotEmpty && !p.startsWith('/')) {
    p = '/$p';
  }
  while (p.endsWith('/') && p.length > 1) {
    p = p.substring(0, p.length - 1);
  }
  if (p == '/') {
    p = '';
  }

  if (c.isNotEmpty && !c.startsWith('/')) {
    c = '/$c';
  }

  if (p.isNotEmpty && c == '/') {
    c = '';
  }

  final combined = '$p$c';
  if (combined.isEmpty) {
    return '/';
  }
  return combined;
}

const _standardMethodOrder = [
  'GET',
  'HEAD',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'OPTIONS',
];

String _buildAllowHeader(Iterable<String> methods) {
  final methodSet = methods.toSet();
  final ordered = <String>[];
  for (final m in _standardMethodOrder) {
    if (methodSet.remove(m)) {
      ordered.add(m);
    }
  }
  final remaining = methodSet.toList()..sort();
  ordered.addAll(remaining);
  return ordered.join(', ');
}

/// Represents a scoped route group in [BloomApiRouter] sharing a URL prefix and middleware pipeline.
///
/// Route groups allow modular endpoint organization with nested prefix hierarchies and
/// deterministic middleware inheritance.
///
/// ### Example
/// ```dart
/// router.group('/api/v1', (v1) {
///   v1.use(BloomCorsMiddleware());
///
///   v1.get('/tasks', (req) async => BloomResponse.json(tasks));
///   v1.post('/tasks', (req) async => BloomResponse.json(newTask, statusCode: 201));
///
///   v1.group('/admin', (admin) {
///     admin.delete('/cache', (req) async => BloomResponse.noContent());
///   });
/// });
/// ```
class BloomRouteGroup {
  final BloomApiRouter _router;
  final String _prefix;
  final List<BloomMiddleware> _middlewares;

  BloomRouteGroup._(this._router, this._prefix,
      [List<BloomMiddleware>? middlewares])
      : _middlewares = List<BloomMiddleware>.from(middlewares ?? const []);

  /// The resolved URL prefix for this route group.
  String get prefix => _prefix;

  /// Registers middleware scoped to all routes within this group and its subgroups.
  void use(BloomMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// Registers a `GET` route within this group.
  void get(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('GET', path, handler, middlewares);
  }

  /// Registers a `POST` route within this group.
  void post(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('POST', path, handler, middlewares);
  }

  /// Registers a `PUT` route within this group.
  void put(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('PUT', path, handler, middlewares);
  }

  /// Registers a `PATCH` route within this group.
  void patch(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('PATCH', path, handler, middlewares);
  }

  /// Registers a `DELETE` route within this group.
  void delete(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('DELETE', path, handler, middlewares);
  }

  /// Registers an `OPTIONS` route within this group.
  void options(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('OPTIONS', path, handler, middlewares);
  }

  /// Registers a route matching all HTTP methods within this group.
  void all(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('*', path, handler, middlewares);
  }

  /// Mounts a Server-Side Rendered (SSR) endpoint within this group.
  void ssr(
    String path,
    BloomNode Function(BloomRequest request) builder, {
    HeadManager Function(BloomRequest request)? head,
    String Function(String bodyHtml, HeadManager? head)? layout,
    List<BloomMiddleware> middlewares = const [],
  }) {
    get(path, (request) async {
      final node = builder(request);
      final bodyHtml = renderToHtml(node);
      final headManager = head?.call(request);

      final String fullHtml;
      if (layout != null) {
        fullHtml = layout(bodyHtml, headManager);
      } else if (headManager != null) {
        fullHtml = headManager.wrapDocument(bodyHtml);
      } else {
        fullHtml =
            '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>$bodyHtml</body></html>';
      }

      return BloomResponse.html(fullHtml);
    }, middlewares: middlewares);
  }

  /// Creates a nested route group within this group.
  void group(
    String prefix,
    void Function(BloomRouteGroup group) configure, {
    List<BloomMiddleware> middlewares = const [],
  }) {
    final combinedPrefix = _joinPaths(_prefix, prefix);
    final combinedMiddlewares = [..._middlewares, ...middlewares];
    final childGroup =
        BloomRouteGroup._(_router, combinedPrefix, combinedMiddlewares);
    configure(childGroup);
  }

  void _addRoute(String method, String path, BloomRouteHandler handler,
      List<BloomMiddleware> routeMiddlewares) {
    final fullPath = _joinPaths(_prefix, path);
    final fullMiddlewares = [..._middlewares, ...routeMiddlewares];
    _router._addRoute(method, fullPath, handler, fullMiddlewares);
  }
}

/// High-performance server router for Bloom API routes, WebSocket gateways, and SSR endpoints.
///
/// ### Architectural Contract
/// - Provides unified route registration ([get], [post], [put], [delete], [patch], [all]) with nested
///   or route-scoped middleware pipelines and global pipeline hooks ([use]).
/// - Supports path parameter matching (`/api/tasks/:id`), wildcard captures (`/*`), and automatic
///   OpenAPI 3.1 schema specification generation and interactive Scalar / Swagger UI mounting ([enableOpenApi]).
/// - Bridges native `dart:io` [HttpRequest] to typed, testable [BloomRequest] and [BloomResponse] abstractions.
///
/// ### Concurrency & Shutdown Model
/// - Non-blocking asynchronous request handling across server isolates.
/// - Tracks active requests via in-flight request completers to support graceful zero-downtime shutdown
///   via [close], draining active connections within a configurable timeout before force-closing sockets.
/// - Rejects incoming requests with HTTP 503 Service Unavailable during shutdown drain phase.
///
/// ### Specificity-Based Route Sorting
/// Routes are sorted by specificity score (exact static matches > parameterized segments > wildcard routes)
/// so registration order does not cause unintentional route shadowing.
///
/// ### Streaming Request Guards & Response Backpressure
/// - [handleIoRequest] checks byte stream length against [maxRequestBodyBytes] before buffering full payloads,
///   short-circuiting oversized payload attacks with HTTP 413 Payload Too Large.
/// - Incremental responses use `addStream` to propagate backpressure from the client socket directly to
///   the byte producer.
///
/// ### Example
/// ```dart
/// final router = BloomApiRouter();
///
/// // Global middleware
/// router.use(BloomCorsMiddleware());
///
/// // Route definitions
/// router.get('/api/health', (req) async => BloomResponse.json({'status': 'ok'}));
/// router.get('/api/users/:id', (req) async {
///   final id = req.params['id']!;
///   return BloomResponse.json({'id': id, 'name': 'User $id'});
/// });
///
/// // Bind and listen
/// final server = await router.serve(port: 8080);
/// ```
class BloomApiRouter {
  final List<BloomMiddleware> _globalMiddlewares = [];
  final List<_RouteEntry> _routes = [];
  final List<HttpServer> _servers = [];
  final Set<Completer<void>> _inFlightRequests = {};
  bool _isClosing = false;

  /// Registers a global [middleware] executed before all route handlers in this router.
  ///
  /// Global middlewares execute in the order they are registered.
  ///
  /// ### Example
  /// ```dart
  /// router.use(BloomCorsMiddleware());
  /// ```
  void use(BloomMiddleware middleware) {
    _globalMiddlewares.add(middleware);
  }

  /// Registers a `GET` route for [path] handled by [handler] with optional route-scoped [middlewares].
  ///
  /// ### Example
  /// ```dart
  /// router.get('/api/items', (req) async => BloomResponse.json(items));
  /// ```
  void get(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('GET', path, handler, middlewares);
  }

  /// Registers a `POST` route for [path] handled by [handler] with optional route-scoped [middlewares].
  ///
  /// ### Example
  /// ```dart
  /// router.post('/api/items', (req) async {
  ///   final payload = req.json();
  ///   return BloomResponse.json(payload, statusCode: 201);
  /// });
  /// ```
  void post(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('POST', path, handler, middlewares);
  }

  /// Registers a `PUT` route for [path] handled by [handler] with optional route-scoped [middlewares].
  ///
  /// ### Example
  /// ```dart
  /// router.put('/api/items/:id', (req) async => BloomResponse.json({'updated': req.params['id']}));
  /// ```
  void put(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('PUT', path, handler, middlewares);
  }

  /// Registers a `DELETE` route for [path] handled by [handler] with optional route-scoped [middlewares].
  ///
  /// ### Example
  /// ```dart
  /// router.delete('/api/items/:id', (req) async => BloomResponse.noContent());
  /// ```
  void delete(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('DELETE', path, handler, middlewares);
  }

  /// Registers a `PATCH` route for [path] handled by [handler] with optional route-scoped [middlewares].
  ///
  /// ### Example
  /// ```dart
  /// router.patch('/api/items/:id', (req) async => BloomResponse.json({'patched': req.params['id']}));
  /// ```
  void patch(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('PATCH', path, handler, middlewares);
  }

  /// Registers an `OPTIONS` route for [path] handled by [handler] with optional route-scoped [middlewares].
  ///
  /// ### Example
  /// ```dart
  /// router.options('/api/items', (req) async => BloomResponse.noContent());
  /// ```
  void options(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('OPTIONS', path, handler, middlewares);
  }

  /// Registers a route for [path] matching all HTTP methods (GET, POST, PUT, DELETE, PATCH, OPTIONS, etc.).
  ///
  /// ### Example
  /// ```dart
  /// router.all('/api/proxy/*', (req) async => proxyHandler(req));
  /// ```
  void all(String path, BloomRouteHandler handler,
      {List<BloomMiddleware> middlewares = const []}) {
    _addRoute('*', path, handler, middlewares);
  }

  /// Creates a scoped route group with a URL [prefix] and optional inherited [middlewares].
  ///
  /// Nested groups inherit parent group prefix and middlewares in declaration order:
  /// global middlewares -> parent group middlewares -> child group middlewares -> route middlewares.
  ///
  /// ### Example
  /// ```dart
  /// router.group('/api/v1', (api) {
  ///   api.use(BloomCorsMiddleware());
  ///   api.get('/tasks', (req) async => BloomResponse.json(tasks));
  /// });
  /// ```
  void group(
    String prefix,
    void Function(BloomRouteGroup group) configure, {
    List<BloomMiddleware> middlewares = const [],
  }) {
    final routeGroup =
        BloomRouteGroup._(this, _joinPaths('', prefix), [...middlewares]);
    configure(routeGroup);
  }

  /// Mounts a high-performance Server-Side Rendered (SSR) endpoint using [BloomNode].
  ///
  /// Executes pure-Dart [builder] in <1ms without JavaScript engine overhead.
  /// Automatically wraps the resulting HTML using [layout], [head], or a default HTML5 template.
  ///
  /// ### Example
  /// ```dart
  /// router.ssr('/dashboard', (req) => Div(
  ///   classes: 'p-6 max-w-4xl mx-auto',
  ///   children: [H1(text: 'Welcome back')],
  /// ));
  /// ```
  void ssr(
    String path,
    BloomNode Function(BloomRequest request) builder, {
    HeadManager Function(BloomRequest request)? head,
    String Function(String bodyHtml, HeadManager? head)? layout,
    List<BloomMiddleware> middlewares = const [],
  }) {
    get(path, (request) async {
      final node = builder(request);
      final bodyHtml = renderToHtml(node);
      final headManager = head?.call(request);

      final String fullHtml;
      if (layout != null) {
        fullHtml = layout(bodyHtml, headManager);
      } else if (headManager != null) {
        fullHtml = headManager.wrapDocument(bodyHtml);
      } else {
        fullHtml =
            '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>$bodyHtml</body></html>';
      }

      return BloomResponse.html(fullHtml);
    }, middlewares: middlewares);
  }

  void _addRoute(String method, String pattern, BloomRouteHandler handler,
      List<BloomMiddleware> middlewares) {
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

  /// Dispatches and processes an incoming [BloomRequest] through the middleware and route pipeline.
  ///
  /// Alias for [handleRequest].
  Future<BloomResponse> handle(BloomRequest request) => handleRequest(request);

  /// Dispatches and processes an incoming [BloomRequest] through global middlewares and matching routes.
  ///
  /// Matches routes based on specificity order. If a matching route is found, executes the
  /// route's scoped middleware chain followed by its handler. Handles `HEAD` requests by executing
  /// the matching `GET` handler and safely canceling any resulting body stream without sending body bytes.
  ///
  /// Path parameters never overwrite the reserved `auth_*` namespace
  /// (`auth_user_id`, `auth_roles`, …) populated by verified auth middleware:
  /// global middlewares run before route matching, so a route like
  /// `/users/:auth_user_id` must not clobber verified identity for
  /// downstream `params` readers. Never name a route parameter `auth_*`;
  /// prefer the verified `req.authUserId`/`req.authRoles` getters (Expando)
  /// over raw `params` where available.
  ///
  /// Returns a 404 Not Found [BloomResponse] if no registered route matches [request].
  ///
  /// ### Example
  /// ```dart
  /// final req = BloomRequest(method: 'GET', uri: Uri.parse('http://localhost/api/health'));
  /// final res = await router.handleRequest(req);
  /// expect(res.statusCode, equals(200));
  /// ```
  Future<BloomResponse> handleRequest(BloomRequest request) async {
    return _executePipeline(_globalMiddlewares, request, () async {
      final method = request.method.toUpperCase();
      final path = request.path;

      // 1. Check for an exact matching route for method and path.
      for (final route in _routes) {
        final matchesMethod = route.method == '*' ||
            route.method == method ||
            (method == 'HEAD' && route.method == 'GET');
        if (!matchesMethod) continue;

        final match = route.regex.firstMatch(path);
        if (match != null) {
          for (var i = 0; i < route.paramNames.length; i++) {
            final name = route.paramNames[i];
            // Reserve the auth_* namespace for verified auth middleware.
            // Global middlewares run before matching and store verified
            // identity in params; an attacker-controlled path segment must
            // never replace it for downstream params readers.
            if (name.startsWith('auth_')) continue;
            request.params[name] = Uri.decodeComponent(match.group(i + 1)!);
          }

          return _executePipeline(route.middlewares, request, () async {
            final res = await route.handler(request);
            if (method == 'HEAD') {
              // A HEAD response carries no body. Cancel any stream the handler
              // produced, or its subscription is never listened to and the
              // producer is left running for the life of the process.
              if (res.isStreaming) {
                unawaited(res.takeBodyStream().listen(null).cancel());
              }
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

      // 2. No matching route for (method, path). Check if path matches any registered routes.
      final matchingRoutes = <_RouteEntry>[];
      for (final route in _routes) {
        if (route.regex.firstMatch(path) != null) {
          matchingRoutes.add(route);
        }
      }

      // If no route matches the path at all, return 404 Not Found.
      if (matchingRoutes.isEmpty) {
        return BloomResponse.notFound(
            'Cannot ${request.method} ${request.path}');
      }

      // 3. Path matches one or more routes, but not the requested HTTP method.
      final allowedMethods = <String>{};
      bool hasExplicitOptions = false;

      for (final route in matchingRoutes) {
        if (route.method == '*') {
          allowedMethods.add(method);
        } else if (route.method == 'GET') {
          allowedMethods.add('GET');
          allowedMethods.add('HEAD');
        } else if (route.method == 'OPTIONS') {
          hasExplicitOptions = true;
          allowedMethods.add('OPTIONS');
        } else {
          allowedMethods.add(route.method);
        }
      }

      if (!hasExplicitOptions) {
        allowedMethods.add('OPTIONS');
      }

      final allowHeader = _buildAllowHeader(allowedMethods);

      // If the request is OPTIONS with no explicit OPTIONS route, respond 204 with Allow header.
      if (method == 'OPTIONS') {
        return BloomResponse.noContent(headers: {
          'allow': allowHeader,
        });
      }

      // Otherwise respond 405 Method Not Allowed with Allow header.
      return BloomResponse.methodNotAllowed(
        'Method Not Allowed',
        {
          'allow': allowHeader,
        },
      );
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

  /// Binds to a native `dart:io` [HttpServer] and begins serving API and SSR requests.
  ///
  /// Listens on [address] (defaults to [InternetAddress.anyIPv4]) and [port] (default 8080).
  /// If [securityContext] is provided, uses [HttpServer.bindSecure] for TLS/HTTPS termination.
  ///
  /// [maxRequestBodyBytes] optionally enforces a strict size limit on incoming request bodies,
  /// short-circuiting oversized payloads with an HTTP 413 response before full buffering.
  ///
  /// Tracks active in-flight requests to support graceful zero-downtime shutdown via [close].
  ///
  /// ### Example
  /// ```dart
  /// final server = await router.serve(
  ///   address: InternetAddress.loopbackIPv4,
  ///   port: 3000,
  ///   maxRequestBodyBytes: 10 * 1024 * 1024, // 10MB limit
  /// );
  /// print('Server running on port ${server.port}');
  /// ```
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

  /// Gracefully closes all active [HttpServer] instances and drains in-flight requests.
  ///
  /// 1. Stops accepting new socket connections immediately on all bound servers.
  /// 2. Waits up to [gracePeriod] (default 30 seconds) for in-flight requests to complete.
  /// 3. Rejects new incoming requests during drain with HTTP 503 Service Unavailable.
  /// 4. Force-closes any sockets remaining open when [gracePeriod] expires.
  ///
  /// ### Example
  /// ```dart
  /// ProcessSignal.sigterm.watch().listen((_) async {
  ///   print('Shutting down gracefully...');
  ///   await router.close(gracePeriod: Duration(seconds: 15));
  ///   exit(0);
  /// });
  /// ```
  Future<void> close(
      {Duration gracePeriod = const Duration(seconds: 30)}) async {
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

  /// Bridges a native `dart:io` [HttpRequest] to the Bloom router pipeline.
  ///
  /// Converts [ioReq] into a typed [BloomRequest], executes the matching route handler
  /// and middleware chain, and streams or buffers the resulting [BloomResponse] back
  /// to the underlying [HttpResponse] socket.
  ///
  /// If [maxRequestBodyBytes] is exceeded, responds with HTTP 413 Payload Too Large.
  /// If an uncaught exception occurs, responds with HTTP 500 Internal Server Error.
  /// If a streaming response encounters a failure mid-stream, the socket connection
  /// is aborted to notify the client of incomplete transmission.
  Future<void> handleIoRequest(HttpRequest ioReq,
      {int? maxRequestBodyBytes}) async {
    try {
      final headers = <String, String>{};
      ioReq.headers.forEach((k, v) => headers[k] = v.join(', '));

      final isSecure = ioReq.certificate != null ||
          ioReq.requestedUri.scheme.toLowerCase() == 'https' ||
          ioReq.uri.scheme.toLowerCase() == 'https' ||
          headers['x-forwarded-proto']?.toLowerCase() == 'https' ||
          headers['x-forwarded-ssl']?.toLowerCase() == 'on';

      final contentType = headers['content-type'] ?? '';
      final isMultipart =
          contentType.toLowerCase().contains('multipart/form-data');

      final BloomRequest bloomReq;
      if (isMultipart) {
        bloomReq = BloomRequest(
          method: ioReq.method,
          uri: ioReq.requestedUri,
          headers: headers,
          streamBody: ioReq,
          maxRequestBodyBytes: maxRequestBodyBytes,
          isSecure: isSecure,
        );
      } else {
        final bodyBytes =
            await _readStreamBytes(ioReq, maxBytes: maxRequestBodyBytes);
        bloomReq = BloomRequest(
          method: ioReq.method,
          uri: ioReq.requestedUri,
          headers: headers,
          rawBody: bodyBytes,
          isSecure: isSecure,
        );
      }

      final bloomRes = await handleRequest(bloomReq);

      ioReq.response.statusCode = bloomRes.statusCode;
      bloomRes.headers.forEach((k, v) => ioReq.response.headers.set(k, v));
      if (bloomRes.isStreaming) {
        // addStream propagates backpressure from the socket to the source,
        // so a slow client throttles the producer instead of filling memory.
        //
        // Status and headers are already committed by the time the first
        // chunk is written, so a mid-stream failure cannot be reported as an
        // error status. Aborting the connection is the only honest signal:
        // the client sees a truncated chunked body rather than a well-formed
        // response that silently lost data.
        try {
          await ioReq.response.addStream(bloomRes.takeBodyStream());
        } catch (_) {
          await ioReq.response.close().catchError((_) {});
          return;
        }
      } else {
        ioReq.response.add(bloomRes.body);
      }
      await ioReq.response.close();
    } on BloomPayloadTooLargeException catch (e) {
      try {
        final payloadRes = BloomResponse.payloadTooLarge(e.message);
        ioReq.response.statusCode = payloadRes.statusCode;
        payloadRes.headers.forEach((k, v) => ioReq.response.headers.set(k, v));
        ioReq.response.add(payloadRes.body);
        await ioReq.response.close();
      } catch (_) {}
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

  Future<Uint8List> _readStreamBytes(Stream<List<int>> stream,
      {int? maxBytes}) async {
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
  ///
  /// Mounts:
  /// - [schemaPath] (default `'/api/openapi.json'`): The raw OpenAPI 3.1 JSON specification.
  /// - [docsPath] (default `'/api/docs'`): Modern dark-themed Scalar API reference explorer.
  /// - [swaggerPath] (default `'/api/swagger'`): Interactive Swagger UI test console.
  ///
  /// ### Example
  /// ```dart
  /// router.enableOpenApi(
  ///   title: 'E-Commerce API',
  ///   version: '2.1.0',
  ///   description: 'Public storefront and admin REST endpoints',
  /// );
  /// ```
  void enableOpenApi({
    String title = 'Bloom API',
    String version = '1.0.0',
    String description = 'Full-stack Bloom Server API',
    String schemaPath = '/api/openapi.json',
    String docsPath = '/api/docs',
    String swaggerPath = '/api/swagger',
  }) {
    get(
        schemaPath,
        (req) async => BloomResponse.json(toOpenApiSpec(
              title: title,
              version: version,
              description: description,
            )));

    get(
        docsPath,
        (req) async =>
            BloomResponse.html(_renderScalarHtml(title, schemaPath)));
    get(
        swaggerPath,
        (req) async =>
            BloomResponse.html(_renderSwaggerHtml(title, schemaPath)));
  }

  /// Generates an OpenAPI 3.1 specification map from all registered routes.
  ///
  /// Converts parameterized path patterns (`/api/tasks/:id` -> `/api/tasks/{id}`),
  /// extracts path parameters, infers tags from URL segments, and configures JSON request/response schemas.
  ///
  /// Returns a standard OpenAPI 3.1.0 compliant [Map].
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
      final segments = openApiPath
          .split('/')
          .where((s) => s.isNotEmpty && s != 'api')
          .toList();
      final tag = segments.isNotEmpty
          ? segments.first.substring(0, 1).toUpperCase() +
              segments.first.substring(1)
          : 'General';

      final operation = <String, dynamic>{
        'tags': [tag],
        'summary': '${route.method} $openApiPath',
        'responses': {
          '200': {'description': 'Successful response'},
        },
      };

      if (route.paramNames.isNotEmpty) {
        operation['parameters'] = route.paramNames
            .map((p) => {
                  'name': p,
                  'in': 'path',
                  'required': true,
                  'schema': {'type': 'string'},
                })
            .toList();
      }

      if (methodLower == 'post' ||
          methodLower == 'put' ||
          methodLower == 'patch') {
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
