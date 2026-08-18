/// A lightweight, real-time pub/sub, presence, and live query invalidation layer for Bloom server and client applications.
///
/// Features:
/// - Server-side [BloomChannelHub] for channel subscriptions and dead-socket pruned broadcasts.
/// - Server-side [BloomPresenceTracker] for join/leave user presence tracking.
/// - Client-side [BloomRealtimeClient] with robust exponential backoff reconnection.
/// - Wire protocol [RealtimeMessage] serialization and deserialization.
/// - Seamless [BloomData] query invalidation bridge ([RealtimeQueryBridge], [BloomRealtimeClientQueryBridgeExtension]).
///
/// ```dart
/// import 'package:bloom_framework/bloom_data.dart';
/// import 'package:bloom_realtime/bloom_realtime.dart';
///
/// void main() async {
///   // 1. Connect realtime client
///   final realtime = BloomRealtimeClient(
///     uri: Uri.parse('ws://localhost:8080/ws/realtime'),
///   );
///   await realtime.connect();
///
///   // 2. Invalidate query cache automatically on channel broadcasts
///   realtime.invalidateQueriesOnBroadcast(
///     channel: 'lists:42',
///     key: ['lists', '42', 'todos'],
///   );
/// }
/// ```
library;

export 'src/protocol.dart';
export 'src/server/channel_hub.dart';
export 'src/server/presence.dart';
export 'src/server/cluster.dart';
export 'src/client/realtime_client.dart';
