import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Zero-configuration HTTP dev server with Server-Sent Events (SSE) live reload.
class BloomLiveReloadServer {
  final Directory webDir;
  final String host;
  final int port;
  final bool autoInjectScript;

  HttpServer? _server;
  final List<HttpResponse> _sseClients = [];

  static const String liveReloadScript = '''
<script>
  (() => {
    if (window.__BLOOM_HR_ACTIVE__) return;
    window.__BLOOM_HR_ACTIVE__ = true;
    const connect = () => {
      const es = new EventSource('/_bloom_hr');
      es.addEventListener('reload', (e) => {
        console.log('%c⚡ [Bloom Hot Reload]%c Refreshing application...', 'color:#6366F1;font-weight:bold', 'color:inherit');
        window.location.reload();
      });
      es.addEventListener('error', (e) => {
        if (e.data) console.error('[Bloom Build Error]', e.data);
      });
      es.onerror = () => {
        es.close();
        setTimeout(connect, 1000);
      };
    };
    connect();
  })();
</script>
''';

  BloomLiveReloadServer({
    required this.webDir,
    this.host = '0.0.0.0',
    this.port = 8080,
    this.autoInjectScript = true,
  });

  HttpServer? get server => _server;
  int get activeClientCount => _sseClients.length;

  Future<void> start() async {
    _server = await HttpServer.bind(host, port);
    _server!.listen(_handleRequest);
  }

  void broadcastReload({String? reason}) {
    final payload = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (reason != null) 'reason': reason,
    });

    final data = 'event: reload\ndata: $payload\n\n';
    _broadcast(data);
  }

  void broadcastError(String errorMessage) {
    final payload = jsonEncode({'message': errorMessage});
    final data = 'event: error\ndata: $payload\n\n';
    _broadcast(data);
  }

  void _broadcast(String sseMessage) {
    final deadClients = <HttpResponse>[];
    for (final client in _sseClients) {
      try {
        client.write(sseMessage);
        unawaited(client.flush());
      } catch (_) {
        deadClients.add(client);
      }
    }
    _sseClients.removeWhere(deadClients.contains);
  }

  Future<void> stop() async {
    for (final client in _sseClients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _sseClients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  void _handleRequest(HttpRequest req) async {
    final path = req.uri.path;

    // 1. SSE Live Reload Stream
    if (path == '/_bloom_hr') {
      req.response.bufferOutput = false;
      req.response.headers
        ..set(HttpHeaders.contentTypeHeader, 'text/event-stream')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache')
        ..set(HttpHeaders.connectionHeader, 'keep-alive')
        ..set('Access-Control-Allow-Origin', '*');

      _sseClients.add(req.response);
      return;
    }

    try {
      var reqPath = path.startsWith('/') ? path.substring(1) : path;
      if (reqPath.isEmpty) reqPath = 'index.html';

      var targetPath = p.canonicalize(p.join(webDir.path, reqPath));

      if (p.isWithin(webDir.path, targetPath) || targetPath == p.canonicalize(webDir.path)) {
        var targetFile = File(targetPath);
        if (targetFile.existsSync() && !FileSystemEntity.isDirectorySync(targetFile.path)) {
          final ext = p.extension(targetFile.path).replaceAll('.', '').toLowerCase();
          req.response.headers.set(HttpHeaders.contentTypeHeader, _getContentType(ext));
          req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

          if (ext == 'html' && autoInjectScript) {
            var html = targetFile.readAsStringSync();
            if (!html.contains('__BLOOM_HR_ACTIVE__')) {
              html = html.replaceFirst('</body>', '$liveReloadScript</body>');
            }
            req.response.write(html);
          } else {
            req.response.add(targetFile.readAsBytesSync());
          }
          await req.response.close();
          return;
        }

        // SPA Fallback to index.html
        final indexFile = File(p.join(webDir.path, 'index.html'));
        if (indexFile.existsSync()) {
          var html = indexFile.readAsStringSync();
          if (autoInjectScript && !html.contains('__BLOOM_HR_ACTIVE__')) {
            html = html.replaceFirst('</body>', '$liveReloadScript</body>');
          }
          req.response.headers.set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
          req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
          req.response.write(html);
          await req.response.close();
          return;
        }
      }

      req.response.statusCode = HttpStatus.notFound;
      req.response.write('404 Not Found');
      await req.response.close();
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  String _getContentType(String ext) {
    return switch (ext) {
      'html' => 'text/html; charset=utf-8',
      'js' => 'application/javascript; charset=utf-8',
      'json' => 'application/json; charset=utf-8',
      'css' => 'text/css; charset=utf-8',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'svg' => 'image/svg+xml',
      'ico' => 'image/x-icon',
      'woff2' => 'font/woff2',
      'woff' => 'font/woff',
      _ => 'application/octet-stream',
    };
  }
}
