// lib/src/web/prerender_engine.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import '../utils/ansi.dart';

/// Real Headless Chromium Prerendering Engine for Bloom Web Applications.
///
/// Drives a headless Chromium browser to render routes against the compiled
/// Flutter web application, waiting for [window.__BLOOM_PRERENDER_READY__]
/// and capturing the rendered DOM.
class BloomPrerenderEngine {
  Browser? _browser;
  HttpServer? _staticServer;
  late final String _baseUrl;

  /// Returns whether the headless Chromium browser is currently active.
  bool get isBrowserRunning => _browser != null;

  /// Starts headless Chromium without a local static server or base URL.
  Future<void> startBrowserOnly() async {
    await _launchBrowser();
  }

  /// Starts an engine that serves [buildWebDir] itself via a local static file server.
  Future<void> startWithStaticDir(Directory buildWebDir) async {
    try {
      _staticServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _baseUrl = 'http://localhost:${_staticServer!.port}';

      _staticServer!.listen((HttpRequest req) async {
        try {
          var reqPath = req.uri.path;
          if (reqPath.startsWith('/')) reqPath = reqPath.substring(1);
          if (reqPath.isEmpty) reqPath = 'index.html';

          var targetPath = p.canonicalize(p.join(buildWebDir.path, reqPath));

          if (p.isWithin(buildWebDir.path, targetPath) || targetPath == p.canonicalize(buildWebDir.path)) {
            var targetFile = File(targetPath);
            if (targetFile.existsSync() && !FileSystemEntity.isDirectorySync(targetFile.path)) {
              final bytes = targetFile.readAsBytesSync();
              final ext = targetFile.path.split('.').last.toLowerCase();
              final contentType = _getContentType(ext);
              req.response.headers.set(HttpHeaders.contentTypeHeader, contentType);
              req.response.add(bytes);
              await req.response.close();
              return;
            }

            final indexFile = File(p.join(buildWebDir.path, 'index.html'));
            if (indexFile.existsSync()) {
              final bytes = indexFile.readAsBytesSync();
              req.response.headers.set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
              req.response.add(bytes);
              await req.response.close();
              return;
            }
          }

          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        } catch (e) {
          try {
            req.response.statusCode = HttpStatus.internalServerError;
            await req.response.close();
          } catch (_) {}
        }
      });
    } catch (e) {
      print(Ansi.warn('  ⚠ Notice: Failed to start static file server for prerendering: $e'));
    }

    await _launchBrowser();
  }

  /// Starts an engine that renders against an already-running server at [baseUrl].
  Future<void> startWithExistingServer(String baseUrl) async {
    _baseUrl = baseUrl;
    await _launchBrowser();
  }

  Future<void> _launchBrowser() async {
    try {
      _browser = await puppeteer.launch(
        headless: true,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
        ],
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print(Ansi.warn('  ⚠ Notice: Headless Chromium prerendering unavailable ($e). Falling back to shell-template output.'));
      _browser = null;
    }
  }

  /// Renders standalone [svgContent] into PNG bytes of [width] x [height].
  ///
  /// Returns null on any failure (browser uninitialized, Chromium error, etc.),
  /// allowing callers to fall back gracefully without failing builds.
  Future<Uint8List?> renderSvgToPng(
    String svgContent, {
    required int width,
    required int height,
    bool omitBackground = true,
  }) async {
    if (_browser == null) return null;

    Page? page;
    try {
      page = await _browser!.newPage();
      await page.setViewport(DeviceViewport(width: width, height: height));

      final html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
    svg { display: block; width: 100%; height: 100%; }
  </style>
</head>
<body>$svgContent</body>
</html>
''';

      await page.setContent(html, wait: Until.load);
      final bytes = await page.screenshot(
        omitBackground: omitBackground,
      );
      return bytes;
    } catch (e) {
      return null;
    } finally {
      if (page != null) {
        try {
          await page.close();
        } catch (_) {}
      }
    }
  }

  /// Navigates to [routePath] (e.g. '/products/1'), waits for
  /// `window.__BLOOM_PRERENDER_READY__ === true`, and returns the captured
  /// `document.documentElement.outerHTML`. Returns null on any failure
  /// (browser launch failure, navigation timeout, Chromium unavailable) —
  /// callers MUST treat null as "fall back to the old fake-shell template",
  /// never as a fatal error.
  Future<String?> renderRoute(
    String routePath, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_browser == null) return null;

    Page? page;
    try {
      page = await _browser!.newPage();

      final cleanPath = routePath.startsWith('/') ? routePath : '/$routePath';
      final targetUrl = '$_baseUrl$cleanPath';

      final response = await page.goto(targetUrl, wait: Until.load).timeout(timeout);
      if (!response.ok) {
        // A non-2xx navigation response (e.g. 404, because build/web has no
        // compiled app yet, or this specific route has nothing to serve)
        // means there is no real content to capture. Fall back rather than
        // returning whatever generic error/decoy markup got served.
        return null;
      }

      try {
        await page.waitForFunction(
          '() => window.__BLOOM_PRERENDER_READY__ === true',
          timeout: timeout,
        );
      } catch (_) {
        // On timeout, still attempt to capture document.documentElement.outerHTML anyway (best-effort partial capture)
      }

      final result = await page.evaluate('() => document.documentElement.outerHTML');
      return result?.toString();
    } catch (e) {
      return null;
    } finally {
      if (page != null) {
        try {
          await page.close();
        } catch (_) {}
      }
    }
  }

  /// Closes the browser instance and any running static file server.
  Future<void> close() async {
    if (_browser != null) {
      try {
        await _browser!.close();
      } catch (_) {}
      _browser = null;
    }
    if (_staticServer != null) {
      try {
        await _staticServer!.close(force: true);
      } catch (_) {}
      _staticServer = null;
    }
  }

  static String _getContentType(String extension) {
    switch (extension) {
      case 'html': return 'text/html; charset=utf-8';
      case 'js': return 'application/javascript; charset=utf-8';
      case 'css': return 'text/css; charset=utf-8';
      case 'json': return 'application/json; charset=utf-8';
      case 'png': return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'svg': return 'image/svg+xml';
      case 'wasm': return 'application/wasm';
      default: return 'application/octet-stream';
    }
  }
}
