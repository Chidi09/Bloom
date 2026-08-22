// lib/src/realtime.dart
import 'dart:async';
import 'dart:convert';
import 'package:signals/signals.dart';

// ─── Wire protocol ──────────────────────────────────────────────────────────
//
// Vendored copy of `bloom_realtime`'s `RealtimeMessage` wire envelope (pure
// Dart, only `dart:convert`). Kept here instead of depending on the
// `bloom_realtime` package because that package transitively requires the
// Flutter SDK (via `bloom_framework`) and uses `dart:io` WebSocket — both
// incompatible with `bloom_js_native`'s zero-Flutter, browser-JS-compilable
// design. This is the same wire format, so a client built on this envelope
// interoperates unmodified with a real Bloom Realtime server.

/// Wire message envelope for Bloom Realtime channel/presence communication.
class RealtimeMessage {
  /// Message type (e.g. `'subscribe'`, `'broadcast'`, `'presence_join'`).
  final String type;

  /// Channel identifier. Optional for system messages like ping/pong.
  final String? channel;

  /// Payload map associated with the event.
  final Map<String, dynamic> payload;

  const RealtimeMessage({
    required this.type,
    this.channel,
    this.payload = const {},
  });

  static const String typeSubscribe = 'subscribe';
  static const String typeUnsubscribe = 'unsubscribe';
  static const String typeBroadcast = 'broadcast';
  static const String typePresenceJoin = 'presence_join';
  static const String typePresenceLeave = 'presence_leave';
  static const String typePresenceState = 'presence_state';
  static const String typeError = 'error';
  static const String typePing = 'ping';
  static const String typePong = 'pong';

  factory RealtimeMessage.subscribe(String channel) =>
      RealtimeMessage(type: typeSubscribe, channel: channel);

  factory RealtimeMessage.unsubscribe(String channel) =>
      RealtimeMessage(type: typeUnsubscribe, channel: channel);

  factory RealtimeMessage.broadcast(String channel, Map<String, dynamic> payload) =>
      RealtimeMessage(type: typeBroadcast, channel: channel, payload: payload);

  factory RealtimeMessage.presenceJoin(String channel, Map<String, dynamic> userInfo) =>
      RealtimeMessage(type: typePresenceJoin, channel: channel, payload: userInfo);

  factory RealtimeMessage.presenceLeave(String channel, Map<String, dynamic> userInfo) =>
      RealtimeMessage(type: typePresenceLeave, channel: channel, payload: userInfo);

  factory RealtimeMessage.presenceState(String channel, List<Map<String, dynamic>> presences) =>
      RealtimeMessage(type: typePresenceState, channel: channel, payload: {'presences': presences});

  factory RealtimeMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final channel = json['channel'] as String?;
    final rawPayload = json['payload'];
    final Map<String, dynamic> payload;
    if (rawPayload is Map<String, dynamic>) {
      payload = rawPayload;
    } else if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    } else {
      payload = const {};
    }
    return RealtimeMessage(type: type, channel: channel, payload: payload);
  }

  static RealtimeMessage? tryParse(dynamic raw) {
    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return RealtimeMessage.fromJson(decoded);
        if (decoded is Map) return RealtimeMessage.fromJson(Map<String, dynamic>.from(decoded));
      } else if (raw is List<int>) {
        final decoded = jsonDecode(utf8.decode(raw));
        if (decoded is Map<String, dynamic>) return RealtimeMessage.fromJson(decoded);
        if (decoded is Map) return RealtimeMessage.fromJson(Map<String, dynamic>.from(decoded));
      } else if (raw is Map<String, dynamic>) {
        return RealtimeMessage.fromJson(raw);
      } else if (raw is Map) {
        return RealtimeMessage.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // Invalid JSON or format
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (channel != null) 'channel': channel,
        if (payload.isNotEmpty) 'payload': payload,
      };

  String encode() => jsonEncode(toJson());

  @override
  String toString() => 'RealtimeMessage(type: $type, channel: $channel, payload: $payload)';
}

