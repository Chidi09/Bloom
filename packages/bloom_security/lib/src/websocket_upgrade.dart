import 'dart:async';
import 'dart:io';
import 'package:bloom_server/bloom_server.dart';

/// Handler callback invoked when a WebSocket connection is successfully upgraded.
///
/// Receives the active [WebSocket] connection and the initial [HttpRequest] that initiated the handshake.
///
/// Example:
/// ```dart
/// void onWsConnected(WebSocket socket, HttpRequest request) {
///   socket.listen((message) {
///     socket.add('Echo: $message');
///   });
/// }
/// ```
typedef BloomWebSocketHandler = FutureOr<void> Function(
  WebSocket socket,
  HttpRequest request,
);

/// WebSocket route definition.
class _BloomWebSocketRouteEntry {
  final String pattern;
  final RegExp regex;
  final List<String> paramNames;
  final BloomWebSocketHandler handler;

  _BloomWebSocketRouteEntry({
    required this.pattern,
    required this.regex,
    required this.paramNames,
    required this.handler,
  });
}

/// Helper class for raw WebSocket upgrade operations on incoming [HttpRequest] instances.
class BloomWebSocketUpgrade {
  /// Checks whether an incoming [HttpRequest] is a WebSocket upgrade request.
  ///
  /// Returns `true` if the HTTP headers include `Connection: Upgrade` and `Upgrade: websocket`.
  ///
  /// Example:
  /// ```dart
  /// if (BloomWebSocketUpgrade.isWebSocketRequest(request)) {
  ///   final socket = await BloomWebSocketUpgrade.upgrade(request);
  /// }
  /// ```
  static bool isWebSocketRequest(HttpRequest request) {
    return WebSocketTransformer.isUpgradeRequest(request);
  }

  /// Upgrades an incoming [HttpRequest] to a [WebSocket] connection.
  ///
  /// Note: This must be called BEFORE the request body is consumed or the HTTP response is closed.
  ///
  /// - [request]: The active HTTP request to upgrade.
  /// - [onConnection]: Optional callback invoked immediately upon successful upgrade.
  /// - [compression]: Compression options for the WebSocket connection (defaults to [CompressionOptions.compressionDefault]).
  /// - [protocols]: Optional subprotocols supported by the server.
  ///
  /// Example:
  /// ```dart
  /// final socket = await BloomWebSocketUpgrade.upgrade(
  ///   request,
  ///   onConnection: (ws, req) {
  ///     ws.add('Welcome!');
  ///   },
  /// );
  /// ```
  static Future<WebSocket> upgrade(
    HttpRequest request, {
    BloomWebSocketHandler? onConnection,
    CompressionOptions? compression,
    List<String>? protocols,
  }) async {
    final socket = await WebSocketTransformer.upgrade(
      request,
      compression: compression ?? CompressionOptions.compressionDefault,
      protocolSelector: (protocols != null && protocols.isNotEmpty)
          ? (clientProtocols) => protocols.firstWhere(
                (p) => clientProtocols.contains(p),
                orElse: () => '',
              )
          : null,
    );

    if (onConnection != null) {
      await onConnection(socket, request);
    }

    return socket;
  }
}

/// WebSocket server and router for Bloom applications.
///
/// Dispatches incoming WebSocket requests to registered WebSocket handlers,
/// and delegates standard HTTP requests to a [BloomApiRouter].
///
/// Example:
/// ```dart
/// final router = BloomApiRouter();
/// router.get('/api/status', (req) => BloomResponse.json({'status': 'ok'}));
///
/// final wsServer = BloomWebSocketServer(apiRouter: router);
/// wsServer.register('/ws/chat', (socket, req) {
///   socket.listen((msg) => socket.add('Echo: $msg'));
/// });
///
/// final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
/// server.listen(wsServer.handleIoRequest);
/// ```
class BloomWebSocketServer {
  /// The optional [BloomApiRouter] handling non-WebSocket HTTP requests.
  final BloomApiRouter? apiRouter;
  final List<_BloomWebSocketRouteEntry> _wsRoutes = [];

  /// Creates a [BloomWebSocketServer] with an optional [apiRouter] fallback.
  ///
  /// - [apiRouter]: Optional router used to dispatch standard non-WebSocket HTTP requests.
  BloomWebSocketServer({this.apiRouter});

