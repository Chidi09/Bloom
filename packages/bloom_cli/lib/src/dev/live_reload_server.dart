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

    const NS = 'http://www.w3.org/2000/svg';
    const bloomMarkPaths = [
      ['M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z', '#pf_pink'],
      ['M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z', '#pf_orange'],
      ['M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z', '#pf_cyan'],
      ['M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z', '#pf_blue'],
      ['M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z', '#pf_purple'],
    ];

    function svgEl(tag, attrs) {
      const el = document.createElementNS(NS, tag);
      for (const k in attrs) el.setAttribute(k, attrs[k]);
      return el;
    }

    function buildBloomMark(size) {
      const svg = svgEl('svg', { viewBox: '0 0 200 200', width: size, height: size, fill: 'none' });
      const defs = svgEl('defs', {});
      const grads = [
        ['pf_pink', '100', '20', '100', '100', '#FF4B8B', '#FF8BA7'],
        ['pf_orange', '180', '80', '110', '110', '#FF884D', '#FFA066'],
        ['pf_cyan', '140', '175', '100', '115', '#20C9B0', '#48E5C8'],
        ['pf_blue', '60', '175', '100', '115', '#2563EB', '#60A5FA'],
        ['pf_purple', '20', '80', '90', '110', '#8B5CF6', '#A855F7'],
      ];
      for (const [id, x1, y1, x2, y2, c1, c2] of grads) {
        const g = svgEl('linearGradient', { id, x1, y1, x2, y2 });
        const s1 = svgEl('stop', { 'stop-color': c1 });
        const s2 = svgEl('stop', { offset: '1', 'stop-color': c2 });
        g.appendChild(s1); g.appendChild(s2);
        defs.appendChild(g);
      }
      svg.appendChild(defs);
      for (const [d, fillRef] of bloomMarkPaths) {
        svg.appendChild(svgEl('path', { d, fill: 'url(' + fillRef + ')', opacity: '0.9' }));
      }
      svg.appendChild(svgEl('path', {
        d: 'M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z',
        fill: '#FFFFFF',
      }));
      return svg;
    }

    function mountDevTools() {
      const root = document.createElement('div');
      root.setAttribute('data-bloom-devtools', 'true');
      root.style.cssText = 'position:fixed;left:16px;bottom:16px;z-index:2147483647;font-family:ui-monospace,SFMono-Regular,Consolas,Menlo,monospace;';

      const badge = document.createElement('button');
      badge.setAttribute('aria-label', 'Bloom dev tools');
      badge.style.cssText = 'width:40px;height:40px;border-radius:999px;border:1px solid rgba(255,255,255,0.12);background:#18181b;box-shadow:0 4px 16px rgba(0,0,0,0.4);display:flex;align-items:center;justify-content:center;cursor:pointer;padding:0;transition:transform 160ms ease, box-shadow 160ms ease;';
      const mark = buildBloomMark(22);
      mark.style.transition = 'transform 500ms cubic-bezier(0.4,0,0.2,1)';
      badge.appendChild(mark);
      badge.onmouseenter = () => { badge.style.transform = 'scale(1.08)'; };
      badge.onmouseleave = () => { badge.style.transform = 'scale(1)'; };

      const statusDot = document.createElement('span');
      statusDot.style.cssText = 'position:absolute;width:9px;height:9px;border-radius:999px;background:#3fb950;border:2px solid #18181b;transform:translate(13px,-13px);transition:background 200ms ease;';
      const badgeWrap = document.createElement('div');
      badgeWrap.style.cssText = 'position:relative;';
      badgeWrap.appendChild(badge);
      badgeWrap.appendChild(statusDot);

      const panel = document.createElement('div');
      panel.style.cssText = 'display:none;position:absolute;left:0;bottom:52px;min-width:220px;background:#18181b;border:1px solid rgba(255,255,255,0.1);border-radius:10px;box-shadow:0 8px 30px rgba(0,0,0,0.5);padding:12px;color:#e4e4e7;font-size:12px;';

      function row(label, value) {
        const r = document.createElement('div');
        r.style.cssText = 'display:flex;justify-content:space-between;gap:16px;padding:3px 0;';
        const l = document.createElement('span');
        l.textContent = label;
        l.style.color = '#a1a1aa';
        const v = document.createElement('span');
        v.textContent = value;
        v.style.fontWeight = '600';
        r.appendChild(l); r.appendChild(v);
        return r;
      }

      const title = document.createElement('div');
      title.style.cssText = 'font-weight:700;font-size:13px;margin-bottom:8px;display:flex;align-items:center;gap:6px;';
      title.appendChild(buildBloomMark(14));
      const titleText = document.createElement('span');
      titleText.textContent = 'Bloom Dev Tools';
      title.appendChild(titleText);
      panel.appendChild(title);

      const routeRow = row('Route', location.pathname);
      const statusRow = row('Live reload', 'connected');
      const reloadsRow = row('Reloads', '0');
      panel.appendChild(routeRow);
      panel.appendChild(statusRow);
      panel.appendChild(reloadsRow);

      let open = false;
      badge.onclick = () => {
        open = !open;
        panel.style.display = open ? 'block' : 'none';
      };

      root.appendChild(panel);
      root.appendChild(badgeWrap);
      document.body.appendChild(root);

      let reloadCount = 0;

      return {
        setStatus(connected) {
          statusDot.style.background = connected ? '#3fb950' : '#f85149';
          statusRow.lastChild.textContent = connected ? 'connected' : 'reconnecting…';
        },
        showRefreshing() {
          reloadCount += 1;
          reloadsRow.lastChild.textContent = String(reloadCount);
          mark.style.transform = 'rotate(360deg)';
          badge.style.boxShadow = '0 0 0 3px rgba(99,102,241,0.45), 0 4px 16px rgba(0,0,0,0.4)';
        },
      };
    }

    const devtools = document.readyState === 'loading'
      ? null
      : mountDevTools();
    function ensureDevtools() {
      return devtools || mountDevTools();
    }
    let dt = devtools;
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => { dt = ensureDevtools(); });
    }

    const connect = () => {
      const es = new EventSource('/_bloom_hr');
      es.addEventListener('open', () => { if (dt) dt.setStatus(true); });
      es.addEventListener('reload', (e) => {
        console.log('%c⚡ [Bloom Hot Reload]%c Refreshing application...', 'color:#6366F1;font-weight:bold', 'color:inherit');
        if (dt) dt.showRefreshing();
        setTimeout(() => window.location.reload(), 280);
      });
      es.addEventListener('error', (e) => {
        if (e.data) console.error('[Bloom Build Error]', e.data);
      });
      es.onerror = () => {
        if (dt) dt.setStatus(false);
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
