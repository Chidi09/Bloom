import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bloom_cli/src/dev/ddc_dev_compiler.dart';
import 'package:bloom_cli/src/dev/live_reload_server.dart';
import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:test/test.dart';

void main() {
  group('In-Page Fast Remount (DDC Dev Loop)', () {
    late Directory tempDir;
    late Directory webDir;
    late Directory libDir;
    late DdcToolchain toolchain;
    late File packageConfig;
    Browser? browser;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('bloom_hot_remount_test_');
      webDir = Directory(p.join(tempDir.path, 'web'))..createSync();
      libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();

      // Use the root monorepo toolchain and package_config
      toolchain = DdcToolchain.discover(projectRoot: tempDir);
      await toolchain.ensureSdkArtifacts();

      packageConfig = File(
          '/root/dev/Bloom/examples/bloom_js_ecommerce/web/.dart_tool/package_config.json');

      browser = await puppeteer.launch(
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
      );
    });

    tearDown(() async {
      await browser?.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('DDC hot-remount updates DOM in place without browser navigation', () async {
      final entryFile = File(p.join(libDir.path, 'main.dart'));
      final outputFile = File(p.join(webDir.path, 'main.js'));
      final indexHtml = File(p.join(webDir.path, 'index.html'));

      indexHtml.writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Hot Remount Test</title>
</head>
<body>
  <div id="app"></div>
</body>
</html>
''');

      // Version 1 of fixture app
      entryFile.writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  mount(
    Div(children: [
      H1(text: 'Version 1 - Alpha Initial'),
      P(text: 'Static paragraph'),
    ]),
    '#app',
  );
}
''');

      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entryFile,
        outputFile: outputFile,
        packageConfigFile: packageConfig,
        moduleName: 'main',
      );

      final compile1 = await compiler.compile();
      expect(compile1.success, isTrue, reason: 'Initial compile failed: ${compile1.error}');

      final devServer = BloomLiveReloadServer(
        webDir: webDir,
        host: '127.0.0.1',
        port: 0,
        autoInjectScript: true,
        isDdcMode: true,
        ddcCacheDir: toolchain.cacheDir,
      );
      await devServer.start();
      final port = devServer.server!.port;

      try {
        final page = await browser!.newPage();
        await page.goto('http://127.0.0.1:$port', wait: Until.domContentLoaded);

        // Wait for initial render
        String? initialH1;
        for (var i = 0; i < 50; i++) {
          initialH1 = await page.evaluate(r'''
            (() => {
              const h1 = document.querySelector('#app h1');
              return h1 ? h1.textContent : null;
            })()
          ''') as String?;
          if (initialH1 == 'Version 1 - Alpha Initial') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(initialH1, equals('Version 1 - Alpha Initial'));

        // Install sentinels to verify no browser navigation or document replacement occurs
        await page.evaluate(r'''
          (() => {
            window.__bloomTestSentinel = 424242;
            window.__navigationOccurred = false;
            window.addEventListener('beforeunload', () => {
              window.__navigationOccurred = true;
            });
          })()
        ''');

        // Version 2 of fixture app
        entryFile.writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  mount(
    Div(children: [
      H1(text: 'Version 2 - Beta Remounted'),
      P(text: 'Updated paragraph content'),
    ]),
    '#app',
  );
}
''');

        final compile2 = await compiler.compile();
        expect(compile2.success, isTrue, reason: 'Second compile failed: ${compile2.error}');

        // Trigger hot-remount SSE broadcast
        devServer.broadcastHotRemount(reason: 'main.dart');

        // Wait for remount to update the DOM
        String? remountedH1;
        for (var i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          remountedH1 = await page.evaluate(r'''
            (() => {
              const h1 = document.querySelector('#app h1');
              return h1 ? h1.textContent : null;
            })()
          ''') as String?;
          if (remountedH1 == 'Version 2 - Beta Remounted') break;
        }

        expect(remountedH1, equals('Version 2 - Beta Remounted'));

        // Verify page identity / state: window sentinel intact, no beforeunload fired
        final stateJson = await page.evaluate(r'''
          (() => JSON.stringify({
            sentinel: window.__bloomTestSentinel,
            navigationOccurred: window.__navigationOccurred,
            pText: document.querySelector('#app p') ? document.querySelector('#app p').textContent : null
          }))()
        ''');
        final state = jsonDecode(stateJson as String) as Map<String, dynamic>;

        expect(state['sentinel'], equals(424242),
            reason: 'Window sentinel survived in-place remount (no page reload)');
        expect(state['navigationOccurred'], isFalse,
            reason: 'No beforeunload / page navigation occurred during hot-remount');
        expect(state['pText'], equals('Updated paragraph content'));
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('deliberate error in second main() invocation renders dev error overlay in DOM', () async {
      final entryFile = File(p.join(libDir.path, 'main.dart'));
      final outputFile = File(p.join(webDir.path, 'main.js'));
      final indexHtml = File(p.join(webDir.path, 'index.html'));

      indexHtml.writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Hot Remount Error Overlay Test</title>
</head>
<body>
  <div id="app"></div>
</body>
</html>
''');

      // Version 1: healthy app
      entryFile.writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  mount(
    Div(children: [
      H1(text: 'Healthy Application'),
    ]),
    '#app',
  );
}
''');

      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entryFile,
        outputFile: outputFile,
        packageConfigFile: packageConfig,
        moduleName: 'main',
      );

      final compile1 = await compiler.compile();
      expect(compile1.success, isTrue, reason: 'Test 2 initial compile failed: ${compile1.error}');

      final devServer = BloomLiveReloadServer(
        webDir: webDir,
        host: '127.0.0.1',
        port: 0,
        autoInjectScript: true,
        isDdcMode: true,
        ddcCacheDir: toolchain.cacheDir,
      );
      await devServer.start();
      final port = devServer.server!.port;

      try {
        final page = await browser!.newPage();
        await page.goto('http://127.0.0.1:$port', wait: Until.domContentLoaded);

        String? initialH1;
        for (var i = 0; i < 50; i++) {
          initialH1 = await page.evaluate(r'''
            (() => document.querySelector('#app h1') ? document.querySelector('#app h1').textContent : null)()
          ''') as String?;
          if (initialH1 == 'Healthy Application') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(initialH1, equals('Healthy Application'));

        // Version 2: main() throws an unhandled exception on execution
        entryFile.writeAsStringSync('''
void main() {
  throw StateError('Simulated runtime crash during hot remount');
}
''');

        final compile2 = await compiler.compile();
        expect(compile2.success, isTrue, reason: 'Test 2 recompile failed: ${compile2.error}');

        devServer.broadcastHotRemount(reason: 'main.dart');

        // Wait for error overlay to appear
        bool overlayFound = false;
        String? overlayText;
        for (var i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          final resJson = await page.evaluate(r'''
            (() => {
              const overlay = document.querySelector('[data-bloom-dev-error-overlay]');
              return JSON.stringify({
                exists: !!overlay,
                text: overlay ? overlay.textContent : null
              });
            })()
          ''');
          final res = jsonDecode(resJson as String) as Map<String, dynamic>;
          if (res['exists'] == true) {
            overlayFound = true;
            overlayText = res['text'] as String?;
            break;
          }
        }

        expect(overlayFound, isTrue,
            reason: 'Dev error overlay should be rendered when re-invoked main() throws');
        expect(overlayText, contains('Simulated runtime crash during hot remount'));
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('non-DDC dev path broadcasts reload and performs full browser page navigation', () async {
      final indexHtml = File(p.join(webDir.path, 'index.html'));
      indexHtml.writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Dart2js Reload Test</title>
</head>
<body>
  <div id="app"><h1>Non-DDC App</h1></div>
</body>
</html>
''');

      final devServer = BloomLiveReloadServer(
        webDir: webDir,
        host: '127.0.0.1',
        port: 0,
        autoInjectScript: true,
        isDdcMode: false,
      );
      await devServer.start();
      final port = devServer.server!.port;

      try {
        final page = await browser!.newPage();
        await page.goto('http://127.0.0.1:$port', wait: Until.domContentLoaded);
        await Future.delayed(const Duration(milliseconds: 600));

        // Install sentinel
        await page.evaluate(r'''
          (() => {
            window.__nonDdcSentinel = 777;
          })()
        ''');

        final initialSentinel = await page.evaluate(r'''
          (() => window.__nonDdcSentinel)()
        ''');
        expect(initialSentinel, equals(777));

        // Broadcast standard reload
        devServer.broadcastReload(reason: 'style.css');

        // Wait for page reload to happen and wipe __nonDdcSentinel
        dynamic postReloadSentinel = 777;
        for (var i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          try {
            postReloadSentinel = await page.evaluate(r'''
              (() => typeof window.__nonDdcSentinel !== 'undefined' ? window.__nonDdcSentinel : null)()
            ''');
            if (postReloadSentinel == null) break;
          } catch (_) {
            // During navigation page context may briefly throw
          }
        }

        expect(postReloadSentinel, isNull,
            reason: 'Full page reload should clear JavaScript global state for non-DDC mode');
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
