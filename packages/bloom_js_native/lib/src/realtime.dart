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

/// Wire message envelope for Bloom Realtime channel, broadcast, and presence communication.
///
/// Encapsulates message framing across WebSockets or server-sent events. Pure Dart,
/// requiring only `dart:convert`, ensuring compatibility across Dart VM, SSR, and browser runtimes.
///
/// ### Message Types
/// - Channel subscription: [typeSubscribe], [typeUnsubscribe]
/// - Broadcast events: [typeBroadcast]
/// - Presence tracking: [typePresenceJoin], [typePresenceLeave], [typePresenceState]
/// - System heartbeats: [typePing], [typePong], [typeError]
///
/// ### Example
/// ```dart
/// // Construct a broadcast message
/// final msg = RealtimeMessage.broadcast('chat:general', {'text': 'Hello, world!'});
/// final jsonString = msg.encode();
///
/// // Parse incoming wire message
/// final parsed = RealtimeMessage.tryParse(jsonString);
/// if (parsed != null && parsed.type == RealtimeMessage.typeBroadcast) {
///   print('Message on ${parsed.channel}: ${parsed.payload}');
/// }
/// ```
class RealtimeMessage {
  /// Message type identifier (e.g. `'subscribe'`, `'broadcast'`, `'presence_join'`).
  final String type;

  /// Channel identifier associated with this message, or `null` for system-level messages like ping/pong.
  final String? channel;

  /// Payload map associated with the event.
  final Map<String, dynamic> payload;

  /// Creates a [RealtimeMessage] envelope with a [type], optional [channel], and optional [payload].
  const RealtimeMessage({
    required this.type,
    this.channel,
    this.payload = const {},
  });

  /// Wire action type indicating a channel subscription request.
  static const String typeSubscribe = 'subscribe';

  /// Wire action type indicating an unsubscription request.
  static const String typeUnsubscribe = 'unsubscribe';

  /// Wire action type indicating an arbitrary event broadcast to channel subscribers.
  static const String typeBroadcast = 'broadcast';

  /// Wire action type indicating a client joined channel presence.
  static const String typePresenceJoin = 'presence_join';

  /// Wire action type indicating a client left channel presence.
  static const String typePresenceLeave = 'presence_leave';

  /// Wire action type carrying the full snapshot of active channel presences.
  static const String typePresenceState = 'presence_state';

  /// Wire action type indicating a server-side or protocol error.
  static const String typeError = 'error';

  /// Wire heartbeat ping message.
  static const String typePing = 'ping';

  /// Wire heartbeat pong response.
  static const String typePong = 'pong';

  /// Creates a subscription message targeting [channel].
  ///
  /// ```dart
  /// final msg = RealtimeMessage.subscribe('room:lobby');
  /// ```
  factory RealtimeMessage.subscribe(String channel) =>
      RealtimeMessage(type: typeSubscribe, channel: channel);

  /// Creates an unsubscription message targeting [channel].
  ///
  /// ```dart
  /// final msg = RealtimeMessage.unsubscribe('room:lobby');
  /// ```
  factory RealtimeMessage.unsubscribe(String channel) =>
      RealtimeMessage(type: typeUnsubscribe, channel: channel);

  /// Creates a broadcast event message on [channel] with the given [payload].
  ///
  /// ```dart
  /// final msg = RealtimeMessage.broadcast('room:lobby', {'action': 'typing', 'user': 'Alice'});
  /// ```
  factory RealtimeMessage.broadcast(String channel, Map<String, dynamic> payload) =>
      RealtimeMessage(type: typeBroadcast, channel: channel, payload: payload);

  /// Creates a presence join message announcing [userInfo] metadata in [channel].
  ///
  /// ```dart
  /// final msg = RealtimeMessage.presenceJoin('room:lobby', {'name': 'Alice', 'status': 'online'});
  /// ```
  factory RealtimeMessage.presenceJoin(String channel, Map<String, dynamic> userInfo) =>
      RealtimeMessage(type: typePresenceJoin, channel: channel, payload: userInfo);

