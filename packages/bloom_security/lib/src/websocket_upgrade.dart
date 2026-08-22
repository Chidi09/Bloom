import 'dart:async';
import 'dart:io';
import 'package:bloom_server/bloom_server.dart';

/// Handler callback invoked when a WebSocket connection is successfully upgraded.
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

/// Helper class for raw WebSocket upgrade operations.
class BloomWebSocketUpgrade {
  /// Checks whether an incoming [HttpRequest] is a WebSocket upgrade request.
  static bool isWebSocketRequest(HttpRequest request) {
    return WebSocketTransformer.isUpgradeRequest(request);
  }

  /// Upgrades an incoming [HttpRequest] to a [WebSocket] connection.
  ///
  /// Note: This must be called BEFORE the request body is consumed or the HTTP response is closed.
  ///
  /// - [request]: The active HTTP request to upgrade.
  /// - [onConnection]: Optional callback invoked immediately upon successful upgrade.
  /// - [compression]: Compression options for the WebSocket connection.
  /// - [protocols]: Optional subprotocols supported by the server.
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
class BloomWebSocketServer {
  /// The optional [BloomApiRouter] handling non-WebSocket HTTP requests.
  final BloomApiRouter? apiRouter;
  final List<_BloomWebSocketRouteEntry> _wsRoutes = [];

  /// Creates a [BloomWebSocketServer] with an optional [apiRouter] fallback.
  BloomWebSocketServer({this.apiRouter});

  /// Registers a WebSocket route on a path pattern (e.g. `'/ws/chat'` or `'/ws/rooms/:roomId'`).
  ///
  /// - [pathPattern]: Path pattern string supporting parameterized segments (`:id`) or wildcards (`*`).
  /// - [handler]: Callback executed when a WebSocket upgrade is completed on a matching path.
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
