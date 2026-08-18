import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:bloom_realtime/bloom_realtime.dart';

class _ClusterBroadcastEvent {
  final String channel;
  final Map<String, dynamic> payload;

  _ClusterBroadcastEvent({
    required this.channel,
    required this.payload,
  });
}

class _WorkerInit {
  final int workerId;
  final int port;
  final SendPort masterPort;

  _WorkerInit({
    required this.workerId,
    required this.port,
    required this.masterPort,
  });
}

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 5004;
  final workerCount = Platform.numberOfProcessors > 0 ? Platform.numberOfProcessors : 4;

  print('=== Starting Clustered Bloom Realtime Server ===');
  print('Isolates: $workerCount workers (Multi-Core Port Sharing)');

  final masterReceivePort = ReceivePort();
  final workerSendPorts = <SendPort>[];

  var workersReady = 0;
  final allWorkersReady = Completer<void>();

  masterReceivePort.listen((message) {
    if (message is SendPort) {
      workerSendPorts.add(message);
      workersReady++;
      if (workersReady == workerCount) {
        for (final p in workerSendPorts) {
          p.send(workerSendPorts);
        }
        allWorkersReady.complete();
      }
    }
  });

  for (var i = 0; i < workerCount; i++) {
    await Isolate.spawn(
      _runRealtimeWorker,
      _WorkerInit(
        workerId: i,
        port: port,
        masterPort: masterReceivePort.sendPort,
      ),
    );
  }

  await allWorkersReady.future;
  print('All $workerCount realtime isolates initialized on ws://127.0.0.1:$port/ws');

  await Completer<void>().future;
}

void _runRealtimeWorker(_WorkerInit init) async {
  final hub = BloomChannelHub();
  final workerReceivePort = ReceivePort();
  init.masterPort.send(workerReceivePort.sendPort);

  List<SendPort> peerPorts = [];
  bool isForwardingFromPeer = false;

  workerReceivePort.listen((message) {
    if (message is List<SendPort>) {
      peerPorts = message;
    } else if (message is _ClusterBroadcastEvent) {
      isForwardingFromPeer = true;
      hub.broadcast(message.channel, message.payload);
      isForwardingFromPeer = false;
    }
  });

  hub.onBroadcast = (channel, payload) {
    if (!isForwardingFromPeer) {
      for (var i = 0; i < peerPorts.length; i++) {
        if (i != init.workerId) {
          peerPorts[i].send(_ClusterBroadcastEvent(
            channel: channel,
            payload: payload,
          ));
        }
      }
    }
  };

  // Bind with shared: true to distribute incoming TCP connections evenly across all isolates
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    init.port,
    shared: true,
  );

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
      hub.broadcast(channel, payload);
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'success': true}))
        ..close();
    } else if (request.uri.path == '/stats') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'workerId': init.workerId,
          'activeConnections': hub.activeConnectionCount,
        }))
        ..close();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
    }
  });
}
