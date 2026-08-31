import 'dart:async';
import 'dart:convert';
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

/// Admission hook signature invoked prior to upgrading an HTTP connection to a WebSocket.
///
/// Returns `true` to approve the connection, or `false` to reject the handshake with HTTP 403 Forbidden.
///
/// Example:
/// ```dart
/// Future<bool> authAdmissionHook(HttpRequest request) async {
///   final authHeader = request.headers.value('authorization');
///   return authHeader != null && authHeader.startsWith('Bearer ');
/// }
/// ```
typedef BloomWebSocketAdmissionHook = FutureOr<bool> Function(
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

/// Helper class for raw WebSocket upgrade and security validation on incoming [HttpRequest] instances.
class BloomWebSocketUpgrade {
  /// Checks whether an incoming [HttpRequest] is a WebSocket upgrade request.
  ///
  /// Returns `true` if the HTTP headers include `Connection: Upgrade` and `Upgrade: websocket`.
  static bool isWebSocketRequest(HttpRequest request) {
    return WebSocketTransformer.isUpgradeRequest(request);
  }

  /// Validates whether the `Origin` header of an incoming WebSocket handshake request is allowed.
  ///
  /// - Non-browser requests lacking an `Origin` header are permitted if [allowNullOrigin] is `true` (default).
  /// - Wildcard origins (`['*']`) permit any origin.
  /// - Explicit allowlists permit matching origins (case-insensitive) or same-origin requests.
  /// - By default (empty [allowedOrigins]), cross-origin browser handshakes are rejected (**deny-by-default**).
  static bool isOriginAllowed({
    required HttpRequest request,
    List<String> allowedOrigins = const [],
    bool allowNullOrigin = true,
  }) {
    final origin = request.headers.value('origin');
    if (origin == null || origin.trim().isEmpty) {
      return allowNullOrigin;
    }

    final cleanOrigin = origin.trim();

    if (allowedOrigins.contains('*')) {
      return true;
    }

    if (allowedOrigins.isNotEmpty) {
      final lowerOrigin = cleanOrigin.toLowerCase();
      final inAllowlist =
          allowedOrigins.any((o) => o.trim().toLowerCase() == lowerOrigin);
      if (inAllowlist) return true;
      return _isSameOrigin(cleanOrigin, request);
    }

    // Deny-by-default for cross-origin browser handshakes:
    // When no allowlist is configured, only same-origin handshakes are permitted.
    return _isSameOrigin(cleanOrigin, request);
  }

  static bool _isSameOrigin(String origin, HttpRequest request) {
    try {
      final originUri = Uri.parse(origin);
      final reqUri = request.requestedUri;

      final originPort = originUri.hasPort
          ? originUri.port
          : (originUri.scheme.toLowerCase() == 'https' ? 443 : 80);
      final reqPort = reqUri.hasPort
          ? reqUri.port
          : (reqUri.scheme.toLowerCase() == 'https' ? 443 : 80);

      final schemeMatch =
          originUri.scheme.toLowerCase() == reqUri.scheme.toLowerCase();
      final hostMatch =
          originUri.host.toLowerCase() == reqUri.host.toLowerCase();
      final portMatch = originPort == reqPort;

      if (schemeMatch && hostMatch && portMatch) {
        return true;
      }

      // Also check against Host header if requestedUri differs due to reverse proxying
      final hostHeader = request.headers.value('host');
      if (hostHeader != null && hostHeader.isNotEmpty) {
        final parts = hostHeader.split(':');
        final headerHost = parts[0].toLowerCase();
        final headerPort = parts.length > 1
            ? int.tryParse(parts[1]) ?? reqPort
            : (reqUri.scheme.toLowerCase() == 'https' ? 443 : 80);

        if (originUri.host.toLowerCase() == headerHost &&
            originPort == headerPort) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Upgrades an incoming [HttpRequest] to a [WebSocket] connection with security checks.
  ///
  /// Enforces origin validation, executes [admissionHook] (if provided), and bounds inbound
  /// message size if [maxMessageBytes] is configured.
  ///
  /// - [request]: The active HTTP request to upgrade.
  /// - [onConnection]: Optional callback invoked immediately upon successful upgrade.
  /// - [compression]: Compression options for the WebSocket connection.
  /// - [protocols]: Optional subprotocols supported by the server.
  /// - [allowedOrigins]: Origin allowlist or `['*']` for wildcard.
  /// - [allowNullOrigin]: Whether to admit non-browser handshakes without an `Origin` header.
  /// - [admissionHook]: Hook evaluated before upgrade to authorize the connection.
  /// - [maxMessageBytes]: Maximum allowed inbound message payload bytes before closing the peer.
  static Future<WebSocket> upgrade(
    HttpRequest request, {
    BloomWebSocketHandler? onConnection,
    CompressionOptions? compression,
    List<String>? protocols,
    List<String> allowedOrigins = const [],
    bool allowNullOrigin = true,
    BloomWebSocketAdmissionHook? admissionHook,
    int? maxMessageBytes,
  }) async {
    if (!isOriginAllowed(
      request: request,
      allowedOrigins: allowedOrigins,
      allowNullOrigin: allowNullOrigin,
    )) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      throw const HttpException('WebSocket origin not allowed');
    }

    if (admissionHook != null) {
      final admitted = await admissionHook(request);
      if (!admitted) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        throw const HttpException('WebSocket admission rejected');
      }
    }

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

    final effectiveSocket = (maxMessageBytes != null && maxMessageBytes > 0)
        ? _BloomBoundedWebSocket(socket, maxMessageBytes)
        : socket;

    if (onConnection != null) {
      await onConnection(effectiveSocket, request);
    }

    return effectiveSocket;
  }
}

/// Hardened WebSocket server and router for Bloom applications.
///
/// Features:
/// - Configurable origin validation with deny-by-default for cross-origin browser handshakes.
/// - Pre-upgrade [admissionHook] support for auth and quota verification.
/// - Configurable [maxConnections] limit rejecting over-capacity handshakes with HTTP 503.
/// - Configurable [maxMessageBytes] limit closing over-limit sockets with `WebSocketStatus.messageTooBig` (1009).
/// - Dual routing: WebSocket upgrades matched by path pattern, non-WebSocket HTTP delegated to [apiRouter].
///
/// Example:
/// ```dart
/// final wsServer = BloomWebSocketServer(
///   apiRouter: router,
///   allowedOrigins: ['https://myapp.com'],
///   maxConnections: 1000,
///   maxMessageBytes: 64 * 1024,
///   admissionHook: (req) => req.headers.value('authorization') != null,
/// );
/// wsServer.register('/ws/chat', (socket, req) {
///   socket.listen((msg) => socket.add('Echo: $msg'));
/// });
/// ```
class BloomWebSocketServer {
  /// The optional [BloomApiRouter] handling non-WebSocket HTTP requests.
  final BloomApiRouter? apiRouter;

  /// Allowed origins for WebSocket handshakes. Defaults to `const []` (deny cross-origin by default).
  final List<String> allowedOrigins;

  /// Whether to admit non-browser handshakes without an `Origin` header. Defaults to `true`.
  final bool allowNullOrigin;

  /// Optional hook evaluated prior to upgrading the connection.
  final BloomWebSocketAdmissionHook? admissionHook;

  /// Maximum concurrent active WebSocket connections.
  final int? maxConnections;

  /// Maximum permitted inbound message payload bytes per frame.
  final int? maxMessageBytes;

  final List<_BloomWebSocketRouteEntry> _wsRoutes = [];
  int _activeConnections = 0;

  /// Returns the current number of active concurrent WebSocket connections.
  int get activeConnections => _activeConnections;

  /// Creates a [BloomWebSocketServer] with security hardening options.
  BloomWebSocketServer({
    this.apiRouter,
    this.allowedOrigins = const [],
    this.allowNullOrigin = true,
    this.admissionHook,
    this.maxConnections,
    this.maxMessageBytes,
  }) {
    if (maxConnections != null && maxConnections! <= 0) {
      throw ArgumentError.value(
        maxConnections,
        'maxConnections',
        'maxConnections must be greater than 0',
      );
    }
    if (maxMessageBytes != null && maxMessageBytes! <= 0) {
      throw ArgumentError.value(
        maxMessageBytes,
        'maxMessageBytes',
        'maxMessageBytes must be greater than 0',
      );
    }
  }

  /// Registers a WebSocket route on a path pattern (e.g. `'/ws/chat'` or `'/ws/rooms/:roomId'`).
  ///
  /// Supports wildcards (`'*'`, `'/*'`) and path parameters prefixed with a colon (e.g. `':roomId'`).
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
  Future<void> handleIoRequest(HttpRequest ioReq) async {
    final path = ioReq.uri.path;

    if (WebSocketTransformer.isUpgradeRequest(ioReq)) {
      for (final route in _wsRoutes) {
        if (route.regex.hasMatch(path)) {
          // 1. Origin validation
          if (!BloomWebSocketUpgrade.isOriginAllowed(
            request: ioReq,
            allowedOrigins: allowedOrigins,
            allowNullOrigin: allowNullOrigin,
          )) {
            try {
              ioReq.response.statusCode = HttpStatus.forbidden;
              await ioReq.response.close();
            } catch (_) {}
            return;
          }

          // 2. Max connections cap
          if (maxConnections != null && _activeConnections >= maxConnections!) {
            try {
              ioReq.response.statusCode = HttpStatus.serviceUnavailable;
              ioReq.response.headers.set('Retry-After', '30');
              await ioReq.response.close();
            } catch (_) {}
            return;
          }

          // 3. Admission hook
          if (admissionHook != null) {
            final admitted = await admissionHook!(ioReq);
            if (!admitted) {
              try {
                ioReq.response.statusCode = HttpStatus.forbidden;
                await ioReq.response.close();
              } catch (_) {}
              return;
            }
          }

          // 4. Upgrade connection
          try {
            final socket = await WebSocketTransformer.upgrade(
              ioReq,
              compression: CompressionOptions.compressionDefault,
            );

            _activeConnections++;
            socket.done.whenComplete(() {
              _activeConnections = (_activeConnections - 1).clamp(0, 1 << 30);
            });

            final effectiveSocket =
                (maxMessageBytes != null && maxMessageBytes! > 0)
                    ? _BloomBoundedWebSocket(socket, maxMessageBytes!)
                    : socket;

            await route.handler(effectiveSocket, ioReq);
            return;
          } catch (_) {
            try {
              ioReq.response.statusCode = HttpStatus.badRequest;
              await ioReq.response.close();
            } catch (_) {}
            return;
          }
        }
      }
    }

    // Delegate non-WebSocket HTTP request to BloomApiRouter if available
    if (apiRouter != null) {
      await apiRouter!.handleIoRequest(ioReq);
    } else {
      ioReq.response.statusCode = HttpStatus.notFound;
      await ioReq.response.close();
    }
  }

  /// Binds an [HttpServer] and routes both WebSocket connections and [BloomApiRouter] HTTP routes.
  static Future<HttpServer> bind({
    BloomApiRouter? router,
    InternetAddress? address,
    int port = 8080,
    Map<String, BloomWebSocketHandler>? webSocketRoutes,
    List<String> allowedOrigins = const [],
    bool allowNullOrigin = true,
    BloomWebSocketAdmissionHook? admissionHook,
    int? maxConnections,
    int? maxMessageBytes,
  }) async {
    final wsServer = BloomWebSocketServer(
      apiRouter: router,
      allowedOrigins: allowedOrigins,
      allowNullOrigin: allowNullOrigin,
      admissionHook: admissionHook,
      maxConnections: maxConnections,
      maxMessageBytes: maxMessageBytes,
    );

    if (webSocketRoutes != null) {
      webSocketRoutes.forEach((pattern, handler) {
        wsServer.register(pattern, handler);
      });
    }

    final server =
        await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    server.listen((ioReq) async {
      await wsServer.handleIoRequest(ioReq);
    });

    return server;
  }
}

/// Extension on [BloomApiRouter] for ergonomic WebSocket-enabled serving.
extension BloomWebSocketApiRouterExtension on BloomApiRouter {
  /// Binds and starts the HTTP server with both HTTP routes and WebSocket upgrade routes.
  Future<HttpServer> serveWithWebSockets({
    InternetAddress? address,
    int port = 8080,
    Map<String, BloomWebSocketHandler> webSocketRoutes = const {},
    List<String> allowedOrigins = const [],
    bool allowNullOrigin = true,
    BloomWebSocketAdmissionHook? admissionHook,
    int? maxConnections,
    int? maxMessageBytes,
  }) {
    return BloomWebSocketServer.bind(
      router: this,
      address: address,
      port: port,
      webSocketRoutes: webSocketRoutes,
      allowedOrigins: allowedOrigins,
      allowNullOrigin: allowNullOrigin,
      admissionHook: admissionHook,
      maxConnections: maxConnections,
      maxMessageBytes: maxMessageBytes,
    );
  }
}

/// Internal WebSocket proxy enforcing [maxMessageBytes] limits on inbound messages.
class _BloomBoundedWebSocket extends Stream<dynamic> implements WebSocket {
  final WebSocket _inner;
  final int maxMessageBytes;

  _BloomBoundedWebSocket(this._inner, this.maxMessageBytes);

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = _inner.transform(
      StreamTransformer<dynamic, dynamic>.fromHandlers(
        handleData: (data, sink) {
          int size = 0;
          if (data is String) {
            size = utf8.encode(data).length;
          } else if (data is List<int>) {
            size = data.length;
          }

          if (size > maxMessageBytes) {
            _inner.close(
              WebSocketStatus.messageTooBig,
              'Inbound message size of $size bytes exceeds limit of $maxMessageBytes bytes',
            );
            sink.close();
            return;
          }

          sink.add(data);
        },
      ),
    );

    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Duration? get pingInterval => _inner.pingInterval;

  @override
  set pingInterval(Duration? value) => _inner.pingInterval = value;

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;

  @override
  String get extensions => _inner.extensions;

  @override
  String? get protocol => _inner.protocol;

  @override
  int get readyState => _inner.readyState;

  @override
  Future close([int? code, String? reason]) => _inner.close(code, reason);

  @override
  void add(dynamic data) => _inner.add(data);

  @override
  void addUtf8Text(List<int> payload) => _inner.addUtf8Text(payload);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream<dynamic> stream) => _inner.addStream(stream);

  @override
  Future get done => _inner.done;
}
