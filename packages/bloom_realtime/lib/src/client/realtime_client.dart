// lib/src/client/realtime_client.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../protocol.dart';

/// Connection states for [BloomRealtimeClient].
enum RealtimeConnectionState {
  /// Disconnected from the WebSocket server.
  disconnected,

  /// In the process of establishing an initial connection.
  connecting,

  /// Connected and active.
  connected,

  /// Attempting to reconnect after a lost connection.
  reconnecting,
}

/// Client-side Realtime manager that connects to a Bloom WebSocket endpoint.
///
/// Features:
/// - Pub/Sub channel subscriptions returning a `Stream<Map<String, dynamic>>`
/// - Presence tracking with state snapshots, joins, and leaves
/// - Automatic exponential backoff reconnection with jitter and max cap
/// - Automatic re-subscription to channels after reconnection
class BloomRealtimeClient {
  /// Target WebSocket server endpoint URI.
  final Uri uri;

  /// Initial reconnection delay before first retry attempt.
  final Duration initialReconnectDelay;

  /// Maximum ceiling on reconnection delays.
  final Duration maxReconnectDelay;

  /// Exponential backoff multiplier applied on each failed reconnection.
  final double backoffMultiplier;

  /// Whether to automatically reconnect when the connection drops.
  final bool autoReconnect;

  /// Interval at which ping keep-alive messages are sent.
  final Duration pingInterval;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  final Random _random = Random();

  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  final StreamController<RealtimeConnectionState> _stateController =
      StreamController<RealtimeConnectionState>.broadcast();

  /// channel -> StreamController of broadcast payloads
  final Map<String, StreamController<Map<String, dynamic>>> _channelControllers = {};

  /// Set of channels the client wants to be subscribed to
  final Set<String> _desiredSubscriptions = {};

  /// Presence channels where the client has joined: channel -> userInfo
  final Map<String, Map<String, dynamic>> _desiredPresenceJoins = {};

  /// Presence state listeners: channel -> StreamController of presence user lists
  final Map<String, StreamController<List<Map<String, dynamic>>>> _presenceControllers = {};

  /// Current presence store: channel -> List of user maps
  final Map<String, List<Map<String, dynamic>>> _presenceStore = {};

  /// Creates a [BloomRealtimeClient] targeting [uri].
  ///
  /// - [uri]: WebSocket server URI (e.g. `ws://localhost:8080/ws/realtime`).
  /// - [initialReconnectDelay]: Delay before first retry (defaults to 500ms).
  /// - [maxReconnectDelay]: Maximum retry delay ceiling (defaults to 30s).
  /// - [backoffMultiplier]: Backoff multiplier factor (defaults to 1.5).
  /// - [autoReconnect]: Whether to automatically reconnect on disconnect (defaults to `true`).
  /// - [pingInterval]: Keep-alive ping interval (defaults to 30s).
  BloomRealtimeClient({
    required this.uri,
    this.initialReconnectDelay = const Duration(milliseconds: 500),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 1.5,
    this.autoReconnect = true,
    this.pingInterval = const Duration(seconds: 30),
  });

  /// Current connection state.
  RealtimeConnectionState get state => _state;

  /// Stream of connection state changes.
  Stream<RealtimeConnectionState> get onStateChanged => _stateController.stream;

  /// Whether currently connected to the server.
  bool get isConnected => _state == RealtimeConnectionState.connected;

