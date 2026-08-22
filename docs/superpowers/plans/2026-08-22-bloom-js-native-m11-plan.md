# Bloom JS Native M11 — HTTP Tests, Server Supervisor, Animations, Forms & Realtime Bindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all remaining gaps across the Bloom stack: add `BloomHttpClient` test coverage, implement `BloomServerSupervisor` for <80ms server hot-reload, add `BloomAnimate` CSS animation bindings, implement `BloomForm` reactive form management, and add `BloomRealtimeBinding` reactive WebSocket signal bindings to `bloom_js_native`.

**Architecture:**
- Tasks 1–2 close existing gaps in `bloom_js_native` and `bloom_cli`.
- Tasks 3–5 are new pure-Dart subsystems added to `bloom_js_native` (zero Flutter deps, zero `dart:js_interop` in pure logic files).
- All reactive wiring uses `package:signals ^5.5.0` signals and effects — the same pattern used throughout M8–M10.
- `BloomRealtimeBinding` wraps `BloomRealtimeClient` from `package:bloom_realtime` with signal-backed reactive state.

**Tech Stack:** Dart 3.4+, `package:signals ^5.5.0`, `package:http ^1.2.0` (with `http/testing.dart` for mocks), `package:web ^1.1.0`, `package:bloom_realtime` (monorepo path dep).

**Spec:** `docs/superpowers/specs/2026-08-21-bloom-hot-reload-design.md`, `docs/superpowers/specs/2026-08-21-bloom-js-cli-and-keyed-reconciliation-design.md`, plus this plan's inline specs for Tasks 3–5.

## Global Constraints
- `dart analyze packages/bloom_js_native packages/bloom_cli` must produce **0 errors, 0 warnings** after every task.
- All tests pass: `cd packages/bloom_js_native && dart test` and `cd packages/bloom_cli && dart test`.
- No Flutter SDK imports (`package:flutter/...`) anywhere in `bloom_js_native`.
- No `dart:js_interop` or `package:web` in pure-Dart logic files (files outside `mount.dart` / `browser.dart`).
- Do NOT use `cat << EOF` shell heredocs — use `write_to_file` or `replace_file_content` directly.
- Commit after every task with `feat(...)` or `fix(...)` prefix.

---

### Task 1: BloomHttpClient Test Suite

**Files:**
- Modify: `packages/bloom_js_native/pubspec.yaml` (add `http: ^1.2.0` to `dev_dependencies` for `MockClient` access)
- Create: `packages/bloom_js_native/test/http_test.dart`

**Interfaces:**
- Consumes: `BloomHttpClient` from `lib/src/http.dart` — constructor `BloomHttpClient({String? baseUrl, http.Client? innerClient, Duration timeout, String? authToken, String? Function()? authTokenProvider})`, methods `get<T>`, `post<T>`, `put<T>`, `patch<T>`, `delete<T>`, `close()`, lists `requestInterceptors`, `responseInterceptors`.
- Consumes: `BloomEnv` from `lib/src/env.dart` — `BloomEnv.loadMap({...})`, `BloomEnv.clear()`.
- Consumes: `http.MockClient` from `package:http/testing.dart`.
- Produces: complete test coverage so executors can trust `BloomHttpClient` contracts.

- [ ] **Step 1: Add `http` to dev_dependencies in pubspec.yaml**

In `packages/bloom_js_native/pubspec.yaml`, change:
```yaml
dev_dependencies:
  lints: ^5.0.0
  test: ^1.25.0
```
to:
```yaml
dev_dependencies:
  lints: ^5.0.0
  test: ^1.25.0
  http: ^1.2.0
```
Then run:
```bash
cd packages/bloom_js_native && dart pub get
```

- [ ] **Step 2: Write the full test file**

Create `packages/bloom_js_native/test/http_test.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  setUp(() => BloomEnv.clear());

  group('BloomHttpClient — constructor', () {
    test('reads API_BASE_URL from BloomEnv when no explicit baseUrl', () {
      BloomEnv.loadMap({'API_BASE_URL': 'https://api.example.com'});
      final client = BloomHttpClient(
        innerClient: MockClient((_) async => http.Response('null', 200)),
      );
      expect(client.baseUrl, 'https://api.example.com');
      client.close();
    });

    test('explicit baseUrl overrides BloomEnv', () {
      BloomEnv.loadMap({'API_BASE_URL': 'https://should.be.ignored'});
      final client = BloomHttpClient(
        baseUrl: 'https://explicit.example.com',
        innerClient: MockClient((_) async => http.Response('null', 200)),
      );
      expect(client.baseUrl, 'https://explicit.example.com');
      client.close();
    });

    test('baseUrl is null when no env var and no explicit value', () {
      final client = BloomHttpClient(
        innerClient: MockClient((_) async => http.Response('null', 200)),
      );
      expect(client.baseUrl, isNull);
      client.close();
    });
  });

  group('BloomHttpClient — HTTP verbs', () {
    late BloomHttpClient client;
    late List<http.BaseRequest> captured;

    setUp(() {
      captured = [];
      client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient: MockClient((req) async {
          captured.add(req);
          return http.Response(jsonEncode({'ok': true}), 200,
              headers: {'content-type': 'application/json'});
        }),
      );
    });

    tearDown(() => client.close());

    test('get<T> sends GET to resolved path', () async {
      final result = await client.get<Map<String, dynamic>>('/items');
      expect(result, {'ok': true});
      expect(captured.single.method, 'GET');
      expect(captured.single.url.path, '/items');
    });

    test('post<T> sends POST with JSON body', () async {
      await client.post<Map<String, dynamic>>('/items', body: {'name': 'widget'});
      expect(captured.single.method, 'POST');
      final sent = captured.single as http.Request;
      expect(jsonDecode(sent.body), {'name': 'widget'});
    });

    test('put<T> sends PUT', () async {
      await client.put<Map<String, dynamic>>('/items/1', body: {'name': 'updated'});
      expect(captured.single.method, 'PUT');
    });

    test('patch<T> sends PATCH', () async {
      await client.patch<Map<String, dynamic>>('/items/1', body: {'name': 'patched'});
      expect(captured.single.method, 'PATCH');
    });

    test('delete<T> sends DELETE', () async {
      await client.delete<Map<String, dynamic>>('/items/1');
      expect(captured.single.method, 'DELETE');
    });

    test('query parameters are appended to URL', () async {
      await client.get<Map<String, dynamic>>('/search',
          queryParameters: {'q': 'dart', 'page': 2});
      final uri = captured.single.url;
      expect(uri.queryParameters['q'], 'dart');
      expect(uri.queryParameters['page'], '2');
    });

    test('absolute URL bypasses baseUrl', () async {
      await client.get<Map<String, dynamic>>('https://other.host.com/data');
      expect(captured.single.url.host, 'other.host.com');
    });
  });

  group('BloomHttpClient — auth token', () {
    test('static authToken injected as Bearer header', () async {
      final captured = <http.BaseRequest>[];
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        authToken: 'my-secret-token',
        innerClient: MockClient((req) async {
          captured.add(req);
          return http.Response('null', 200);
        }),
      );
      await client.get<dynamic>('/secure');
      expect(captured.single.headers['Authorization'], 'Bearer my-secret-token');
      client.close();
    });

    test('authTokenProvider called per request', () async {
      int callCount = 0;
      final captured = <http.BaseRequest>[];
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () {
          callCount++;
          return 'dynamic-token-$callCount';
        },
        innerClient: MockClient((req) async {
          captured.add(req);
          return http.Response('null', 200);
        }),
      );
      await client.get<dynamic>('/a');
      await client.get<dynamic>('/b');
      expect(captured[0].headers['Authorization'], 'Bearer dynamic-token-1');
      expect(captured[1].headers['Authorization'], 'Bearer dynamic-token-2');
      client.close();
    });
  });

  group('BloomHttpClient — interceptors', () {
    test('requestInterceptor can mutate headers', () async {
      final captured = <http.BaseRequest>[];
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient: MockClient((req) async {
          captured.add(req);
          return http.Response('null', 200);
        }),
      );
      client.requestInterceptors.add((req) {
        req.headers['X-Custom'] = 'injected';
        return req;
      });
      await client.get<dynamic>('/');
      expect(captured.single.headers['X-Custom'], 'injected');
      client.close();
    });

    test('responseInterceptor can transform response', () async {
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient: MockClient(
            (_) async => http.Response(jsonEncode({'v': 1}), 200)),
      );
      client.responseInterceptors.add((resp) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        body['intercepted'] = true;
        return http.Response(jsonEncode(body), resp.statusCode,
            headers: resp.headers);
      });
      final result = await client.get<Map<String, dynamic>>('/data');
      expect(result['intercepted'], isTrue);
      client.close();
    });
  });

  group('BloomHttpClient — error handling', () {
    test('throws ClientException on 4xx status', () async {
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient:
            MockClient((_) async => http.Response('{"error":"not found"}', 404)),
      );
      expect(() => client.get<dynamic>('/missing'),
          throwsA(isA<http.ClientException>()));
      client.close();
    });

    test('throws ClientException on 5xx status', () async {
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient:
            MockClient((_) async => http.Response('server error', 500)),
      );
      expect(() => client.get<dynamic>('/crash'),
          throwsA(isA<http.ClientException>()));
      client.close();
    });

    test('returns null for empty 2xx response', () async {
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient: MockClient((_) async => http.Response('', 204)),
      );
      final result = await client.get<dynamic>('/empty');
      expect(result, isNull);
      client.close();
    });

    test('throws StateError for relative path without baseUrl', () {
      final client = BloomHttpClient(
        innerClient: MockClient((_) async => http.Response('null', 200)),
      );
      expect(() => client.get<dynamic>('/no-base'), throwsA(isA<StateError>()));
      client.close();
    });
  });
}
```

