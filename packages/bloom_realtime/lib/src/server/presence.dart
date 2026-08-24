// lib/src/server/presence.dart
import 'dart:io';
import '../protocol.dart';
import 'channel_hub.dart';

/// Representation of a user's presence state in a channel.
///
/// Encapsulates the user's connection ID, custom profile metadata map,
/// and join timestamp.
///
/// ### Example
/// ```dart
/// final user = PresenceUser(
///   connectionId: 'conn_123',
///   info: {'userId': 'u_42', 'name': 'Alice', 'avatar': 'https://...'},
/// );
/// print('User ${user.info['name']} joined at ${user.joinedAt}');
/// ```
class PresenceUser {
  /// Unique connection ID associated with this user session.
  final String connectionId;

  /// User profile metadata (e.g. `userId`, `username`, `avatar`).
  final Map<String, dynamic> info;

  /// Timestamp when the user joined the presence channel.
  final DateTime joinedAt;

  /// Creates a [PresenceUser] instance.
  ///
  /// - [connectionId]: Unique connection ID string.
  /// - [info]: User metadata map.
  /// - [joinedAt]: Optional join timestamp override (defaults to [DateTime.now]).
  ///
  /// Example:
  /// ```dart
  /// final user = PresenceUser(
  ///   connectionId: 'conn_abc',
  ///   info: {'name': 'Bob'},
  /// );
  /// ```
  PresenceUser({
    required this.connectionId,
    required this.info,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  /// Serializes presence user data to a JSON-compatible map.
  ///
  /// Example:
  /// ```dart
  /// final map = user.toJson();
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'info': info,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  /// Deserializes a [PresenceUser] from a JSON map.
  ///
  /// Example:
  /// ```dart
  /// final user = PresenceUser.fromJson({
  ///   'connectionId': 'conn_abc',
  ///   'info': {'name': 'Alice'},
  ///   'joinedAt': '2026-08-24T00:00:00.000Z',
  /// });
  /// ```
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
/// and automatically broadcasts join, leave, and state snapshot events.
///
/// ### Lifecycle Automation
/// Automatically intercepts [BloomChannelHub.onConnectionClosed] and
/// [BloomChannelHub.onUnsubscribed] to broadcast `presence_leave` events and prune
/// presence stores when connections disconnect or unsubscribe.
///
/// ### Example
/// ```dart
/// final hub = BloomChannelHub();
/// final tracker = BloomPresenceTracker(hub: hub);
///
/// // Join presence
/// tracker.join('room:1', connId, {'name': 'Alice'});
///
/// // Query active presences
/// final active = tracker.getPresences('room:1');
/// print('${active.length} users online');
///
/// // Leave presence
/// tracker.leave('room:1', connId);
/// ```
class BloomPresenceTracker {
  /// Underlying [BloomChannelHub] managing WebSocket subscriptions.
  final BloomChannelHub hub;

  /// channel -> { connectionId: PresenceUser }
  final Map<String, Map<String, PresenceUser>> _presences = {};

  /// Creates a [BloomPresenceTracker] backed by [hub] and hooks disconnect lifecycles.
  ///
  /// Example:
  /// ```dart
  /// final tracker = BloomPresenceTracker(hub: hub);
  /// ```
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

  /// Tracks a user joining [channel] with metadata.
  ///
  /// Subscribes the connection to the hub channel, records user presence,
  /// sends the current full presence state snapshot to the joining connection,
  /// and broadcasts a `presence_join` event to everyone in the channel.
  ///
  /// - [channel]: Target channel name.
  /// - [socketOrId]: [WebSocket] instance or connection ID string.
  /// - [userInfo]: User metadata payload map (e.g. name, avatar, user ID).
  ///
  /// Returns `true` if successfully joined, or `false` if the connection could not be resolved.
  ///
  /// Example:
  /// ```dart
  /// tracker.join('chat:lobby', connId, {'userId': '123', 'name': 'Bob'});
  /// ```
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

  /// Removes a user from a [channel]'s presence list and broadcasts `presence_leave`.
  ///
  /// - [channel]: Target channel name.
  /// - [socketOrId]: [WebSocket] instance or connection ID string.
  ///
  /// Returns `true` if the user was present and removed, or `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// tracker.leave('chat:lobby', connId);
  /// ```
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
  /// Returns an empty list if the channel has no active presences.
  ///
  /// - [channel]: Target channel name.
  ///
  /// Example:
  /// ```dart
  /// final users = tracker.getPresences('chat:lobby');
  /// for (final u in users) {
  ///   print('${u.connectionId}: ${u.info}');
  /// }
  /// ```
  List<PresenceUser> getPresences(String channel) {
    final map = _presences[channel];
    if (map == null) return const [];
    return List<PresenceUser>.from(map.values);
  }

  /// Checks if a connection is currently present in [channel].
  ///
  /// - [channel]: Target channel name.
  /// - [socketOrId]: [WebSocket] instance or connection ID string.
  ///
  /// Example:
  /// ```dart
  /// if (tracker.isPresent('chat:lobby', connId)) {
  ///   print('User is in lobby');
  /// }
  /// ```
  bool isPresent(String channel, dynamic socketOrId) {
    final connectionId = _resolveConnectionId(socketOrId);
    if (connectionId == null) return false;
    return _presences[channel]?.containsKey(connectionId) ?? false;
  }

  /// Automatically attaches protocol handling to a [socket] for presence and pub/sub events.
  ///
  /// Listens to incoming [RealtimeMessage] packets and invokes the corresponding
  /// subscribe, unsubscribe, presence join/leave, broadcast, and ping/pong handlers.
  ///
  /// - [socket]: Upgraded `dart:io` [WebSocket] connection.
  ///
  /// Example:
  /// ```dart
  /// final socket = await BloomChannelHub.upgrade(request);
  /// tracker.attachProtocolHandler(socket);
  /// ```
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