// ─── Connection state ───────────────────────────────────────────────────────

/// Connection states for a [BloomRealtimeChannelClient].
enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

// ─── Client contract ────────────────────────────────────────────────────────

/// Minimal realtime client contract that [BloomRealtimeBinding] wraps.
/// A concrete implementation (e.g. a browser `package:web` WebSocket client)
/// lives outside this pure-Dart file per project convention (`package:web`
/// is confined to `mount.dart`/`*_browser.dart` files).
abstract class BloomRealtimeChannelClient {
  /// Current connection state.
  RealtimeConnectionState get state;

  /// Stream of connection state changes.
  Stream<RealtimeConnectionState> get onStateChanged;

  /// Subscribes to a channel and returns a broadcast stream of message payloads.
  Stream<Map<String, dynamic>> subscribe(String channelName);

  /// Joins presence in [channelName] with [userInfo] metadata. Returns a
  /// stream of the current active presence list.
  Stream<List<Map<String, dynamic>>> joinPresence(
    String channelName,
    Map<String, dynamic> userInfo,
  );

  /// Unsubscribes from a channel.
  void unsubscribe(String channelName);

  /// Releases all client resources.
  void dispose();
}

// ─── BloomRealtimeBinding ───────────────────────────────────────────────────

/// Reactive signal-backed bindings for a [BloomRealtimeChannelClient].
/// Wraps channel subscriptions and presence streams as observable signals.
/// Pure-Dart, no DOM dependency.
class BloomRealtimeBinding {
  final BloomRealtimeChannelClient client;

  late final Signal<RealtimeConnectionState> _connectionState;
  final Map<String, Signal<Map<String, dynamic>?>> _channelSignals = {};
  final Map<String, Signal<List<Map<String, dynamic>>>> _presenceSignals = {};
  final List<StreamSubscription<dynamic>> _subs = [];

  BloomRealtimeBinding({required this.client}) {
    _connectionState = signal(client.state);
    _subs.add(client.onStateChanged.listen((s) {
      _connectionState.value = s;
    }));
  }

  /// Reactive signal for the current connection state.
  ReadonlySignal<RealtimeConnectionState> get connectionState =>
      _connectionState.readonly();

  /// Returns a [ReadonlySignal] for the latest message on [channelName].
  /// Starts as `null`. Each new broadcast event replaces the signal value.
  /// Calling with the same [channelName] always returns the same signal instance.
  ReadonlySignal<Map<String, dynamic>?> channel(String channelName) {
    if (_channelSignals.containsKey(channelName)) {
      return _channelSignals[channelName]!.readonly();
    }
    final sig = signal<Map<String, dynamic>?>(null);
    _channelSignals[channelName] = sig;
    _subs.add(client.subscribe(channelName).listen((msg) => sig.value = msg));
    return sig.readonly();
  }

  /// Returns a [ReadonlySignal] for the current presence list on [channelName].
  /// Starts as an empty list. Updates on every presence state event.
  /// [userInfo] is the metadata this client publishes for itself when joining.
  ReadonlySignal<List<Map<String, dynamic>>> presence(
    String channelName, {
    Map<String, dynamic> userInfo = const {},
  }) {
    if (_presenceSignals.containsKey(channelName)) {
      return _presenceSignals[channelName]!.readonly();
    }
    final sig = signal<List<Map<String, dynamic>>>(const []);
    _presenceSignals[channelName] = sig;
    _subs.add(client
        .joinPresence(channelName, userInfo)
        .listen((users) => sig.value = users));
    return sig.readonly();
  }

  bool _disposed = false;

  /// Cancels all subscriptions and releases resources. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final subs = List<StreamSubscription<dynamic>>.of(_subs);
    _subs.clear();
    for (final sub in subs) {
      await sub.cancel();
    }
  }
}

/// Creates a [BloomRealtimeBinding] wrapping [client].
BloomRealtimeBinding realtimeBinding(BloomRealtimeChannelClient client) =>
    BloomRealtimeBinding(client: client);
