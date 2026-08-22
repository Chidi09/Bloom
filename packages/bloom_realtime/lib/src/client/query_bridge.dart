// lib/src/client/query_bridge.dart
import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'realtime_client.dart';

/// Bridges Realtime channel broadcasts to the `BloomData` client query cache.
///
/// When a broadcast arrives on [channel], this helper calls [BloomData.invalidateQueries(key)]
/// (or custom invalidation logic), immediately causing active `BloomQuery` widgets and listeners
/// tracking [key] to refetch in the background.
class RealtimeQueryBridge {
  final StreamSubscription<Map<String, dynamic>> _subscription;

  RealtimeQueryBridge._(this._subscription);

  /// Cancels the bridge subscription.
  void cancel() {
    _subscription.cancel();
  }

  /// Listens to a realtime channel on [client] and calls [BloomData.invalidateQueries]
  /// with [key] on every received message, or when [filter] matches.
  ///
  /// - [client]: Active [BloomRealtimeClient] connection.
  /// - [channel]: Channel name to listen to.
  /// - [key]: `BloomData` query key to invalidate.
  /// - [filter]: Optional callback to filter which broadcast payloads trigger invalidation.
  ///
  /// Returns a [RealtimeQueryBridge] whose [cancel] method tears down the subscription.
  ///
  /// Example:
  /// ```dart
  /// final bridge = RealtimeQueryBridge.bind(
  ///   client: realtimeClient,
  ///   channel: 'todos:42',
  ///   key: ['todos', 42],
  /// );
  /// ```
  static RealtimeQueryBridge bind({
    required BloomRealtimeClient client,
    required String channel,
    required List<dynamic> key,
    bool Function(Map<String, dynamic> payload)? filter,
  }) {
    final stream = client.subscribe(channel);
    final sub = stream.listen((payload) {
      if (filter == null || filter(payload)) {
        BloomData.invalidateQueries(key);
      }
    });
    return RealtimeQueryBridge._(sub);
  }

  /// Listens to an existing channel [stream] and calls [BloomData.invalidateQueries]
  /// with [key] on every message (or when [filter] returns `true`).
  ///
  /// - [stream]: Broadcast event stream from a channel subscription.
  /// - [key]: `BloomData` query key to invalidate.
  /// - [filter]: Optional filter predicate.
  static RealtimeQueryBridge bindStream({
    required Stream<Map<String, dynamic>> stream,
    required List<dynamic> key,
    bool Function(Map<String, dynamic> payload)? filter,
  }) {
    final sub = stream.listen((payload) {
      if (filter == null || filter(payload)) {
        BloomData.invalidateQueries(key);
      }
    });
    return RealtimeQueryBridge._(sub);
  }
}

/// Extension on [BloomRealtimeClient] for seamless query invalidation binding.
extension BloomRealtimeClientQueryBridgeExtension on BloomRealtimeClient {
  /// Binds a realtime channel directly to a `BloomData` query key for automatic invalidation.
  ///
  /// Example:
  /// ```dart
  /// client.invalidateQueriesOnBroadcast(
  ///   channel: 'lists:123',
  ///   key: ['lists', 123],
  /// );
  /// ```
  RealtimeQueryBridge invalidateQueriesOnBroadcast({
    required String channel,
    required List<dynamic> key,
    bool Function(Map<String, dynamic> payload)? filter,
  }) {
    return RealtimeQueryBridge.bind(
      client: this,
      channel: channel,
      key: key,
      filter: filter,
    );
  }
}

/// Extension on channel streams for ergonomic query invalidation binding.
extension RealtimeChannelStreamQueryBridgeExtension on Stream<Map<String, dynamic>> {
  /// Invalidates queries matching [key] whenever an event is emitted by this channel stream.
  RealtimeQueryBridge invalidateQueries(
    List<dynamic> key, {
    bool Function(Map<String, dynamic> payload)? filter,
  }) {
    return RealtimeQueryBridge.bindStream(
      stream: this,
      key: key,
      filter: filter,
    );
  }
}
