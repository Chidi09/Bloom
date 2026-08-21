# Bloom Hot Reload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a zero-configuration, sub-second unified Hot Reload & Live Sync engine across Bloom JS Native Web and Bloom Server in `bloom_cli`.

**Architecture:** Implement `BloomSourceWatcher` (debounced file observer), `BloomLiveReloadServer` (SSE broadcast server with dynamic script injection), and `BloomServerSupervisor` (rapid sub-isolate lifecycle daemon) inside `packages/bloom_cli/lib/src/dev/`.

**Tech Stack:** Dart 3.5+, `package:bloom_cli`, `package:watcher`, `dart:io`, Server-Sent Events (SSE), `Isolate.spawnUri`.

**Spec:** [`docs/superpowers/specs/2026-08-21-bloom-hot-reload-design.md`](file:///root/dev/Bloom/docs/superpowers/specs/2026-08-21-bloom-hot-reload-design.md)

## Global Constraints

- 100% Pure Dart VM implementation without external runtime binaries.
- Strict 0-error, 0-warning rule on `dart analyze`.
- Automated tests for SSE broadcasting, file watch debouncing, and script auto-injection.

---

### Task 1: Implement `BloomSourceWatcher` (Debounced Recursive File Observer)

**Files:**
- Create: `packages/bloom_cli/lib/src/dev/source_watcher.dart`
- Test: `packages/bloom_cli/test/dev/source_watcher_test.dart`

**Interfaces:**
- Produces: `class BloomSourceWatcher` with `Stream<List<FileSystemEvent>> onChange` and `void dispose()`.

- [ ] **Step 1: Write the failing unit test**

```dart
// packages/bloom_cli/test/dev/source_watcher_test.dart
import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:bloom_cli/src/dev/source_watcher.dart';

void main() {
  group('BloomSourceWatcher', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bloom_watch_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('debounces rapid file modifications into a single event', () async {
      final watcher = BloomSourceWatcher(
        directories: [tempDir],
        debounceDuration: const Duration(milliseconds: 50),
      );

      final events = <List<FileSystemEvent>>[];
      final sub = watcher.onChange.listen(events.add);

      final testFile = File('${tempDir.path}/test.dart');
      await testFile.writeAsString('void main() {}');
      await testFile.writeAsString('void main() { print(1); }');
      await testFile.writeAsString('void main() { print(2); }');

      await Future.delayed(const Duration(milliseconds: 150));
      expect(events.length, 1);

      await sub.cancel();
      watcher.dispose();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/bloom_cli && dart test test/dev/source_watcher_test.dart`  
Expected: FAIL (file not found / class not defined)

- [ ] **Step 3: Implement `BloomSourceWatcher`**

```dart
// packages/bloom_cli/lib/src/dev/source_watcher.dart
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

class BloomSourceWatcher {
  final List<Directory> directories;
  final Duration debounceDuration;
  final List<String> extensions;
  final List<String> ignorePatterns;

  final StreamController<List<FileSystemEvent>> _controller =
      StreamController<List<FileSystemEvent>>.broadcast();

  final List<StreamSubscription> _subscriptions = [];
  Timer? _debounceTimer;
  final List<FileSystemEvent> _pendingEvents = [];

  BloomSourceWatcher({
    required this.directories,
    this.debounceDuration = const Duration(milliseconds: 150),
    this.extensions = const ['.dart', '.html', '.css', '.yaml', '.json'],
    this.ignorePatterns = const ['.git', '.dart_tool', 'build', '.tmp'],
  }) {
    _startWatching();
  }

  Stream<List<FileSystemEvent>> get onChange => _controller.stream;

  void _startWatching() {
    for (final dir in directories) {
      if (!dir.existsSync()) continue;

      final sub = dir.watch(recursive: true).listen((event) {
        final path = event.path;

        // Check ignore patterns
        for (final pattern in ignorePatterns) {
          if (path.contains(pattern)) return;
        }

        // Check file extension
        final ext = p.extension(path).toLowerCase();
        if (extensions.isNotEmpty && !extensions.contains(ext)) return;

        _pendingEvents.add(event);

        _debounceTimer?.cancel();
        _debounceTimer = Timer(debounceDuration, () {
          if (_pendingEvents.isNotEmpty) {
            _controller.add(List.from(_pendingEvents));
            _pendingEvents.clear();
          }
        });
      });

      _subscriptions.add(sub);
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _controller.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_cli && dart test test/dev/source_watcher_test.dart`  
Expected: PASS

---

### Task 2: Implement `BloomLiveReloadServer` (SSE Engine & Auto-Injector)

**Files:**
- Create: `packages/bloom_cli/lib/src/dev/live_reload_server.dart`
- Test: `packages/bloom_cli/test/dev/live_reload_server_test.dart`

**Interfaces:**
- Consumes: `BloomSourceWatcher`
- Produces: `class BloomLiveReloadServer` with `Future<void> start()`, `void broadcastReload()`, `void broadcastError(String msg)`, `Future<void> stop()`.

- [ ] **Step 1: Write the failing unit test**

```dart
// packages/bloom_cli/test/dev/live_reload_server_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:bloom_cli/src/dev/live_reload_server.dart';

void main() {
  group('BloomLiveReloadServer', () {
    late Directory tempWebDir;
    late BloomLiveReloadServer devServer;
    late int testPort;

    setUp(() async {
      tempWebDir = await Directory.systemTemp.createTemp('bloom_web_test_');
      final indexHtml = File('${tempWebDir.path}/index.html');
      await indexHtml.writeAsString('<!DOCTYPE html><html><body><h1>Hello Bloom</h1></body></html>');

      testPort = 9876;
      devServer = BloomLiveReloadServer(
        webDir: tempWebDir,
        host: '127.0.0.1',
        port: testPort,
      );
      await devServer.start();
    });

    tearDown(() async {
      await devServer.stop();
      if (tempWebDir.existsSync()) {
        await tempWebDir.delete(recursive: true);
      }
    });

    test('serves index.html with live reload script automatically injected', () async {
      final client = HttpClient();
      final req = await client.get('127.0.0.1', testPort, '/');
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 200);
      expect(body, contains('__BLOOM_HR_ACTIVE__'));
      expect(body, contains('EventSource(\'/_bloom_hr\')'));
      client.close();
    });

    test('establishes SSE stream on /_bloom_hr and receives broadcast', () async {
      final client = HttpClient();
      final req = await client.get('127.0.0.1', testPort, '/_bloom_hr');
      final res = await req.close();

      expect(res.statusCode, 200);
      expect(res.headers.value('content-type'), contains('text/event-stream'));

      final firstChunkFuture = utf8.decodeStream(res.take(1));
      devServer.broadcastReload(reason: 'header.dart');

      final chunk = await firstChunkFuture;
      expect(chunk, contains('event: reload'));
      expect(chunk, contains('header.dart'));
      client.close();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/bloom_cli && dart test test/dev/live_reload_server_test.dart`  
Expected: FAIL (class not defined)

- [ ] **Step 3: Implement `BloomLiveReloadServer`**

```dart
// packages/bloom_cli/lib/src/dev/live_reload_server.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_cli && dart test test/dev/live_reload_server_test.dart`  
Expected: PASS

---

### Task 3: Integrate Hot Reload into `bloom js dev` and `bloom dev`

**Files:**
- Modify: `packages/bloom_cli/lib/src/commands/js_command.dart`
- Modify: `packages/bloom_cli/lib/src/commands/dev_command.dart`

**Interfaces:**
- Consumes: `BloomSourceWatcher`, `BloomLiveReloadServer`
- Produces: CLI commands `bloom js dev` and `bloom dev` with unified live reload.

- [ ] **Step 1: Connect `JsDevCommand` to `BloomLiveReloadServer` & `BloomSourceWatcher`**
- [ ] **Step 2: Connect `DevCommand` to supervise backend server and web client concurrently**
- [ ] **Step 3: Run `dart analyze` across `packages/bloom_cli` to verify 0 errors and 0 warnings**

---

### Task 4: End-to-End Verification & Demonstration

**Files:**
- Test: `examples/bloom_todo/apps/web/`
- Test: `examples/bloom_todo/apps/server/`

- [ ] **Step 1: Test `bloom js dev` in `examples/bloom_todo/apps/web`**
- [ ] **Step 2: Trigger a simulated change in `lib/views/header.dart` and confirm SSE `reload` broadcast**
- [ ] **Step 3: Run full monorepo analysis gate**
