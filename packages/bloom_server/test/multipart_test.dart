// test/multipart_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bloom_server/bloom_server.dart';
import 'package:test/test.dart';

void main() {
  const boundary = '----BloomTestBoundary12345';

  group('Multipart Parser - Fields and File Parsing', () {
    test('parses two fields plus a file with metadata and streaming bytes',
        () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="username"\r\n',
        '\r\n',
        'chidi_dev\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="role"\r\n',
        '\r\n',
        'architect\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="document"; filename="report.pdf"\r\n',
        'Content-Type: application/pdf\r\n',
        '\r\n',
        '%PDF-1.4 sample file content\r\n',
        '--$boundary--\r\n',
      ].join();

      final stream = Stream<List<int>>.value(utf8.encode(payload));
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      final parts = <BloomMultipartPart>[];
      List<int>? fileBytes;
      await for (final part in req.multipart()) {
        parts.add(part);
        if (part is BloomMultipartFile) {
          fileBytes = await part.bytes.expand((c) => c).toList();
        }
      }

      expect(parts.length, 3);

      // Part 1: Field username
      expect(parts[0], isA<BloomMultipartField>());
      final field1 = parts[0] as BloomMultipartField;
      expect(field1.name, 'username');
      expect(field1.value, 'chidi_dev');
      expect(
          field1.headers['content-disposition'], 'form-data; name="username"');

      // Part 2: Field role
      expect(parts[1], isA<BloomMultipartField>());
      final field2 = parts[1] as BloomMultipartField;
      expect(field2.name, 'role');
      expect(field2.value, 'architect');

      // Part 3: File document
      expect(parts[2], isA<BloomMultipartFile>());
      final file = parts[2] as BloomMultipartFile;
      expect(file.name, 'document');
      expect(file.filename, 'report.pdf');
      expect(file.contentType, 'application/pdf');
      expect(file.headers['content-type'], 'application/pdf');

      expect(fileBytes, isNotNull);
      expect(utf8.decode(fileBytes!), '%PDF-1.4 sample file content');
    });

    test('parses when boundary is split across tiny 1-byte chunks', () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="title"\r\n',
        '\r\n',
        'Bloom Microframework\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="payload"; filename="data.bin"\r\n',
        'Content-Type: application/octet-stream\r\n',
        '\r\n',
        'binary-stream-test-bytes\r\n',
        '--$boundary--\r\n',
      ].join();

      final allBytes = utf8.encode(payload);
      // Stream 1 byte at a time to test byte-by-byte boundary sliding window
      final stream = Stream<List<int>>.fromIterable(
        allBytes.map((b) => [b]),
      );

      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      final parts = <BloomMultipartPart>[];
      await for (final part in req.multipart()) {
        parts.add(part);
        if (part is BloomMultipartFile) {
          final bytes = await part.bytes.expand((c) => c).toList();
          expect(utf8.decode(bytes), 'binary-stream-test-bytes');
        }
      }

      expect(parts.length, 2);
      expect(parts[0], isA<BloomMultipartField>());
      expect((parts[0] as BloomMultipartField).name, 'title');
      expect((parts[0] as BloomMultipartField).value, 'Bloom Microframework');
      expect(parts[1], isA<BloomMultipartFile>());
      expect((parts[1] as BloomMultipartFile).name, 'payload');
      expect((parts[1] as BloomMultipartFile).filename, 'data.bin');
    });

    test('handles false boundary prefixes in file stream without truncation',
        () async {
      final fakePrefix = '\r\n--${boundary.substring(0, 10)}almost_boundary';
      final fileData = 'prefix-data$fakePrefix-suffix-data';

      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="file"; filename="test.txt"\r\n',
        '\r\n',
        '$fileData\r\n',
        '--$boundary--\r\n',
      ].join();

      final stream = Stream<List<int>>.value(utf8.encode(payload));
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      final parts = <BloomMultipartPart>[];
      List<int>? fileBytes;
      await for (final part in req.multipart()) {
        parts.add(part);
        if (part is BloomMultipartFile) {
          fileBytes = await part.bytes.expand((c) => c).toList();
        }
      }

      expect(parts.length, 1);
      final file = parts[0] as BloomMultipartFile;
      expect(file.name, 'file');
      expect(fileBytes, isNotNull);
      expect(utf8.decode(fileBytes!), fileData);
    });

    test('file bytes stream may only be consumed once', () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="doc"; filename="a.txt"\r\n',
        '\r\n',
        'sample content\r\n',
        '--$boundary--\r\n',
      ].join();

      final stream = Stream<List<int>>.value(utf8.encode(payload));
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      await for (final part in req.multipart()) {
        if (part is BloomMultipartFile) {
          final stream1 = part.bytes;
          await stream1.drain<void>();
          expect(() => part.bytes, throwsStateError);
        }
      }
    });

    test('parses multiple files interspersed with form fields', () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="field1"\r\n',
        '\r\n',
        'value1\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="file1"; filename="a.txt"\r\n',
        'Content-Type: text/plain\r\n',
        '\r\n',
        'content A\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="field2"\r\n',
        '\r\n',
        'value2\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="file2"; filename="b.json"\r\n',
        'Content-Type: application/json\r\n',
        '\r\n',
        '{"status":"ok"}\r\n',
        '--$boundary--\r\n',
      ].join();

      final stream = Stream<List<int>>.value(utf8.encode(payload));
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      final parts = <BloomMultipartPart>[];
      final fileContents = <String, String>{};
      await for (final part in req.multipart()) {
        parts.add(part);
        if (part is BloomMultipartFile) {
          final bytes = await part.bytes.expand((c) => c).toList();
          fileContents[part.name] = utf8.decode(bytes);
        }
      }

      expect(parts.length, 4);

      expect(parts[0], isA<BloomMultipartField>());
      expect((parts[0] as BloomMultipartField).value, 'value1');

      expect(parts[1], isA<BloomMultipartFile>());
      final file1 = parts[1] as BloomMultipartFile;
      expect(file1.filename, 'a.txt');
      expect(fileContents['file1'], 'content A');

      expect(parts[2], isA<BloomMultipartField>());
      expect((parts[2] as BloomMultipartField).value, 'value2');

      expect(parts[3], isA<BloomMultipartFile>());
      final file2 = parts[3] as BloomMultipartFile;
      expect(file2.filename, 'b.json');
      expect(file2.contentType, 'application/json');
      expect(fileContents['file2'], '{"status":"ok"}');
    });

    test('preserves UTF-8 multi-byte characters in form fields', () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="greeting"\r\n',
        '\r\n',
        'こんにちは世界 - Привет мир - café crème\r\n',
        '--$boundary--\r\n',
      ].join();

      final stream = Stream<List<int>>.value(utf8.encode(payload));
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      final parts = await req.multipart().toList();
      expect(parts.length, 1);
      final field = parts[0] as BloomMultipartField;
      expect(field.value, 'こんにちは世界 - Привет мир - café crème');
    });

    test('BloomRequest.copyWith and isStreaming work as expected', () {
      final stream = Stream<List<int>>.value([]);
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      expect(req.isStreaming, isTrue);
      final copy = req.copyWith(method: 'PUT');
      expect(copy.method, 'PUT');
      expect(copy.isStreaming, isTrue);

      final bufferedReq = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/api'),
        body: 'hello',
      );
      expect(bufferedReq.isStreaming, isFalse);
      expect(bufferedReq.text(), 'hello');
    });

    test('empty multipart body completes cleanly', () async {
      final payload = '--$boundary--\r\n';
      final stream = Stream<List<int>>.value(utf8.encode(payload));
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      final parts = await req.multipart().toList();
      expect(parts, isEmpty);
    });

    test('parser does not emit the next part until a yielded file is drained',
        () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="file1"; filename="large.bin"\r\n',
        'Content-Type: application/octet-stream\r\n',
        '\r\n',
        'chunk1-chunk2-chunk3-data\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="field_after"\r\n',
        '\r\n',
        'after_file_value\r\n',
        '--$boundary--\r\n',
      ].join();

      final stream = Stream<List<int>>.value(utf8.encode(payload));
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      final receivedParts = <BloomMultipartPart>[];
      bool fileDrained = false;
      bool fieldReceivedBeforeDrain = false;

      final iterator = StreamIterator(req.multipart());

      // Move to first part (file1)
      expect(await iterator.moveNext(), isTrue);
      final filePart = iterator.current;
      expect(filePart, isA<BloomMultipartFile>());
      expect((filePart as BloomMultipartFile).name, 'file1');
      receivedParts.add(filePart);

      // Verify that while file is NOT drained, moving to next part is pending
      bool nextPartResolved = false;
      final nextPartFuture = iterator.moveNext().then((hasVal) {
        nextPartResolved = true;
        if (!fileDrained) {
          fieldReceivedBeforeDrain = true;
        }
        return hasVal;
      });

      // Give event loop turns to ensure parser does not prematurely advance
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(nextPartResolved, isFalse,
          reason: 'Next part must not be emitted before file stream is read');

      // Now drain the file stream
      final fileBytes = await filePart.bytes.expand((c) => c).toList();
      expect(utf8.decode(fileBytes), 'chunk1-chunk2-chunk3-data');
      fileDrained = true;

      // Next part should now resolve
      expect(await nextPartFuture, isTrue);
      expect(fieldReceivedBeforeDrain, isFalse);
      final fieldPart = iterator.current;
      expect(fieldPart, isA<BloomMultipartField>());
      final field = fieldPart as BloomMultipartField;
      expect(field.name, 'field_after');
      expect(field.value, 'after_file_value');
      receivedParts.add(fieldPart);

      // End of multipart
      expect(await iterator.moveNext(), isFalse);
      expect(receivedParts.length, 2);
    });

    test('canceling a file bytes stream discards remaining bytes and advances',
        () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="file1"; filename="large.bin"\r\n',
        '\r\n',
        '123456789012345678901234567890\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="field2"\r\n',
        '\r\n',
        'second_value\r\n',
        '--$boundary--\r\n',
      ].join();

      final stream = Stream<List<int>>.value(utf8.encode(payload));
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: stream,
      );

      final parts = <BloomMultipartPart>[];
      await for (final part in req.multipart()) {
        parts.add(part);
        if (part is BloomMultipartFile) {
          // Cancel file stream early
          final sub = part.bytes.listen((_) {});
          await sub.cancel();
        }
      }

      expect(parts.length, 2);
      expect(parts[0], isA<BloomMultipartFile>());
      expect(parts[1], isA<BloomMultipartField>());
      expect((parts[1] as BloomMultipartField).value, 'second_value');
    });
  });

  group('Multipart Guard & Error Handling', () {
    test('calling multipart on buffered JSON request throws StateError', () {
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/api/users'),
        headers: {
          'content-type': 'application/json',
        },
        body: jsonEncode({'key': 'value'}),
      );

      expect(() => req.multipart(), throwsStateError);
    });

    test(
        'calling multipart on request with non-multipart Content-Type throws FormatException',
        () async {
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/api/users'),
        headers: {
          'content-type': 'application/json',
        },
        streamBody: Stream<List<int>>.value(utf8.encode('{"key":"value"}')),
      );

      expect(() => req.multipart(), throwsFormatException);
    });

    test(
        'calling multipart with missing or empty boundary throws FormatException',
        () {
      final reqNoBoundary = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data',
        },
        streamBody: Stream<List<int>>.value([]),
      );
      expect(() => reqNoBoundary.multipart(), throwsFormatException);

      final reqEmptyBoundary = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=""',
        },
        streamBody: Stream<List<int>>.value([]),
      );
      expect(() => reqEmptyBoundary.multipart(), throwsFormatException);
    });

    test('accessing rawBody or text on a streaming request throws StateError',
        () {
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: Stream<List<int>>.value([]),
      );

      expect(req.isStreaming, isTrue);
      expect(() => req.rawBody, throwsStateError);
      expect(() => req.text(), throwsStateError);
      expect(() => req.json(), throwsStateError);
      expect(() => req.formData(), throwsStateError);
    });

    test('calling multipart twice on the same request throws StateError', () {
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: Stream<List<int>>.value(utf8.encode('--$boundary--\r\n')),
      );

      req.multipart();
      expect(() => req.multipart(), throwsStateError);
    });

    test('part missing Content-Disposition throws FormatException', () async {
      final payload = [
        '--$boundary\r\n',
        'X-Custom-Header: value\r\n',
        '\r\n',
        'field content\r\n',
        '--$boundary--\r\n',
      ].join();

      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: Stream<List<int>>.value(utf8.encode(payload)),
      );

      expect(req.multipart().toList(), throwsFormatException);
    });

    test('part missing name parameter throws FormatException', () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; filename="test.txt"\r\n',
        '\r\n',
        'content\r\n',
        '--$boundary--\r\n',
      ].join();

      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: Stream<List<int>>.value(utf8.encode(payload)),
      );

      expect(req.multipart().toList(), throwsFormatException);
    });

    test(
        'enforces maxRequestBodyBytes and throws BloomPayloadTooLargeException',
        () async {
      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="doc"; filename="large.bin"\r\n',
        '\r\n',
        '1234567890123456789012345678901234567890\r\n',
        '--$boundary--\r\n',
      ].join();

      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/upload'),
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        streamBody: Stream<List<int>>.value(utf8.encode(payload)),
        maxRequestBodyBytes: 25, // limit is smaller than payload
      );

      expect(
        () async {
          await for (final part in req.multipart()) {
            if (part is BloomMultipartFile) {
              await part.bytes.drain<void>();
            }
          }
        }(),
        throwsA(isA<BloomPayloadTooLargeException>()),
      );
    });
  });

  group('HttpServer Integration - Streaming Multipart Over Real Socket', () {
    late BloomApiRouter router;
    late HttpServer server;

    setUp(() async {
      router = BloomApiRouter();
      server = await router.serve(port: 0);
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('streams multipart upload without full buffering and responds 200',
        () async {
      router.post('/api/upload', (req) async {
        final parsed = <String, dynamic>{};
        await for (final part in req.multipart()) {
          if (part is BloomMultipartField) {
            parsed[part.name] = part.value;
          } else if (part is BloomMultipartFile) {
            final bytes = await part.bytes.expand((c) => c).toList();
            parsed[part.name] = {
              'filename': part.filename,
              'contentType': part.contentType,
              'length': bytes.length,
              'content': utf8.decode(bytes),
            };
          }
        }
        return BloomResponse.json(parsed);
      });

      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="author"\r\n',
        '\r\n',
        'Ada Lovelace\r\n',
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="code"; filename="algorithm.txt"\r\n',
        'Content-Type: text/plain\r\n',
        '\r\n',
        'function compute() { return 42; }\r\n',
        '--$boundary--\r\n',
      ].join();

      final client = HttpClient();
      final req = await client.post('127.0.0.1', server.port, '/api/upload');
      req.headers
          .set('content-type', 'multipart/form-data; boundary=$boundary');
      req.add(utf8.encode(payload));
      final res = await req.close();

      expect(res.statusCode, 200);
      final resBody = await res.transform(utf8.decoder).join();
      final json = jsonDecode(resBody) as Map<String, dynamic>;

      expect(json['author'], 'Ada Lovelace');
      final codeFile = json['code'] as Map<String, dynamic>;
      expect(codeFile['filename'], 'algorithm.txt');
      expect(codeFile['contentType'], 'text/plain');
      expect(codeFile['content'], 'function compute() { return 42; }');

      client.close();
    });

    test('returns 413 Payload Too Large when maxRequestBodyBytes is exceeded',
        () async {
      await server.close(force: true);
      router = BloomApiRouter();
      server = await router.serve(
        port: 0,
        maxRequestBodyBytes: 30, // 30-byte limit
      );

      router.post('/api/upload', (req) async {
        await for (final part in req.multipart()) {
          if (part is BloomMultipartFile) {
            await part.bytes.drain<void>();
          }
        }
        return BloomResponse.text('ok');
      });

      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="file"; filename="test.bin"\r\n',
        '\r\n',
        'A very long payload that definitely exceeds 30 bytes\r\n',
        '--$boundary--\r\n',
      ].join();

      final client = HttpClient();
      final req = await client.post('127.0.0.1', server.port, '/api/upload');
      req.headers
          .set('content-type', 'multipart/form-data; boundary=$boundary');
      req.add(utf8.encode(payload));
      final res = await req.close();

      expect(res.statusCode, 413);
      final resBody = await res.transform(utf8.decoder).join();
      final json = jsonDecode(resBody) as Map<String, dynamic>;
      expect(json['error'], contains('exceeded maximum allowed size'));

      client.close();
    });

    test(
        'real HTTP multipart handler exceeding maxRequestBodyBytes receives 413 without application try-catch',
        () async {
      await server.close(force: true);
      router = BloomApiRouter();
      server = await router.serve(
        port: 0,
        maxRequestBodyBytes: 40, // 40-byte limit
      );

      // Handler does NOT catch BloomPayloadTooLargeException or any exception
      router.post('/api/strict-upload', (req) async {
        final results = <String>[];
        await for (final part in req.multipart()) {
          if (part is BloomMultipartFile) {
            final bytes = await part.bytes.expand((c) => c).toList();
            results.add('${part.name}:${bytes.length}');
          } else if (part is BloomMultipartField) {
            results.add('${part.name}:${part.value}');
          }
        }
        return BloomResponse.json({'results': results});
      });

      final payload = [
        '--$boundary\r\n',
        'Content-Disposition: form-data; name="bigfile"; filename="heavy.dat"\r\n',
        'Content-Type: application/octet-stream\r\n',
        '\r\n',
        '01234567890123456789012345678901234567890123456789\r\n',
        '--$boundary--\r\n',
      ].join();

      final client = HttpClient();
      final req =
          await client.post('127.0.0.1', server.port, '/api/strict-upload');
      req.headers
          .set('content-type', 'multipart/form-data; boundary=$boundary');
      req.add(utf8.encode(payload));
      final res = await req.close();

      expect(res.statusCode, 413);
      final resBody = await res.transform(utf8.decoder).join();
      final json = jsonDecode(resBody) as Map<String, dynamic>;
      expect(json['statusCode'], 413);
      expect(json['error'], contains('exceeded maximum allowed size'));

      client.close();
    });
  });
}