- [ ] **Step 3: Run the tests**

```bash
cd packages/bloom_js_native && dart test test/http_test.dart --reporter expanded
```
Expected: All tests pass.

- [ ] **Step 4: Run full suite + analyzer**

```bash
cd packages/bloom_js_native && dart test --reporter compact && dart analyze lib/
```
Expected: All tests pass, 0 issues.

- [ ] **Step 5: Commit**

```bash
cd /root/dev/Bloom && git add packages/bloom_js_native/ && git commit -m "test(bloom_js_native): add comprehensive BloomHttpClient test suite"
```

---

### Task 2: BloomServerSupervisor — Backend Isolate Hot-Reload

**Files:**
- Create: `packages/bloom_cli/lib/src/dev/server_supervisor.dart`
- Modify: `packages/bloom_cli/lib/src/commands/js_command.dart`
- Create: `packages/bloom_cli/test/server_supervisor_test.dart`

**Interfaces:**
- Produces: `BloomServerSupervisor({required File entryFile, List<String> args, Duration restartDebounce})`, methods `Future<void> start()`, `Future<void> restart({String? reason})`, `Future<void> stop()`, getters `bool isRunning`, `int? currentPid`, `Stream<String> onOutput`.
- Consumes: `BloomSourceWatcher` from `lib/src/dev/source_watcher.dart` — `BloomSourceWatcher({required List<Directory> directories, Duration debounceDuration})`, `Stream<List<FileSystemEvent>> onChange`.

- [ ] **Step 1: Write failing tests**

Create `packages/bloom_cli/test/server_supervisor_test.dart`:

```dart
import 'dart:io';
import 'package:test/test.dart';
import 'package:bloom_cli/src/dev/server_supervisor.dart';

void main() {
  group('BloomServerSupervisor', () {
    late File entryFile;

    setUp(() async {
      entryFile = File('${Directory.systemTemp.path}/bloom_test_entry_${DateTime.now().millisecondsSinceEpoch}.dart');
      await entryFile.writeAsString('void main() { print("server running"); }');
    });

    tearDown(() async {
      if (await entryFile.exists()) await entryFile.delete();
    });

    test('isRunning is false before start()', () {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      expect(supervisor.isRunning, isFalse);
    });

    test('currentPid is null before start()', () {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      expect(supervisor.currentPid, isNull);
    });

    test('start() sets isRunning to true', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      await supervisor.start();
      expect(supervisor.isRunning, isTrue);
      await supervisor.stop();
    });

    test('stop() sets isRunning to false', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      await supervisor.start();
      await supervisor.stop();
      expect(supervisor.isRunning, isFalse);
    });

    test('restart() changes the process PID', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      await supervisor.start();
      final pid1 = supervisor.currentPid;
      await supervisor.restart(reason: 'file.dart');
      final pid2 = supervisor.currentPid;
      expect(pid1, isNotNull);
      expect(pid2, isNotNull);
      expect(pid1 == pid2, isFalse);
      await supervisor.stop();
    });

    test('onOutput stream receives stdout', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      final output = <String>[];
      supervisor.onOutput.listen(output.add);
      await supervisor.start();
      await Future.delayed(const Duration(milliseconds: 400));
      await supervisor.stop();
      expect(output.any((l) => l.contains('server running')), isTrue);
    });

    test('double stop() is idempotent', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      await supervisor.start();
      await supervisor.stop();
      expect(() => supervisor.stop(), returnsNormally);
    });
  });
}
```

- [ ] **Step 2: Run failing tests**

```bash
cd packages/bloom_cli && dart test test/server_supervisor_test.dart 2>&1 | head -10
```
Expected: FAIL with import error (file not created yet).

- [ ] **Step 3: Implement BloomServerSupervisor**

Create `packages/bloom_cli/lib/src/dev/server_supervisor.dart`:

