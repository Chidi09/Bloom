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
      await indexHtml.writeAsString(
          '<!DOCTYPE html><html><body><h1>Hello Bloom</h1></body></html>');

      testPort = 19876;
      devServer = BloomLiveReloadServer(
        webDir: tempWebDir,
        host: '127.0.0.1',
        port: testPort,
      );
      await devServer.start();
    });

    test('defaults to loopback and requires an explicit LAN host', () async {
      final localServer = BloomLiveReloadServer(webDir: tempWebDir);
      expect(localServer.host, '127.0.0.1');
      expect(
        BloomLiveReloadServer(webDir: tempWebDir, host: '0.0.0.0').host,
        '0.0.0.0',
      );

      final boundServer = BloomLiveReloadServer(webDir: tempWebDir, port: 0);
      addTearDown(boundServer.stop);
      await boundServer.start();
      expect(boundServer.server!.address.address, '127.0.0.1');
    });

    tearDown(() async {
      await devServer.stop();
      if (tempWebDir.existsSync()) {
        await tempWebDir.delete(recursive: true);
      }
    });

    test('serves index.html with live reload script automatically injected',
        () async {
      final client = HttpClient();
      final req = await client.get('127.0.0.1', testPort, '/');
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 200);
      expect(body, contains('__BLOOM_HR_ACTIVE__'));
      expect(body, contains('EventSource(\'/_bloom_hr\')'));
      expect(body, contains('data-bloom-devtools-host'));
      expect(body, contains('attachShadow'));
      expect(body, contains('Bloom DevTools'));
      expect(body, contains('role="dialog"'));
      client.close(force: true);
    });

    test(
        'DDC mode removes the scaffold main.js script before injecting its bootstrap',
        () async {
      await devServer.stop();
      await File('${tempWebDir.path}/index.html').writeAsString('''
<!DOCTYPE html>
<html>
<head>
  <script type="module">window.npmBootstrapLoaded = true;</script>
</head>
<body>
  <div id="app"></div>
  <script defer src="/main.js?v=dev"></script>
</body>
</html>
''');
      devServer = BloomLiveReloadServer(
        webDir: tempWebDir,
        host: '127.0.0.1',
        port: testPort,
        isDdcMode: true,
      );
      await devServer.start();

      final client = HttpClient();
      final req = await client.get('127.0.0.1', testPort, '/');
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 200);
      expect(body, contains('window.npmBootstrapLoaded = true'));
      expect(body, isNot(contains('src="/main.js?v=dev"')));
      expect(body, contains('Bloom DDC Dev Bootstrap'));
      expect(body, contains('__BLOOM_HR_ACTIVE__'));
      expect(body, contains('__bloomPrepareHotEffects'));
      expect(body, contains('__bloomDisposePreviousHotEffects'));
      client.close(force: true);
    });

    test('DDC bootstrap safely renders app and module-load errors', () {
      final bootstrap = BloomLiveReloadServer.ddcBootstrapScript;

      expect(bootstrap, contains('function reportDdcError(err, label)'));
      expect(bootstrap,
          contains('reportDdcError(err, \'[Bloom DDC Main Error]\')'));
      expect(
          bootstrap,
          contains(
              'reportDdcError(err, \'[Bloom DDC Error] Failed to load application modules:\')'));
      expect(bootstrap, contains('detail.textContent = message'));
      expect(bootstrap, contains('trace.textContent = stack'));
      expect(bootstrap, contains('window.__bloomPrepareHotEffects()'));
      expect(bootstrap, contains('window.__bloomDisposePreviousHotEffects()'));
      expect(
        bootstrap.indexOf('__bloomPrepareHotEffects()'),
        lessThan(bootstrap.indexOf("require.undef('main')")),
      );
      expect(
        bootstrap.indexOf('app[k].main();'),
        lessThan(bootstrap.indexOf('__bloomDisposePreviousHotEffects()')),
      );
      expect(
          bootstrap,
          contains(
              'Preserve the mounted tree until the updated main() calls mount()'));
      expect(bootstrap, isNot(contains('__bloomDisposeActiveMount();')));
      expect(bootstrap, isNot(contains('host.innerHTML =')));
    });

    test('establishes SSE stream on /_bloom_hr and receives broadcast',
        () async {
      final socket = await Socket.connect('127.0.0.1', testPort);
      socket.write('GET /_bloom_hr HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n');
      await socket.flush();

      final completer = Completer<String>();
      final sub =
          socket.cast<List<int>>().transform(utf8.decoder).listen((data) {
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

    test('broadcasts structured error payload for the dev overlay', () async {
      final socket = await Socket.connect('127.0.0.1', testPort);
      socket.write('GET /_bloom_hr HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n');
      await socket.flush();

      final completer = Completer<String>();
      socket.cast<List<int>>().transform(utf8.decoder).listen((data) {
        if (!completer.isCompleted && data.contains('event: error')) {
          completer.complete(data);
        }
      });

      await Future.delayed(const Duration(milliseconds: 50));
      devServer.broadcastError(
        'Expected ;',
        kind: 'build',
        file: 'lib/main.dart',
        line: 12,
        column: 7,
        codeFrame: '11 | return 1;\n12 | return 2',
        stack: 'main.dart:12:7',
      );

      final received =
          await completer.future.timeout(const Duration(seconds: 2));
      expect(received, contains('event: error'));
      expect(received, contains('"kind":"build"'));
      expect(received, contains('"file":"lib/main.dart"'));
      expect(received, contains('"line":12'));
      expect(received, contains('"column":7'));
      expect(
          received, contains('"codeFrame":"11 | return 1;\\n12 | return 2"'));

      await socket.close();
    });
  });
}
