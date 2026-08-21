import 'dart:async';
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

      testPort = 19876;
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
      client.close(force: true);
    });

    test('establishes SSE stream on /_bloom_hr and receives broadcast', () async {
      final socket = await Socket.connect('127.0.0.1', testPort);
      socket.write('GET /_bloom_hr HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n');
      await socket.flush();

      final completer = Completer<String>();
      final sub = socket.cast<List<int>>().transform(utf8.decoder).listen((data) {
        if (!completer.isCompleted && data.contains('event: reload')) {
          completer.complete(data);
        }
      });

      // Allow registration
      await Future.delayed(const Duration(milliseconds: 50));
      expect(devServer.activeClientCount, 1);

      devServer.broadcastReload(reason: 'header.dart');
      final chunk = await completer.future.timeout(const Duration(seconds: 2));

      expect(chunk, contains('event: reload'));
      expect(chunk, contains('header.dart'));

      await sub.cancel();
      await socket.close();
    });
  });
}
