import 'dart:io';
import '../lib/server.dart';

void main(List<String> args) async {
  int? portArg;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--port' && i + 1 < args.length) {
      portArg = int.tryParse(args[i + 1]);
    } else if (a.startsWith('--port=')) {
      portArg = int.tryParse(a.substring('--port='.length));
    } else if (portArg == null) {
      portArg = int.tryParse(a);
    }
  }
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? portArg ?? 3000;
  final router = buildRouter();
  final server = await router.serve(address: InternetAddress.anyIPv4, port: port);
  print('Marketplace Bloom server running on http://${server.address.host}:${server.port}');
}