  /// Creates a presence leave message announcing that a user left [channel].
  ///
  /// ```dart
  /// final msg = RealtimeMessage.presenceLeave('room:lobby', {'userId': 'user_123'});
  /// ```
  factory RealtimeMessage.presenceLeave(String channel, Map<String, dynamic> userInfo) =>
      RealtimeMessage(type: typePresenceLeave, channel: channel, payload: userInfo);

  /// Creates a presence state snapshot message containing all active [presences] in [channel].
  factory RealtimeMessage.presenceState(String channel, List<Map<String, dynamic>> presences) =>
      RealtimeMessage(type: typePresenceState, channel: channel, payload: {'presences': presences});

  /// Deserializes a [RealtimeMessage] from a decoded JSON map.
  ///
  /// If `'payload'` is missing or invalid, defaults to an empty map.
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

  /// Attempts to parse [raw] (a JSON string, UTF-8 byte list, or Map) into a [RealtimeMessage].
  ///
  /// Returns `null` if parsing fails, malformed JSON is encountered, or an exception is thrown.
  ///
  /// ```dart
  /// final message = RealtimeMessage.tryParse(incomingData);
  /// ```
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

  /// Serializes this message to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'type': type,
        if (channel != null) 'channel': channel,
        if (payload.isNotEmpty) 'payload': payload,
      };

  /// Encodes this message to a JSON string.
  ///
  /// ```dart
  /// final wireString = message.encode();
  /// ```
  String encode() => jsonEncode(toJson());

  @override
  String toString() => 'RealtimeMessage(type: $type, channel: $channel, payload: $payload)';
}

// ─── Connection state ───────────────────────────────────────────────────────

/// Connection states for a [BloomRealtimeChannelClient].
///
/// Tracks the socket lifecycle from initial connection through unexpected disconnects and reconnects.
enum RealtimeConnectionState {
  /// Socket is disconnected and inactive.
  disconnected,

  /// Socket is currently establishing a connection.
  connecting,

  /// Socket is active, authenticated, and ready to send/receive messages.
  connected,

  /// Connection was lost unexpectedly and the client is attempting automatic reconnection.
  reconnecting,
}

// ─── Client contract ────────────────────────────────────────────────────────

/// Minimal realtime client contract that [BloomRealtimeBinding] wraps.
///
/// Concrete implementations (such as a browser `package:web` WebSocket client or
/// a server mock) manage physical transport, heartbeat ping/pong cycles, reconnect backoffs,
/// and channel multiplexing.
///
/// ### Ownership & Disposal Contract
/// The creator of the [BloomRealtimeChannelClient] owns its lifecycle and must call [dispose]
/// when the client is no longer needed to close underlying sockets and cancel timers.
abstract class BloomRealtimeChannelClient {
  /// The current connection state of the client.
  RealtimeConnectionState get state;

  /// Broadcast stream that emits whenever [state] changes.
  Stream<RealtimeConnectionState> get onStateChanged;

  /// Subscribes to [channelName] and returns a broadcast stream of received event payloads.
  Stream<Map<String, dynamic>> subscribe(String channelName);

  /// Joins presence in [channelName] publishing [userInfo] metadata.
  ///
  /// Returns a stream of active users currently present in the channel.
  Stream<List<Map<String, dynamic>>> joinPresence(
    String channelName,
    Map<String, dynamic> userInfo,
  );

  /// Unsubscribes from [channelName], ceasing message delivery for this channel.
  void unsubscribe(String channelName);

  /// Closes all active socket connections, cancels timers, and releases resources.
  void dispose();
}

// ─── BloomRealtimeBinding ───────────────────────────────────────────────────

