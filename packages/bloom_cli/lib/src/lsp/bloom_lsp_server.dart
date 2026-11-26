// lib/src/lsp/bloom_lsp_server.dart
import 'dart:async';
import 'dart:convert';

import '../lint/bloom_lint.dart';

/// Symbol hover documentation entries for Bloom JS Native.
const Map<String, String> bloomHoverDocs = {
  'signal':
      '```dart\nSignal<T> signal<T>(T initialValue, {String? key})\n```\n'
          'Creates a reactive signal cell. Read `.value` inside `Live`, `Show`, `ForEach`, `Memo`, `computed`, or `effect` to subscribe. Assign `.value = ...` to notify dependents.',
  'computed':
      '```dart\nReadonlySignal<T> computed<T>(T Function() fn)\n```\n'
          'Creates a lazy, memoized derived signal that automatically tracks signals read inside `fn`.',
  'effect':
      '```dart\nvoid Function() effect(BloomEffectCallback compute)\n```\n'
          'Runs `compute` immediately and re-runs whenever read signals change. Call the returned disposer to prevent leaks.',
  'batch':
      '```dart\nT batch<T>(T Function() fn)\n```\n'
          'Coalesces multiple signal writes into a single downstream notification pass.',
  'untracked':
      '```dart\nT untracked<T>(T Function() fn)\n```\n'
          'Reads signals inside `fn` without subscribing the enclosing `effect` or `computed`.',
  'useReducer':
      '```dart\nBloomReducer<S, A> useReducer<S, A>(BloomReducerFn<S, A> reducerFn, S initialState, {String? key})\n```\n'
          'Signal-backed reducer state container with `.state`, `.dispatch(action)`, and `.history`.',
  'Live':
      '```dart\nconst Live(BloomNode Function() builder)\n```\n'
          'Reactive AST boundary that tracks signals read in `builder` and patches only its DOM region.',
  'Show':
      '```dart\nconst Show(bool Function() when, {required BloomNode child, BloomNode? fallback, ...})\n```\n'
          'Reactive conditional branch node with automatic disposal of unmounted subtrees and optional enter/exit transitions.',
  'ForEach':
      '```dart\nconst ForEach<T>(List<T> Function() items, BloomNode Function(T) builder, {String Function(T)? key})\n```\n'
          'Collection renderer. Always provide `key:` for dynamic lists to enable keyed in-place DOM reconciliation and preserve focus/local state.',
  'Memo':
      '```dart\nconst Memo<T>(T Function() dependency, BloomNode Function(T value) builder)\n```\n'
          'Memoizes subtree builds by comparing `dependency()` and rebuilding only when the value changes.',
  'Suspense':
      '```dart\nconst Suspense<T>({required Future<T> Function() resource, required BloomNode Function(T) builder, required BloomNode fallback})\n```\n'
          'Declarative async boundary supporting client loading states and out-of-order streaming SSR (`renderToStreamWithSuspense`).',
  'ErrorBoundary':
      '```dart\nconst ErrorBoundary({required BloomNode Function() builder, required BloomNode Function(Object, StackTrace) fallback})\n```\n'
          'Catches synchronous and reactive errors within its subtree during SSR and browser mounting.',
  'Mount':
      '```dart\nconst Mount(BloomNode child, {void Function()? onMount, void Function(BloomElement)? onMountElement, void Function()? onUnmount})\n```\n'
          'Lifecycle hook node. Browser-only callbacks run after DOM insertion and clean up on disposal (no-op during SSR).',
  'Portal':
      '```dart\nconst Portal({required BloomNode child, String targetSelector = \'body\'})\n```\n'
          'Mounts `child` into an out-of-tree DOM target while preserving parent reactive disposal.',
  'mountApp':
      '```dart\nBloomMountHandle mountApp(BloomNode root, String selector)\n```\n'
          '**Browser-only** (`package:bloom_js_native/browser.dart`). Hydrates pre-rendered SSR HTML in place or mounts into an empty target.',
  'mount':
      '```dart\nBloomMountHandle mount(BloomNode root, String selector)\n```\n'
          '**Browser-only** (`package:bloom_js_native/browser.dart`). Appends a fresh descriptor tree into `selector`.',
  'hydrate':
      '```dart\nBloomMountHandle hydrate(BloomNode root, String selector)\n```\n'
          '**Browser-only** (`package:bloom_js_native/browser.dart`). Adopts SSR DOM nodes and attaches reactive boundaries in place.',
  'RouterLink':
      '```dart\nRouterLink({required BloomNavigator controller, required String href, String? text, ...})\n```\n'
          'Router-aware anchor link that navigates via `controller` without full-page reloads.',
  'BloomRevalidateConfig':
      '```dart\nconst BloomRevalidateConfig.isr({required Duration revalidate, List<String> tags = const []})\n```\n'
          'Declarative page-level SSR/SSG/ISR caching and revalidation configuration.',
  'BloomIsrRenderer':
      '```dart\nclass BloomIsrRenderer\n```\n'
          'Stale-while-revalidate HTML renderer with deduplicated background regeneration and path/tag invalidation.',
  'bloomHmrScope':
      '```dart\nT bloomHmrScope<T>(String scopeId, T Function() callback)\n```\n'
          'Isolates signal keys created inside `callback` during DDC hot reload (zero overhead in production/SSR).',
  'bloomHmrState':
      '```dart\nT bloomHmrState<T>(String key, T Function() create)\n```\n'
          'Preserves non-signal state across DDC hot remounts under `key` (zero overhead in production/SSR).',
};

