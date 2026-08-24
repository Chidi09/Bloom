// lib/src/protocol.dart
import 'dart:convert';

/// Wire message envelope shared between Bloom Realtime client and server.
///
/// Encapsulates message framing across WebSockets or server-sent events. Pure Dart,
/// requiring only `dart:convert`, ensuring compatibility across Dart VM, SSR, and client runtimes.
///
/// ### Message Types
/// - Channel subscription: [typeSubscribe], [typeUnsubscribe]
/// - Broadcast events: [typeBroadcast]
/// - Presence tracking: [typePresenceJoin], [typePresenceLeave], [typePresenceState]
/// - System heartbeats and diagnostics: [typePing], [typePong], [typeError]
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

  /// Channel identifier (e.g. `'lists:42'`, `'presence:room-1'`).
  ///
  /// Optional for system-level messages like ping/pong.
  final String? channel;

  /// Payload map associated with the event.
  final Map<String, dynamic> payload;

  /// Creates a [RealtimeMessage] envelope.
  ///
  /// - [type]: The message type identifier.
  /// - [channel]: Optional target channel name.
  /// - [payload]: Optional payload map data (defaults to empty map).
  ///
  /// Example:
  /// ```dart
  /// const msg = RealtimeMessage(
  ///   type: RealtimeMessage.typeBroadcast,
  ///   channel: 'notifications',
  ///   payload: {'unread': 3},
  /// );
  /// ```
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
  /// Example:
  /// ```dart
  /// final msg = RealtimeMessage.subscribe('room:lobby');
  /// ```
  factory RealtimeMessage.subscribe(String channel) {
    return RealtimeMessage(
      type: typeSubscribe,
      channel: channel,
    );
  }

  /// Creates an unsubscription message targeting [channel].
  ///
  /// Example:
  /// ```dart
  /// final msg = RealtimeMessage.unsubscribe('room:lobby');
  /// ```
  factory RealtimeMessage.unsubscribe(String channel) {
    return RealtimeMessage(
      type: typeUnsubscribe,
      channel: channel,
    );
  }

  /// Creates a broadcast event message on [channel] with the given [payload].
  ///
  /// Example:
  /// ```dart
  /// final msg = RealtimeMessage.broadcast('room:lobby', {
  ///   'action': 'typing',
  ///   'user': 'Alice',
  /// });
  /// ```
  factory RealtimeMessage.broadcast(String channel, Map<String, dynamic> payload) {
    return RealtimeMessage(
      type: typeBroadcast,
      channel: channel,
      payload: payload,
    );
  }

  /// Creates a presence join message announcing [userInfo] metadata in [channel].
  ///
  /// Example:
  /// ```dart
  /// final msg = RealtimeMessage.presenceJoin('room:lobby', {
  ///   'userId': 'user_123',
  ///   'name': 'Alice',
  /// });
  /// ```
  factory RealtimeMessage.presenceJoin(String channel, Map<String, dynamic> userInfo) {
    return RealtimeMessage(
      type: typePresenceJoin,
      channel: channel,
      payload: userInfo,
    );
  }

  /// Creates a presence leave message announcing that a user left [channel].
  ///
  /// Example:
  /// ```dart
  /// final msg = RealtimeMessage.presenceLeave('room:lobby', {
  ///   'userId': 'user_123',
  /// });
  /// ```
  factory RealtimeMessage.presenceLeave(String channel, Map<String, dynamic> userInfo) {
    return RealtimeMessage(
      type: typePresenceLeave,
      channel: channel,
      payload: userInfo,
    );
  }

  /// Creates a presence state snapshot message containing all active [presences] in [channel].
  ///
  /// Example:
  /// ```dart
  /// final msg = RealtimeMessage.presenceState('room:lobby', [
  ///   {'userId': 'user_1', 'name': 'Alice'},
  ///   {'userId': 'user_2', 'name': 'Bob'},
  /// ]);
  /// ```
  factory RealtimeMessage.presenceState(String channel, List<Map<String, dynamic>> presences) {
    return RealtimeMessage(
      type: typePresenceState,
      channel: channel,
      payload: {'presences': presences},
    );
  }

  /// Creates an error message envelope.
  ///
  /// - [message]: Descriptive error message.
  /// - [channel]: Optional associated channel name.
  /// - [code]: Optional machine-readable error code.
  ///
  /// Example:
  /// ```dart
  /// final err = RealtimeMessage.error(
  ///   'Unauthorized channel access',
  ///   channel: 'admin:secret',
  ///   code: 'UNAUTHORIZED',
  /// );
  /// ```
  factory RealtimeMessage.error(String message, {String? channel, String? code}) {
    return RealtimeMessage(
      type: typeError,
      channel: channel,
      payload: {
        'message': message,
        if (code != null) 'code': code,
      },
    );
  }

  /// Creates a ping keep-alive heartbeat message.
  ///
  /// Example:
  /// ```dart
  /// final ping = RealtimeMessage.ping();
  /// ```
  factory RealtimeMessage.ping() => const RealtimeMessage(type: typePing);

  /// Creates a pong keep-alive heartbeat response message.
  ///
  /// Example:
  /// ```dart
  /// final pong = RealtimeMessage.pong();
  /// ```
  factory RealtimeMessage.pong() => const RealtimeMessage(type: typePong);

  /// Deserializes a [RealtimeMessage] from a decoded JSON map.
  ///
  /// If `'payload'` is missing or not a Map, defaults to an empty map.
  ///
  /// Example:
  /// ```dart
  /// final msg = RealtimeMessage.fromJson({
  ///   'type': 'broadcast',
  ///   'channel': 'chat',
  ///   'payload': {'text': 'hi'},
  /// });
  /// ```
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

    return RealtimeMessage(
      type: type,
      channel: channel,
      payload: payload,
    );
  }

  /// Attempts to parse [raw] (a JSON string, UTF-8 byte list, or Map) into a [RealtimeMessage].
  ///
  /// Returns `null` if parsing fails, malformed JSON is encountered, or an exception is thrown.
  ///
  /// Example:
  /// ```dart
  /// final msg = RealtimeMessage.tryParse('{"type":"ping"}');
  /// ```
  static RealtimeMessage? tryParse(dynamic raw) {
    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return RealtimeMessage.fromJson(decoded);
        } else if (decoded is Map) {
          return RealtimeMessage.fromJson(Map<String, dynamic>.from(decoded));
        }
      } else if (raw is List<int>) {
        final decoded = jsonDecode(utf8.decode(raw));
        if (decoded is Map<String, dynamic>) {
          return RealtimeMessage.fromJson(decoded);
        } else if (decoded is Map) {
          return RealtimeMessage.fromJson(Map<String, dynamic>.from(decoded));
        }
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
  ///
  /// Omits `channel` and `payload` if null or empty respectively.
  ///
  /// Example:
  /// ```dart
  /// final jsonMap = msg.toJson();
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (channel != null) 'channel': channel,
      if (payload.isNotEmpty) 'payload': payload,
    };
  }

  /// Encodes this message to a JSON string.
  ///
  /// Example:
  /// ```dart
  /// final jsonString = msg.encode();
  /// ```
  String encode() => jsonEncode(toJson());

  /// Encodes this message to a UTF-8 byte buffer for binary frame transmission.
  ///
  /// Example:
  /// ```dart
  /// final bytes = msg.encodeBytes();
  /// ```
  List<int> encodeBytes() => utf8.encode(encode());

  @override
  String toString() => 'RealtimeMessage(type: $type, channel: $channel, payload: $payload)';
}
