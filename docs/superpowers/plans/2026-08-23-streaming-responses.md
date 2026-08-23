# Streaming Responses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a Bloom route return a response body as a `Stream<List<int>>` that is written to the socket incrementally, instead of buffering every response fully in memory.

**Architecture:** `BloomResponse` gains an optional `bodyStream` alongside its existing `Uint8List body`. Because the response object travels back up the middleware chain *before* any byte is written, middleware keeps mutating headers exactly as it does today — the router is the only thing that subscribes to the stream, and it does so last. The buffered path is untouched, so this is purely additive.

**Tech Stack:** Dart 3, `dart:io` `HttpResponse.addStream`, `package:test`.

**Spec:** This document. It originates from an audit finding, recorded below in "Background", rather than a separate spec file.

## Background — why this exists

`BloomResponse.body` is a `final Uint8List`. `BloomApiRouter.handleIoRequest` writes it with a single `ioReq.response.add(bloomRes.body)` then closes. Consequences:

- Every response is fully resident in RAM before a byte reaches the client. A 100MB download costs 100MB per concurrent request.
- Time-to-first-byte waits on the complete upstream/disk read.
- There is no backpressure.
- SSE and chunked responses cannot be expressed through a normal route at all, because the router closes the response immediately after one write.

This was found while building the SSR reverse proxy, which is forced to `fold` an entire upstream response into a list before returning it.

## Global Constraints

- **The server core is duplicated.** `packages/bloom_framework/lib/src/server/` and `packages/bloom_server/lib/src/server/` contain **byte-identical** copies of `api_router.dart`, `bloom_middleware.dart`, `bloom_request.dart`, and `bloom_response.dart` (603 and 131 lines respectively). Only `rpc_mount.dart` is unique to `bloom_server`. **Every change in this plan must be applied to both copies, identically.** Verify with `diff` at the end of each task; the files must remain byte-identical.
- **Purely additive.** The existing `body` field, all ten `BloomResponse` factories, and the buffered write path must not change behaviour. No existing test may be modified to accommodate this work.
- **No new dependencies.** `dart:io`, `dart:async`, `dart:typed_data` only.
- **Dart SDK** `>=3.0.0 <4.0.0`. Test package is `test: ^1.25.0`.
- Run tests from the package root: `cd packages/bloom_server && dart test`.
- Do not set `content-length` on a streaming response; `dart:io` falls back to chunked transfer encoding when content length is unset.

## File Structure

| File | Responsibility |
|---|---|
| `packages/bloom_server/lib/src/server/bloom_response.dart` | Add `bodyStream` field, `BloomResponse.stream()` factory, `isStreaming` getter, and consumption guard. |
| `packages/bloom_server/lib/src/server/api_router.dart` | Branch the write path in `handleIoRequest`; cancel streams on the HEAD path. |
| `packages/bloom_framework/lib/src/server/bloom_response.dart` | Identical copy of the above. |
| `packages/bloom_framework/lib/src/server/api_router.dart` | Identical copy of the above. |
| `packages/bloom_server/test/streaming_response_test.dart` | New. Unit + end-to-end socket tests. |

---

### Task 1: Add `bodyStream` to `BloomResponse`

**Files:**
- Modify: `packages/bloom_server/lib/src/server/bloom_response.dart`
- Modify: `packages/bloom_framework/lib/src/server/bloom_response.dart`
- Test: `packages/bloom_server/test/streaming_response_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Stream<List<int>>? get bodyStream`
  - `bool get isStreaming` — true when `bodyStream != null`
  - `factory BloomResponse.stream(Stream<List<int>> body, {int statusCode = 200, Map<String, String>? headers, String? contentType})`
  - `Stream<List<int>> takeBodyStream()` — returns the stream and marks it consumed; throws `StateError` if called twice.

- [ ] **Step 1: Write the failing test**

Create `packages/bloom_server/test/streaming_response_test.dart`:

