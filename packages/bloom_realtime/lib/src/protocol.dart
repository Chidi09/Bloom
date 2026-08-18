// lib/src/protocol.dart
import 'dart:convert';

/// Wire message envelope shared between Bloom Realtime client and server.
class RealtimeMessage {
  /// Message type (e.g. `'subscribe'`, `'unsubscribe'`, `'broadcast'`, `'presence_join'`, `'presence_leave'`, `'presence_state'`, `'error'`, `'ping'`, `'pong'`).
  final String type;

  /// Channel identifier (e.g. `'lists:42'`, `'presence:room-1'`). Optional for system messages like ping/pong.
  final String? channel;

  /// Payload map associated with the event.
  final Map<String, dynamic> payload;

  /// Creates a [RealtimeMessage] envelope.
  ///
  /// - [type]: The message type identifier.
  /// - [channel]: Optional target channel name.
  /// - [payload]: Optional payload map data.
  const RealtimeMessage({
    required this.type,
    this.channel,
    this.payload = const {},
  });

  /// Common message types
  static const String typeSubscribe = 'subscribe';
  static const String typeUnsubscribe = 'unsubscribe';
  static const String typeBroadcast = 'broadcast';
  static const String typePresenceJoin = 'presence_join';
  static const String typePresenceLeave = 'presence_leave';
  static const String typePresenceState = 'presence_state';
  static const String typeError = 'error';
  static const String typePing = 'ping';
  static const String typePong = 'pong';

  /// Factory helper for subscribe message.
  ///
  /// - [channel]: Channel name to subscribe to.
  factory RealtimeMessage.subscribe(String channel) {
    return RealtimeMessage(
      type: typeSubscribe,
      channel: channel,
    );
  }

  /// Factory helper for unsubscribe message.
  ///
  /// - [channel]: Channel name to unsubscribe from.
  factory RealtimeMessage.unsubscribe(String channel) {
    return RealtimeMessage(
      type: typeUnsubscribe,
      channel: channel,
    );
  }

  /// Factory helper for broadcast message.
  ///
  /// - [channel]: Target channel name for the broadcast.
  /// - [payload]: Map payload data to send.
  factory RealtimeMessage.broadcast(String channel, Map<String, dynamic> payload) {
    return RealtimeMessage(
      type: typeBroadcast,
      channel: channel,
      payload: payload,
    );
  }

  /// Factory helper for presence join message.
  ///
  /// - [channel]: Target channel name.
  /// - [userInfo]: User metadata payload (e.g. user ID, name, avatar).
  factory RealtimeMessage.presenceJoin(String channel, Map<String, dynamic> userInfo) {
    return RealtimeMessage(
      type: typePresenceJoin,
      channel: channel,
      payload: userInfo,
    );
  }

  /// Factory helper for presence leave message.
  ///
  /// - [channel]: Target channel name.
  /// - [userInfo]: User metadata payload.
  factory RealtimeMessage.presenceLeave(String channel, Map<String, dynamic> userInfo) {
    return RealtimeMessage(
      type: typePresenceLeave,
      channel: channel,
      payload: userInfo,
    );
  }

  /// Factory helper for presence snapshot/state message.
  ///
  /// - [channel]: Target channel name.
  /// - [presences]: List of presence maps for all users currently in the channel.
  factory RealtimeMessage.presenceState(String channel, List<Map<String, dynamic>> presences) {
    return RealtimeMessage(
      type: typePresenceState,
      channel: channel,
      payload: {'presences': presences},
    );
  }

  /// Factory helper for error message.
  ///
  /// - [message]: Descriptive error message.
  /// - [channel]: Optional associated channel name.
  /// - [code]: Optional machine-readable error code.
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

  /// Factory helper for ping keep-alive message.
  factory RealtimeMessage.ping() => const RealtimeMessage(type: typePing);

  /// Factory helper for pong keep-alive response message.
  factory RealtimeMessage.pong() => const RealtimeMessage(type: typePong);

  /// Deserializes a [RealtimeMessage] from a JSON map.
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

  /// Parses a [RealtimeMessage] from a raw JSON string or binary byte buffer.
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

  /// Serializes this message to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (channel != null) 'channel': channel,
      if (payload.isNotEmpty) 'payload': payload,
    };
  }

  /// Encodes this message to a JSON string.
  String encode() => jsonEncode(toJson());

  /// Encodes this message to a UTF-8 byte buffer for zero-copy binary frame transmission.
  List<int> encodeBytes() => utf8.encode(encode());

  @override
  String toString() => 'RealtimeMessage(type: $type, channel: $channel, payload: $payload)';
}
