import 'dart:io';

import 'package:args/command_runner.dart';

import '../lsp/bloom_lsp_server.dart';

/// Starts the Bloom Language Server (LSP) over stdio for editor IntelliSense.
class LspCommand extends Command<int> {
  @override
  final String name = 'lsp';

  @override
  final String description =
      'Start the Bloom Language Server (LSP) over stdio for signal, component, and lint IntelliSense.';

  @override
  Future<int> run() async {
    final server = BloomLspServer(input: stdin, output: stdout);
    await server.listen();
    return 0;
  }
}
