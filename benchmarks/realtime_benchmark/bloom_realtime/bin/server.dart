import 'dart:convert';
import 'dart:io';
import 'package:bloom_realtime/bloom_realtime.dart';

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 5001;
  final hub = BloomChannelHub();

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('Bloom Realtime Server running on ws://127.0.0.1:$port/ws');

  server.listen((HttpRequest request) async {
    if (request.uri.path == '/ws') {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        hub.registerConnection(socket);
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.close();
      }
    } else if (request.uri.path == '/broadcast' && request.method == 'POST') {
      final bodyStr = await utf8.decodeStream(request);
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;
      final channel = json['channel'] as String;
      final payload = json['payload'] as Map<String, dynamic>;
      final sentCount = hub.broadcast(channel, payload);
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'sent': sentCount}))
        ..close();
    } else if (request.uri.path == '/stats') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'activeConnections': hub.activeConnectionCount,
          'activeChannels': hub.activeChannelCount,
        }))
        ..close();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
    }
  });
}
