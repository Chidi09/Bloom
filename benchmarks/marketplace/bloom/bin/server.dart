import 'dart:io';
import '../lib/server.dart';

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? (args.isNotEmpty ? int.tryParse(args.first) ?? 3000 : 3000);
  final router = buildRouter();
  final server = await router.serve(address: InternetAddress.anyIPv4, port: port);
  print('Marketplace Bloom server running on http://${server.address.host}:${server.port}');
}
