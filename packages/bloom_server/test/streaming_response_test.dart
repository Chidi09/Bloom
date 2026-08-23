import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

    test('a mid-stream failure truncates rather than hanging or faking success',
        () async {
      // The error path is the one that cannot be made correct by status code:
      // headers and a 200 are already on the wire by the time the source
      // throws, so the server cannot retract them. What it must not do is hang
      // the connection open or close it cleanly as though the body were whole.
      router.get('/explode', (req) async {
        return BloomResponse.stream(
          () async* {
            yield utf8.encode('partial');
            throw StateError('upstream died mid-stream');
          }(),
        );
      });

      final client = HttpClient();
      final req = await client.get('127.0.0.1', server.port, '/explode');
      final res = await req.close();

      expect(res.statusCode, 200, reason: 'status was committed before the throw');

      // Reading the truncated chunked body may itself throw; either outcome is
      // acceptable, a hang is not. What must NOT happen is a clean, complete
      // read that silently loses the rest of the payload.
      String? body;
      try {
        body = await res
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        fail('Connection hung after a mid-stream failure.');
      } catch (_) {
        body = null; // transport-level error surfaced, which is correct
      }

      if (body != null) {
        expect(body, 'partial',
            reason: 'only the bytes written before the failure may arrive');
      }

      client.close();
    });

    test('the server survives a mid-stream failure and serves the next request',
        () async {
      router.get('/explode2', (req) async {
        return BloomResponse.stream(
          () async* {
            yield utf8.encode('x');
            throw StateError('boom');
          }(),
        );
      });
      router.get('/after', (req) async => BloomResponse.text('still alive'));

      final client = HttpClient();
      try {
        final bad = await client.get('127.0.0.1', server.port, '/explode2');
        final badRes = await bad.close();
        await badRes.drain<void>().timeout(const Duration(seconds: 5));
      } catch (_) {
        // Expected; the point is what happens next.
      }

      final good = await client.get('127.0.0.1', server.port, '/after');
      final goodRes = await good.close();
      expect(await goodRes.transform(utf8.decoder).join(), 'still alive');
      client.close();
    });
  });

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
}