```dart
// lib/src/dev/server_supervisor.dart
import 'dart:async';
import 'dart:io';

/// Supervised Dart process manager for Bloom server backends.
/// Provides <80ms restart times by killing and re-spawning the child process
/// rather than waiting for a graceful shutdown sequence.
class BloomServerSupervisor {
  /// Dart entry file executed as `dart run <entryFile>`.
  final File entryFile;

  /// Additional arguments forwarded to the subprocess.
  final List<String> args;

  /// Minimum time to wait after kill before re-spawning. Defaults to 80ms.
  final Duration restartDebounce;

  Process? _process;
  bool _stopped = false;
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();

  BloomServerSupervisor({
    required this.entryFile,
    this.args = const [],
    this.restartDebounce = const Duration(milliseconds: 80),
  });

  /// Whether a supervised process is currently running.
  bool get isRunning => _process != null && !_stopped;

  /// PID of the current supervised process, or `null` if not running.
  int? get currentPid => _process?.pid;

  /// Broadcast stream of combined stdout+stderr lines from the supervised process.
  Stream<String> get onOutput => _outputController.stream;

  /// Starts the supervised server process.
  Future<void> start() async {
    _stopped = false;
    _process = await Process.start(
      'dart',
      ['run', entryFile.path, ...args],
      runInShell: false,
    );
    _process!.stdout
        .transform(const SystemEncoding().decoder)
        .listen(_outputController.add);
    _process!.stderr
        .transform(const SystemEncoding().decoder)
        .listen(_outputController.add);
  }

  /// Kills the current process and starts a fresh one after [restartDebounce].
  Future<void> restart({String? reason}) async {
    if (_stopped) return;
    await _killCurrent();
    await Future.delayed(restartDebounce);
    await start();
  }

  /// Permanently stops the supervised process.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _killCurrent();
    if (!_outputController.isClosed) {
      await _outputController.close();
    }
  }

  Future<void> _killCurrent() async {
    final proc = _process;
    _process = null;
    if (proc != null) {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(
        const Duration(milliseconds: 200),
        onTimeout: () {
          proc.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd packages/bloom_cli && dart test test/server_supervisor_test.dart --reporter expanded
```
Expected: All 6 tests pass.

- [ ] **Step 5: Integrate supervisor into `JsDevCommand`**

Open `packages/bloom_cli/lib/src/commands/js_command.dart`. Add this import at the top after the existing imports:

```dart
import '../dev/server_supervisor.dart';
```

In `JsDevCommand.run()`, find the comment `// Keep process active` and replace everything from there to the end of the method with:

```dart
    // 6. Optional: Supervise a co-located Bloom server if bin/server.dart exists
    final serverEntry =
        File(p.join(project.rootDir.path, 'bin', 'server.dart'));
    BloomServerSupervisor? supervisor;
    if (serverEntry.existsSync()) {
      supervisor = BloomServerSupervisor(entryFile: serverEntry);
      await supervisor.start();
      supervisor.onOutput
          .listen((line) => print(Ansi.dimText('[server] $line')));
      print(Ansi.info('› Backend server supervisor active (bin/server.dart)'));

      final serverWatchDir =
          Directory(p.join(project.rootDir.path, 'lib'));
      if (serverWatchDir.existsSync()) {
        final serverWatcher = BloomSourceWatcher(
          directories: [serverWatchDir],
          debounceDuration: const Duration(milliseconds: 200),
        );
        serverWatcher.onChange.listen((events) async {
          final changed = p.basename(events.first.path);
          print(
              Ansi.info('\n🔄 Server source changed: $changed — Restarting...'));
          await supervisor!.restart(reason: changed);
          print(Ansi.success('⚡ Server restarted.'));
        });
      }
    }

    // Keep process active
    final completer = Completer<void>();
    ProcessSignal.sigint.watch().listen((_) async {
      print(Ansi.dimText('\nStopping Bloom JS dev server...'));
      await devServer.stop();
      await supervisor?.stop();
      completer.complete();
    });

    await completer.future;
    return 0;
  }
```

- [ ] **Step 6: Analyze and run all CLI tests**

```bash
cd packages/bloom_cli && dart analyze lib/ && dart test
```
Expected: 0 issues, all tests pass.

- [ ] **Step 7: Commit**

```bash
cd /root/dev/Bloom && git add packages/bloom_cli/ && git commit -m "feat(bloom_cli): add BloomServerSupervisor for <80ms backend hot-reload and integrate into bloom js dev"
```

---

### Task 3: BloomAnimate — CSS Animation Bindings

