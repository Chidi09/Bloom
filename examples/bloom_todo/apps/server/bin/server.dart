import 'dart:io';

import 'package:bloom_framework/bloom_server.dart';
import '../lib/router.dart';

/// Entrypoint for bloom_todo_server.
Future<void> main(List<String> args) async {
  const port = 8080;
  final isolateCount = Platform.numberOfProcessors;

  _printBanner(port: port, isolates: isolateCount);

  final router = BloomApiRouter();
  registerUrls(router);

  final server = await router.serve(port: port);
  print('🌸 Bloom Todo Server listening on http://${server.address.host}:${server.port}');
}

void _printBanner({required int port, required int isolates}) {
  const reset = '\x1B[0m';
  const cyan = '\x1B[36m';
  const bold = '\x1B[1m';
  const green = '\x1B[32m';

  print('');
  print('$cyan$bold┌────────────────────────────────────────────┐$reset');
  print('$cyan$bold│          🌸  bloom_todo_server              │$reset');
  print('$cyan$bold└────────────────────────────────────────────┘$reset');
  print('$green  ✔ Port      :$reset http://0.0.0.0:$port');
  print('$green  ✔ Isolates  :$reset $isolates');
  print('$green  ✔ Started   :$reset ${DateTime.now().toUtc().toIso8601String()}');
  print('');
}
