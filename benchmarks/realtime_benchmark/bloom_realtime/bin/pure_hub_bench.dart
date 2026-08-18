import 'dart:async';
import 'dart:io';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  final hub = BloomChannelHub();
  const clientCount = 1000;
  const broadcastCount = 1000;

  final controller = StreamController<dynamic>.broadcast();

  for (var i = 0; i < clientCount; i++) {
    final s = _MockWebSocket(controller.stream);
    hub.registerConnection(s, connectionId: 'client_$i', autoHandleProtocol: false);
    hub.subscribe('room:bench', 'client_$i');
  }

  print('=== BloomChannelHub In-Memory Dispatch Benchmark ===');
  print('Subscribers: $clientCount sockets in room:bench');
  print('Broadcasts:  $broadcastCount messages (${clientCount * broadcastCount} total dispatches)');

  final payload = {'index': 1, 'text': 'Realtime payload', 'data': [1, 2, 3]};

  // Warmup
  for (var b = 0; b < 10; b++) {
    hub.broadcast('room:bench', payload);
  }

  final sw = Stopwatch()..start();
  for (var b = 0; b < broadcastCount; b++) {
    hub.broadcast('room:bench', payload);
  }
  sw.stop();

  final elapsedMs = sw.elapsedMilliseconds;
  final totalDeliveries = clientCount * broadcastCount;
  final throughput = (totalDeliveries / (elapsedMs / 1000)).toStringAsFixed(0);

  print('Elapsed Time: ${elapsedMs}ms');
  print('Pure Dispatch Throughput: $throughput messages/sec');
}

class _MockWebSocket extends Stream<dynamic> implements WebSocket {
  final Stream<dynamic> _stream;
  int messageCount = 0;

  _MockWebSocket(this._stream);

  @override
  int get readyState => WebSocket.open;

  @override
  void add(dynamic data) {
    messageCount++;
  }

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future get done => Completer().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