  /// Connects to the WebSocket server.
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_state == RealtimeConnectionState.connected ||
        _state == RealtimeConnectionState.connecting) {
      return;
    }

    _updateState(
      _reconnectAttempts > 0
          ? RealtimeConnectionState.reconnecting
          : RealtimeConnectionState.connecting,
    );

    try {
      final ws = await WebSocket.connect(uri.toString());
      if (_isDisposed) {
        await ws.close();
        return;
      }

      _socket = ws;
      _reconnectAttempts = 0;
      _updateState(RealtimeConnectionState.connected);

      _socketSub = ws.listen(
        _onDataReceived,
        onDone: _onDisconnected,
        onError: (err) => _onDisconnected(),
        cancelOnError: true,
      );

      _startPingTimer();

      // Re-send subscriptions and presence joins after connecting/reconnecting
      _resubscribeAll();
    } catch (e) {
      _onDisconnected();
    }
  }

  /// Subscribes to a channel and returns a broadcast [Stream] of message payloads.
  Stream<Map<String, dynamic>> subscribe(String channelName) {
    _desiredSubscriptions.add(channelName);

    final controller = _channelControllers.putIfAbsent(
      channelName,
      () => StreamController<Map<String, dynamic>>.broadcast(
        onCancel: () {
          // If no listeners remain on this controller, we can leave desiredSubscriptions intact
          // or user can explicitly call unsubscribe.
        },
      ),
    );

    if (isConnected) {
      _send(RealtimeMessage.subscribe(channelName));
    }

    return controller.stream;
  }

  /// Unsubscribes from a channel.
  void unsubscribe(String channelName) {
    _desiredSubscriptions.remove(channelName);
    _desiredPresenceJoins.remove(channelName);
    _presenceStore.remove(channelName);

    if (isConnected) {
      _send(RealtimeMessage.unsubscribe(channelName));
    }

    _channelControllers[channelName]?.close();
    _channelControllers.remove(channelName);

    _presenceControllers[channelName]?.close();
    _presenceControllers.remove(channelName);
  }

  /// Broadcasts a payload to a channel from the client.
  void broadcast(String channelName, Map<String, dynamic> payload) {
    _send(RealtimeMessage.broadcast(channelName, payload));
  }

  /// Joins presence in [channelName] with [userInfo] metadata.
  ///
  /// Returns a [Stream] of the current active presence list (list of users in the channel).
  Stream<List<Map<String, dynamic>>> joinPresence(
    String channelName,
    Map<String, dynamic> userInfo,
  ) {
    _desiredPresenceJoins[channelName] = userInfo;
    _desiredSubscriptions.add(channelName);

    final controller = _presenceControllers.putIfAbsent(
      channelName,
      () => StreamController<List<Map<String, dynamic>>>.broadcast(),
    );

    if (isConnected) {
      _send(RealtimeMessage.presenceJoin(channelName, userInfo));
    }

    return controller.stream;
  }

  /// Leaves presence in [channelName].
  void leavePresence(String channelName) {
    final userInfo = _desiredPresenceJoins.remove(channelName);
    _presenceStore.remove(channelName);

    if (isConnected && userInfo != null) {
      _send(RealtimeMessage.presenceLeave(channelName, userInfo));
    }
  }

  /// Sends a raw [RealtimeMessage] over the WebSocket if connected.
  bool _send(RealtimeMessage message) {
    if (_socket != null && _state == RealtimeConnectionState.connected) {
      try {
        _socket!.add(message.encode());
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _onDataReceived(dynamic rawData) {
    final message = RealtimeMessage.tryParse(rawData);
    if (message == null) return;

    final channel = message.channel;

    switch (message.type) {
      case RealtimeMessage.typeBroadcast:
        if (channel != null) {
          // Check if it's a presence broadcast event
          if (message.payload.containsKey('event') &&
              (message.payload['event'] == 'presence_join' ||
                  message.payload['event'] == 'presence_leave')) {
            _handlePresenceEvent(channel, message.payload);
          }

          _channelControllers[channel]?.add(message.payload);
        }
        break;

      case RealtimeMessage.typePresenceState:
        if (channel != null) {
          final rawPresences = message.payload['presences'];
          if (rawPresences is List) {
            final list = rawPresences
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
            _presenceStore[channel] = list;
            _presenceControllers[channel]?.add(list);
          }
        }
        break;

      case RealtimeMessage.typePong:
        // Keep-alive response
        break;
    }
  }

  void _handlePresenceEvent(String channel, Map<String, dynamic> payload) {
    final event = payload['event'] as String?;
    final presenceData = payload['presence'];
    if (presenceData is! Map) return;
    final presenceMap = Map<String, dynamic>.from(presenceData);
    final connId = presenceMap['connectionId'] as String?;

    final current = _presenceStore.putIfAbsent(channel, () => []);

    if (event == 'presence_join') {
      current.removeWhere((p) => p['connectionId'] == connId);
      current.add(presenceMap);
      _presenceControllers[channel]?.add(List.from(current));
    } else if (event == 'presence_leave') {
      current.removeWhere((p) => p['connectionId'] == connId);
      _presenceControllers[channel]?.add(List.from(current));
    }
  }

  void _onDisconnected() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket = null;
    _stopPingTimer();

    if (_isDisposed) {
      _updateState(RealtimeConnectionState.disconnected);
      return;
    }

    _updateState(RealtimeConnectionState.disconnected);

    if (autoReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Exponential backoff: delay = min(initial * (multiplier ^ attempt), max) + jitter
    final expDelayMs = (initialReconnectDelay.inMilliseconds *
            pow(backoffMultiplier, _reconnectAttempts))
        .round();
    final cappedDelayMs = min(expDelayMs, maxReconnectDelay.inMilliseconds);
    
    // Add jitter (up to 20% randomness) to prevent thundering herds
    final jitter = (cappedDelayMs * 0.2 * _random.nextDouble()).round();
    final totalDelay = Duration(milliseconds: cappedDelayMs + jitter);

    _reconnectAttempts++;
    _updateState(RealtimeConnectionState.reconnecting);

    _reconnectTimer = Timer(totalDelay, () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  void _resubscribeAll() {
    for (final channel in _desiredSubscriptions) {
      _send(RealtimeMessage.subscribe(channel));
    }
    for (final entry in _desiredPresenceJoins.entries) {
      _send(RealtimeMessage.presenceJoin(entry.key, entry.value));
    }
  }

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (isConnected) {
        _send(RealtimeMessage.ping());
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _updateState(RealtimeConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  /// Disconnects and releases all resources.
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopPingTimer();

    try {
      _socketSub?.cancel();
      _socket?.close();
    } catch (_) {}

    for (final ctrl in _channelControllers.values) {
      ctrl.close();
    }
    _channelControllers.clear();

    for (final ctrl in _presenceControllers.values) {
      ctrl.close();
    }
    _presenceControllers.clear();

    _desiredSubscriptions.clear();
    _desiredPresenceJoins.clear();
    _presenceStore.clear();

    _updateState(RealtimeConnectionState.disconnected);
    _stateController.close();
  }
}
