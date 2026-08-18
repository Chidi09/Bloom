import 'dart:io';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  print('Starting BloomRealtimeCluster on port 5005...');
  final cluster = await BloomRealtimeCluster.bind(
    port: 5005,
    workers: 4,
  );
  print('✓ BloomRealtimeCluster running with ${cluster.workerCount} workers!');

  // Test broadcast
  cluster.broadcast('room:test', {'msg': 'Hello from cluster!'});

  await Future.delayed(const Duration(seconds: 2));
  cluster.close();
  print('✓ BloomRealtimeCluster closed successfully!');
  exit(0);
}