**Files:**
- Create: `packages/bloom_js_native/lib/src/animate.dart`
- Modify: `packages/bloom_js_native/lib/src/framework.dart` (add `AnimatedNode` case to `renderToHtml`)
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart` (add export)
- Create: `packages/bloom_js_native/test/animate_test.dart`

**Interfaces:**
- Produces:
  - `BloomKeyframe({required double offset, required Map<String, String> styles})` — `toCssPercent()` → `String`, `toCssBlock()` → `String`.
  - `BloomAnimation({required String name, required List<BloomKeyframe> keyframes, Duration duration, Duration delay, int iterations, String easing, String fillMode, String direction})` — `toKeyframesCSS()` → `String`, `toInlineStyle()` → `String`.
  - `AnimatedNode extends BloomNode` — `AnimatedNode({required BloomNode child, required BloomAnimation animation})`.
  - `Animated extends AnimatedNode` — `const` DSL subclass.
  - `BloomAnimationPresets` — static constants: `fadeIn`, `fadeOut`, `slideInLeft`, `slideInRight`, `scaleIn`, `pulse`.
- Consumes: `BloomNode` from `lib/src/framework.dart`.

- [ ] **Step 1: Write failing tests**

Create `packages/bloom_js_native/test/animate_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomKeyframe', () {
    test('toCssPercent for offset 0.0', () {
      const kf = BloomKeyframe(offset: 0.0, styles: {'opacity': '0'});
      expect(kf.toCssPercent(), '0%');
    });

    test('toCssPercent for offset 0.5', () {
      const kf = BloomKeyframe(offset: 0.5, styles: {'opacity': '0.5'});
      expect(kf.toCssPercent(), '50%');
    });

    test('toCssPercent for offset 1.0', () {
      const kf = BloomKeyframe(offset: 1.0, styles: {'opacity': '1'});
      expect(kf.toCssPercent(), '100%');
    });

    test('toCssBlock produces valid CSS', () {
      const kf = BloomKeyframe(
          offset: 0.0, styles: {'opacity': '0', 'transform': 'scale(0.8)'});
      final css = kf.toCssBlock();
      expect(css, startsWith('0%{'));
      expect(css, contains('opacity:0'));
    });
  });

  group('BloomAnimation', () {
    test('defaults are sensible', () {
      const anim = BloomAnimation(
        name: 'test',
        keyframes: [
          BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
          BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
        ],
      );
      expect(anim.duration, const Duration(milliseconds: 300));
      expect(anim.delay, Duration.zero);
      expect(anim.iterations, 1);
      expect(anim.easing, 'ease');
      expect(anim.fillMode, 'both');
      expect(anim.direction, 'normal');
    });

    test('toKeyframesCSS generates @keyframes block', () {
      const anim = BloomAnimation(
        name: 'fade',
        keyframes: [
          BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
          BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
        ],
      );
      final css = anim.toKeyframesCSS();
      expect(css, contains('@keyframes fade'));
      expect(css, contains('0%'));
      expect(css, contains('100%'));
      expect(css, contains('opacity:0'));
      expect(css, contains('opacity:1'));
    });

    test('toInlineStyle encodes all animation properties', () {
      const anim = BloomAnimation(
        name: 'slide',
        keyframes: [],
        duration: Duration(milliseconds: 500),
        delay: Duration(milliseconds: 100),
        iterations: 3,
        easing: 'linear',
        fillMode: 'forwards',
        direction: 'alternate',
      );
      final style = anim.toInlineStyle();
      expect(style, contains('slide'));
      expect(style, contains('500ms'));
      expect(style, contains('100ms'));
      expect(style, contains('3'));
      expect(style, contains('linear'));
      expect(style, contains('forwards'));
      expect(style, contains('alternate'));
    });

    test('infinite iterations uses "infinite" string', () {
      const anim = BloomAnimation(
          name: 'pulse', keyframes: [], iterations: -1);
      expect(anim.toInlineStyle(), contains('infinite'));
    });
  });

  group('AnimatedNode SSR', () {
    test('renderToHtml includes @keyframes and animation style', () {
      const node = Animated(
        animation: BloomAnimation(
          name: 'fade-in',
          keyframes: [
            BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
            BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
          ],
        ),
        child: Div(children: [Text('hello')]),
      );
      final html = renderToHtml(node);
      expect(html, contains('@keyframes fade-in'));
      expect(html, contains('animation:'));
      expect(html, contains('hello'));
    });

    test('identical animation names deduplicated across siblings', () {
      const anim = BloomAnimation(
        name: 'slide',
        keyframes: [
          BloomKeyframe(offset: 0.0, styles: {'transform': 'translateX(-100%)'}),
          BloomKeyframe(offset: 1.0, styles: {'transform': 'translateX(0)'}),
        ],
      );
      const tree = Div(children: [
        Animated(animation: anim, child: Span(text: 'a')),
        Animated(animation: anim, child: Span(text: 'b')),
      ]);
      final html = renderToHtml(tree);
      expect('@keyframes slide'.allMatches(html).length, 1);
    });
  });

  group('BloomAnimationPresets', () {
    test('fadeIn name is bloom-fade-in', () {
      expect(BloomAnimationPresets.fadeIn.name, 'bloom-fade-in');
    });

    test('fadeIn has exactly 2 keyframes', () {
      expect(BloomAnimationPresets.fadeIn.keyframes.length, 2);
    });

    test('fadeOut goes from opacity 1 to 0', () {
      expect(BloomAnimationPresets.fadeOut.keyframes.first.styles['opacity'], '1');
      expect(BloomAnimationPresets.fadeOut.keyframes.last.styles['opacity'], '0');
    });

    test('slideInLeft has transform in keyframes', () {
      expect(BloomAnimationPresets.slideInLeft.keyframes.first.styles,
          containsPair('transform', anything));
    });

    test('scaleIn has scale in keyframes', () {
      expect(BloomAnimationPresets.scaleIn.keyframes.first.styles['transform'],
          contains('scale'));
    });

    test('pulse has 3 keyframes', () {
      expect(BloomAnimationPresets.pulse.keyframes.length, 3);
    });

    test('pulse uses infinite iterations', () {
      expect(BloomAnimationPresets.pulse.iterations, -1);
    });
  });
}
```

- [ ] **Step 2: Run failing tests**

```bash
cd packages/bloom_js_native && dart test test/animate_test.dart 2>&1 | head -10
```
Expected: FAIL — `BloomKeyframe`, `BloomAnimation`, `Animated`, `BloomAnimationPresets` not defined.

- [ ] **Step 3: Implement `animate.dart`**

Create `packages/bloom_js_native/lib/src/animate.dart`:

```dart
// lib/src/animate.dart
import 'framework.dart';

/// A single keyframe stop in a CSS animation (offset 0.0–1.0).
class BloomKeyframe {
  /// Normalized position: 0.0 = from, 1.0 = to.
  final double offset;

  /// CSS property/value pairs at this keyframe (e.g. `{'opacity': '0'}`).
  final Map<String, String> styles;

  const BloomKeyframe({required this.offset, required this.styles});

  /// Returns the CSS percentage string (e.g. `'50%'` for offset 0.5).
  String toCssPercent() => '${(offset * 100).round()}%';

  /// Returns the full keyframe CSS block (e.g. `'0%{opacity:0}'`).
  String toCssBlock() {
    final decls = styles.entries.map((e) => '${e.key}:${e.value}').join(';');
    return '${toCssPercent()}{$decls}';
  }
}

/// Immutable CSS animation descriptor — generates `@keyframes` and inline `animation` style.
class BloomAnimation {
  /// The animation identifier used in both `@keyframes` and the `animation` property.
  final String name;

  /// Ordered keyframe stops.
  final List<BloomKeyframe> keyframes;

  /// Total cycle duration. Defaults to 300ms.
  final Duration duration;

  /// Start delay. Defaults to zero.
  final Duration delay;

  /// Number of iterations. Use `-1` for infinite. Defaults to 1.
  final int iterations;

  /// CSS easing function. Defaults to `'ease'`.
  final String easing;

  /// CSS `animation-fill-mode`. Defaults to `'both'`.
  final String fillMode;

  /// CSS `animation-direction`. Defaults to `'normal'`.
  final String direction;

  const BloomAnimation({
    required this.name,
    required this.keyframes,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.iterations = 1,
    this.easing = 'ease',
    this.fillMode = 'both',
    this.direction = 'normal',
  });

  /// Returns the complete `@keyframes name { ... }` CSS block.
  String toKeyframesCSS() {
    final stops = keyframes.map((k) => k.toCssBlock()).join('');
    return '@keyframes $name{$stops}';
  }

  /// Returns the CSS `animation` shorthand value suitable for an inline `style` attribute.
  String toInlineStyle() {
    final iterStr = iterations == -1 ? 'infinite' : '$iterations';
    return 'animation:$name ${duration.inMilliseconds}ms $easing ${delay.inMilliseconds}ms $iterStr $direction $fillMode';
  }
}

/// AST node that wraps [child] with a CSS animation.
/// On SSR it emits a `<style>@keyframes …</style>` block (deduplicated by name) and
/// a wrapper `<div>` carrying the `animation:` inline style.
class AnimatedNode extends BloomNode {
  final BloomNode child;
  final BloomAnimation animation;
  const AnimatedNode({required this.child, required this.animation});
}

