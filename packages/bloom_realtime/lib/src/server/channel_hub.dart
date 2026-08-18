// lib/src/server/channel_hub.dart
import 'dart:async';
import 'dart:io';
import '../protocol.dart';

/// Connection context holding a WebSocket and its lifecycle subscriptions.
class _HubConnection {
  final String id;
  final WebSocket socket;
  final Set<String> subscribedChannels = <String>{};
  StreamSubscription<dynamic>? socketSubscription;
  bool isDisposed = false;

  _HubConnection({required this.id, required this.socket});
}

/// In-process registry and pub/sub broadcaster of WebSocket connections grouped by channel name.
///
/// NOTE: This hub is an in-memory, single-process implementation. If your Bloom API server
/// is horizontally scaled across multiple processes or containers, broadcast events are local
/// to the current process unless bridged via an external broker (e.g., Redis pub/sub).
class BloomChannelHub {
  final Map<String, _HubConnection> _connections = {};
  final Map<String, Set<_HubConnection>> _channelSubscribers = {};
  final Map<WebSocket, String> _socketToId = {};
  int _idCounter = 0;

  /// Optional callback invoked when a connection is subscribed to a channel.
  void Function(String connectionId, String channel)? onSubscribed;

  /// Optional callback invoked when a connection is unsubscribed from a channel.
  void Function(String connectionId, String channel)? onUnsubscribed;

  /// Optional callback invoked when a connection is closed and cleaned up.
  void Function(String connectionId)? onConnectionClosed;

  /// Optional callback invoked when a broadcast payload is dispatched to a channel.
  void Function(String channel, Map<String, dynamic> payload)? onBroadcast;

  /// Number of active connections.
  int get activeConnectionCount => _connections.length;

  /// Number of unique channels currently containing subscribers.
  int get activeChannelCount => _channelSubscribers.length;

  /// Get subscriber count for a specific [channel].
  int channelSubscriberCount(String channel) =>
      _channelSubscribers[channel]?.length ?? 0;

  /// High-performance WebSocket upgrader with optimal production defaults:
  /// - Sets `tcpNoDelay: true` to eliminate Nagle packet buffering latency.
  /// - Disables `permessage-deflate` by default (`CompressionOptions.compressionOff`) to save CPU on small JSON events.
  ///
  /// - [request]: The incoming [HttpRequest].
  /// - [compression]: Compression strategy (defaults to [CompressionOptions.compressionOff]).
  /// - [tcpNoDelay]: When `true`, detaches the underlying TCP socket to guarantee `TCP_NODELAY` is enabled.
  /// - [protocol]: Optional subprotocol string.
  static Future<WebSocket> upgrade(
    HttpRequest request, {
    CompressionOptions compression = CompressionOptions.compressionOff,
    bool tcpNoDelay = true,
    String? protocol,
  }) async {
    if (tcpNoDelay) {
      final socket = await request.response.detachSocket();
      socket.setOption(SocketOption.tcpNoDelay, true);
      return WebSocket.fromUpgradedSocket(
        socket,
        protocol: protocol,
        serverSide: true,
        compression: compression,
      );
    } else {
      return WebSocketTransformer.upgrade(
        request,
        protocolSelector: protocol != null ? (_) => protocol : null,
        compression: compression,
      );
    }
  }

