@Tags(['browser_e2e'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bloom_cli/src/dev/ddc_dev_compiler.dart';
import 'package:bloom_cli/src/dev/live_reload_server.dart';
import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:test/test.dart';
import 'fixture_package_config.dart';

void main() {
  group('Signal State-Preserving Hot Remount (End-to-End)', () {
    late Directory tempDir;
    late Directory webDir;
    late Directory libDir;
    late DdcToolchain toolchain;
    late File packageConfig;
    Browser? browser;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('bloom_signal_hot_remount_test_');
      webDir = Directory(p.join(tempDir.path, 'web'))..createSync();
      libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();

      toolchain = DdcToolchain.discover(projectRoot: tempDir);
      await toolchain.ensureSdkArtifacts();
      packageConfig = await createJsNativePackageConfig(tempDir);

      browser = await puppeteer.launch(
        headless: true,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage'
        ],
      );
    });

    tearDown(() async {
      await browser?.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
        'auto-keyed top-level signal preserves mutated state across hot remount after adding unrelated signal',
        () async {
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
import 'package:web/web.dart' as web;

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
      expect(compile1.success, isTrue,
          reason: 'Initial compile failed: ${compile1.error}');

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
        final browserErrors = <String>[];
        page.onConsole.listen((message) {
          if (message.type.name == 'error') {
            browserErrors.add(message.text ?? '');
          }
        });
        page.onError.listen((error) => browserErrors.add(error.toString()));
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
        await _waitForSseClient(devServer);

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
        expect(countTextAfterClicks, equals('Count: 3'),
            reason: 'Signal should have incremented to 3');

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
        expect(compile2.success, isTrue,
            reason: 'Recompile failed: ${compile2.error}');

        // Broadcast hot remount
        devServer.broadcastHotRemount(reason: 'main.dart');

        // Wait for DOM to update with Version 2 heading
        String? remountedH1;
        for (var i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          remountedH1 = await page.evaluate(r'''
            (() => document.querySelector('#app h1') ? document.querySelector('#app h1').textContent : null)()
          ''') as String?;
          if (remountedH1 == 'Version 2 - Hot Remounted with Preserved State')
            break;
        }

        expect(
          remountedH1,
          equals('Version 2 - Hot Remounted with Preserved State'),
          reason: 'Browser errors: $browserErrors',
        );

        // Assert the mutated count (3) survived the remount and was NOT reset to 0!
        final countTextAfterRemount = await page.evaluate(r'''
          (() => document.querySelector('.count-value') ? document.querySelector('.count-value').textContent : null)()
        ''') as String?;
        expect(countTextAfterRemount, equals('Count: 3'),
            reason:
                'Signal state must survive hot remount despite unrelated signal added above it');
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('stateful store instances preserve isolated field signals on remount',
        () async {
      final entryFile = File(p.join(libDir.path, 'main.dart'));
      final storeFile = File(p.join(libDir.path, 'store.dart'));
      final outputFile = File(p.join(webDir.path, 'main.js'));
      final indexHtml = File(p.join(webDir.path, 'index.html'));
      indexHtml.writeAsStringSync('''
<!DOCTYPE html><html><body><div id="app"></div></body></html>
''');

      String storeSource({bool addOther = false}) => '''
import 'package:bloom_js_native/bloom_js_native.dart';

class CounterStore {
  final count = signal(0);
}
${addOther ? 'class OtherStore { final value = signal(10); }' : ''}
''';

      String appSource({required String heading, bool addOther = false}) => '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'store.dart';

void main() {
  ${addOther ? 'final other = OtherStore();' : ''}
  final left = CounterStore();
  final right = CounterStore();
  mount(Div(children: [
    ${addOther ? "Live(() => P(text: 'Other: \${other.value}'))," : ''}
    H1(text: '$heading'),
    Live(() => P(className: 'left-count', text: 'Left: \${left.count.value}')),
    Button(className: 'left-inc', text: 'Left +', on: {'click': (_) => left.count.value++}),
    Live(() => P(className: 'right-count', text: 'Right: \${right.count.value}')),
    Button(className: 'right-inc', text: 'Right +', on: {'click': (_) => right.count.value++}),
  ]), '#app');
}
''';

      entryFile.writeAsStringSync(appSource(heading: 'Stores V1'));
      storeFile.writeAsStringSync(storeSource());
      final compiler = DdcDevCompiler(
        toolchain: toolchain,
        entryFile: entryFile,
        outputFile: outputFile,
        packageConfigFile: packageConfig,
        moduleName: 'main',
      );
      final compile1 = await compiler.compile();
      expect(compile1.success, isTrue,
          reason: 'Initial compile failed: ${compile1.error}');

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
        final browserErrors = <String>[];
        page.onConsole.listen((message) {
          if (message.type.name == 'error')
            browserErrors.add(message.text ?? '');
        });
        page.onError.listen((error) => browserErrors.add(error.toString()));
        await page.goto('http://127.0.0.1:$port', wait: Until.domContentLoaded);

        String? heading;
        for (var attempt = 0; attempt < 50; attempt++) {
          heading = await page.evaluate(
              'document.querySelector("#app h1")?.textContent') as String?;
          if (heading == 'Stores V1') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(heading, 'Stores V1');
        await _waitForSseClient(devServer);
        await page.click('.left-inc');
        await page.click('.left-inc');
        await page.click('.right-inc');
        await page.click('.right-inc');
        await page.click('.right-inc');
        expect(
            await page
                .evaluate('document.querySelector(".left-count")?.textContent'),
            'Left: 2');
        expect(
            await page.evaluate(
                'document.querySelector(".right-count")?.textContent'),
            'Right: 3');

        entryFile
            .writeAsStringSync(appSource(heading: 'Stores V2', addOther: true));
        storeFile.writeAsStringSync(storeSource(addOther: true));
        final compile2 = await compiler.compile();
        expect(compile2.success, isTrue,
            reason: 'Recompile failed: ${compile2.error}');
        devServer.broadcastHotRemount(reason: 'main.dart');

        heading = null;
        for (var attempt = 0; attempt < 50; attempt++) {
          await Future.delayed(const Duration(milliseconds: 100));
          heading = await page.evaluate(
              'document.querySelector("#app h1")?.textContent') as String?;
          if (heading == 'Stores V2') break;
        }
        expect(heading, 'Stores V2', reason: 'Browser errors: $browserErrors');
        expect(
            await page
                .evaluate('document.querySelector(".left-count")?.textContent'),
            'Left: 2');
        expect(
            await page.evaluate(
                'document.querySelector(".right-count")?.textContent'),
            'Right: 3');
        expect(browserErrors, isEmpty);
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
        'signal type mismatch between edits cleanly falls back to new initialValue without crashing',
        () async {
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
      expect(compile1.success, isTrue,
          reason: 'Initial compile failed: ${compile1.error}');

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
        final browserErrors = <String>[];
        page.onConsole.listen((message) {
          if (message.type.name == 'error') {
            browserErrors.add(message.text ?? '');
          }
        });
        page.onError.listen((error) => browserErrors.add(error.toString()));
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
        await _waitForSseClient(devServer);

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
        expect(compile2.success, isTrue,
            reason: 'Recompile failed: ${compile2.error}');

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

        expect(
          remountedH1,
          equals('Type Test V2 - Type Changed'),
          reason: 'Browser errors: $browserErrors',
        );

        // Assert the new string signal cleanly reset to 'hello_string_state' without crashing
        final dataText2 = await page.evaluate(r'''
          (() => document.querySelector('.data-display') ? document.querySelector('.data-display').textContent : null)()
        ''') as String?;
        expect(dataText2, equals('Data: hello_string_state'),
            reason:
                'Type mismatch at call site must safely fall back to fresh initialValue');
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('auto-keyed state in keyed ForEach survives DDC hot remount per item',
        () async {
      final entryFile = File(p.join(libDir.path, 'main.dart'));
      final outputFile = File(p.join(webDir.path, 'main.js'));
      final indexHtml = File(p.join(webDir.path, 'index.html'));
      indexHtml.writeAsStringSync('''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Scoped signal test</title></head>
<body><div id="app"></div></body></html>
''');

      entryFile.writeAsStringSync(r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  mount(Div(children: [
    H1(text: 'List V1'),
    ForEach<int>(
      () => [1, 2],
      (item) => Memo<int>(() => item, (itemValue) {
        final count = signal(0);
        return Button(
          className: 'item-$itemValue',
          text: '$itemValue: ${count.value}',
          on: {'click': (_) => count.value++},
        );
      }),
      key: (item) => item.toString(),
    ),
  ]), '#app');
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
      expect(compile1.success, isTrue,
          reason: 'Initial compile failed: ${compile1.error}');

      final devServer = BloomLiveReloadServer(
        webDir: webDir,
        host: '127.0.0.1',
        port: 0,
        autoInjectScript: true,
        isDdcMode: true,
        ddcCacheDir: toolchain.cacheDir,
      );
      await devServer.start();

      try {
        final page = await browser!.newPage();
        final browserErrors = <String>[];
        page.onConsole.listen((message) {
          if (message.type.name == 'error') {
            browserErrors.add(message.text ?? '');
          }
        });
        page.onError.listen((error) => browserErrors.add(error.toString()));
        await page.goto('http://127.0.0.1:${devServer.server!.port}',
            wait: Until.domContentLoaded);

        String? heading;
        for (var attempt = 0; attempt < 100; attempt++) {
          heading = await page.evaluate(
              "document.querySelector('#app h1')?.textContent") as String?;
          if (heading == 'List V1') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(heading, 'List V1', reason: 'Browser errors: $browserErrors');
        await _waitForSseClient(devServer);

        await page.click('.item-1');
        await page.click('.item-2');
        await page.click('.item-2');
        await page.click('.item-2');

        entryFile.writeAsStringSync(r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

final unrelated = signal(50);

void main() {
  mount(Div(children: [
    H1(text: 'List V2'),
    ForEach<int>(
      () => [1, 2],
      (item) => Memo<int>(() => item, (itemValue) {
        final count = signal(0);
        return Button(
          className: 'item-$itemValue',
          text: 'Item $itemValue: ${count.value}',
          on: {'click': (_) => count.value++},
        );
      }),
      key: (item) => item.toString(),
    ),
  ]), '#app');
}
''');
        final compile2 = await compiler.compile();
        expect(compile2.success, isTrue,
            reason: 'Recompile failed: ${compile2.error}');
        devServer.broadcastHotRemount(reason: 'main.dart');

        for (var attempt = 0; attempt < 100; attempt++) {
          heading = await page.evaluate(
              "document.querySelector('#app h1')?.textContent") as String?;
          if (heading == 'List V2') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(heading, 'List V2', reason: 'Browser errors: $browserErrors');

        final buttonValues = jsonDecode(await page.evaluate(r'''
          JSON.stringify(Array.from(document.querySelectorAll('#app button'), button => button.textContent))
        ''') as String) as List<dynamic>;
        expect(buttonValues, ['Item 1: 1', 'Item 2: 3'],
            reason:
                'Each keyed row must restore its own state; browser errors: $browserErrors');
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('auto-keyed signals in an async Suspense builder survive hot remount',
        () async {
      final entryFile = File(p.join(libDir.path, 'main.dart'));
      final outputFile = File(p.join(webDir.path, 'main.js'));
      final indexHtml = File(p.join(webDir.path, 'index.html'));
      indexHtml.writeAsStringSync('''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Suspense signal test</title></head>
<body><div id="app"></div></body></html>
''');

      entryFile.writeAsStringSync(r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;

final source = signal(1);

void main() {
  effect(() {
    final accumulated = signal(0);
    final next = untracked(() => accumulated.value) + source.value;
    accumulated.value = next;
    web.document.body!.setAttribute('data-effect-count', '$next');
  });
  mount(Mount(
    Div(children: [
      Suspense<Signal<int>>(
      resource: () async => signal(0),
      fallback: P(text: 'Loading'),
      builder: (resourceCount) {
        final count = signal(0);
        return Div(children: [
          Button(
            className: 'resource',
            text: 'Resource: ${resourceCount.value}',
            on: {'click': (_) => resourceCount.value++},
          ),
          Button(
            className: 'resolved',
            text: 'Count: ${count.value}',
            on: {'click': (_) => count.value++},
          ),
        ]);
      },
      ),
      Button(
        className: 'source',
        text: 'Update source',
        on: {'click': (_) => source.value++},
      ),
    ]),
    onMount: () {
      final mounts = signal(0);
      mounts.value++;
      web.document.body!.setAttribute('data-mount-count', '${mounts.value}');
    },
  ), '#app');
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
      expect(compile1.success, isTrue,
          reason: 'Initial compile failed: ${compile1.error}');

      final devServer = BloomLiveReloadServer(
        webDir: webDir,
        host: '127.0.0.1',
        port: 0,
        autoInjectScript: true,
        isDdcMode: true,
        ddcCacheDir: toolchain.cacheDir,
      );
      await devServer.start();
      try {
        final page = await browser!.newPage();
        final browserErrors = <String>[];
        page.onConsole.listen((message) {
          if (message.type.name == 'error') {
            browserErrors.add(message.text ?? '');
          }
        });
        page.onError.listen((error) => browserErrors.add(error.toString()));
        await page.goto('http://127.0.0.1:${devServer.server!.port}',
            wait: Until.domContentLoaded);
        await _waitForSseClient(devServer);

        String? value;
        for (var attempt = 0; attempt < 100; attempt++) {
          value = await page.evaluate(
              "document.querySelector('.resolved')?.textContent") as String?;
          if (value == 'Count: 0') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(value, 'Count: 0', reason: 'Browser errors: $browserErrors');
        expect(
          await page
              .evaluate("document.querySelector('.resource')?.textContent"),
          'Resource: 0',
          reason: 'Browser errors: $browserErrors',
        );
        expect(
          await page.evaluate("document.body.getAttribute('data-mount-count')"),
          '1',
        );
        expect(
          await page
              .evaluate("document.body.getAttribute('data-effect-count')"),
          '1',
        );
        await page.click('.source');
        expect(
          await page
              .evaluate("document.body.getAttribute('data-effect-count')"),
          '3',
        );
        await page.click('.resolved');
        await page.click('.resource');

        entryFile.writeAsStringSync(r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;

Future<int> loadValue() async => 1;
final source = signal(1);
final unrelated = signal(50);

void main() {
  effect(() {
    final accumulated = signal(0);
    final next = untracked(() => accumulated.value) + source.value;
    accumulated.value = next;
    web.document.body!.setAttribute('data-effect-count', '$next');
  });
  mount(Mount(
    Div(children: [
      Suspense<Signal<int>>(
      resource: () async => signal(0),
      fallback: P(text: 'Loading'),
      builder: (resourceCount) {
        final count = signal(0);
        return Div(children: [
          Button(
            className: 'resource',
            text: 'Updated resource: ${resourceCount.value}',
            on: {'click': (_) => resourceCount.value++},
          ),
          Button(
            className: 'resolved',
            text: 'Updated count: ${count.value}',
            on: {'click': (_) => count.value++},
          ),
        ]);
      },
      ),
      Button(
        className: 'source',
        text: 'Update source',
        on: {'click': (_) => source.value++},
      ),
    ]),
    onMount: () {
      final mounts = signal(0);
      mounts.value++;
      web.document.body!.setAttribute('data-mount-count', '${mounts.value}');
    },
  ), '#app');
}
''');
        final compile2 = await compiler.compile();
        expect(compile2.success, isTrue,
            reason: 'Recompile failed: ${compile2.error}');
        devServer.broadcastHotRemount(reason: 'main.dart');

        for (var attempt = 0; attempt < 100; attempt++) {
          value = await page.evaluate(
              "document.querySelector('.resolved')?.textContent") as String?;
          if (value == 'Updated count: 1') break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(value, 'Updated count: 1',
            reason: 'Browser errors: $browserErrors');
        expect(
          await page
              .evaluate("document.querySelector('.resource')?.textContent"),
          'Updated resource: 1',
          reason: 'Suspense resource signal should carry over through DDC HMR',
        );
        expect(
          await page.evaluate("document.body.getAttribute('data-mount-count')"),
          '2',
          reason: 'Mount lifecycle signal should carry over through DDC HMR',
        );
        expect(
          await page
              .evaluate("document.body.getAttribute('data-effect-count')"),
          '5',
          reason: 'Effect callback signal should carry over through DDC HMR',
        );
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('stable reactive callbacks preserve local signals across hot remount',
        () async {
      final entryFile = File(p.join(libDir.path, 'main.dart'));
      final outputFile = File(p.join(webDir.path, 'main.js'));
      final indexHtml = File(p.join(webDir.path, 'index.html'));
      indexHtml.writeAsStringSync('''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Callback signal test</title></head>
<body><div id="app"></div></body></html>
''');

      entryFile.writeAsStringSync(r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

Signal<int>? memoState;
Signal<int>? listState;
Signal<int>? showState;
Signal<int>? batchState;
Signal<int>? untrackedState;

BloomNode lazyCard() => lazy(
  () async {
    final count = signal(0);
    return Button(
      className: 'lazy',
      text: 'Lazy: ${count.value}',
      on: {'click': (_) => count.value++},
    );
  },
  fallback: P(text: 'Loading lazy card'),
);

void initializeCallbackSignals() {
  batch(() {
    batchState = signal(0);
  });
  untracked(() {
    untrackedState = signal(0);
  });
}

BloomNode app() {
  initializeCallbackSignals();
  return Div(children: [
  lazyCard(),
  customElement('bloom-hmr-counter', className: 'custom-builder'),
  Button(
    className: 'batch-state',
    text: 'Batch: ${batchState!.value}',
    on: {'click': (_) => batchState!.value++},
  ),
  Button(
    className: 'untracked-state',
    text: 'Untracked: ${untrackedState!.value}',
    on: {'click': (_) => untrackedState!.value++},
  ),
  Show(
    () {
      showState = signal(0);
      return showState!.value > 0;
    },
    child: Live(() => Button(
      className: 'show',
      text: 'Show: ${showState!.value}',
    )),
    fallback: Button(
      className: 'show',
      text: 'Enable show',
      on: {'click': (_) => showState!.value++},
    ),
  ),
  Memo<int>(
    () {
      memoState = signal(0);
      return memoState!.value;
    },
    (value) => Button(
      className: 'memo',
      text: 'Memo: $value',
      on: {'click': (_) => memoState!.value++},
    ),
  ),
  ForEach<int>(
    () {
      listState = signal(0);
      final value = listState!.value;
      return [value, value + 1];
    },
    (item) => Button(
      className: 'item',
      text: 'Item: $item',
      on: {'click': (_) => listState!.value++},
    ),
    key: (item) => item.toString(),
  ),
  ForEach<int>(
    () => [1, 2],
    (item) {
      Signal<int>? eventState;
      final renderCount = signal(0);
      return Live(() => Button(
        className: 'event-item-$item',
        text: 'Event $item: ${eventState?.value ?? 0}/${renderCount.value}',
        on: {'click': (_) {
          eventState ??= signal(0);
          eventState!.value++;
          renderCount.value++;
        }},
      ));
    },
    key: (item) => item.toString(),
  ),
  ForEach<int>(
    () => [1, 2],
    (item) {
      Signal<int>? eventState;
      return customElement(
        'chart-view',
        className: 'custom-event-$item',
        waitForUpgrade: false,
        events: {
          'chart-select': (event) {
            eventState ??= signal(0);
            eventState!.value++;
            event.target?.setAttribute('data-count', '${eventState!.value}');
          },
        },
      );
    },
    key: (item) => item.toString(),
  ),
  ]);
}

void main() {
  defineCustomElement('bloom-hmr-counter', (_) {
    final count = signal(0);
    return Button(
      text: 'Custom: ${count.value}',
      on: {'click': (_) => count.value++},
    );
  });
  mount(app(), '#app');
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
      expect(compile1.success, isTrue,
          reason: 'Initial compile failed: ${compile1.error}');

      final devServer = BloomLiveReloadServer(
        webDir: webDir,
        host: '127.0.0.1',
        port: 0,
        autoInjectScript: true,
        isDdcMode: true,
        ddcCacheDir: toolchain.cacheDir,
      );
      await devServer.start();
      try {
        final page = await browser!.newPage();
        final browserErrors = <String>[];
        page.onConsole.listen((message) {
          if (message.type.name == 'error') {
            browserErrors.add(message.text ?? '');
          }
        });
        page.onError.listen((error) => browserErrors.add(error.toString()));
        await page.goto('http://127.0.0.1:${devServer.server!.port}',
            wait: Until.domContentLoaded);
        await _waitForSseClient(devServer);

        for (var attempt = 0; attempt < 100; attempt++) {
          final ready = await page.evaluate(r'''
            document.querySelector('.memo')?.textContent === 'Memo: 0' &&
            document.querySelector('.lazy')?.textContent === 'Lazy: 0' &&
            document.querySelector('.batch-state')?.textContent === 'Batch: 0' &&
            document.querySelector('.untracked-state')?.textContent === 'Untracked: 0' &&
            document.querySelector('.custom-builder')?.shadowRoot
              ?.querySelector('button')?.textContent === 'Custom: 0' &&
            document.querySelectorAll('.item').length === 2
          ''') as bool;
          if (ready) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(
            await page.evaluate("document.querySelector('.memo')?.textContent"),
            'Memo: 0',
            reason: 'Browser errors: $browserErrors');
        expect(
          await page.evaluate("document.querySelector('.show')?.textContent"),
          'Enable show',
          reason: 'Browser errors: $browserErrors',
        );
        await page.click('.show');
        await page.click('.memo');
        await page.click('.lazy');
        await page.click('.batch-state');
        await page.click('.untracked-state');
        await page.evaluate(r'''
          document.querySelector('.custom-builder')?.shadowRoot
            ?.querySelector('button')
            ?.dispatchEvent(new MouseEvent('click', {bubbles: true}));
        ''');
        await page.click('.item');
        await page.click('.event-item-1');
        await page.evaluate(r'''
          document.querySelector('.custom-event-1')
            ?.dispatchEvent(new CustomEvent('chart-select'));
          document.querySelector('.custom-event-1')
            ?.dispatchEvent(new CustomEvent('chart-select'));
          document.querySelector('.custom-event-2')
            ?.dispatchEvent(new CustomEvent('chart-select'));
        ''');
        expect(
          await page.evaluate(r'''
            JSON.stringify([
              document.querySelector('.custom-event-1')?.getAttribute('data-count'),
              document.querySelector('.custom-event-2')?.getAttribute('data-count')
            ])
          '''),
          '["2","1"]',
          reason: 'Custom event handlers must have keyed row scopes',
        );

        entryFile.writeAsStringSync(r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

Signal<int>? memoState;
Signal<int>? listState;
Signal<int>? showState;
Signal<int>? batchState;
Signal<int>? untrackedState;

BloomNode lazyCard() => lazy(
  () async {
    final count = signal(0);
    return Button(
      className: 'lazy',
      text: 'Lazy V2: ${count.value}',
      on: {'click': (_) => count.value++},
    );
  },
  fallback: P(text: 'Loading lazy card'),
);

void initializeCallbackSignals() {
  batch(() {
    batchState = signal(0);
  });
  untracked(() {
    untrackedState = signal(0);
  });
}

BloomNode app() {
  initializeCallbackSignals();
  return Div(children: [
  lazyCard(),
  customElement('bloom-hmr-counter', className: 'custom-builder'),
  Button(
    className: 'batch-state',
    text: 'Batch V2: ${batchState!.value}',
    on: {'click': (_) => batchState!.value++},
  ),
  Button(
    className: 'untracked-state',
    text: 'Untracked V2: ${untrackedState!.value}',
    on: {'click': (_) => untrackedState!.value++},
  ),
  Show(
    () {
      showState = signal(0);
      return showState!.value > 0;
    },
    child: Live(() => Button(
      className: 'show',
      text: 'Show V2: ${showState!.value}',
    )),
    fallback: Button(
      className: 'show',
      text: 'Enable show V2',
      on: {'click': (_) => showState!.value++},
    ),
  ),
  Memo<int>(
    () {
      memoState = signal(0);
      return memoState!.value;
    },
    (value) => Button(
      className: 'memo',
      text: 'Memo V2: $value',
      on: {'click': (_) => memoState!.value++},
    ),
  ),
  ForEach<int>(
    () {
      listState = signal(0);
      final value = listState!.value;
      return [value, value + 1];
    },
    (item) => Button(
      className: 'item',
      text: 'Item V2: $item',
      on: {'click': (_) => listState!.value++},
    ),
    key: (item) => item.toString(),
  ),
  ForEach<int>(
    () => [1, 2],
    (item) {
      Signal<int>? eventState;
      final renderCount = signal(0);
      return Live(() => Button(
        className: 'event-item-$item',
        text: 'Event V2 $item: ${eventState?.value ?? 0}/${renderCount.value}',
        on: {'click': (_) {
          eventState ??= signal(0);
          eventState!.value++;
          renderCount.value++;
        }},
      ));
    },
    key: (item) => item.toString(),
  ),
  ForEach<int>(
    () => [1, 2],
    (item) {
      Signal<int>? eventState;
      return customElement(
        'chart-view',
        className: 'custom-event-$item',
        waitForUpgrade: false,
        events: {
          'chart-select': (event) {
            eventState ??= signal(0);
            eventState!.value++;
            event.target?.setAttribute('data-count', '${eventState!.value}');
          },
        },
      );
    },
    key: (item) => item.toString(),
  ),
  ]);
}

void main() {
  defineCustomElement('bloom-hmr-counter', (_) {
    final count = signal(0);
    return Button(
      text: 'Custom V2: ${count.value}',
      on: {'click': (_) => count.value++},
    );
  });
  mount(app(), '#app');
}
''');
        final compile2 = await compiler.compile();
        expect(compile2.success, isTrue,
            reason: 'Recompile failed: ${compile2.error}');
        devServer.broadcastHotRemount(reason: 'main.dart');

        String? showText;
        String? memoText;
        String? lazyText;
        String? customBuilderText;
        String? batchText;
        String? untrackedText;
        List<dynamic> itemTexts = const [];
        List<dynamic> eventTexts = const [];
        for (var attempt = 0; attempt < 100; attempt++) {
          showText = await page.evaluate(
              "document.querySelector('.show')?.textContent") as String?;
          memoText = await page.evaluate(
              "document.querySelector('.memo')?.textContent") as String?;
          lazyText = await page.evaluate(
              "document.querySelector('.lazy')?.textContent") as String?;
          batchText = await page.evaluate(
              "document.querySelector('.batch-state')?.textContent") as String?;
          untrackedText = await page.evaluate(
                  "document.querySelector('.untracked-state')?.textContent")
              as String?;
          customBuilderText = await page.evaluate(r'''
            document.querySelector('.custom-builder')?.shadowRoot
              ?.querySelector('button')?.textContent
          ''') as String?;
          itemTexts = jsonDecode(await page.evaluate(r'''
            JSON.stringify(Array.from(document.querySelectorAll('.item'), item => item.textContent))
          ''') as String) as List<dynamic>;
          eventTexts = jsonDecode(await page.evaluate(r'''
            JSON.stringify(Array.from(document.querySelectorAll('[class^="event-item-"]'), item => item.textContent))
          ''') as String) as List<dynamic>;
          if (showText == 'Show V2: 1' &&
              memoText == 'Memo V2: 1' &&
              lazyText == 'Lazy V2: 1' &&
              batchText == 'Batch V2: 1' &&
              untrackedText == 'Untracked V2: 1' &&
              customBuilderText == 'Custom V2: 1' &&
              itemTexts.join(',') == 'Item V2: 1,Item V2: 2' &&
              eventTexts.join(',') == 'Event V2 1: 0/1,Event V2 2: 0/0') {
            break;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
        expect(showText, 'Show V2: 1',
            reason: 'Show predicate state was lost; errors: $browserErrors');
        expect(memoText, 'Memo V2: 1',
            reason: 'Memo dependency state was lost; errors: $browserErrors');
        expect(lazyText, 'Lazy V2: 1',
            reason:
                'Lazy loader signal state was lost; errors: $browserErrors');
        expect(customBuilderText, 'Custom V2: 1',
            reason:
                'Custom element builder state was lost; errors: $browserErrors');
        expect(batchText, 'Batch V2: 1',
            reason: 'batch callback state was lost; errors: $browserErrors');
        expect(untrackedText, 'Untracked V2: 1',
            reason:
                'untracked callback state was lost; errors: $browserErrors');
        expect(itemTexts, ['Item V2: 1', 'Item V2: 2'],
            reason: 'ForEach items state was lost; errors: $browserErrors');
        expect(eventTexts, ['Event V2 1: 0/1', 'Event V2 2: 0/0'],
            reason:
                'Event handler scope was not preserved; errors: $browserErrors');

        await Future<void>.delayed(const Duration(milliseconds: 20));
        await page.evaluate(r'''
          document.querySelector('.custom-event-1')
            ?.dispatchEvent(new CustomEvent('chart-select'));
          document.querySelector('.custom-event-2')
            ?.dispatchEvent(new CustomEvent('chart-select'));
        ''');
        expect(
          await page.evaluate(r'''
            JSON.stringify([
              document.querySelector('.custom-event-1')?.getAttribute('data-count'),
              document.querySelector('.custom-event-2')?.getAttribute('data-count')
            ])
          '''),
          '["3","2"]',
          reason:
              'Custom event callback state must survive HMR per keyed row; errors: $browserErrors',
        );

        await page.click('.event-item-1');
        await page.click('.event-item-2');
        eventTexts = jsonDecode(await page.evaluate(r'''
          JSON.stringify(Array.from(document.querySelectorAll('[class^="event-item-"]'), item => item.textContent))
        ''') as String) as List<dynamic>;
        expect(eventTexts, ['Event V2 1: 2/2', 'Event V2 2: 1/1'],
            reason:
                'Event callback state must remain isolated per keyed row; errors: $browserErrors');
      } finally {
        await devServer.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

Future<void> _waitForSseClient(BloomLiveReloadServer server) async {
  for (var attempt = 0;
      attempt < 50 && server.activeClientCount == 0;
      attempt++) {
    await Future.delayed(const Duration(milliseconds: 20));
  }
  expect(
    server.activeClientCount,
    greaterThan(0),
    reason: 'The browser must establish its live-reload SSE connection first',
  );
}