/// `const`-safe DSL alias for [AnimatedNode].
class Animated extends AnimatedNode {
  const Animated({required super.animation, required super.child});
}

/// Ready-to-use animation presets. Use via `BloomAnimationPresets.fadeIn` etc.
class BloomAnimationPresets {
  BloomAnimationPresets._();

  static const fadeIn = BloomAnimation(
    name: 'bloom-fade-in',
    keyframes: [
      BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
      BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
    ],
  );

  static const fadeOut = BloomAnimation(
    name: 'bloom-fade-out',
    keyframes: [
      BloomKeyframe(offset: 0.0, styles: {'opacity': '1'}),
      BloomKeyframe(offset: 1.0, styles: {'opacity': '0'}),
    ],
  );

  static const slideInLeft = BloomAnimation(
    name: 'bloom-slide-in-left',
    keyframes: [
      BloomKeyframe(
          offset: 0.0,
          styles: {'transform': 'translateX(-100%)', 'opacity': '0'}),
      BloomKeyframe(
          offset: 1.0,
          styles: {'transform': 'translateX(0)', 'opacity': '1'}),
    ],
  );

  static const slideInRight = BloomAnimation(
    name: 'bloom-slide-in-right',
    keyframes: [
      BloomKeyframe(
          offset: 0.0,
          styles: {'transform': 'translateX(100%)', 'opacity': '0'}),
      BloomKeyframe(
          offset: 1.0,
          styles: {'transform': 'translateX(0)', 'opacity': '1'}),
    ],
  );

  static const scaleIn = BloomAnimation(
    name: 'bloom-scale-in',
    keyframes: [
      BloomKeyframe(
          offset: 0.0, styles: {'transform': 'scale(0.8)', 'opacity': '0'}),
      BloomKeyframe(
          offset: 1.0, styles: {'transform': 'scale(1)', 'opacity': '1'}),
    ],
  );

  static const pulse = BloomAnimation(
    name: 'bloom-pulse',
    keyframes: [
      BloomKeyframe(offset: 0.0, styles: {'transform': 'scale(1)'}),
      BloomKeyframe(offset: 0.5, styles: {'transform': 'scale(1.05)'}),
      BloomKeyframe(offset: 1.0, styles: {'transform': 'scale(1)'}),
    ],
    iterations: -1,
    easing: 'ease-in-out',
  );
}
```

- [ ] **Step 4: Wire `AnimatedNode` into `renderToHtml()` in `framework.dart`**

Open `packages/bloom_js_native/lib/src/framework.dart` and find the `renderToHtml()` top-level function. It delegates to a private function (likely `_renderNode` or `_renderToHtmlBuffer`). Add a case for `AnimatedNode` inside the switch/if-else that handles node types:

Inside the private render helper, find the existing pattern for `ElNode`, `TextNode`, etc. Add before the `ElNode` case:

```dart
case AnimatedNode():
  // Emit @keyframes only once per animation name per render pass
  if (!_emittedKeyframes.contains(node.animation.name)) {
    _emittedKeyframes.add(node.animation.name);
    buf.write('<style>${node.animation.toKeyframesCSS()}</style>');
  }
  buf.write('<div style="${node.animation.toInlineStyle()}">');
  _renderNode(node.child, buf);
  buf.write('</div>');
```

Add a render-local set to track emitted keyframe names. The exact mechanism depends on how `framework.dart` passes state. Two approaches:

**Approach A** — if `renderToHtml()` creates a `StringBuffer` and passes it to a recursive private function, add a `Set<String> emittedKeyframes = {}` parameter to the private function and thread it through all recursive calls.

**Approach B** — if the render is not easily parameterized, use a temporary top-level `Set<String> _emittedKeyframes = {}` that is reset at the start of each top-level `renderToHtml()` call:

```dart
final Set<String> _emittedKeyframes = {};

String renderToHtml(BloomNode node) {
  _emittedKeyframes.clear(); // Reset per render pass
  final buf = StringBuffer();
  _renderNode(node, buf);
  return buf.toString();
}
```

Read `framework.dart` before implementing — follow whatever existing pattern is used. The test contract is: `renderToHtml(Animated(...))` must contain `<style>@keyframes name{...}</style>` exactly once per unique animation name.

- [ ] **Step 5: Export from barrel**

Add to `packages/bloom_js_native/lib/bloom_js_native.dart`:
```dart
export 'src/animate.dart';
```

- [ ] **Step 6: Run tests**

```bash
cd packages/bloom_js_native && dart test test/animate_test.dart --reporter expanded && dart analyze lib/
```
Expected: All 14 animation tests pass, 0 analyzer issues.

- [ ] **Step 7: Run full suite**

```bash
cd packages/bloom_js_native && dart test --reporter compact
```
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
cd /root/dev/Bloom && git add packages/bloom_js_native/ && git commit -m "feat(bloom_js_native): add BloomAnimate CSS animation bindings with presets and SSR @keyframes deduplication"
```

---

### Task 4: BloomForm — Reactive Form Management

**Files:**
- Create: `packages/bloom_js_native/lib/src/form.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart` (add export)
- Create: `packages/bloom_js_native/test/form_test.dart`

**Interfaces:**
- Produces:
  - Validators (top-level functions): `required([String? msg])`, `minLength(int n, [String? msg])`, `maxLength(int n, [String? msg])`, `email([String? msg])`, `pattern(RegExp re, [String? msg])` — all return `String? Function(String)`.
  - `BloomFormField({String initialValue, List<String? Function(String)> validators})` — signals: `Signal<String> value`, `Signal<List<String>> errors`, `Signal<bool> isDirty`, `Signal<bool> isTouched`, `ReadonlySignal<bool> isValid`. Methods: `setValue(String)`, `touch()`, `validate() → bool`, `reset()`.
  - `BloomForm(Map<String, BloomFormField> fields)` — signals: `ReadonlySignal<bool> isValid`, `ReadonlySignal<bool> isDirty`, `Signal<bool> isSubmitting`. Methods: `getField(String) → BloomFormField`, `getValue(String) → String`, `Map<String, String> get values`, `validate() → bool`, `Future<void> submit(Future<void> Function(Map<String, String>) onSubmit)`, `reset()`.
- Consumes: `signal<T>()`, `computed()` from `package:signals/signals.dart`.

- [ ] **Step 1: Write failing tests**