/// Reactive signal-backed adapter wrapping a [BloomRealtimeChannelClient].
///
/// Converts realtime streams into observable signals:
/// - [connectionState]: Tracks socket connection status.
/// - [channel]: Caches and updates a signal for the latest message on a channel.
/// - [presence]: Caches and updates a signal for the list of online presences in a channel.
///
/// ### Ownership & Cleanup
/// [BloomRealtimeBinding] listens to streams provided by [client]. When the binding is
/// no longer needed (for example, when a controller or view unmounts), call [dispose] to
/// cancel internal stream subscriptions. Note that disposing the binding does NOT dispose
/// the underlying [client], allowing the client socket connection to be shared across
/// multiple bindings or views.
///
/// ### Backend Behavior
/// - **Browser (`mount`)**: Subscribed `Live` descriptors update reactively as incoming socket
///   frames arrive.
/// - **SSR (`renderToHtml`)**: Safe to instantiate with a mock or disconnected client. Initial
///   signals yield `null` messages and empty presence lists.
///
/// ### Example
/// ```dart
/// final binding = BloomRealtimeBinding(client: realtimeClient);
///
/// // Observe messages on a chat channel
/// final chatSignal = binding.channel('chat:lobby');
///
/// // Observe active users
/// final usersSignal = binding.presence('chat:lobby', userInfo: {'name': 'Bob'});
///
/// BloomNode buildChatRoom() {
///   return Div(
///     children: [
///       Live(() => P(text: 'Online: ${usersSignal.value.length} users')),
///       Live(() => P(text: 'Latest: ${chatSignal.value?['text'] ?? 'No messages'}')),
///     ],
///   );
/// }
/// ```
class BloomRealtimeBinding {
  /// The underlying channel client providing transport streams.
  final BloomRealtimeChannelClient client;

  late final Signal<RealtimeConnectionState> _connectionState;
  final Map<String, Signal<Map<String, dynamic>?>> _channelSignals = {};
  final Map<String, Signal<List<Map<String, dynamic>>>> _presenceSignals = {};
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Creates a [BloomRealtimeBinding] wrapping [client] and begins observing connection state changes.
  BloomRealtimeBinding({required this.client}) {
    _connectionState = signal(client.state);
    _subs.add(client.onStateChanged.listen((s) {
      _connectionState.value = s;
    }));
  }

  /// Reactive signal reflecting the current [RealtimeConnectionState].
  ///
  /// Reading `.value` in a reactive context automatically triggers re-evaluation
  /// when the connection status changes.
  ///
  /// ```dart
  /// Live(() => P(text: 'Status: ${binding.connectionState.value.name}'))
  /// ```
  ReadonlySignal<RealtimeConnectionState> get connectionState =>
      _connectionState.readonly();

  /// Returns a [ReadonlySignal] reflecting the latest message payload on [channelName].
  ///
  /// Starts with a value of `null`. Each incoming broadcast event on [channelName]
  /// updates the signal. Repeated calls with the same [channelName] return the existing cached signal.
  ///
  /// ```dart
  /// final notifications = binding.channel('notifications');
  /// ```
  ReadonlySignal<Map<String, dynamic>?> channel(String channelName) {
    if (_channelSignals.containsKey(channelName)) {
      return _channelSignals[channelName]!.readonly();
    }
    final sig = signal<Map<String, dynamic>?>(null);
    _channelSignals[channelName] = sig;
    _subs.add(client.subscribe(channelName).listen((msg) => sig.value = msg));
    return sig.readonly();
  }

  /// Returns a [ReadonlySignal] tracking the active presence list on [channelName].
  ///
  /// Starts as an empty list and updates whenever users join, leave, or broadcast presence updates.
  /// [userInfo] is the metadata published on behalf of this client upon joining. Repeated calls
  /// with the same [channelName] return the cached signal.
  ///
  /// ```dart
  /// final activeUsers = binding.presence('room:123', userInfo: {'name': 'Alice'});
  /// ```
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

  /// Cancels all active channel and presence stream subscriptions registered by this binding.
  ///
  /// Idempotent. Does NOT dispose the underlying [client].
  ///
  /// ```dart
  /// await binding.dispose();
  /// ```
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
///
/// Convenience factory function.
///
/// ```dart
/// final binding = realtimeBinding(client);
/// ```
BloomRealtimeBinding realtimeBinding(BloomRealtimeChannelClient client) =>
    BloomRealtimeBinding(client: client);