```dart
import 'dart:convert';
import 'package:bloom_server/bloom_server.dart';
import 'package:test/test.dart';

void main() {
  group('BloomResponse.stream', () {
    test('exposes the stream and reports isStreaming', () async {
      final source = Stream<List<int>>.fromIterable([
        utf8.encode('hello '),
        utf8.encode('world'),
      ]);

      final res = BloomResponse.stream(source, contentType: 'text/plain');

      expect(res.isStreaming, isTrue);
      expect(res.statusCode, 200);
      expect(res.headers['content-type'], 'text/plain');
      // The buffered body stays empty so existing consumers see no bytes
      // rather than a silently truncated payload.
      expect(res.body, isEmpty);

      final collected = await res.takeBodyStream().expand((c) => c).toList();
      expect(utf8.decode(collected), 'hello world');
    });

    test('a buffered response is not streaming', () {
      final res = BloomResponse.text('plain');
      expect(res.isStreaming, isFalse);
      expect(() => res.takeBodyStream(), throwsStateError);
    });

    test('takeBodyStream throws if the stream is taken twice', () {
      final res = BloomResponse.stream(const Stream<List<int>>.empty());
      res.takeBodyStream();
      // Single-subscription streams cannot be listened to twice; failing
      // loudly here beats an opaque "Stream has already been listened to".
      expect(() => res.takeBodyStream(), throwsStateError);
    });

    test('does not set content-length', () {
      final res = BloomResponse.stream(const Stream<List<int>>.empty());
      // Length is unknown up front; dart:io uses chunked encoding when
      // content-length is absent. Setting it would truncate the response.
      expect(res.headers.containsKey('content-length'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/bloom_server && dart test test/streaming_response_test.dart`
Expected: FAIL — `The method 'stream' isn't defined for the type 'BloomResponse'`.

- [ ] **Step 3: Write minimal implementation**

In `packages/bloom_server/lib/src/server/bloom_response.dart`, add the field to the class and a new factory. Replace the existing field declarations and default constructor with:

```dart
  /// Response body binary payload.
  ///
  /// Always empty when [isStreaming] is true — a streaming response carries
  /// its bytes in [bodyStream] instead.
  final Uint8List body;

  /// Incremental response body, or null for a buffered response.
  ///
  /// Held unconsumed until the router writes it, which is what allows
  /// middleware to keep mutating [headers] after the handler returns: no
  /// byte reaches the socket until the whole middleware chain has unwound.
  final Stream<List<int>>? _bodyStream;

  bool _streamTaken = false;

  /// Whether this response delivers its body incrementally.
  bool get isStreaming => _bodyStream != null;

  /// Creates a [BloomResponse] with an optional [statusCode], [headers], and [body].
  BloomResponse({
    this.statusCode = 200,
    Map<String, String>? headers,
    Uint8List? body,
  })  : headers = Map<String, String>.from(headers ?? {}),
        body = body ?? Uint8List(0),
        _bodyStream = null;

  /// Creates a response whose body is written incrementally from [body].
  ///
  /// Use for large payloads, proxied upstreams, and any response whose length
  /// is not known in advance. No `content-length` is set, so the response is
  /// sent with chunked transfer encoding.
  BloomResponse.stream(
    Stream<List<int>> body, {
    this.statusCode = 200,
    Map<String, String>? headers,
    String? contentType,
  })  : headers = {
          if (contentType != null) 'content-type': contentType,
          ...?headers,
        },
        body = Uint8List(0),
        _bodyStream = body;

  /// Returns the body stream, marking it consumed.
  ///
  /// Throws [StateError] if this is not a streaming response, or if the stream
  /// was already taken — a single-subscription stream cannot be listened twice,
  /// and this turns that into a clear error at the call site.
  Stream<List<int>> takeBodyStream() {
    final stream = _bodyStream;
    if (stream == null) {
      throw StateError(
        'BloomResponse.takeBodyStream() called on a buffered response. '
        'Check isStreaming before calling.',
      );
    }
    if (_streamTaken) {
      throw StateError(
        'BloomResponse body stream has already been taken. A response body '
        'may only be consumed once.',
      );
    }
    _streamTaken = true;
    return stream;
  }
```