Create `packages/bloom_js_native/test/form_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('Validators', () {
    test('required() returns null for non-empty value', () {
      expect(required()('hello'), isNull);
    });

    test('required() returns error for empty value', () {
      expect(required()(''), isNotNull);
    });

    test('required() uses custom message', () {
      expect(required('Name is required')(''), 'Name is required');
    });

    test('minLength(3) passes for 3-char string', () {
      expect(minLength(3)('abc'), isNull);
    });

    test('minLength(3) fails for 2-char string', () {
      expect(minLength(3)('ab'), isNotNull);
    });

    test('maxLength(5) passes for 5-char string', () {
      expect(maxLength(5)('hello'), isNull);
    });

    test('maxLength(5) fails for 6-char string', () {
      expect(maxLength(5)('toolong'), isNotNull);
    });

    test('email() passes valid email', () {
      expect(email()('user@example.com'), isNull);
    });

    test('email() fails invalid email', () {
      expect(email()('not-an-email'), isNotNull);
    });

    test('pattern() passes matching string', () {
      expect(pattern(RegExp(r'^\d+$'))('123'), isNull);
    });

    test('pattern() fails non-matching string', () {
      expect(pattern(RegExp(r'^\d+$'))('abc'), isNotNull);
    });
  });

  group('BloomFormField', () {
    test('starts clean with initial value', () {
      final field = BloomFormField(initialValue: 'hello');
      expect(field.value.value, 'hello');
      expect(field.isDirty.value, isFalse);
      expect(field.isTouched.value, isFalse);
      expect(field.isValid.value, isTrue);
    });

    test('setValue marks dirty and updates value', () {
      final field = BloomFormField(initialValue: '');
      field.setValue('new value');
      expect(field.value.value, 'new value');
      expect(field.isDirty.value, isTrue);
    });

    test('touch marks isTouched', () {
      final field = BloomFormField(initialValue: '');
      field.touch();
      expect(field.isTouched.value, isTrue);
    });

    test('validate() populates errors for failing validators', () {
      final field = BloomFormField(
        initialValue: '',
        validators: [required('Required'), minLength(3, 'Too short')],
      );
      field.validate();
      expect(field.errors.value, contains('Required'));
    });

    test('validate() clears errors after fixing value', () {
      final field = BloomFormField(
          initialValue: '', validators: [required()]);
      field.validate();
      expect(field.isValid.value, isFalse);
      field.setValue('hello');
      field.validate();
      expect(field.isValid.value, isTrue);
      expect(field.errors.value, isEmpty);
    });

    test('reset() restores initial value and clears state', () {
      final field = BloomFormField(initialValue: 'init');
      field.setValue('changed');
      field.touch();
      field.validate();
      field.reset();
      expect(field.value.value, 'init');
      expect(field.isDirty.value, isFalse);
      expect(field.isTouched.value, isFalse);
      expect(field.errors.value, isEmpty);
    });
  });

  group('BloomForm', () {
    late BloomForm form;

    setUp(() {
      form = BloomForm({
        'username': BloomFormField(
          initialValue: '',
          validators: [required(), minLength(3)],
        ),
        'email': BloomFormField(
          initialValue: '',
          validators: [required(), email()],
        ),
      });
    });

    test('isValid is false when required fields are empty', () {
      form.validate();
      expect(form.isValid.value, isFalse);
    });

    test('isValid is true when all fields pass', () {
      form.getField('username').setValue('alice');
      form.getField('email').setValue('alice@example.com');
      form.validate();
      expect(form.isValid.value, isTrue);
    });

    test('getValue returns current field value', () {
      form.getField('username').setValue('bob');
      expect(form.getValue('username'), 'bob');
    });

    test('values returns map of all fields', () {
      form.getField('username').setValue('charlie');
      form.getField('email').setValue('charlie@example.com');
      final vals = form.values;
      expect(vals['username'], 'charlie');
      expect(vals['email'], 'charlie@example.com');
    });

    test('submit calls onSubmit with values when valid', () async {
      form.getField('username').setValue('dave');
      form.getField('email').setValue('dave@example.com');
      Map<String, String>? submitted;
      await form.submit((vals) async => submitted = vals);
      expect(submitted, isNotNull);
      expect(submitted!['username'], 'dave');
    });

    test('submit does not call onSubmit when invalid', () async {
      bool called = false;
      await form.submit((_) async => called = true);
      expect(called, isFalse);
    });

    test('isSubmitting is true during submit', () async {
      form.getField('username').setValue('eve');
      form.getField('email').setValue('eve@example.com');
      final statuses = <bool>[];
      form.isSubmitting.listen((v) => statuses.add(v));
      await form.submit((_) async =>
          await Future.delayed(const Duration(milliseconds: 10)));
      expect(statuses, containsAllInOrder([true, false]));
    });

    test('reset() restores all fields', () {
      form.getField('username').setValue('frank');
      form.reset();
      expect(form.getValue('username'), '');
    });

    test('getField throws StateError for unknown name', () {
      expect(() => form.getField('nonexistent'), throwsA(isA<StateError>()));
    });
  });
}
```

- [ ] **Step 2: Run failing tests**

```bash
cd packages/bloom_js_native && dart test test/form_test.dart 2>&1 | head -10
```
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement `form.dart`**

Create `packages/bloom_js_native/lib/src/form.dart`:

```dart
// lib/src/form.dart
import 'dart:async';
import 'package:signals/signals.dart';

// ─── Validators ───────────────────────────────────────────────────────────────

/// Fails for empty or whitespace-only strings.
String? Function(String) required([String? message]) =>
    (v) => v.trim().isEmpty ? (message ?? 'This field is required.') : null;

/// Fails when the value is shorter than [n] characters.
String? Function(String) minLength(int n, [String? message]) =>
    (v) => v.length < n ? (message ?? 'Must be at least $n characters.') : null;

/// Fails when the value is longer than [n] characters.
String? Function(String) maxLength(int n, [String? message]) =>
    (v) => v.length > n ? (message ?? 'Must be at most $n characters.') : null;

/// Fails when the value is not a valid email address.
String? Function(String) email([String? message]) {
  final re = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
  return (v) =>
      re.hasMatch(v) ? null : (message ?? 'Enter a valid email address.');
}

/// Fails when the value does not match [re].
String? Function(String) pattern(RegExp re, [String? message]) =>
    (v) => re.hasMatch(v) ? null : (message ?? 'Invalid format.');

// ─── BloomFormField ───────────────────────────────────────────────────────────

/// A single reactive form field.
class BloomFormField {
  final String _initialValue;
  final List<String? Function(String)> validators;

  late final Signal<String> value;
  late final Signal<List<String>> errors;
  late final Signal<bool> isDirty;
  late final Signal<bool> isTouched;
  late final ReadonlySignal<bool> isValid;

  BloomFormField({
    String initialValue = '',
    this.validators = const [],
  }) : _initialValue = initialValue {
    value = signal(initialValue);
    errors = signal<List<String>>([]);
    isDirty = signal(false);
    isTouched = signal(false);
    isValid = computed(() => errors.value.isEmpty);
  }

  /// Updates the value and marks the field dirty.
  void setValue(String newValue) {
    value.value = newValue;
    isDirty.value = true;
  }

  /// Marks the field as touched (e.g. on blur).
  void touch() => isTouched.value = true;

  /// Runs all validators and updates [errors]. Returns `true` if valid.
  bool validate() {
    final errs = <String>[];
    for (final v in validators) {
      final err = v(value.value);
      if (err != null) errs.add(err);
    }
    errors.value = errs;
    return errs.isEmpty;
  }

  /// Resets to initial value and clears all state.
  void reset() {
    value.value = _initialValue;
    errors.value = [];
    isDirty.value = false;
    isTouched.value = false;
  }
}

// ─── BloomForm ────────────────────────────────────────────────────────────────

/// Reactive controller for a collection of [BloomFormField]s.
class BloomForm {
  final Map<String, BloomFormField> _fields;

  late final ReadonlySignal<bool> isValid;
  late final ReadonlySignal<bool> isDirty;
  final Signal<bool> isSubmitting = signal(false);

  BloomForm(Map<String, BloomFormField> fields) : _fields = fields {
    isValid = computed(() => _fields.values.every((f) => f.isValid.value));
    isDirty = computed(() => _fields.values.any((f) => f.isDirty.value));
  }

  /// Returns the [BloomFormField] registered under [name]. Throws [StateError] if absent.
  BloomFormField getField(String name) {
    final field = _fields[name];
    if (field == null) {
      throw StateError(
          'BloomForm: No field registered with name "$name".');
    }
    return field;
  }

  /// Returns the current string value of the field named [name].
  String getValue(String name) => getField(name).value.value;

  /// Snapshot map of all current field values.
  Map<String, String> get values =>
      {for (final e in _fields.entries) e.key: e.value.value.value};

  /// Validates all fields. Returns `true` if every field passes.
  bool validate() =>
      _fields.values.map((f) => f.validate()).every((r) => r);

  /// If valid, calls [onSubmit] with current values and wraps it with [isSubmitting].
  Future<void> submit(
      Future<void> Function(Map<String, String> values) onSubmit) async {
    if (!validate()) return;
    isSubmitting.value = true;
    try {
      await onSubmit(values);
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Resets all fields to their initial state.
  void reset() {
    for (final field in _fields.values) {
      field.reset();
    }
    isSubmitting.value = false;
  }
}
```

