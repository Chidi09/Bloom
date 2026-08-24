/// A lightweight, high-performance real-time pub/sub, presence, and live query invalidation layer for Bloom.
///
/// `bloom_realtime` provides full-stack real-time infrastructure designed for both
/// server-side connection management and client-side reactive subscriptions.
///
/// ### Core Capabilities
/// - **Server-Side Pub/Sub ([BloomChannelHub])**: In-memory channel registry, connection tracking, and dead-socket pruned broadcasts.
/// - **Presence Tracking ([BloomPresenceTracker])**: Track online users, state snapshots, and automatic join/leave broadcasts.
/// - **Multi-Core Clustering ([BloomRealtimeCluster])**: High-throughput multi-isolate orchestrator with shared TCP port binding and peer mesh routing.
/// - **Client WebSocket Manager ([BloomRealtimeClient])**: Resilient client with exponential backoff reconnection, automatic channel resubscription, and heartbeat keep-alives.
/// - **Wire Protocol ([RealtimeMessage])**: Pure Dart wire message envelope with JSON and UTF-8 byte serialization.
///
/// ### Server Example
/// ```dart
/// import 'dart:io';
/// import 'package:bloom_realtime/bloom_realtime.dart';
///
/// void main() async {
///   final hub = BloomChannelHub();
///   final presence = BloomPresenceTracker(hub: hub);
///   final server = await HttpServer.bind('0.0.0.0', 8080);
///
///   server.listen((HttpRequest request) async {
///     if (request.uri.path == '/ws/realtime' && WebSocketTransformer.isUpgradeRequest(request)) {
///       final socket = await BloomChannelHub.upgrade(request);
///       presence.attachProtocolHandler(socket);
///     } else {
///       request.response.statusCode = HttpStatus.notFound;
///       await request.response.close();
///     }
///   });
/// }
/// ```
///
/// ### Client Example
/// ```dart
/// import 'package:bloom_realtime/bloom_realtime.dart';
///
/// void main() async {
///   final client = BloomRealtimeClient(
///     uri: Uri.parse('ws://localhost:8080/ws/realtime'),
///   );
///   await client.connect();
///
///   // Subscribe to broadcast events on a channel
///   final stream = client.subscribe('chat:general');
///   stream.listen((payload) {
///     print('Received message: $payload');
///   });
///
///   // Broadcast a message to the channel
///   client.broadcast('chat:general', {'text': 'Hello, world!'});
/// }
/// ```
library;

export 'src/protocol.dart';
export 'src/server/channel_hub.dart';
export 'src/server/presence.dart';
export 'src/server/cluster.dart';
export 'src/client/realtime_client.dart';