Note the class can no longer be `const`-constructible; it never was.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_server && dart test test/streaming_response_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Mirror into bloom_framework and verify byte-identity**

```bash
cp packages/bloom_server/lib/src/server/bloom_response.dart \
   packages/bloom_framework/lib/src/server/bloom_response.dart
diff packages/bloom_server/lib/src/server/bloom_response.dart \
     packages/bloom_framework/lib/src/server/bloom_response.dart && echo IDENTICAL
```
Expected: prints `IDENTICAL`.

- [ ] **Step 6: Analyze both packages**

Run: `cd packages/bloom_server && dart analyze && cd ../bloom_framework && dart analyze`
Expected: `No issues found!` from both.

- [ ] **Step 7: Commit**

```bash
git add packages/bloom_server/lib/src/server/bloom_response.dart \
        packages/bloom_framework/lib/src/server/bloom_response.dart \
        packages/bloom_server/test/streaming_response_test.dart
git commit -m "feat(bloom_server): add streaming body to BloomResponse"
```

---

### Task 2: Write streaming bodies to the socket

**Files:**
- Modify: `packages/bloom_server/lib/src/server/api_router.dart:352-355`
- Modify: `packages/bloom_framework/lib/src/server/api_router.dart` (same lines)
- Test: `packages/bloom_server/test/streaming_response_test.dart` (extend)

**Interfaces:**
- Consumes: `BloomResponse.isStreaming`, `BloomResponse.takeBodyStream()` from Task 1.
- Produces: no new public API. `handleIoRequest` now writes streaming bodies incrementally.

- [ ] **Step 1: Write the failing test**

Append to `packages/bloom_server/test/streaming_response_test.dart`, inside `main()`:

```dart
  group('streaming over a real socket', () {
    late BloomApiRouter router;
    late HttpServer server;

    setUp(() async {
      router = BloomApiRouter();
      server = await router.serve(port: 0);
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('streams chunks and uses chunked transfer encoding', () async {
      router.get('/stream', (req) async {
        return BloomResponse.stream(
          Stream<List<int>>.fromIterable([
            utf8.encode('one|'),
            utf8.encode('two|'),
            utf8.encode('three'),
          ]),
          contentType: 'text/plain',
        );
      });

      final client = HttpClient();
      final req = await client.get('127.0.0.1', server.port, '/stream');
      final res = await req.close();

      expect(res.statusCode, 200);
      // No content-length was set, so dart:io must chunk the response.
      expect(res.headers.value('content-length'), isNull);
      expect(await res.transform(utf8.decoder).join(), 'one|two|three');
      client.close();
    });

    test('buffered responses still work unchanged', () async {
      router.get('/buffered', (req) async => BloomResponse.text('plain body'));

      final client = HttpClient();
      final req = await client.get('127.0.0.1', server.port, '/buffered');
      final res = await req.close();

      expect(res.statusCode, 200);
      expect(await res.transform(utf8.decoder).join(), 'plain body');
      client.close();
    });

    test('middleware can still mutate headers on a streaming response', () async {
      // The whole design rests on this: the response travels back up the
      // middleware chain before any byte is written, so late header
      // mutation stays legal exactly as it is for buffered responses.
      router.use(BloomCorsMiddleware(allowOrigin: 'https://example.com'));
      router.get('/cors-stream', (req) async {
        return BloomResponse.stream(
          Stream<List<int>>.fromIterable([utf8.encode('body')]),
        );
      });

      final client = HttpClient();
      final req = await client.get('127.0.0.1', server.port, '/cors-stream');
      final res = await req.close();

      expect(res.headers.value('access-control-allow-origin'),
          'https://example.com');
      expect(await res.transform(utf8.decoder).join(), 'body');
      client.close();
    });

    test('HEAD sends no body and does not leak the stream', () async {
      var cancelled = false;
      final controller = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      controller.add(utf8.encode('should not be sent'));

      router.get('/head-stream', (req) async {
        return BloomResponse.stream(controller.stream);
      });

      final client = HttpClient();
      final req = await client.open('HEAD', '127.0.0.1', server.port, '/head-stream');
      final res = await req.close();

      expect(res.statusCode, 200);
      expect(await res.transform(utf8.decoder).join(), isEmpty);
      // Without an explicit cancel the subscription would stay open forever.
      expect(cancelled, isTrue);
      client.close();
      await controller.close();
    });
  });
```