- [ ] **Step 4: Export from barrel**

Add to `packages/bloom_js_native/lib/bloom_js_native.dart`:
```dart
export 'src/form.dart';
```

- [ ] **Step 5: Run tests and analyzer**

```bash
cd packages/bloom_js_native && dart test test/form_test.dart --reporter expanded && dart analyze lib/
```
Expected: All 22 form tests pass, 0 analyzer issues.

> **If `form.values` throws a type error:** The `_fields` map is `Map<String, BloomFormField>`, so `e.value` is `BloomFormField` and `e.value.value` is `Signal<String>`. The `.value` on that is the `String`. So the full chain is `e.value.value.value`. If the analyzer complains about the intermediate access naming, rename one of the `.value` chains: `e.value.value.value` → use a local variable `final field = e.value; field.value.value`.

- [ ] **Step 6: Run full suite**

```bash
cd packages/bloom_js_native && dart test --reporter compact
```
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
cd /root/dev/Bloom && git add packages/bloom_js_native/ && git commit -m "feat(bloom_js_native): add BloomForm reactive form management with validators, field state, and submit lifecycle"
```

---

### Task 5: BloomRealtimeBinding — Reactive WebSocket Signal Bindings

**Files:**
- Modify: `packages/bloom_js_native/pubspec.yaml` (add `bloom_realtime` path dependency)
- Create: `packages/bloom_js_native/lib/src/realtime.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart` (add export)
- Create: `packages/bloom_js_native/test/realtime_test.dart`

**Interfaces:**
- Consumes from `package:bloom_realtime` (at `../../packages/bloom_realtime`):
  - `BloomRealtimeClient` — `Stream<Map<String, dynamic>> subscribe(String channel)`, `Stream<List<Map<String, dynamic>>> presence(String channel)`, `RealtimeConnectionState get state`, `Stream<RealtimeConnectionState> get onStateChanged` (confirm actual stream name by reading `realtime_client.dart`).
  - `RealtimeConnectionState` enum — `.disconnected`, `.connecting`, `.connected`, `.reconnecting`.
- Produces:
  - `BloomRealtimeBinding({required BloomRealtimeClient client})` — `ReadonlySignal<RealtimeConnectionState> get connectionState`, `ReadonlySignal<Map<String, dynamic>?> channel(String name)`, `ReadonlySignal<List<Map<String, dynamic>>> presence(String name)`, `Future<void> dispose()`.
  - Top-level: `BloomRealtimeBinding realtimeBinding(BloomRealtimeClient client)`.

- [ ] **Step 1: Add bloom_realtime path dependency**

In `packages/bloom_js_native/pubspec.yaml`, under `dependencies:`, add:
```yaml
  bloom_realtime:
    path: ../../packages/bloom_realtime
```

Run:
```bash
cd packages/bloom_js_native && dart pub get
```

If `dart pub get` fails because `bloom_realtime` imports `dart:io` WebSocket and conflicts with the `package:web` environment, check the pubspec of `bloom_realtime` for platform constraints. If it works, continue. If the dependency graph conflicts, use `path: ../../packages/bloom_realtime` and add `dependency_overrides` if needed.

- [ ] **Step 2: Confirm BloomRealtimeClient API**

Run:
```bash
grep -n "get state\|onStateChanged\|stateStream\|Stream.*Connection\|Stream.*Realtime" packages/bloom_realtime/lib/src/client/realtime_client.dart | head -20
```

Note the exact getter/stream name for connection state changes. Update the `realtime.dart` implementation in Step 4 to use the confirmed name.

- [ ] **Step 3: Write failing tests**

Create `packages/bloom_js_native/test/realtime_test.dart`:

```dart
import 'dart:async';
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() {
  group('BloomRealtimeBinding', () {
    late _FakeRealtimeClient fakeClient;
    late BloomRealtimeBinding binding;

    setUp(() {
      fakeClient = _FakeRealtimeClient();
      binding = BloomRealtimeBinding(client: fakeClient);
    });

    tearDown(() async => binding.dispose());

    test('connectionState starts as disconnected', () {
      expect(binding.connectionState.value,
          RealtimeConnectionState.disconnected);
    });

    test('connectionState updates when client state changes', () async {
      fakeClient.emitState(RealtimeConnectionState.connected);
      await Future.microtask(() {});
      expect(binding.connectionState.value,
          RealtimeConnectionState.connected);
    });

    test('channel() returns ReadonlySignal starting as null', () {
      final sig = binding.channel('todos');
      expect(sig.value, isNull);
    });

    test('channel() signal updates on client broadcast', () async {
      final sig = binding.channel('todos');
      fakeClient.emitMessage('todos', {'id': 1, 'title': 'Buy milk'});
      await Future.microtask(() {});
      expect(sig.value, {'id': 1, 'title': 'Buy milk'});
    });

    test('same channel() call returns same signal instance', () {
      final a = binding.channel('chat');
      final b = binding.channel('chat');
      expect(identical(a, b), isTrue);
    });

    test('presence() returns ReadonlySignal starting as empty list', () {
      final sig = binding.presence('room-1');
      expect(sig.value, isEmpty);
    });

    test('presence() signal updates on client presence event', () async {
      final sig = binding.presence('room-1');
      fakeClient.emitPresence('room-1', [
        {'id': 'u1', 'name': 'Alice'},
        {'id': 'u2', 'name': 'Bob'},
      ]);
      await Future.microtask(() {});
      expect(sig.value.length, 2);
      expect(sig.value.first['name'], 'Alice');
    });

    test('dispose() closes without error', () async {
      binding.channel('ch1');
      binding.presence('p1');
      expect(() => binding.dispose(), returnsNormally);
    });
  });

  group('realtimeBinding() helper', () {
    test('creates a BloomRealtimeBinding', () {
      final client = _FakeRealtimeClient();
      final b = realtimeBinding(client);
      expect(b, isA<BloomRealtimeBinding>());
      b.dispose();
    });
  });
}

