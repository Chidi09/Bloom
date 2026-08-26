import 'dart:async';
import 'dart:io';
import 'package:bloom_cli/src/dev/ddc_dev_compiler.dart';
import 'package:bloom_cli/src/dev/live_reload_server.dart';
import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:test/test.dart';

void main() {
  group('Signal State-Preserving Hot Remount (End-to-End)', () {
    late Directory tempDir;
    late Directory webDir;
    late Directory libDir;
    late DdcToolchain toolchain;
    late File packageConfig;
    Browser? browser;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('bloom_signal_hot_remount_test_');
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

    test('auto-keyed top-level signal preserves mutated state across hot remount after adding unrelated signal', () async {
      final entryFile = File(p.join(libDir.path, 'main.dart'));
      final outputFile = File(p.join(webDir.path, 'main.js'));
      final indexHtml = File(p.join(webDir.path, 'index.html'));

      indexHtml.writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Signal Hot Remount Test</title>
</head>
<body>
  <div id="app"></div>
</body>
</html>
''');

      // Version 1: App with an auto-keyed top-level signal and an increment button
      entryFile.writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

final count = signal(0);

void main() {
  mount(
    Div(children: [
      H1(text: 'Version 1 - Initial State'),
      Live(() => P(className: 'count-value', text: 'Count: \${count.value}')),
      Button(
        className: 'inc-btn',
        text: 'Increment',
        on: {'click': (_) => count.value++},
      ),
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
            (() => document.querySelector('#app h1') ? document.querySelector('#app h1').textContent : null)()
          ''') as String?;
          if (initialH1 == 'Version 1 - Initial State') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(initialH1, equals('Version 1 - Initial State'));

        // Verify initial count is 0
        final countText1 = await page.evaluate(r'''
          (() => document.querySelector('.count-value') ? document.querySelector('.count-value').textContent : null)()
        ''') as String?;
        expect(countText1, equals('Count: 0'));

        // Mutate the signal value in the browser via button click
        await page.click('.inc-btn');
        await page.click('.inc-btn');
        await page.click('.inc-btn');

        final countTextAfterClicks = await page.evaluate(r'''
          (() => document.querySelector('.count-value') ? document.querySelector('.count-value').textContent : null)()
        ''') as String?;
        expect(countTextAfterClicks, equals('Count: 3'), reason: 'Signal should have incremented to 3');

        // Version 2: Edit source by adding an UNRELATED signal ABOVE the tracked one
        // and changing the H1 heading. This specifically tests that the key is NOT a
        // naive whole-file ordinal counter (which would shift from 0 to 1).
        entryFile.writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

final unrelatedSignalAbove = signal('unrelated_value');
final count = signal(0);

void main() {
  mount(
    Div(children: [
      H1(text: 'Version 2 - Hot Remounted with Preserved State'),
      Live(() => P(className: 'count-value', text: 'Count: \${count.value}')),
      Button(
        className: 'inc-btn',
        text: 'Increment',
        on: {'click': (_) => count.value++},
      ),
    ]),
    '#app',
  );
}
''');

        final compile2 = await compiler.compile();
        expect(compile2.success, isTrue, reason: 'Recompile failed: ${compile2.error}');

        // Broadcast hot remount
        devServer.broadcastHotRemount(reason: 'main.dart');

        // Wait for DOM to update with Version 2 heading
        String? remountedH1;
        for (var i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          remountedH1 = await page.evaluate(r'''
            (() => document.querySelector('#app h1') ? document.querySelector('#app h1').textContent : null)()
          ''') as String?;
          if (remountedH1 == 'Version 2 - Hot Remounted with Preserved State') break;
        }

        expect(remountedH1, equals('Version 2 - Hot Remounted with Preserved State'));

        // Assert the mutated count (3) survived the remount and was NOT reset to 0!
        final countTextAfterRemount = await page.evaluate(r'''
          (() => document.querySelector('.count-value') ? document.querySelector('.count-value').textContent : null)()
        ''') as String?;
        expect(countTextAfterRemount, equals('Count: 3'),
            reason: 'Signal state must survive hot remount despite unrelated signal added above it');
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('signal type mismatch between edits cleanly falls back to new initialValue without crashing', () async {
      final entryFile = File(p.join(libDir.path, 'main.dart'));
      final outputFile = File(p.join(webDir.path, 'main.js'));
      final indexHtml = File(p.join(webDir.path, 'index.html'));

      indexHtml.writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Signal Type Mismatch Fallback Test</title>
</head>
<body>
  <div id="app"></div>
</body>
</html>
''');

      // Version 1: typed int signal
      entryFile.writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

final dataField = signal<int>(100);

void main() {
  mount(
    Div(children: [
      H1(text: 'Type Test V1'),
      Live(() => P(className: 'data-display', text: 'Data: \${dataField.value}')),
      Button(
        className: 'mutate-btn',
        text: 'Mutate',
        on: {'click': (_) => dataField.value = 500},
      ),
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

        String? initialH1;
        for (var i = 0; i < 50; i++) {
          initialH1 = await page.evaluate(r'''
            (() => document.querySelector('#app h1') ? document.querySelector('#app h1').textContent : null)()
          ''') as String?;
          if (initialH1 == 'Type Test V1') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(initialH1, equals('Type Test V1'));

        // Mutate int signal to 500
        await page.click('.mutate-btn');
        final dataText1 = await page.evaluate(r'''
          (() => document.querySelector('.data-display') ? document.querySelector('.data-display').textContent : null)()
        ''') as String?;
        expect(dataText1, equals('Data: 500'));

        // Version 2: Change the declared signal type at the same call site from int to String
        entryFile.writeAsStringSync('''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

final dataField = signal<String>('hello_string_state');

void main() {
  mount(
    Div(children: [
      H1(text: 'Type Test V2 - Type Changed'),
      Live(() => P(className: 'data-display', text: 'Data: \${dataField.value}')),
    ]),
    '#app',
  );
}
''');

        final compile2 = await compiler.compile();
        expect(compile2.success, isTrue, reason: 'Recompile failed: ${compile2.error}');

        devServer.broadcastHotRemount(reason: 'main.dart');

        // Wait for V2 render
        String? remountedH1;
        for (var i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          remountedH1 = await page.evaluate(r'''
            (() => document.querySelector('#app h1') ? document.querySelector('#app h1').textContent : null)()
          ''') as String?;
          if (remountedH1 == 'Type Test V2 - Type Changed') break;
        }

        expect(remountedH1, equals('Type Test V2 - Type Changed'));

        // Assert the new string signal cleanly reset to 'hello_string_state' without crashing
        final dataText2 = await page.evaluate(r'''
          (() => document.querySelector('.data-display') ? document.querySelector('.data-display').textContent : null)()
        ''') as String?;
        expect(dataText2, equals('Data: hello_string_state'),
            reason: 'Type mismatch at call site must safely fall back to fresh initialValue');
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
