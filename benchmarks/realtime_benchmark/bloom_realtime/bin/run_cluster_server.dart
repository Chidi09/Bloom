import 'dart:io';
import 'package:bloom_realtime/bloom_realtime.dart';

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 5005;
  final workers = Platform.numberOfProcessors > 0 ? Platform.numberOfProcessors : 4;

  print('======================================================');
  print('  Starting Production BloomRealtimeCluster (Port: $port)');
  print('  Workers: $workers Isolates (Multi-Core shared: true)');
  print('  TCP_NODELAY: Enabled | compressionOff: Enabled');
  print('======================================================');

  final cluster = await BloomRealtimeCluster.bind(
    port: port,
    wsPath: '/ws',
    workers: workers,
    compression: CompressionOptions.compressionOff,
    tcpNoDelay: true,
  );

  print('✓ BloomRealtimeCluster is ready and accepting WebSocket connections on ws://127.0.0.1:$port/ws');

  // Listen for SIGINT / SIGTERM
  ProcessSignal.sigint.watch().listen((_) {
    cluster.close();
    exit(0);
  });
}
