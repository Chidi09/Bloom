// test/open_in_editor_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/dev/live_reload_server.dart';

void main() {
  group('BloomLiveReloadServer Open in Editor (/__open-in-editor)', () {
    late Directory tempWebDir;
    late BloomLiveReloadServer devServer;
    late String baseUrl;

    setUp(() async {
      tempWebDir = await Directory.systemTemp.createTemp('bloom_open_editor_test_');

      // Create index.html
      final indexHtml = File(p.join(tempWebDir.path, 'index.html'));
      await indexHtml.writeAsString('<!DOCTYPE html><html><body><h1>Bloom App</h1></body></html>');

      // Create a real file at lib/pages/home.dart
      final pagesDir = Directory(p.join(tempWebDir.path, 'lib', 'pages'))..createSync(recursive: true);
      final homeDart = File(p.join(pagesDir.path, 'home.dart'));
      await homeDart.writeAsString('''
import 'package:flutter/widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
''');

      devServer = BloomLiveReloadServer(
        webDir: tempWebDir,
        host: '127.0.0.1',
        port: 0,
      );
      await devServer.start();
      baseUrl = 'http://127.0.0.1:${devServer.server!.port}';
    });

    tearDown(() async {
      await devServer.stop();
      if (tempWebDir.existsSync()) {
        try {
          await tempWebDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('POST /__open-in-editor with valid relative path returns 200 and opened boolean', () async {
      final res = await http.post(
        Uri.parse('$baseUrl/__open-in-editor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file': 'lib/pages/home.dart', 'line': 5}),
      );

      expect(res.statusCode, HttpStatus.ok);
      expect(res.headers['content-type'], contains('application/json'));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json.containsKey('opened'), isTrue);
      expect(json['opened'], isA<bool>());
    });

    test('POST /__open-in-editor with valid absolute path inside webDir returns 200', () async {
      final absPath = p.join(tempWebDir.path, 'lib', 'pages', 'home.dart');
      final res = await http.post(
        Uri.parse('$baseUrl/__open-in-editor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file': absPath, 'line': 1}),
      );

      expect(res.statusCode, HttpStatus.ok);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json.containsKey('opened'), isTrue);
      expect(json['opened'], isA<bool>());
    });

    test('POST /__open-in-editor rejects path-traversal attempts with 400', () async {
      final res = await http.post(
        Uri.parse('$baseUrl/__open-in-editor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file': '../../../etc/passwd', 'line': 1}),
      );

      expect(res.statusCode, HttpStatus.badRequest);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['error'], contains('escapes project directory'));
    });

    test('POST /__open-in-editor rejects absolute path outside webDir with 400', () async {
      final res = await http.post(
        Uri.parse('$baseUrl/__open-in-editor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file': '/etc/passwd', 'line': 1}),
      );

      expect(res.statusCode, HttpStatus.badRequest);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['error'], contains('escapes project directory'));
    });

    test('POST /__open-in-editor rejects nonexistent file with 400', () async {
      final res = await http.post(
        Uri.parse('$baseUrl/__open-in-editor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file': 'lib/does_not_exist.dart', 'line': 1}),
      );

      expect(res.statusCode, HttpStatus.badRequest);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['error'], contains('does not exist'));
    });

    test('POST /__open-in-editor rejects malformed JSON body with 400', () async {
      final res = await http.post(
        Uri.parse('$baseUrl/__open-in-editor'),
        headers: {'Content-Type': 'application/json'},
        body: '{not valid json',
      );

      expect(res.statusCode, HttpStatus.badRequest);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['error'], contains('Malformed JSON'));
    });

    test('POST /__open-in-editor rejects missing or empty file parameter with 400', () async {
      final res = await http.post(
        Uri.parse('$baseUrl/__open-in-editor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file': '', 'line': 1}),
      );

      expect(res.statusCode, HttpStatus.badRequest);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['error'], contains('Missing or invalid "file"'));
    });

    test('OPTIONS /__open-in-editor handles CORS preflight with 200', () async {
      final req = http.Request('OPTIONS', Uri.parse('$baseUrl/__open-in-editor'));
      final streamedRes = await req.send();
      final res = await http.Response.fromStream(streamedRes);

      expect(res.statusCode, HttpStatus.ok);
      expect(res.headers['access-control-allow-origin'], '*');
      expect(res.headers['access-control-allow-methods'], contains('POST'));
    });

    test('GET /__open-in-editor returns 405 Method Not Allowed', () async {
      final res = await http.get(Uri.parse('$baseUrl/__open-in-editor'));
      expect(res.statusCode, HttpStatus.methodNotAllowed);
    });

    test('liveReloadScript contains file location regex and /__open-in-editor client wiring', () {
      final script = BloomLiveReloadServer.liveReloadScript;
      expect(script, contains(r'/([\w./-]+\.dart):(\d+)(?::\d+)?/'));
      expect(script, contains('/__open-in-editor'));
      expect(script, contains('bloom-open-btn'));
      expect(script, contains('bloom-error-footer'));
    });
  });
}
