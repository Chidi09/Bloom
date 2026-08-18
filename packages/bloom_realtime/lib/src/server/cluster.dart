import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../protocol.dart';
import 'channel_hub.dart';

/// Inter-isolate broadcast event envelope passed across worker SendPorts.
class _ClusterBroadcastMessage {
  final String channel;
  final Map<String, dynamic> payload;
  final bool asBinary;

  _ClusterBroadcastMessage({
    required this.channel,
    required this.payload,
    this.asBinary = false,
  });
}

/// Worker initialization payload passed to Isolate.spawn.
class _ClusterWorkerInit {
  final int workerId;
  final String address;
  final int port;
  final String wsPath;
  final SendPort masterPort;
  final CompressionOptions compression;
  final bool tcpNoDelay;

  _ClusterWorkerInit({
    required this.workerId,
    required this.address,
    required this.port,
    required this.wsPath,
    required this.masterPort,
    required this.compression,
    required this.tcpNoDelay,
  });
}

/// High-throughput multi-isolate cluster orchestrator for Bloom Realtime.
///
/// Distributes incoming WebSocket connections across multiple CPU cores using
/// kernel-level port sharing (`shared: true`), synchronizing pub/sub broadcasts
/// in-memory via high-speed isolate `SendPort` event channels.
class BloomRealtimeCluster {
  /// Number of active worker isolates running in the cluster.
  final int workerCount;

  /// Listening port for the cluster.
  final int port;

  final List<Isolate> _isolates;
  final List<SendPort> _workerPorts;
  final ReceivePort _masterReceivePort;

  BloomRealtimeCluster._({
    required this.workerCount,
    required this.port,
    required List<Isolate> isolates,
    required List<SendPort> workerPorts,
    required ReceivePort masterReceivePort,
  })  : _isolates = isolates,
        _workerPorts = workerPorts,
        _masterReceivePort = masterReceivePort;

  /// Spawns and starts a multi-isolate realtime cluster.
  ///
  /// - [address]: Loopback or bind IP (defaults to `'0.0.0.0'`).
  /// - [port]: TCP port to listen on (defaults to `8080`).
  /// - [wsPath]: HTTP path prefix for WebSocket upgrade (defaults to `'/ws'`).
  /// - [workers]: Number of isolate workers (defaults to [Platform.numberOfProcessors]).
  /// - [compression]: WebSocket compression options (defaults to [CompressionOptions.compressionOff]).
  /// - [tcpNoDelay]: Sets `TCP_NODELAY` on sockets (defaults to `true`).
  static Future<BloomRealtimeCluster> bind({
    String address = '0.0.0.0',
    int port = 8080,
    String wsPath = '/ws',
    int? workers,
    CompressionOptions compression = CompressionOptions.compressionOff,
    bool tcpNoDelay = true,
  }) async {
    final workerCount = workers ?? (Platform.numberOfProcessors > 0 ? Platform.numberOfProcessors : 2);
    final masterReceivePort = ReceivePort();
    final workerPorts = <SendPort>[];
    final isolates = <Isolate>[];

    var readyCount = 0;
    final readyCompleter = Completer<void>();

    masterReceivePort.listen((msg) {
      if (msg is SendPort) {
        workerPorts.add(msg);
        readyCount++;
        if (readyCount == workerCount) {
          // Broadcast full worker port table to every worker for mesh routing
          for (final wp in workerPorts) {
            wp.send(workerPorts);
          }
          readyCompleter.complete();
        }
      }
    });

    for (var i = 0; i < workerCount; i++) {
      final iso = await Isolate.spawn(
        _clusterWorkerEntrypoint,
        _ClusterWorkerInit(
          workerId: i,
          address: address,
          port: port,
          wsPath: wsPath,
          masterPort: masterReceivePort.sendPort,
          compression: compression,
          tcpNoDelay: tcpNoDelay,
        ),
      );
      isolates.add(iso);
    }

    await readyCompleter.future;

    return BloomRealtimeCluster._(
      workerCount: workerCount,
      port: port,
      isolates: isolates,
      workerPorts: workerPorts,
      masterReceivePort: masterReceivePort,
    );
  }

  /// Broadcasts an event across all cluster workers and connected WebSocket clients.
  void broadcast(String channel, Map<String, dynamic> payload, {bool asBinary = false}) {
    final msg = _ClusterBroadcastMessage(
      channel: channel,
      payload: payload,
      asBinary: asBinary,
    );
    for (final wp in _workerPorts) {
      wp.send(msg);
    }
  }

  /// Shuts down all worker isolates and releases listening ports.
  void close() {
    for (final wp in _workerPorts) {
      wp.send('shutdown');
    }
    for (final iso in _isolates) {
      iso.kill(priority: Isolate.immediate);
    }
    _masterReceivePort.close();
  }
}

void _clusterWorkerEntrypoint(_ClusterWorkerInit init) async {
  final hub = BloomChannelHub();
  final workerReceivePort = ReceivePort();
  init.masterPort.send(workerReceivePort.sendPort);

  List<SendPort> peerPorts = [];
  bool isForwardingFromPeer = false;
  HttpServer? server;

  workerReceivePort.listen((message) async {
    if (message is List<SendPort>) {
      peerPorts = message;
    } else if (message is _ClusterBroadcastMessage) {
      isForwardingFromPeer = true;
      hub.broadcast(message.channel, message.payload, asBinary: message.asBinary);
      isForwardingFromPeer = false;
    } else if (message == 'shutdown') {
      hub.dispose();
      await server?.close(force: true);
      workerReceivePort.close();
    }
  });

  hub.onBroadcast = (channel, payload) {
    if (!isForwardingFromPeer) {
      final clusterMsg = _ClusterBroadcastMessage(channel: channel, payload: payload);
      for (var i = 0; i < peerPorts.length; i++) {
        if (i != init.workerId) {
          peerPorts[i].send(clusterMsg);
        }
      }
    }
  };

  final bindAddress = init.address == '0.0.0.0'
      ? InternetAddress.anyIPv4
      : InternetAddress(init.address);

  server = await HttpServer.bind(
    bindAddress,
    init.port,
    shared: true,
  );

  server.listen((HttpRequest request) async {
    if (request.uri.path == init.wsPath) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final socket = await BloomChannelHub.upgrade(
            request,
            compression: init.compression,
          );
          hub.registerConnection(socket);
        } catch (_) {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.close();
        }
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.close();
      }
    } else if (request.uri.path == '/health') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'healthy', 'workerId': init.workerId}))
        ..close();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
    }
  });
}