Add these imports to the top of the test file:

```dart
import 'dart:async';
import 'dart:io';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/bloom_server && dart test test/streaming_response_test.dart`
Expected: FAIL — the `/stream` test receives an empty body, because `handleIoRequest` writes the empty buffered `body`.

- [ ] **Step 3: Write minimal implementation**

In `packages/bloom_server/lib/src/server/api_router.dart`, replace these three lines in `handleIoRequest`:

```dart
      ioReq.response.statusCode = bloomRes.statusCode;
      bloomRes.headers.forEach((k, v) => ioReq.response.headers.set(k, v));
      ioReq.response.add(bloomRes.body);
      await ioReq.response.close();
```

with:

```dart
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
```

Then in `handleRequest`, fix the HEAD branch so it does not leak the stream. Replace:

```dart
            if (method == 'HEAD') {
              return BloomResponse(
                statusCode: res.statusCode,
                headers: res.headers,
                body: null,
              );
            }
```

with:

```dart
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
```

Ensure `import 'dart:async';` is present at the top of `api_router.dart` for `unawaited`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_server && dart test test/streaming_response_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Run the full suite for regressions**

Run: `cd packages/bloom_server && dart test`
Expected: all pass, including `rpc_mount_test.dart`.

- [ ] **Step 6: Mirror into bloom_framework and verify byte-identity**

```bash
cp packages/bloom_server/lib/src/server/api_router.dart \
   packages/bloom_framework/lib/src/server/api_router.dart
diff packages/bloom_server/lib/src/server/api_router.dart \
     packages/bloom_framework/lib/src/server/api_router.dart && echo IDENTICAL
cd packages/bloom_framework && dart analyze
```
Expected: `IDENTICAL`, then `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add packages/bloom_server/lib/src/server/api_router.dart \
        packages/bloom_framework/lib/src/server/api_router.dart \
        packages/bloom_server/test/streaming_response_test.dart
git commit -m "feat(bloom_server): write streaming response bodies incrementally"
```

---

### Task 3: Add a file-streaming helper

**Files:**
- Modify: `packages/bloom_server/lib/src/server/bloom_response.dart`
- Modify: `packages/bloom_framework/lib/src/server/bloom_response.dart`
- Test: `packages/bloom_server/test/streaming_response_test.dart` (extend)

**Interfaces:**
- Consumes: `BloomResponse.stream` from Task 1.
- Produces: `factory BloomResponse.file(File file, {String? contentType, int statusCode = 200, Map<String, String>? headers})`.

**Rationale:** serving a file is the most common reason to stream, and doing it by hand invites the buffered `readAsBytes` mistake this whole plan exists to remove. `content-length` *is* set here, because a file's length is known — that gives clients a progress bar and avoids chunked encoding.

- [ ] **Step 1: Write the failing test**

Append inside `main()`:

