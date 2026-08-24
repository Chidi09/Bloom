/// Query cache invalidation extras for `bloom_realtime`.
///
/// Bridges channel broadcasts directly to `bloom_js_native`'s pure-Dart
/// `BloomData` client query cache (signals-backed, zero Flutter dependency).
///
/// Import this library in client applications that use `BloomQuery` or `BloomData`.
/// Pure server entrypoints that do not need the client query invalidation bridge
/// can import `package:bloom_realtime/bloom_realtime.dart` instead.
///
/// ### Example
/// ```dart
/// import 'package:bloom_js_native/bloom_js_native.dart';
/// import 'package:bloom_realtime/bloom_realtime_client.dart';
///
/// void main() async {
///   final client = BloomRealtimeClient(
///     uri: Uri.parse('ws://localhost:8080/ws/realtime'),
///   );
///   await client.connect();
///
///   // Automatically invalidate BloomData query cache when updates arrive
///   final bridge = client.invalidateQueriesOnBroadcast(
///     channel: 'lists:42',
///     key: ['lists', '42', 'todos'],
///   );
///
///   // Later, when tearing down or navigating away:
///   bridge.cancel();
/// }
/// ```
library;

export 'bloom_realtime.dart';
export 'src/client/query_bridge.dart';

