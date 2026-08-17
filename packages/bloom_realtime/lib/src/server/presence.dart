// lib/src/server/presence.dart
import 'dart:io';
import '../protocol.dart';
import 'channel_hub.dart';

/// Representation of a user's presence in a channel.
class PresenceUser {
  /// Unique connection ID associated with this user session.
  final String connectionId;

  /// User profile metadata (e.g. `userId`, `username`, `avatar`).
  final Map<String, dynamic> info;

  /// Timestamp when the user joined the presence channel.
  final DateTime joinedAt;

  /// Creates a [PresenceUser] instance.
  ///
  /// - [connectionId]: Connection ID string.
  /// - [info]: User metadata map.
  /// - [joinedAt]: Optional join timestamp override (defaults to current time).
  PresenceUser({
    required this.connectionId,
    required this.info,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  /// Serializes presence user data to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'info': info,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  /// Deserializes a [PresenceUser] from a JSON map.
  factory PresenceUser.fromJson(Map<String, dynamic> json) {
    return PresenceUser(
      connectionId: json['connectionId'] as String? ?? '',
      info: json['info'] is Map<String, dynamic>
          ? json['info'] as Map<String, dynamic>
          : json['info'] is Map
              ? Map<String, dynamic>.from(json['info'] as Map)
              : const {},
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Simple presence tracker layered on top of [BloomChannelHub].
///
/// Tracks which connection IDs and associated user metadata are present in channels,
/// and automatically broadcasts join, leave, and state events.
class BloomPresenceTracker {
  /// Underlying [BloomChannelHub] managing WebSocket subscriptions.
  final BloomChannelHub hub;

  /// channel -> { connectionId: PresenceUser }
  final Map<String, Map<String, PresenceUser>> _presences = {};

  /// Creates a [BloomPresenceTracker] backed by [hub].
  BloomPresenceTracker({required this.hub}) {
    // Automatically listen to hub connection disconnects to trigger presence leave
    final originalOnClosed = hub.onConnectionClosed;
    hub.onConnectionClosed = (connectionId) {
      _handleConnectionClosed(connectionId);
      originalOnClosed?.call(connectionId);
    };

    final originalOnUnsub = hub.onUnsubscribed;
    hub.onUnsubscribed = (connectionId, channel) {
      leave(channel, connectionId);
      originalOnUnsub?.call(connectionId, channel);
    };
  }

  /// Track a user joining a [channel] with metadata.
  ///
  /// Subscribes the connection to the hub channel, records user presence,
  /// sends the current full presence state to the joining connection, and broadcasts
  /// a `presence_join` event to everyone in the channel.
  ///
  /// - [channel]: Target channel name.
  /// - [socketOrId]: [WebSocket] instance or connection ID string.
  /// - [userInfo]: User metadata payload (e.g. name, user ID).
  bool join(
    String channel,
    dynamic socketOrId,
    Map<String, dynamic> userInfo,
  ) {
    final connectionId = _resolveConnectionId(socketOrId);
    if (connectionId == null) return false;

    // Ensure connection is subscribed to channel
    hub.subscribe(channel, connectionId);

    final channelPresences = _presences.putIfAbsent(channel, () => {});
    final presence = PresenceUser(
      connectionId: connectionId,
      info: userInfo,
    );
    channelPresences[connectionId] = presence;

    // Send the current presence state snapshot to the joining user
    final stateList = channelPresences.values.map((p) => p.toJson()).toList();
    hub.sendTo(
      connectionId,
      RealtimeMessage.presenceState(channel, stateList),
    );

    // Broadcast presence join to all channel subscribers
    hub.broadcast(
      channel,
      {
        'event': 'presence_join',
        'presence': presence.toJson(),
      },
    );

    return true;
  }

  /// Remove a user from a [channel]'s presence list and broadcast `presence_leave`.
  ///
  /// - [channel]: Target channel name.
  /// - [socketOrId]: [WebSocket] instance or connection ID string.
  bool leave(String channel, dynamic socketOrId) {
    final connectionId = _resolveConnectionId(socketOrId);
    if (connectionId == null) return false;

    final channelPresences = _presences[channel];
    if (channelPresences == null) return false;

    final presence = channelPresences.remove(connectionId);
    if (presence == null) return false;

    if (channelPresences.isEmpty) {
      _presences.remove(channel);
    }

    // Broadcast presence leave to remaining channel subscribers
    hub.broadcast(
      channel,
      {
        'event': 'presence_leave',
        'presence': presence.toJson(),
      },
    );

    return true;
  }

  /// Returns all users currently present in [channel].
  ///
  /// - [channel]: Target channel name.
  List<PresenceUser> getPresences(String channel) {
    final map = _presences[channel];
    if (map == null) return const [];
    return List<PresenceUser>.from(map.values);
  }

  /// Check if a connection is present in [channel].
  ///
  /// - [channel]: Target channel name.
  /// - [socketOrId]: [WebSocket] instance or connection ID string.
  bool isPresent(String channel, dynamic socketOrId) {
    final connectionId = _resolveConnectionId(socketOrId);
    if (connectionId == null) return false;
    return _presences[channel]?.containsKey(connectionId) ?? false;
  }

  /// Automatically attaches protocol handling to a [socket] for presence events.
  ///
  /// - [socket]: Upgraded `dart:io` [WebSocket] connection.
  void attachProtocolHandler(WebSocket socket) {
    final id = hub.registerConnection(socket, autoHandleProtocol: false);

    socket.listen(
      (data) {
        final message = RealtimeMessage.tryParse(data);
        if (message == null) return;

        switch (message.type) {
          case RealtimeMessage.typeSubscribe:
            if (message.channel != null) {
              hub.subscribe(message.channel!, id);
            }
            break;

          case RealtimeMessage.typeUnsubscribe:
            if (message.channel != null) {
              leave(message.channel!, id);
              hub.unsubscribe(message.channel!, id);
            }
            break;

          case RealtimeMessage.typePresenceJoin:
            if (message.channel != null) {
              join(message.channel!, id, message.payload);
            }
            break;

          case RealtimeMessage.typePresenceLeave:
            if (message.channel != null) {
              leave(message.channel!, id);
            }
            break;

          case RealtimeMessage.typeBroadcast:
            if (message.channel != null) {
              hub.broadcast(message.channel!, message.payload);
            }
            break;

          case RealtimeMessage.typePing:
            hub.sendTo(id, RealtimeMessage.pong());
            break;
        }
      },
      onDone: () {
        hub.removeConnection(id);
      },
      onError: (err) {
        hub.removeConnection(id);
      },
      cancelOnError: true,
    );
  }

  void _handleConnectionClosed(String connectionId) {
    // Find all channels where this connection was present and remove them
    final channels = List<String>.from(_presences.keys);
    for (final channel in channels) {
      final channelPresences = _presences[channel];
      if (channelPresences != null && channelPresences.containsKey(connectionId)) {
        final removed = channelPresences.remove(connectionId);
        if (channelPresences.isEmpty) {
          _presences.remove(channel);
        }
        if (removed != null) {
          hub.broadcast(
            channel,
            {
              'event': 'presence_leave',
              'presence': removed.toJson(),
            },
          );
        }
      }
    }
  }

  String? _resolveConnectionId(dynamic socketOrId) {
    if (socketOrId is String) return socketOrId;
    if (socketOrId is WebSocket) return hub.getConnectionId(socketOrId);
    return null;
  }
}