  /// Registers and attaches a newly upgraded [WebSocket] connection to the hub.
  ///
  /// Automatically listens to socket messages (handling standard [RealtimeMessage] protocol),
  /// and automatically cleans up channels and resources on socket close or error.
  ///
  /// - [socket]: Upgraded `dart:io` [WebSocket] connection.
  /// - [connectionId]: Optional custom connection ID string.
  /// - [autoHandleProtocol]: If `true`, automatically parses incoming wire messages.
  String registerConnection(
    WebSocket socket, {
    String? connectionId,
    bool autoHandleProtocol = true,
  }) {
    // Check if socket is already registered
    final existingId = _socketToId[socket];
    if (existingId != null && _connections.containsKey(existingId)) {
      return existingId;
    }

    final id = connectionId ?? 'conn_${++_idCounter}_${DateTime.now().microsecondsSinceEpoch}';
    final conn = _HubConnection(id: id, socket: socket);
    _connections[id] = conn;
    _socketToId[socket] = id;

    // Listen to socket stream with guaranteed cleanup on done/error
    conn.socketSubscription = socket.listen(
      (data) {
        if (autoHandleProtocol) {
          _handleIncomingData(id, data);
        }
      },
      onDone: () {
        removeConnection(id);
      },
      onError: (err) {
        removeConnection(id);
      },
      cancelOnError: true,
    );

    // Also guard socket.done future in case it closes without stream event
    socket.done.then((_) {
      removeConnection(id);
    }).catchError((_) {
      removeConnection(id);
    });

    return id;
  }

  /// Subscribes a connection to [channelName].
  ///
  /// - [channelName]: Name of the channel to join.
  /// - [socketOrId]: Target [WebSocket] instance or connection ID string.
  bool subscribe(String channelName, dynamic socketOrId) {
    final conn = _resolveConnection(socketOrId);
    if (conn == null || conn.isDisposed) return false;

    // If socket is already closed, prune it immediately
    if (conn.socket.readyState != WebSocket.open) {
      removeConnection(conn.id);
      return false;
    }

    conn.subscribedChannels.add(channelName);
    _channelSubscribers.putIfAbsent(channelName, () => <_HubConnection>{}).add(conn);
    onSubscribed?.call(conn.id, channelName);
    return true;
  }

  /// Unsubscribes a connection from [channelName].
  ///
  /// - [channelName]: Name of the channel to leave.
  /// - [socketOrId]: Target [WebSocket] instance or connection ID string.
  bool unsubscribe(String channelName, dynamic socketOrId) {
    final conn = _resolveConnection(socketOrId);
    if (conn == null) return false;

    conn.subscribedChannels.remove(channelName);
    final subs = _channelSubscribers[channelName];
    if (subs != null) {
      subs.remove(conn);
      if (subs.isEmpty) {
        _channelSubscribers.remove(channelName);
      }
    }
    onUnsubscribed?.call(conn.id, channelName);
    return true;
  }

  /// Broadcasts [payload] to all active subscribers of [channelName].
  ///
  /// Dead or closing sockets are actively detected, dropped from the subscriber set,
  /// Broadcasts [payload] to all active subscribers of [channelName].
  ///
  /// Dead or closing sockets are actively detected, dropped from the subscriber set,
  /// and cleaned up from the hub without throwing or leaking memory.
  ///
  /// - [channelName]: Target channel name.
  /// - [payload]: Map payload data to broadcast.
  /// - [asBinary]: When `true`, serializes directly to pre-encoded UTF-8 byte array for binary framing.
  int broadcast(String channelName, Map<String, dynamic> payload, {bool asBinary = false}) {
    final subs = _channelSubscribers[channelName];
    if (subs == null || subs.isEmpty) return 0;

    final msg = RealtimeMessage.broadcast(channelName, payload);
    final dynamic wire = asBinary ? msg.encodeBytes() : msg.encode();

    List<_HubConnection>? deadConns;
    int sentCount = 0;

    for (final conn in subs) {
      if (conn.isDisposed || conn.socket.readyState != WebSocket.open) {
        (deadConns ??= []).add(conn);
        continue;
      }

      try {
        conn.socket.add(wire);
        sentCount++;
      } catch (_) {
        (deadConns ??= []).add(conn);
      }
    }

    // Actively remove any dead sockets identified during broadcast
    if (deadConns != null) {
      for (final dead in deadConns) {
        removeConnection(dead.id);
      }
    }

    onBroadcast?.call(channelName, payload);
    return sentCount;
  }