```dart
  group('BloomResponse.file', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bloom_file_stream_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('streams file contents and sets a known content-length', () async {
      final file = File('${tempDir.path}/data.txt');
      await file.writeAsString('file contents here');

      final res = BloomResponse.file(file, contentType: 'text/plain');

      expect(res.isStreaming, isTrue);
      // A file's size is known, so we can be precise rather than chunking.
      expect(res.headers['content-length'], '18');
      expect(res.headers['content-type'], 'text/plain');

      final bytes = await res.takeBodyStream().expand((c) => c).toList();
      expect(utf8.decode(bytes), 'file contents here');
    });

    test('throws for a missing file', () {
      final missing = File('${tempDir.path}/nope.txt');
      expect(() => BloomResponse.file(missing), throwsA(isA<FileSystemException>()));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/bloom_server && dart test test/streaming_response_test.dart`
Expected: FAIL — `The method 'file' isn't defined for the type 'BloomResponse'`.

- [ ] **Step 3: Write minimal implementation**

Add `import 'dart:io';` to `bloom_response.dart`, then add this factory:

```dart
  /// Streams [file] from disk without loading it into memory.
  ///
  /// Unlike [BloomResponse.stream], `content-length` is set: a file's size is
  /// known ahead of time, which lets clients show real progress and avoids
  /// chunked encoding. Throws [FileSystemException] if [file] does not exist.
  factory BloomResponse.file(
    File file, {
    String? contentType,
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    if (!file.existsSync()) {
      throw FileSystemException('File not found', file.path);
    }
    return BloomResponse.stream(
      file.openRead(),
      statusCode: statusCode,
      contentType: contentType,
      headers: {
        'content-length': file.lengthSync().toString(),
        ...?headers,
      },
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_server && dart test test/streaming_response_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 5: Mirror, analyze, and run the full suite**

```bash
cp packages/bloom_server/lib/src/server/bloom_response.dart \
   packages/bloom_framework/lib/src/server/bloom_response.dart
diff packages/bloom_server/lib/src/server/bloom_response.dart \
     packages/bloom_framework/lib/src/server/bloom_response.dart && echo IDENTICAL
cd packages/bloom_server && dart analyze && dart test
cd ../bloom_framework && dart analyze
```
Expected: `IDENTICAL`, `No issues found!`, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_server/lib/src/server/bloom_response.dart \
        packages/bloom_framework/lib/src/server/bloom_response.dart \
        packages/bloom_server/test/streaming_response_test.dart
git commit -m "feat(bloom_server): add BloomResponse.file for zero-copy file serving"
```

---

### Task 4: Stream the SSR reverse proxy

**Files:**
- Modify: `packages/bloom_cli/lib/src/web/ssr_engine.dart` — the `_forwardProxyRequest` string emitted by `_generateServerDartCode`
- Test: `packages/bloom_cli/test/deployment/ssr_proxy_generation_test.dart` (create)

**Interfaces:**
- Consumes: `BloomResponse.stream` from Task 1.
- Produces: no new API. The generated `build/server.dart` no longer buffers proxied responses.

**Rationale:** this is the code path that motivated the plan. It currently ends with `await upstreamRes.fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk))`.

- [ ] **Step 1: Write the failing test**

Create `packages/bloom_cli/test/deployment/ssr_proxy_generation_test.dart`:

```dart
import 'dart:io';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:bloom_cli/src/web/ssr_engine.dart';
import 'package:test/test.dart';

void main() {
  group('generated SSR proxy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bloom_ssr_proxy_');
      File('${tempDir.path}/bloom.yaml').writeAsStringSync('''
name: proxyprobe
proxy:
  "/gh":
    target: "https://github.com"
    strip_prefix: true
''');
      Directory('${tempDir.path}/lib/app/pages').createSync(recursive: true);
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('streams the upstream body instead of buffering it', () async {
      final project = BloomProject.find(tempDir)!;
      final generated = await BloomSsrEngine(project: project).generate();
      final code = generated.readAsStringSync();

      expect(code, contains('BloomResponse.stream('));
      // The buffering fold is exactly what this task removes.
      expect(code, isNot(contains('fold<List<int>>')));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/bloom_cli && dart test test/deployment/ssr_proxy_generation_test.dart`