class _CompletionSpec {
  final String label;
  final int kind;
  final String detail;
  final String insertText;
  final String documentation;

  const _CompletionSpec({
    required this.label,
    required this.kind,
    required this.detail,
    required this.insertText,
    required this.documentation,
  });
}

const List<_CompletionSpec> _bloomCompletions = [
  _CompletionSpec(
    label: 'Live',
    kind: 7,
    detail: 'Reactive DOM boundary',
    insertText: 'Live(() => \${1:P(text: \'\${2:signal.value}\')})',
    documentation: 'Re-evaluates its subtree when enclosed signals change.',
  ),
  _CompletionSpec(
    label: 'Show',
    kind: 7,
    detail: 'Reactive conditional boundary',
    insertText:
        'Show(() => \${1:condition.value}, child: \${2:Div()}, fallback: \${3:null})',
    documentation: 'Conditionally mounts child or fallback.',
  ),
  _CompletionSpec(
    label: 'ForEach',
    kind: 7,
    detail: 'Keyed reactive list',
    insertText:
        'ForEach<\${1:Item}>(() => \${2:items.value}, (item) => \${3:Li(text: item.toString())}, key: (item) => \${4:item.id})',
    documentation: 'Renders a reactive list with keyed in-place reconciliation.',
  ),
  _CompletionSpec(
    label: 'Memo',
    kind: 7,
    detail: 'Memoized subtree boundary',
    insertText:
        'Memo(() => \${1:dep.value}, (val) => \${2:Div(text: \'\$val\')})',
    documentation: 'Rebuilds only when the dependency value changes.',
  ),
  _CompletionSpec(
    label: 'Suspense',
    kind: 7,
    detail: 'Async resource boundary',
    insertText:
        'Suspense<\${1:Data}>(resource: () => \${2:fetchData()}, builder: (data) => \${3:Div()}, fallback: \${4:P(text: \'Loading...\')})',
    documentation: 'Renders fallback until resource resolves.',
  ),
  _CompletionSpec(
    label: 'ErrorBoundary',
    kind: 7,
    detail: 'Error recovery boundary',
    insertText:
        'ErrorBoundary(builder: () => \${1:Div()}, fallback: (err, st) => \${2:P(text: \'Error: \$err\')})',
    documentation: 'Catches errors inside its subtree.',
  ),
  _CompletionSpec(
    label: 'Mount',
    kind: 7,
    detail: 'DOM lifecycle wrapper',
    insertText:
        'Mount(\${1:Div()}, onMountElement: (el) {\n  \${2}\n})',
    documentation: 'Runs browser lifecycle hooks on mount/unmount.',
  ),
  _CompletionSpec(
    label: 'signal',
    kind: 3,
    detail: 'Reactive state cell',
    insertText: 'signal(\${1:0})',
    documentation: 'Creates a mutable reactive Signal<T>.',
  ),
  _CompletionSpec(
    label: 'computed',
    kind: 3,
    detail: 'Derived reactive value',
    insertText: 'computed(() => \${1})',
    documentation: 'Creates a memoized ReadonlySignal<T>.',
  ),
  _CompletionSpec(
    label: 'effect',
    kind: 3,
    detail: 'Reactive side effect',
    insertText: 'effect(() {\n  \${1}\n})',
    documentation: 'Runs callback whenever read signals change.',
  ),
  _CompletionSpec(
    label: 'useReducer',
    kind: 3,
    detail: 'Reducer state container',
    insertText: 'useReducer(\${1:reducerFn}, \${2:initialState})',
    documentation: 'Creates a signal-backed BloomReducer.',
  ),
  _CompletionSpec(
    label: 'mountApp',
    kind: 3,
    detail: 'Browser entry point (browser.dart)',
    insertText: 'mountApp(\${1:app}, \'\${2:#app}\')',
    documentation: 'Hydrates existing SSR HTML or mounts into an empty target.',
  ),
  _CompletionSpec(
    label: 'RouterLink',
    kind: 7,
    detail: 'Router-aware link',
    insertText:
        'RouterLink(controller: \${1:router}, href: \'\${2:/}\', text: \'\${3:Home}\')',
    documentation: 'Navigates using BloomNavigator without full page reload.',
  ),
  _CompletionSpec(
    label: 'BloomRevalidateConfig.isr',
    kind: 7,
    detail: 'ISR page revalidation config',
    insertText:
        'BloomRevalidateConfig.isr(revalidate: Duration(seconds: \${1:60}), tags: [\'\${2:tag}\'])',
    documentation: 'Configures Incremental Static Regeneration for a route.',
  ),
];