  /// Sends a direct [RealtimeMessage] to a specific connection.
  ///
  /// - [socketOrId]: Target [WebSocket] instance or connection ID string.
  /// - [message]: Message envelope to send.
  /// - [asBinary]: When `true`, sends binary frame.
  bool sendTo(dynamic socketOrId, RealtimeMessage message, {bool asBinary = false}) {
    final conn = _resolveConnection(socketOrId);
    if (conn == null || conn.isDisposed) return false;

    if (conn.socket.readyState != WebSocket.open) {
      removeConnection(conn.id);
      return false;
    }

    try {
      conn.socket.add(asBinary ? message.encodeBytes() : message.encode());
      return true;
    } catch (_) {
      removeConnection(conn.id);
      return false;
    }
  }

  /// Completely removes a connection, cancels its subscriptions, cleans channel indices,
  /// and closes its socket if still open.
  ///
  /// - [socketOrId]: Target [WebSocket] instance or connection ID string to remove.
  void removeConnection(dynamic socketOrId) {
    final conn = _resolveConnection(socketOrId);
    if (conn == null) return;

    if (conn.isDisposed) return;
    conn.isDisposed = true;

    // Remove from main connection map
    _connections.remove(conn.id);
    _socketToId.remove(conn.socket);

    // Cancel socket stream listener
    try {
      conn.socketSubscription?.cancel();
    } catch (_) {}

    // Clean up channel memberships
    for (final channel in List<String>.from(conn.subscribedChannels)) {
      final subs = _channelSubscribers[channel];
      if (subs != null) {
        subs.remove(conn);
        if (subs.isEmpty) {
          _channelSubscribers.remove(channel);
        }
      }
      onUnsubscribed?.call(conn.id, channel);
    }
    conn.subscribedChannels.clear();

    // Close socket if not already closed
    if (conn.socket.readyState == WebSocket.open || conn.socket.readyState == WebSocket.connecting) {
      try {
        conn.socket.close();
      } catch (_) {}
    }

    onConnectionClosed?.call(conn.id);
  }

  /// Returns a list of channel names that [socketOrId] is currently subscribed to.
  ///
  /// - [socketOrId]: Target [WebSocket] instance or connection ID string.
  List<String> getSubscribedChannels(dynamic socketOrId) {
    final conn = _resolveConnection(socketOrId);
    if (conn == null) return const [];
    return List<String>.from(conn.subscribedChannels);
  }

  /// Returns the connection ID for a given [socket], if registered.
  String? getConnectionId(WebSocket socket) => _socketToId[socket];

  /// Disposes the hub, closing all registered WebSocket connections and releasing memory.
  void dispose() {
    final allIds = List<String>.from(_connections.keys);
    for (final id in allIds) {
      removeConnection(id);
    }
    _connections.clear();
    _channelSubscribers.clear();
    _socketToId.clear();
  }

  void _handleIncomingData(String connId, dynamic data) {
    final message = RealtimeMessage.tryParse(data);
    if (message == null) return;

    final conn = _connections[connId];
    if (conn == null) return;

    switch (message.type) {
      case RealtimeMessage.typeSubscribe:
        if (message.channel != null && message.channel!.isNotEmpty) {
          subscribe(message.channel!, connId);
        }
        break;

      case RealtimeMessage.typeUnsubscribe:
        if (message.channel != null && message.channel!.isNotEmpty) {
          unsubscribe(message.channel!, connId);
        }
        break;

      case RealtimeMessage.typeBroadcast:
        if (message.channel != null && message.channel!.isNotEmpty) {
          broadcast(message.channel!, message.payload);
        }
        break;

      case RealtimeMessage.typePing:
        sendTo(connId, RealtimeMessage.pong());
        break;
    }
  }

  _HubConnection? _resolveConnection(dynamic socketOrId) {
    if (socketOrId is String) {
      return _connections[socketOrId];
    } else if (socketOrId is WebSocket) {
      final id = _socketToId[socketOrId];
      if (id != null) return _connections[id];
      // Search fallback
      for (final conn in _connections.values) {
        if (conn.socket == socketOrId) return conn;
      }
    }
    return null;
  }
}
