import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  final hub = BloomChannelHub();
  const clientCount = 1000;
  const broadcastCount = 100;

  // Create mock sockets with dummy stream sinks to isolate pure hub dispatch latency
  final mockSockets = <_MockWebSocket>[];
  for (var i = 0; i < clientCount; i++) {
    final s = _MockWebSocket();
    mockSockets.add(s);
    hub.registerConnection(s as dynamic, connectionId: 'client_$i');
    hub.subscribe('room:bench', 'client_$i');
  }

  print('=== BloomChannelHub Pure Dispatch Benchmark ===');
  print('Subscribers: $clientCount sockets in room:bench');
  print('Broadcasts:  $broadcastCount messages (${clientCount * broadcastCount} total message dispatches)');

  final payload = {'index': 1, 'text': 'Realtime payload', 'data': [1, 2, 3]};

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

class _MockWebSocket implements WebSocket {
  int messageCount = 0;
  @override
  int readyState = WebSocket.open;

  @override
  void add(dynamic data) {
    messageCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
