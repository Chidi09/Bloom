// test/dev/css_hot_swap_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:bloom_cli/src/dev/css_hot_swap.dart';
import 'package:bloom_cli/src/dev/live_reload_server.dart';

void main() {
  group('detectCssOnlyChange', () {
    test('1. Changing only the body of top-level const cardCss = r\'\'\'...\'\'\' returns CssOnlyChange', () {
      const oldSource = r"""
import 'package:bloom_js_native/bloom_js_native.dart';

const cardCss = r'''
.card {
  background-color: #09090b;
  color: #fafafa;
}
''';

Node renderApp() => Div(children: [Text('Hello')]);
""";

      const newSource = r"""
import 'package:bloom_js_native/bloom_js_native.dart';

const cardCss = r'''
.card {
  background-color: #14141a;
  color: #6366f1;
}
''';

Node renderApp() => Div(children: [Text('Hello')]);
""";

      final change = detectCssOnlyChange(oldSource, newSource);
      expect(change, isNotNull);
      expect(
        change!.oldCss,
        r'''

.card {
  background-color: #09090b;
  color: #fafafa;
}
''',
      );
      expect(
        change.newCss,
        r'''

.card {
  background-color: #14141a;
  color: #6366f1;
}
''',
      );
    });

    test('2. Changing only the body of an inline Style(r\'\'\'...\'\'\') returns CssOnlyChange', () {
      const oldSource = r"""
import 'package:bloom_js_native/bloom_js_native.dart';

Node renderCard() {
  return Div(
    styles: [
      Style(r'''
        .btn {
          padding: 8px 16px;
        }
      '''),
    ],
  );
}
""";

      const newSource = r"""
import 'package:bloom_js_native/bloom_js_native.dart';

Node renderCard() {
  return Div(
    styles: [
      Style(r'''
        .btn {
          padding: 12px 24px;
        }
      '''),
    ],
  );
}
""";

      final change = detectCssOnlyChange(oldSource, newSource);
      expect(change, isNotNull);
      expect(
        change!.oldCss,
        r'''

        .btn {
          padding: 8px 16px;
        }
      ''',
      );
      expect(
        change.newCss,
        r'''

        .btn {
          padding: 12px 24px;
        }
      ''',
      );
    });

    test('3. Changing a Dart code line alongside a CSS literal returns null (skeleton mismatch)', () {
      const oldSource = r"""
const cardCss = r'''
.card { color: red; }
''';

int count = 1;
""";

      const newSource = r"""
const cardCss = r'''
.card { color: blue; }
''';

int count = 2;
""";

      final change = detectCssOnlyChange(oldSource, newSource);
      expect(change, isNull);
    });

    test('4. Changing two different CSS literals in the same file returns null (ambiguous)', () {
      const oldSource = r"""
const headerCss = r'''
.header { font-size: 16px; }
''';

const footerCss = r'''
.footer { font-size: 12px; }
''';
""";

      const newSource = r"""
const headerCss = r'''
.header { font-size: 18px; }
''';

const footerCss = r'''
.footer { font-size: 14px; }
''';
""";

      final change = detectCssOnlyChange(oldSource, newSource);
      expect(change, isNull);
    });

    test('5. A raw string literal that is structurally NOT a CSS declaration returns null', () {
      const oldSource = r"""
void main() {
  someOtherFn(r'''
    SELECT * FROM users;
  ''');
}
""";

      const newSource = r"""
void main() {
  someOtherFn(r'''
    SELECT * FROM orders;
  ''');
}
""";

      final change = detectCssOnlyChange(oldSource, newSource);
      expect(change, isNull);
    });

    test('6. No changes between old and new source returns null', () {
      const source = r"""
const cardCss = r'''
.card { color: red; }
''';
""";

      final change = detectCssOnlyChange(source, source);
      expect(change, isNull);
    });

    test('7. A completely unrelated content change (e.g. comment added) returns null', () {
      const oldSource = r"""
// Initial comment
const cardCss = r'''
.card { color: red; }
''';
""";

      const newSource = r"""
// Modified comment
const cardCss = r'''
.card { color: red; }
''';
""";

      final change = detectCssOnlyChange(oldSource, newSource);
      expect(change, isNull);
    });

    test('8. Changing only one of multiple CSS declarations in a file returns CssOnlyChange', () {
      const oldSource = r"""
const headerCss = r'''
.header { font-size: 16px; }
''';

const footerCss = r'''
.footer { font-size: 12px; }
''';
""";

      const newSource = r"""
const headerCss = r'''
.header { font-size: 20px; }
''';

const footerCss = r'''
.footer { font-size: 12px; }
''';
""";

      final change = detectCssOnlyChange(oldSource, newSource);
      expect(change, isNotNull);
      expect(change!.oldCss, '\n.header { font-size: 16px; }\n');
      expect(change.newCss, '\n.header { font-size: 20px; }\n');
    });

    test('9. Handles typed const declarations: const String appCss = r\'\'\'...\'\'\'', () {
      const oldSource = r"""
const String appCss = r'''
body { margin: 0; }
''';
""";

      const newSource = r"""
const String appCss = r'''
body { margin: 8px; }
''';
""";

      final change = detectCssOnlyChange(oldSource, newSource);
      expect(change, isNotNull);
      expect(change!.oldCss, '\nbody { margin: 0; }\n');
      expect(change.newCss, '\nbody { margin: 8px; }\n');
    });
  });

  group('BloomLiveReloadServer.broadcastCssPatch', () {
    late Directory tempWebDir;
    late BloomLiveReloadServer devServer;
    late int testPort;

    setUp(() async {
      tempWebDir = await Directory.systemTemp.createTemp('bloom_css_patch_test_');
      final indexHtml = File('${tempWebDir.path}/index.html');
      await indexHtml.writeAsString('<!DOCTYPE html><html><head></head><body></body></html>');

      testPort = 19888;
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

    test('broadcasts event: css-patch with oldCss and newCss in JSON payload', () async {
      final socket = await Socket.connect('127.0.0.1', testPort);
      socket.write('GET /_bloom_hr HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n');
      await socket.flush();

      final completer = Completer<String>();
      socket.cast<List<int>>().transform(utf8.decoder).listen((data) {
        if (!completer.isCompleted && data.contains('event: css-patch')) {
          completer.complete(data);
        }
      });

      // Wait for registration
      await Future.delayed(const Duration(milliseconds: 50));
      expect(devServer.activeClientCount, 1);

      devServer.broadcastCssPatch(
        oldCss: '.card { color: red; }',
        newCss: '.card { color: blue; }',
      );

      final received = await completer.future.timeout(const Duration(seconds: 2));
      expect(received, contains('event: css-patch'));
      expect(received, contains(r'data: {"timestamp":'));
      expect(received, contains(r'"oldCss":".card { color: red; }"'));
      expect(received, contains(r'"newCss":".card { color: blue; }"'));

      await socket.close();
    });
  });
}
