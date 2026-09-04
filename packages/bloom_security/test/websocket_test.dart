import 'dart:async';
import 'dart:io';
import 'package:bloom_security/bloom_security.dart';
import 'package:test/test.dart';

void main() {
  group('BloomWebSocket Security Tests', () {
    test('Constructor argument validation', () {
      expect(() => BloomWebSocketServer(maxConnections: 0),
          throwsArgumentError);
      expect(() => BloomWebSocketServer(maxConnections: -1),
          throwsArgumentError);
      expect(() => BloomWebSocketServer(maxMessageBytes: 0),
          throwsArgumentError);
      expect(() => BloomWebSocketServer(maxMessageBytes: -100),
          throwsArgumentError);
    });

    test(
        'Live Server: Origin validation rejects cross-origin browser handshakes by default',
        () async {
      final wsServer = BloomWebSocketServer();
      wsServer.register('/ws/feed', (socket, req) {
        socket.add('welcome');
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(wsServer.handleIoRequest);
      final port = server.port;

      try {
        // 1. Cross-origin request with disallowed Origin header should fail
        final client = HttpClient();
        final req = await client.openUrl(
          'GET',
          Uri.parse('http://127.0.0.1:$port/ws/feed'),
        );
        req.headers.set('Connection', 'Upgrade');
        req.headers.set('Upgrade', 'websocket');
        req.headers.set('Sec-WebSocket-Version', '13');
        req.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
        req.headers.set('Origin', 'https://attacker-origin.com');

        final res = await req.close();
        expect(res.statusCode, HttpStatus.forbidden);
        client.close();

        // 2. Same-origin browser request should succeed
        final sameOriginSocket = await WebSocket.connect(
          'ws://127.0.0.1:$port/ws/feed',
          headers: {'Origin': 'http://127.0.0.1:$port'},
        );
        final msgCompleter = Completer<String>();
        sameOriginSocket.listen((data) {
          if (!msgCompleter.isCompleted) {
            msgCompleter.complete(data.toString());
          }
        });
        final msg =
            await msgCompleter.future.timeout(const Duration(seconds: 3));
        expect(msg, 'welcome');
        await sameOriginSocket.close();

        // 3. Non-browser native client without Origin header should succeed
        final nativeSocket =
            await WebSocket.connect('ws://127.0.0.1:$port/ws/feed');
        final nativeMsgCompleter = Completer<String>();
        nativeSocket.listen((data) {
          if (!nativeMsgCompleter.isCompleted) {
            nativeMsgCompleter.complete(data.toString());
          }
        });
        final nativeMsg =
            await nativeMsgCompleter.future.timeout(const Duration(seconds: 3));
        expect(nativeMsg, 'welcome');
        await nativeSocket.close();
      } finally {
        await server.close(force: true);
      }
    });

    test('Live Server: Configured allowedOrigins permits explicit domains',
        () async {
      final wsServer = BloomWebSocketServer(
        allowedOrigins: ['https://dashboard.bloom.dev'],
      );
      wsServer.register('/ws/notifications', (socket, req) {
        socket.add('notifs_ready');
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(wsServer.handleIoRequest);
      final port = server.port;

      try {
        // Allowed origin connects
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:$port/ws/notifications',
          headers: {'Origin': 'https://dashboard.bloom.dev'},
        );
        final completer = Completer<String>();
        socket.listen((data) => completer.complete(data.toString()));
        expect(await completer.future, 'notifs_ready');
        await socket.close();

        // Disallowed origin rejected
        final client = HttpClient();
        final req = await client.openUrl(
          'GET',
          Uri.parse('http://127.0.0.1:$port/ws/notifications'),
        );
        req.headers.set('Connection', 'Upgrade');
        req.headers.set('Upgrade', 'websocket');
        req.headers.set('Sec-WebSocket-Version', '13');
        req.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
        req.headers.set('Origin', 'https://malicious.dev');

        final res = await req.close();
        expect(res.statusCode, HttpStatus.forbidden);
        client.close();
      } finally {
        await server.close(force: true);
      }
    });

    test('Live Server: Admission hook authorizes or rejects upgrades',
        () async {
      final wsServer = BloomWebSocketServer(
        allowedOrigins: ['*'],
        admissionHook: (req) {
          final token = req.headers.value('x-auth-token');
          return token == 'secret-token-123';
        },
      );
      wsServer.register('/ws/secure', (socket, req) {
        socket.add('authorized');
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(wsServer.handleIoRequest);
      final port = server.port;

      try {
        // Handshake with invalid token rejected
        final client = HttpClient();
        final req = await client.openUrl(
          'GET',
          Uri.parse('http://127.0.0.1:$port/ws/secure'),
        );
        req.headers.set('Connection', 'Upgrade');
        req.headers.set('Upgrade', 'websocket');
        req.headers.set('Sec-WebSocket-Version', '13');
        req.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
        req.headers.set('x-auth-token', 'wrong-token');

        final res = await req.close();
        expect(res.statusCode, HttpStatus.forbidden);
        client.close();

        // Handshake with valid token admitted
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:$port/ws/secure',
          headers: {'x-auth-token': 'secret-token-123'},
        );
        final completer = Completer<String>();
        socket.listen((data) => completer.complete(data.toString()));
        expect(await completer.future, 'authorized');
        await socket.close();
      } finally {
        await server.close(force: true);
      }
    });

    test(
        'Live Server: maxConnections cap rejects over-limit connections and decrements on close',
        () async {
      final wsServer = BloomWebSocketServer(
        allowedOrigins: ['*'],
        maxConnections: 2,
      );
      wsServer.register('/ws/capped', (socket, req) {
        socket.listen((msg) {});
        socket.add('connected');
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(wsServer.handleIoRequest);
      final port = server.port;

      try {
        final socket1 =
            await WebSocket.connect('ws://127.0.0.1:$port/ws/capped');
        final socket2 =
            await WebSocket.connect('ws://127.0.0.1:$port/ws/capped');

        expect(wsServer.activeConnections, 2);

        // 3rd connection attempt exceeds maxConnections -> rejected with 503
        final client = HttpClient();
        final req = await client.openUrl(
          'GET',
          Uri.parse('http://127.0.0.1:$port/ws/capped'),
        );
        req.headers.set('Connection', 'Upgrade');
        req.headers.set('Upgrade', 'websocket');
        req.headers.set('Sec-WebSocket-Version', '13');
        req.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');

        final res = await req.close();
        expect(res.statusCode, HttpStatus.serviceUnavailable);
        expect(res.headers.value('retry-after'), '30');
        client.close();

        // Close socket1 -> active connections decrement
        await socket1.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(wsServer.activeConnections, 1);

        // Now new connection succeeds
        final socket3 =
            await WebSocket.connect('ws://127.0.0.1:$port/ws/capped');
        expect(wsServer.activeConnections, 2);

        await socket2.close();
        await socket3.close();
      } finally {
        await server.close(force: true);
      }
    });

    test(
        'Live Server: maxMessageBytes closes socket with 1009 when message is too big',
        () async {
      final receivedMessages = <String>[];
      final wsServer = BloomWebSocketServer(
        allowedOrigins: ['*'],
        maxMessageBytes: 32, // 32 bytes limit
      );
      wsServer.register('/ws/echo', (socket, req) {
        socket.listen((msg) {
          receivedMessages.add(msg.toString());
          socket.add('Echo: $msg');
        });
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(wsServer.handleIoRequest);
      final port = server.port;

      try {
        final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws/echo');

        // Small message (under 32 bytes) succeeds
        socket.add('Hello Bloom');
        final firstEchoCompleter = Completer<String>();
        final closeCompleter = Completer<int?>();

        socket.listen(
          (msg) {
            if (!firstEchoCompleter.isCompleted) {
              firstEchoCompleter.complete(msg.toString());
            }
          },
          onDone: () {
            if (!closeCompleter.isCompleted) {
              closeCompleter.complete(socket.closeCode);
            }
          },
        );

        final firstEcho =
            await firstEchoCompleter.future.timeout(const Duration(seconds: 3));
        expect(firstEcho, 'Echo: Hello Bloom');

        // Oversized message (100 bytes > 32 bytes limit)
        final bigPayload = 'A' * 100;
        socket.add(bigPayload);

        final closeCode =
            await closeCompleter.future.timeout(const Duration(seconds: 3));
        expect(closeCode, WebSocketStatus.messageTooBig);
      } finally {
        await server.close(force: true);
      }
    });
  });
}