/// Fake [BloomRealtimeClient] for testing — no real WebSocket.
class _FakeRealtimeClient implements BloomRealtimeClient {
  final _stateCtrl =
      StreamController<RealtimeConnectionState>.broadcast();
  final _msgCtrls =
      <String, StreamController<Map<String, dynamic>>>{};
  final _presenceCtrls =
      <String, StreamController<List<Map<String, dynamic>>>>{};

  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;

  @override
  RealtimeConnectionState get state => _state;

  // Expose stream used by BloomRealtimeBinding — update name below
  // if the real class uses a different stream name.
  @override
  Stream<RealtimeConnectionState> get onStateChanged => _stateCtrl.stream;

  void emitState(RealtimeConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void emitMessage(String channel, Map<String, dynamic> msg) =>
      _msgCtrls[channel]?.add(msg);

  void emitPresence(String channel, List<Map<String, dynamic>> users) =>
      _presenceCtrls[channel]?.add(users);

  @override
  Stream<Map<String, dynamic>> subscribe(String channel) {
    return (_msgCtrls[channel] ??=
            StreamController<Map<String, dynamic>>.broadcast())
        .stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> presence(String channel) {
    return (_presenceCtrls[channel] ??=
            StreamController<List<Map<String, dynamic>>>.broadcast())
        .stream;
  }

  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> unsubscribe(String channel) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] **Step 4: Implement `realtime.dart`**

Create `packages/bloom_js_native/lib/src/realtime.dart`:

```dart
// lib/src/realtime.dart
import 'dart:async';
import 'package:signals/signals.dart';
import 'package:bloom_realtime/bloom_realtime.dart';

/// Reactive signal-backed bindings for a [BloomRealtimeClient].
/// Wraps channel subscriptions and presence streams as observable signals.
/// Pure-Dart, no DOM dependency.
class BloomRealtimeBinding {
  final BloomRealtimeClient client;

  late final Signal<RealtimeConnectionState> _connectionState;
  final Map<String, Signal<Map<String, dynamic>?>> _channelSignals = {};
  final Map<String, Signal<List<Map<String, dynamic>>>> _presenceSignals = {};
  final List<StreamSubscription<dynamic>> _subs = [];

  BloomRealtimeBinding({required this.client}) {
    _connectionState = signal(client.state);

    _subs.add(client.onStateChanged.listen((s) {
      _connectionState.value = s;
    }));
  }

  /// Reactive signal for the current WebSocket connection state.
  ReadonlySignal<RealtimeConnectionState> get connectionState =>
      _connectionState.readonly();

  /// Returns a [ReadonlySignal] for the latest message on [channelName].
  /// Starts as `null`. Each new broadcast event replaces the signal value.
  /// Calling with the same [channelName] always returns the same signal instance.
  ReadonlySignal<Map<String, dynamic>?> channel(String channelName) {
    if (_channelSignals.containsKey(channelName)) {
      return _channelSignals[channelName]!.readonly();
    }
    final sig = signal<Map<String, dynamic>?>(null);
    _channelSignals[channelName] = sig;
    _subs.add(client.subscribe(channelName).listen((msg) => sig.value = msg));
    return sig.readonly();
  }

  /// Returns a [ReadonlySignal] for the current presence list on [channelName].
  /// Starts as an empty list. Updates on every presence state event.
  ReadonlySignal<List<Map<String, dynamic>>> presence(String channelName) {
    if (_presenceSignals.containsKey(channelName)) {
      return _presenceSignals[channelName]!.readonly();
    }
    final sig = signal<List<Map<String, dynamic>>>(const []);
    _presenceSignals[channelName] = sig;
    _subs.add(
        client.presence(channelName).listen((users) => sig.value = users));
    return sig.readonly();
  }

  /// Cancels all subscriptions and releases resources.
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }
}

/// Creates a [BloomRealtimeBinding] wrapping [client].
BloomRealtimeBinding realtimeBinding(BloomRealtimeClient client) =>
    BloomRealtimeBinding(client: client);
```

> **If `onStateChanged` is named differently** in `BloomRealtimeClient` (confirmed in Step 2), update line `_subs.add(client.onStateChanged.listen(...))` to use the correct stream name. Similarly update the `_FakeRealtimeClient` `@override` getter in the test file.

- [ ] **Step 5: Export from barrel**

Add to `packages/bloom_js_native/lib/bloom_js_native.dart`:
```dart
export 'src/realtime.dart';
```

- [ ] **Step 6: Run tests and analyzer**

```bash
cd packages/bloom_js_native && dart test test/realtime_test.dart --reporter expanded && dart analyze lib/
```
Expected: All 8 realtime tests pass, 0 analyzer issues.

- [ ] **Step 7: Run full suite**

```bash
cd packages/bloom_js_native && dart test --reporter compact
```
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
cd /root/dev/Bloom && git add packages/bloom_js_native/ && git commit -m "feat(bloom_js_native): add BloomRealtimeBinding reactive WebSocket signal bindings with channel and presence support"
```

---

### Task 6: Final Quality Gate

**Files:** No new files.

- [ ] **Step 1: Analyze all packages**

```bash
dart analyze packages/bloom_js_native packages/bloom_cli packages/bloom_validate packages/bloom_framework
```
Expected: `No issues found!`

- [ ] **Step 2: Run bloom_js_native tests**

```bash
cd packages/bloom_js_native && dart test --reporter expanded 2>&1 | tail -5
```
Expected: `All tests passed!` (200+ tests)

- [ ] **Step 3: Run bloom_cli tests**

```bash
cd packages/bloom_cli && dart test --reporter compact 2>&1 | tail -5
```
Expected: All tests pass.

- [ ] **Step 4: Final commit**

```bash
cd /root/dev/Bloom && git add . && git commit -m "chore(m11): quality gate — all tests passing, 0 analyzer issues"
```