/// Zero-dependency Language Server Protocol (LSP) server for Bloom JS Native.
///
/// Surfaces `bloom lint` diagnostics (`untracked_signal_read`,
/// `foreach_missing_key`, `forbidden_browser_import_in_shared_code`, etc.),
/// quick-fix code actions, Bloom component/signal completions, and hover docs.
class BloomLspServer {
  final Stream<List<int>> _input;
  final StreamSink<List<int>> _output;
  final Map<String, String> _documents = {};
  final List<LintFinding> Function(String source, String filePath)? _dartLinter;
  bool _shutdownRequested = false;

  BloomLspServer({
    required Stream<List<int>> input,
    required StreamSink<List<int>> output,
    List<LintFinding> Function(String source, String filePath)? dartLinter,
  })  : _input = input,
        _output = output,
        _dartLinter = dartLinter;

  /// Listens to LSP JSON-RPC messages until `exit` or input stream closes.
  Future<void> listen() async {
    final buffer = <int>[];
    await for (final chunk in _input) {
      buffer.addAll(chunk);
      while (true) {
        final headerEnd = _indexOfHeaderEnd(buffer);
        if (headerEnd < 0) break;

        final headerText = ascii.decode(buffer.sublist(0, headerEnd));
        final contentLength = _parseContentLength(headerText);
        if (contentLength == null) {
          buffer.removeRange(0, headerEnd + 4);
          continue;
        }

        final bodyStart = headerEnd + 4;
        if (buffer.length < bodyStart + contentLength) break;

        final bodyBytes = buffer.sublist(bodyStart, bodyStart + contentLength);
        buffer.removeRange(0, bodyStart + contentLength);

        final decoded = jsonDecode(utf8.decode(bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final shouldExit = await handleMessage(decoded);
          if (shouldExit) return;
        }
      }
    }
  }

  /// Processes a single decoded JSON-RPC message; returns `true` on `exit`.
  Future<bool> handleMessage(Map<String, dynamic> message) async {
    final method = message['method'] as String?;
    final id = message['id'];
    final params =
        (message['params'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    switch (method) {
      case 'initialize':
        _sendResponse(id, {
          'capabilities': {
            'textDocumentSync': 1,
            'hoverProvider': true,
            'completionProvider': {
              'triggerCharacters': ['.', ':'],
            },
            'codeActionProvider': true,
          },
          'serverInfo': {
            'name': 'bloom-lsp',
            'version': '0.1.0',
          },
        });
        return false;

      case 'initialized':
        return false;

      case 'shutdown':
        _shutdownRequested = true;
        _sendResponse(id, null);
        return false;

      case 'exit':
        return true;

      case 'textDocument/didOpen':
        final doc = params['textDocument'] as Map<String, dynamic>?;
        if (doc != null) {
          final uri = doc['uri'] as String? ?? '';
          final text = doc['text'] as String? ?? '';
          _documents[uri] = text;
          _publishDiagnostics(uri, text);
        }
        return false;

      case 'textDocument/didChange':
        final doc = params['textDocument'] as Map<String, dynamic>?;
        final changes = params['contentChanges'] as List<dynamic>?;
        if (doc != null && changes != null && changes.isNotEmpty) {
          final uri = doc['uri'] as String? ?? '';
          final last = changes.last as Map<String, dynamic>;
          final text = last['text'] as String? ?? '';
          _documents[uri] = text;
          _publishDiagnostics(uri, text);
        }
        return false;

      case 'textDocument/didSave':
        final doc = params['textDocument'] as Map<String, dynamic>?;
        if (doc != null) {
          final uri = doc['uri'] as String? ?? '';
          final text = (params['text'] as String?) ?? _documents[uri];
          if (text != null) {
            _documents[uri] = text;
            _publishDiagnostics(uri, text);
          }
        }
        return false;

      case 'textDocument/didClose':
        final doc = params['textDocument'] as Map<String, dynamic>?;
        if (doc != null) {
          final uri = doc['uri'] as String? ?? '';
          _documents.remove(uri);
          _sendNotification('textDocument/publishDiagnostics', {
            'uri': uri,
            'diagnostics': const <Map<String, dynamic>>[],
          });
        }
        return false;

      case 'textDocument/completion':
        _sendResponse(id, {
          'isIncomplete': false,
          'items': [
            for (final c in _bloomCompletions)
              {
                'label': c.label,
                'kind': c.kind,
                'detail': c.detail,
                'documentation': {
                  'kind': 'markdown',
                  'value': c.documentation,
                },
                'insertText': c.insertText,
                'insertTextFormat': 2,
              },
          ],
        });
        return false;

      case 'textDocument/hover':
        final doc = params['textDocument'] as Map<String, dynamic>?;
        final pos = params['position'] as Map<String, dynamic>?;
        final uri = doc?['uri'] as String? ?? '';
        final text = _documents[uri];
        if (text == null || pos == null) {
          _sendResponse(id, null);
          return false;
        }
        final word = _wordAtPosition(
          text,
          (pos['line'] as int?) ?? 0,
          (pos['character'] as int?) ?? 0,
        );
        final docText = word == null ? null : bloomHoverDocs[word];
        if (docText == null) {
          _sendResponse(id, null);
        } else {
          _sendResponse(id, {
            'contents': {
              'kind': 'markdown',
              'value': docText,
            },
          });
        }
        return false;

      case 'textDocument/codeAction':
        final doc = params['textDocument'] as Map<String, dynamic>?;
        final uri = doc?['uri'] as String? ?? '';
        final context = params['context'] as Map<String, dynamic>?;
        final diagnostics =
            (context?['diagnostics'] as List<dynamic>?) ?? const [];
        final text = _documents[uri] ?? '';
        final actions = _buildCodeActions(uri, text, diagnostics);
        _sendResponse(id, actions);
        return false;

      default:
        if (id != null) {
          _sendError(
            id,
            _shutdownRequested ? -32600 : -32601,
            'Method not found: $method',
          );
        }
        return false;
    }
  }

  void _publishDiagnostics(String uri, String text) {
    final filePath = _uriToPath(uri);
    final List<LintFinding> findings;
    if (filePath.endsWith('.html')) {
      findings = BloomLinter.lintHtmlSource(text, filePath: filePath);
    } else if (filePath.endsWith('.dart')) {
      findings = _dartLinter != null
          ? _dartLinter(text, filePath)
          : BloomLinter.lintDartSource(text, filePath: filePath);
    } else {
      findings = const [];
    }

    final lines = text.split('\n');
    final diagnostics = <Map<String, dynamic>>[
      for (final f in findings)
        _findingToDiagnostic(f, lines),
    ];

    _sendNotification('textDocument/publishDiagnostics', {
      'uri': uri,
      'diagnostics': diagnostics,
    });
  }

  Map<String, dynamic> _findingToDiagnostic(
    LintFinding finding,
    List<String> lines,
  ) {
    final lineIdx = (finding.lineNumber - 1).clamp(0, lines.isEmpty ? 0 : lines.length - 1);
    final lineText = lines.isEmpty ? '' : lines[lineIdx];
    final startChar = lineText.indexOf(finding.snippet.trim());
    final startCol = startChar >= 0 ? startChar : 0;
    final endCol = lineText.length;

    final severity = switch (finding.ruleName) {
      'forbidden_browser_import_in_shared_code' ||
      'browser_import_in_test' ||
      'nullable_event_force_unwrap' =>
        1,
      _ => 2,
    };

    return {
      'range': {
        'start': {'line': lineIdx, 'character': startCol},
        'end': {'line': lineIdx, 'character': endCol},
      },
      'severity': severity,
      'code': finding.ruleName,
      'source': 'bloom',
      'message': finding.message,
    };
  }

  List<Map<String, dynamic>> _buildCodeActions(
    String uri,
    String text,
    List<dynamic> diagnostics,
  ) {
    final actions = <Map<String, dynamic>>[];
    final lines = text.split('\n');

    for (final raw in diagnostics) {
      if (raw is! Map<String, dynamic>) continue;
      final code = raw['code'] as String?;
      final range = raw['range'] as Map<String, dynamic>?;
      final start = range?['start'] as Map<String, dynamic>?;
      final lineIdx = (start?['line'] as int?) ?? 0;
      if (lineIdx < 0 || lineIdx >= lines.length) continue;
      final lineText = lines[lineIdx];

      if (code == 'untracked_signal_read') {
        final match = RegExp(r'\b([A-Za-z_]\w*\.value)\b').firstMatch(lineText);
        if (match != null) {
          actions.add({
            'title': 'Wrap signal read in Live(() => ...)',
            'kind': 'quickfix',
            'diagnostics': [raw],
            'edit': {
              'changes': {
                uri: [
                  {
                    'range': {
                      'start': {'line': lineIdx, 'character': 0},
                      'end': {'line': lineIdx, 'character': lineText.length},
                    },
                    'newText':
                        'Live(() => ${lineText.trim()})',
                  },
                ],
              },
            },
          });
        }
      } else if (code == 'foreach_missing_key') {
        final closeIdx = lineText.lastIndexOf(')');
        if (closeIdx >= 0) {
          actions.add({
            'title': 'Add key: parameter to ForEach',
            'kind': 'quickfix',
            'diagnostics': [raw],
            'edit': {
              'changes': {
                uri: [
                  {
                    'range': {
                      'start': {'line': lineIdx, 'character': closeIdx},
                      'end': {'line': lineIdx, 'character': closeIdx},
                    },
                    'newText': ', key: (item) => item',
                  },
                ],
              },
            },
          });
        }
      } else if (code == 'forbidden_browser_import_in_shared_code' ||
          code == 'browser_import_in_test') {
        actions.add({
          'title': 'Remove browser.dart import',
          'kind': 'quickfix',
          'diagnostics': [raw],
          'edit': {
            'changes': {
              uri: [
                {
                  'range': {
                    'start': {'line': lineIdx, 'character': 0},
                    'end': {'line': lineIdx + 1, 'character': 0},
                  },
                  'newText': '',
                },
              ],
            },
          },
        });
      }
    }

    return actions;
  }

  String? _wordAtPosition(String text, int line, int character) {
    final lines = text.split('\n');
    if (line < 0 || line >= lines.length) return null;
    final lineStr = lines[line];
    if (lineStr.isEmpty) return null;
    final clamped = character.clamp(0, lineStr.length - 1);

    bool isWordChar(int codeUnit) =>
        (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
        (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        codeUnit == 0x5F;

    if (!isWordChar(lineStr.codeUnitAt(clamped))) return null;
    var start = clamped;
    while (start > 0 && isWordChar(lineStr.codeUnitAt(start - 1))) {
      start--;
    }
    var end = clamped + 1;
    while (end < lineStr.length && isWordChar(lineStr.codeUnitAt(end))) {
      end++;
    }
    return lineStr.substring(start, end);
  }

  String _uriToPath(String uri) {
    if (uri.startsWith('file://')) {
      return Uri.parse(uri).toFilePath();
    }
    return uri;
  }

  void _sendResponse(Object? id, Object? result) {
    _sendJson({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    });
  }

  void _sendError(Object? id, int code, String message) {
    _sendJson({
      'jsonrpc': '2.0',
      'id': id,
      'error': {
        'code': code,
        'message': message,
      },
    });
  }

  void _sendNotification(String method, Map<String, dynamic> params) {
    _sendJson({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
  }

  void _sendJson(Map<String, dynamic> payload) {
    final body = utf8.encode(jsonEncode(payload));
    final header = ascii.encode('Content-Length: ${body.length}\r\n\r\n');
    _output.add(header);
    _output.add(body);
  }

  /// Encodes an LSP JSON-RPC payload with `Content-Length` framing.
  static List<int> encodeFrame(Map<String, dynamic> payload) {
    final body = utf8.encode(jsonEncode(payload));
    final header = ascii.encode('Content-Length: ${body.length}\r\n\r\n');
    return <int>[...header, ...body];
  }

  static int _indexOfHeaderEnd(List<int> buffer) {
    for (var i = 0; i <= buffer.length - 4; i++) {
      if (buffer[i] == 13 &&
          buffer[i + 1] == 10 &&
          buffer[i + 2] == 13 &&
          buffer[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  static int? _parseContentLength(String headers) {
    for (final line in headers.split('\r\n')) {
      final lower = line.toLowerCase();
      if (lower.startsWith('content-length:')) {
        return int.tryParse(line.substring('content-length:'.length).trim());
      }
    }
    return null;
  }
}