Expected: FAIL — generated code still contains `fold<List<int>>`.

- [ ] **Step 3: Write minimal implementation**

In `ssr_engine.dart`, inside the emitted `_forwardProxyRequest` source, replace:

```dart
    final bodyBytes = await upstreamRes.fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));

    return BloomResponse(
      statusCode: upstreamRes.statusCode,
      headers: responseHeaders,
      body: Uint8List.fromList(bodyBytes),
    );
```

with:

```dart
    // Stream the upstream straight through. Buffering here would hold an
    // entire proxied response in memory and delay first byte until the
    // upstream finished.
    return BloomResponse.stream(
      upstreamRes,
      statusCode: upstreamRes.statusCode,
      headers: responseHeaders,
    );
```

Remove `content-length` from `responseHeaders` before returning, since the proxied body may be re-encoded:

```dart
    responseHeaders.remove('content-length');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_cli && dart test test/deployment/ssr_proxy_generation_test.dart`
Expected: PASS.

- [ ] **Step 5: Type-check the generated output**

The generated server is not covered by any package's analyzer. Verify it manually:

```bash
mkdir -p /tmp/ssrcheck/lib
cat > /tmp/ssrcheck/pubspec.yaml <<'EOF'
name: ssrcheck
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  path: any
  bloom_framework:
    path: /root/dev/Bloom/packages/bloom_framework
  bloom_cli:
    path: /root/dev/Bloom/packages/bloom_cli
EOF
# regenerate a server into /tmp/ssrprobe first, then:
cp /tmp/ssrprobe/build/server.dart /tmp/ssrcheck/lib/server.dart
cd /tmp/ssrcheck && dart pub get && dart analyze
```
Expected: zero *errors*. Three pre-existing warnings (`_isRevalidating`, `_isrCache`, `server` unused) are expected when the probe project has no page routes and are unrelated.

- [ ] **Step 6: Run the full bloom_cli suite**

Run: `cd packages/bloom_cli && dart test -j 2`
Expected: all pass. Use `-j 2`; at `-j 4` the Phase 12 integration test intermittently exceeds its 30s timeout under load.

- [ ] **Step 7: Commit**

```bash
git add packages/bloom_cli/lib/src/web/ssr_engine.dart \
        packages/bloom_cli/test/deployment/ssr_proxy_generation_test.dart
git commit -m "feat(bloom_cli): stream proxied responses in the generated SSR server"
```

---

## Self-Review

**1. Spec coverage.** The Background lists four consequences. Memory residency, time-to-first-byte, and backpressure are addressed by Tasks 1–2 (`addStream` propagates backpressure natively). SSE is *not* fully addressed — see Out of Scope below. File serving (Task 3) and the proxy path (Task 4) are the two concrete callers.

**2. Placeholder scan.** No TBDs; every code step carries the actual code. The one manual procedure (Task 4 Step 5) is spelled out with real commands.

**3. Type consistency.** `takeBodyStream()`, `isStreaming`, `BloomResponse.stream`, and `BloomResponse.file` are named identically in every task that uses them. Task 2 consumes only what Task 1 produces; Tasks 3 and 4 consume `BloomResponse.stream` from Task 1.

## Out of Scope

- **SSE / long-lived streams.** This plan makes bodies incremental, but a route still returns one response. Real SSE also needs flush control, keep-alive, and disconnect detection. `bloom_realtime` already handles push via WebSocket upgrade (`WebSocketTransformer.upgrade`), so SSE is a separate, later decision.
- **Streaming *request* bodies.** `_readStreamBytes` still buffers uploads. Same class of problem, different direction, and it interacts with `maxRequestBodyBytes` enforcement.
- **De-duplicating `bloom_framework` and `bloom_server`.** The copy-paste is a real liability that this plan works around with `cp` + `diff` rather than fixing. Worth its own plan; doing it here would bury a four-task change inside a package restructure.
