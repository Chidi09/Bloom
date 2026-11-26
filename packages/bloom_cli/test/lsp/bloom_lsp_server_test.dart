import 'dart:async';
import 'dart:convert';

import 'package:bloom_cli/src/lsp/bloom_lsp_server.dart';
import 'package:test/test.dart';

List<Map<String, dynamic>> _decodeFrames(List<int> bytes) {
  final messages = <Map<String, dynamic>>[];
  var offset = 0;
  while (offset < bytes.length) {
    var headerEnd = -1;
    for (var i = offset; i <= bytes.length - 4; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        headerEnd = i;
        break;
      }
    }
    if (headerEnd < 0) break;
    final header = ascii.decode(bytes.sublist(offset, headerEnd));
    final lenLine = header
        .split('\r\n')
        .firstWhere((l) => l.toLowerCase().startsWith('content-length:'));
    final length =
        int.parse(lenLine.substring('content-length:'.length).trim());
    final bodyStart = headerEnd + 4;
    final body = bytes.sublist(bodyStart, bodyStart + length);
    messages.add(jsonDecode(utf8.decode(body)) as Map<String, dynamic>);
    offset = bodyStart + length;
  }
  return messages;
}

void main() {
  group('BloomLspServer', () {
    test('handles initialize, didOpen diagnostics, codeAction, completion, hover, and shutdown',
        () async {
      final input = StreamController<List<int>>();
      final outputBytes = <int>[];
      final output = StreamController<List<int>>();
      output.stream.listen(outputBytes.addAll);

      final server = BloomLspServer(input: input.stream, output: output.sink);
      final done = server.listen();

      const sampleUri = 'file:///project/lib/app.dart';
      const sampleSource = '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

final count = signal(0);

BloomNode badView() {
  return P(text: '\${count.value}');
}
''';

      input.add(BloomLspServer.encodeFrame({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {},
      }));
      input.add(BloomLspServer.encodeFrame({
        'jsonrpc': '2.0',
        'method': 'textDocument/didOpen',
        'params': {
          'textDocument': {
            'uri': sampleUri,
            'languageId': 'dart',
            'version': 1,
            'text': sampleSource,
          },
        },
      }));
      input.add(BloomLspServer.encodeFrame({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'textDocument/completion',
        'params': {
          'textDocument': {'uri': sampleUri},
          'position': {'line': 6, 'character': 10},
        },
      }));
      input.add(BloomLspServer.encodeFrame({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'textDocument/hover',
        'params': {
          'textDocument': {'uri': sampleUri},
          'position': {'line': 3, 'character': 16},
        },
      }));
      input.add(BloomLspServer.encodeFrame({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'textDocument/codeAction',
        'params': {
          'textDocument': {'uri': sampleUri},
          'range': {
            'start': {'line': 6, 'character': 0},
            'end': {'line': 6, 'character': 30},
          },
          'context': {
            'diagnostics': [
              {
                'code': 'untracked_signal_read',
                'range': {
                  'start': {'line': 6, 'character': 0},
                  'end': {'line': 6, 'character': 30},
                },
              },
            ],
          },
        },
      }));
      input.add(BloomLspServer.encodeFrame({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'shutdown',
      }));
      input.add(BloomLspServer.encodeFrame({
        'jsonrpc': '2.0',
        'method': 'exit',
      }));

      await done;
      await output.close();
      await input.close();

      final responses = _decodeFrames(outputBytes);
      expect(responses.length, 6);

      // 1. initialize
      final init = responses.firstWhere((m) => m['id'] == 1);
      final caps =
          (init['result'] as Map<String, dynamic>)['capabilities'] as Map;
      expect(caps['hoverProvider'], isTrue);
      expect(caps['codeActionProvider'], isTrue);

      // 2. publishDiagnostics
      final diagMsg = responses.firstWhere(
          (m) => m['method'] == 'textDocument/publishDiagnostics');
      final diags = (diagMsg['params'] as Map)['diagnostics'] as List<dynamic>;
      final codes = diags.map((d) => (d as Map)['code']).toSet();
      expect(codes, contains('forbidden_browser_import_in_shared_code'));
      expect(codes, contains('untracked_signal_read'));

      // 3. completion
      final comp = responses.firstWhere((m) => m['id'] == 2);
      final items = (comp['result'] as Map)['items'] as List<dynamic>;
      expect(items.any((i) => (i as Map)['label'] == 'Live'), isTrue);
      expect(items.any((i) => (i as Map)['label'] == 'ForEach'), isTrue);

      // 4. hover on `signal`
      final hover = responses.firstWhere((m) => m['id'] == 3);
      final hoverVal =
          ((hover['result'] as Map)['contents'] as Map)['value'] as String;
      expect(hoverVal, contains('Signal<T>'));

      // 5. codeAction quick fix
      final codeActions =
          responses.firstWhere((m) => m['id'] == 4)['result'] as List<dynamic>;
      expect(codeActions, isNotEmpty);
      expect((codeActions.first as Map)['title'],
          contains('Live(() => ...)'));

      // 6. shutdown
      final shutdown = responses.firstWhere((m) => m['id'] == 5);
      expect(shutdown['result'], isNull);
    });
  });
}
