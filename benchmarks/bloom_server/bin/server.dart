import 'dart:io';
import 'package:bloom_framework/bloom_server.dart';

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 4001;
  final router = BloomApiRouter();

  router.get('/ping', (req) {
    return BloomResponse.json({'message': 'hello world'});
  });

  router.get('/users/:id', (req) {
    final id = req.params['id'] ?? '';
    return BloomResponse.json({
      'id': id,
      'name': 'Alice',
      'role': 'admin',
    });
  });

  router.post('/echo', (req) {
    final data = req.json();
    return BloomResponse.json({
      'received': true,
      'data': data,
    });
  });

  final server = await router.serve(
    address: InternetAddress.loopbackIPv4,
    port: port,
  );

  print('Bloom server running on http://127.0.0.1:$port');
}