  /// Registers a WebSocket route on a path pattern (e.g. `'/ws/chat'` or `'/ws/rooms/:roomId'`).
  ///
  /// Supports wildcards (`'*'`, `'/*'`) and path parameters prefixed with a colon (e.g. `':roomId'`).
  ///
  /// - [pathPattern]: Path pattern string supporting parameterized segments (`:id`) or wildcards (`*`).
  /// - [handler]: Callback executed when a WebSocket upgrade is completed on a matching path.
  ///
  /// Example:
  /// ```dart
  /// wsServer.register('/ws/feed', (socket, request) {
  ///   socket.add('Connected to live feed');
  /// });
  /// ```
  void register(String pathPattern, BloomWebSocketHandler handler) {
    final paramNames = <String>[];
    var regexPattern = pathPattern;

    if (pathPattern == '*' || pathPattern == '/*') {
      _wsRoutes.add(_BloomWebSocketRouteEntry(
        pattern: pathPattern,
        regex: RegExp(r'^.*$'),
        paramNames: paramNames,
        handler: handler,
      ));
      return;
    }

    final paramRegex = RegExp(r':([a-zA-Z0-9_]+)');
    for (final match in paramRegex.allMatches(pathPattern)) {
      paramNames.add(match.group(1)!);
    }
    regexPattern = regexPattern.replaceAll(paramRegex, r'([^/]+)');
    regexPattern = regexPattern.replaceAll('*', r'.*');

    if (regexPattern != '/' && regexPattern.endsWith('/')) {
      regexPattern = regexPattern.substring(0, regexPattern.length - 1);
    }

    final regex = RegExp('^$regexPattern/?\$');
    _wsRoutes.add(_BloomWebSocketRouteEntry(
      pattern: pathPattern,
      regex: regex,
      paramNames: paramNames,
      handler: handler,
    ));
  }

  /// Handles an incoming [HttpRequest], upgrading if it is a matching WebSocket request,
  /// or delegating to [apiRouter] if it is standard HTTP.
  ///
  /// If no WebSocket route matches and [apiRouter] is null, responds with a 404 Not Found HTTP response.
  ///
  /// - [ioReq]: The incoming `dart:io` [HttpRequest].
  Future<void> handleIoRequest(HttpRequest ioReq) async {
    final path = ioReq.uri.path;

    if (WebSocketTransformer.isUpgradeRequest(ioReq)) {
      for (final route in _wsRoutes) {
        if (route.regex.hasMatch(path)) {
          try {
            final socket = await WebSocketTransformer.upgrade(
              ioReq,
              compression: CompressionOptions.compressionDefault,
            );
            await route.handler(socket, ioReq);
            return;
          } catch (e) {
            // Upgrade failed or socket error
            try {
              ioReq.response.statusCode = HttpStatus.badRequest;
              await ioReq.response.close();
            } catch (_) {}
            return;
          }
        }
      }
    }

    // Delegate to BloomApiRouter if available
    if (apiRouter != null) {
      await apiRouter!.handleIoRequest(ioReq);
    } else {
      ioReq.response.statusCode = HttpStatus.notFound;
      await ioReq.response.close();
    }
  }

  /// Binds an [HttpServer] and routes both WebSocket connections and [BloomApiRouter] HTTP routes.
  ///
  /// - [router]: Optional [BloomApiRouter] instance for HTTP endpoints.
  /// - [address]: Network interface address to bind to (defaults to [InternetAddress.anyIPv4]).
  /// - [port]: TCP port to listen on (defaults to 8080).
  /// - [webSocketRoutes]: Map of path patterns to WebSocket handler callbacks.
  ///
  /// Example:
  /// ```dart
  /// final server = await BloomWebSocketServer.bind(
  ///   router: apiRouter,
  ///   port: 8080,
  ///   webSocketRoutes: {
  ///     '/ws/notifications': (socket, req) {
  ///       socket.add('Connected');
  ///     },
  ///   },
  /// );
  /// ```
  static Future<HttpServer> bind({
    BloomApiRouter? router,
    InternetAddress? address,
    int port = 8080,
    Map<String, BloomWebSocketHandler>? webSocketRoutes,
  }) async {
    final wsServer = BloomWebSocketServer(apiRouter: router);

    if (webSocketRoutes != null) {
      webSocketRoutes.forEach((pattern, handler) {
        wsServer.register(pattern, handler);
      });
    }

    final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    server.listen((ioReq) async {
      await wsServer.handleIoRequest(ioReq);
    });

    return server;
  }
}

/// Extension on [BloomApiRouter] for ergonomic WebSocket-enabled serving.
extension BloomWebSocketApiRouterExtension on BloomApiRouter {
  /// Binds and starts the HTTP server with both HTTP routes and WebSocket upgrade routes.
  ///
  /// - [address]: Network address to bind to (defaults to [InternetAddress.anyIPv4]).
  /// - [port]: Port number to listen on (defaults to 8080).
  /// - [webSocketRoutes]: Map of route paths to [BloomWebSocketHandler] callbacks.
  ///
  /// Example:
  /// ```dart
  /// final router = BloomApiRouter();
  /// router.get('/api/ping', (req) => BloomResponse.text('pong'));
  ///
  /// await router.serveWithWebSockets(
  ///   port: 8080,
  ///   webSocketRoutes: {
  ///     '/ws/events': (socket, req) {
  ///       socket.add('connected');
  ///     },
  ///   },
  /// );
  /// ```
  Future<HttpServer> serveWithWebSockets({
    InternetAddress? address,
    int port = 8080,
    Map<String, BloomWebSocketHandler> webSocketRoutes = const {},
  }) {
    return BloomWebSocketServer.bind(
      router: this,
      address: address,
      port: port,
      webSocketRoutes: webSocketRoutes,
    );
  }
}
