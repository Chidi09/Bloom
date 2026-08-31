// lib/src/realtime_browser.dart
//
// Browser-only WebSocket realtime client for Bloom JS Native.
// Requires package:web and dart:js_interop (exported via browser.dart).

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'realtime.dart';

/// Default initial reconnection delay before the first retry attempt (500ms).
const Duration defaultRealtimeInitialReconnectDelay =
    Duration(milliseconds: 500);

/// Default maximum delay ceiling for exponential reconnection backoff (30s).
const Duration defaultRealtimeMaxReconnectDelay = Duration(seconds: 30);

/// Default exponential backoff multiplier applied on consecutive reconnection failures.
const double defaultRealtimeBackoffMultiplier = 1.5;

/// Default keep-alive heartbeat ping interval (30s).
const Duration defaultRealtimePingInterval = Duration(seconds: 30);

/// Browser-only [BloomRealtimeChannelClient] backed by native browser WebSockets (`package:web`).
///
/// Implements resilient, multiplexed realtime communication for Bloom JS Native applications:
/// - Channel subscription multiplexing (multiple calls to [subscribe] share one underlying socket subscription).
/// - Automatic presence tracking with snapshots, joins, and leaves.
/// - Heartbeat ping/pong keep-alives (automatically replies to server pings with pong frames).
/// - Bounded exponential backoff reconnection with jitter on unexpected socket disconnects.
/// - Automatic channel and presence re-subscription upon reconnecting.
///
/// ### VM / SSR Safety
/// This class requires browser WebSocket APIs and must only be imported in client-side code
/// via `package:bloom_js_native/browser.dart`. Do not import in server-side rendering (SSR) code.
///
/// ### Example
/// ```dart
/// final client = BrowserRealtimeClient(
///   uri: Uri.parse('wss://api.example.com/ws'),
/// );
///
/// final binding = BloomRealtimeBinding(client: client);
/// await client.connect();
///
/// final chatMessages = binding.channel('chat:general');
/// final activeUsers = binding.presence('chat:general', userInfo: {'name': 'Alice'});
/// ```
class BrowserRealtimeClient implements BloomRealtimeChannelClient {
  /// Target WebSocket server endpoint URI.
  final Uri uri;

  /// Initial reconnection delay before the first retry attempt.
  final Duration initialReconnectDelay;

  /// Maximum ceiling on reconnection delay.
  final Duration maxReconnectDelay;

  /// Exponential backoff multiplier applied on each consecutive failed reconnection attempt.
  final double backoffMultiplier;

  /// Whether to automatically reconnect when the connection drops unexpectedly.
  final bool autoReconnect;

  /// Interval at which heartbeat ping keep-alive messages are sent.
  /// Set to [Duration.zero] to disable automatic client pings.
  final Duration pingInterval;

  /// Optional WebSocket sub-protocols to negotiate with the server.
  final List<String>? protocols;

  web.WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  final math.Random _random = math.Random();

  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  final StreamController<RealtimeConnectionState> _stateController =
      StreamController<RealtimeConnectionState>.broadcast();

  /// channel -> StreamController of broadcast payloads
  final Map<String, StreamController<Map<String, dynamic>>>
      _channelControllers = {};
  final Map<String, Stream<Map<String, dynamic>>> _channelStreams = {};

  /// Channels the client desires to be subscribed to
  final Set<String> _desiredSubscriptions = {};

  /// Presence channels where the client has joined: channel -> userInfo
  final Map<String, Map<String, dynamic>> _desiredPresenceJoins = {};

  /// Presence state listeners: channel -> StreamController of presence user lists
  final Map<String, StreamController<List<Map<String, dynamic>>>>
      _presenceControllers = {};
  final Map<String, Stream<List<Map<String, dynamic>>>> _presenceStreams = {};

  /// Current presence store: channel -> List of active presence maps
  final Map<String, List<Map<String, dynamic>>> _presenceStore = {};

  /// Creates a [BrowserRealtimeClient] connecting to [uri].
  ///
  /// - [uri]: The target WebSocket server URI (`ws://` or `wss://`).
  /// - [initialReconnectDelay]: Delay before the first reconnection retry (defaults to 500ms).
  /// - [maxReconnectDelay]: Maximum retry delay cap (defaults to 30s).
  /// - [backoffMultiplier]: Exponential multiplier for retries (defaults to 1.5).
  /// - [autoReconnect]: Whether to automatically reconnect on disconnect (defaults to `true`).
  /// - [pingInterval]: Keep-alive ping interval (defaults to 30s).
  /// - [protocols]: Optional list of sub-protocol strings.
  BrowserRealtimeClient({
    required this.uri,
    this.initialReconnectDelay = defaultRealtimeInitialReconnectDelay,
    this.maxReconnectDelay = defaultRealtimeMaxReconnectDelay,
    this.backoffMultiplier = defaultRealtimeBackoffMultiplier,
    this.autoReconnect = true,
    this.pingInterval = defaultRealtimePingInterval,
    this.protocols,
  });

  @override
  RealtimeConnectionState get state => _state;

  @override
  Stream<RealtimeConnectionState> get onStateChanged => _stateController.stream;

  /// Whether the client is currently connected to the server.
  bool get isConnected => _state == RealtimeConnectionState.connected;

  /// Explicitly initiates connection to the WebSocket server.
  ///
  /// Safe to call repeatedly: if already connected or currently connecting,
  /// this method returns immediately without creating duplicate connections.
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_socket != null ||
        _state == RealtimeConnectionState.connected ||
        _state == RealtimeConnectionState.connecting) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _updateState(
      _reconnectAttempts > 0
          ? RealtimeConnectionState.reconnecting
          : RealtimeConnectionState.connecting,
    );

    try {
      final ws = protocols != null && protocols!.isNotEmpty
          ? web.WebSocket(
              uri.toString(),
              protocols!.map((p) => p.toJS).toList().toJS,
            )
          : web.WebSocket(uri.toString());

      _socket = ws;

      ws.onopen = ((web.Event _) {
        if (_isDisposed || ws != _socket) {
          try {
            ws.close();
          } catch (_) {}
          return;
        }
        _reconnectAttempts = 0;
        _updateState(RealtimeConnectionState.connected);
        _startPingTimer();
        _resubscribeAll();
      }).toJS;

      ws.onmessage = ((web.MessageEvent event) {
        if (_isDisposed || ws != _socket) return;
        _onMessageReceived(event);
      }).toJS;

      ws.onerror = ((web.Event _) {
        if (_isDisposed || ws != _socket) return;
        _handleDisconnect(ws);
      }).toJS;

      ws.onclose = ((web.CloseEvent _) {
        if (_isDisposed || ws != _socket) return;
        _handleDisconnect(ws);
      }).toJS;
    } catch (_) {
      _handleDisconnect(null);
    }
  }

  /// Subscribes to [channelName] and returns a broadcast stream of message payloads.
  ///
  /// If already connected, immediately sends a subscribe frame over the wire.
  /// Repeated calls with the same [channelName] share the same underlying stream
  /// controller without sending duplicate wire subscriptions.
  @override
  Stream<Map<String, dynamic>> subscribe(String channelName) {
    final isNew = _desiredSubscriptions.add(channelName);

    final stream = _channelStreams.putIfAbsent(channelName, () {
      final controller = StreamController<Map<String, dynamic>>.broadcast();
      _channelControllers[channelName] = controller;
      return controller.stream;
    });

    if (isConnected && isNew) {
      send(RealtimeMessage.subscribe(channelName));
    }

    return stream;
  }

  /// Unsubscribes from [channelName], closing its local broadcast controller
  /// and sending an unsubscribe frame to the server if connected.
  @override
  void unsubscribe(String channelName) {
    final wasSubscribed = _desiredSubscriptions.remove(channelName);
    final hadPresence = _desiredPresenceJoins.remove(channelName) != null;
    _presenceStore.remove(channelName);

    if (isConnected && (wasSubscribed || hadPresence)) {
      send(RealtimeMessage.unsubscribe(channelName));
    }

    _channelControllers[channelName]?.close();
    _channelControllers.remove(channelName);
    _channelStreams.remove(channelName);

    _presenceControllers[channelName]?.close();
    _presenceControllers.remove(channelName);
    _presenceStreams.remove(channelName);
  }

  /// Joins presence in [channelName] publishing [userInfo] metadata.
  ///
  /// Returns a broadcast [Stream] emitting the list of active users in the channel.
  /// Automatically subscribes to [channelName] and re-registers presence across reconnects.
  @override
  Stream<List<Map<String, dynamic>>> joinPresence(
    String channelName,
    Map<String, dynamic> userInfo,
  ) {
    _desiredPresenceJoins[channelName] = userInfo;
    final isNew = _desiredSubscriptions.add(channelName);

    final stream = _presenceStreams.putIfAbsent(channelName, () {
      final controller =
          StreamController<List<Map<String, dynamic>>>.broadcast();
      _presenceControllers[channelName] = controller;
      return controller.stream;
    });

    if (isConnected) {
      if (isNew) {
        send(RealtimeMessage.subscribe(channelName));
      }
      send(RealtimeMessage.presenceJoin(channelName, userInfo));
    }

    return stream;
  }

  /// Leaves presence in [channelName], removing local presence state and sending
  /// a presence leave frame to the server.
  void leavePresence(String channelName) {
    final userInfo = _desiredPresenceJoins.remove(channelName);
    _presenceStore.remove(channelName);

    if (isConnected && userInfo != null) {
      send(RealtimeMessage.presenceLeave(channelName, userInfo));
    }
  }

  /// Broadcasts a [payload] map to [channelName].
  void broadcast(String channelName, Map<String, dynamic> payload) {
    send(RealtimeMessage.broadcast(channelName, payload));
  }

  /// Sends a raw [RealtimeMessage] envelope across the WebSocket connection.
  ///
  /// Returns `true` if the message was successfully queued to the browser WebSocket,
  /// or `false` if disconnected or unable to transmit.
  bool send(RealtimeMessage message) {
    final ws = _socket;
    if (ws != null && isConnected) {
      try {
        ws.send(message.encode().toJS);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _onMessageReceived(web.MessageEvent event) {
    final rawData = event.data;
    if (rawData == null) return;

    final String text;
    if (rawData.isA<JSString>()) {
      text = (rawData as JSString).toDart;
    } else {
      text = rawData.toString();
    }

    final message = RealtimeMessage.tryParse(text);
    if (message == null) return;

    final channel = message.channel;

    switch (message.type) {
      case RealtimeMessage.typePing:
        // Automatically reply to server heartbeat ping with pong
        send(const RealtimeMessage(type: RealtimeMessage.typePong));
        break;

      case RealtimeMessage.typePong:
        // Keep-alive heartbeat response
        break;

      case RealtimeMessage.typeBroadcast:
        if (channel != null) {
          if (message.payload.containsKey('event') &&
              (message.payload['event'] == 'presence_join' ||
                  message.payload['event'] == 'presence_leave')) {
            _handlePresenceBroadcastEvent(channel, message.payload);
          }
          _channelControllers[channel]?.add(message.payload);
        }
        break;

      case RealtimeMessage.typePresenceState:
        if (channel != null) {
          final rawPresences = message.payload['presences'];
          if (rawPresences is List<dynamic>) {
            final list = rawPresences
                .whereType<Map<dynamic, dynamic>>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
            _presenceStore[channel] = list;
            _presenceControllers[channel]
                ?.add(List<Map<String, dynamic>>.unmodifiable(list));
          }
        }
        break;

      case RealtimeMessage.typePresenceJoin:
        if (channel != null) {
          _handlePresenceJoin(channel, message.payload);
        }
        break;

      case RealtimeMessage.typePresenceLeave:
        if (channel != null) {
          _handlePresenceLeave(channel, message.payload);
        }
        break;

      default:
        if (channel != null) {
          _channelControllers[channel]?.add(message.payload);
        }
        break;
    }
  }

  void _handlePresenceBroadcastEvent(
      String channel, Map<String, dynamic> payload) {
    final event = payload['event'] as String?;
    final rawPresence = payload['presence'];
    if (rawPresence is Map<dynamic, dynamic>) {
      final presenceMap = Map<String, dynamic>.from(rawPresence);
      if (event == 'presence_join') {
        _handlePresenceJoin(channel, presenceMap);
      } else if (event == 'presence_leave') {
        _handlePresenceLeave(channel, presenceMap);
      }
    }
  }

  void _handlePresenceJoin(String channel, Map<String, dynamic> payload) {
    final Map<String, dynamic> user = payload.containsKey('presence') &&
            payload['presence'] is Map<dynamic, dynamic>
        ? Map<String, dynamic>.from(
            payload['presence'] as Map<dynamic, dynamic>)
        : payload;
    final current = _presenceStore.putIfAbsent(channel, () => []);
    final id = user['connectionId'] ?? user['id'] ?? user['userId'];
    if (id != null) {
      current.removeWhere(
          (p) => (p['connectionId'] ?? p['id'] ?? p['userId']) == id);
    }
    current.add(user);
    _presenceControllers[channel]
        ?.add(List<Map<String, dynamic>>.unmodifiable(current));
  }

  void _handlePresenceLeave(String channel, Map<String, dynamic> payload) {
    final Map<String, dynamic> user = payload.containsKey('presence') &&
            payload['presence'] is Map<dynamic, dynamic>
        ? Map<String, dynamic>.from(
            payload['presence'] as Map<dynamic, dynamic>)
        : payload;
    final current = _presenceStore.putIfAbsent(channel, () => []);
    final id = user['connectionId'] ?? user['id'] ?? user['userId'];
    if (id != null) {
      current.removeWhere(
          (p) => (p['connectionId'] ?? p['id'] ?? p['userId']) == id);
    } else {
      current.remove(user);
    }
    _presenceControllers[channel]
        ?.add(List<Map<String, dynamic>>.unmodifiable(current));
  }

  void _handleDisconnect(web.WebSocket? ws) {
    if (ws != null && ws != _socket) return;

    _cleanupSocket();
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

    final expDelayMs = (initialReconnectDelay.inMilliseconds *
            math.pow(backoffMultiplier, _reconnectAttempts))
        .round();
    final cappedDelayMs =
        math.min(expDelayMs, maxReconnectDelay.inMilliseconds);

    // Add up to 20% jitter to mitigate thundering herds
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
      send(RealtimeMessage.subscribe(channel));
    }
    for (final entry in _desiredPresenceJoins.entries) {
      send(RealtimeMessage.presenceJoin(entry.key, entry.value));
    }
  }

  void _startPingTimer() {
    _stopPingTimer();
    if (pingInterval > Duration.zero) {
      _pingTimer = Timer.periodic(pingInterval, (_) {
        if (isConnected) {
          send(const RealtimeMessage(type: RealtimeMessage.typePing));
        }
      });
    }
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _cleanupSocket({bool close = false}) {
    final ws = _socket;
    _socket = null;
    if (ws != null) {
      try {
        ws.onopen = null;
        ws.onmessage = null;
        ws.onerror = null;
        ws.onclose = null;
        if (close) {
          ws.close();
        }
      } catch (_) {}
    }
  }

  void _updateState(RealtimeConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  /// Closes the socket, cancels reconnect and ping timers, closes all broadcast controllers,
  /// and releases resources.
  ///
  /// Safe to call multiple times.
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopPingTimer();

    _cleanupSocket(close: true);

    for (final ctrl in _channelControllers.values) {
      ctrl.close();
    }
    _channelControllers.clear();
    _channelStreams.clear();

    for (final ctrl in _presenceControllers.values) {
      ctrl.close();
    }
    _presenceControllers.clear();
    _presenceStreams.clear();

    _desiredSubscriptions.clear();
    _desiredPresenceJoins.clear();
    _presenceStore.clear();

    _updateState(RealtimeConnectionState.disconnected);
    _stateController.close();
  }
}

/// Convenience factory for creating a [BrowserRealtimeClient].
BrowserRealtimeClient browserRealtimeClient({
  required Uri uri,
  Duration initialReconnectDelay = defaultRealtimeInitialReconnectDelay,
  Duration maxReconnectDelay = defaultRealtimeMaxReconnectDelay,
  double backoffMultiplier = defaultRealtimeBackoffMultiplier,
  bool autoReconnect = true,
  Duration pingInterval = defaultRealtimePingInterval,
  List<String>? protocols,
}) =>
    BrowserRealtimeClient(
      uri: uri,
      initialReconnectDelay: initialReconnectDelay,
      maxReconnectDelay: maxReconnectDelay,
      backoffMultiplier: backoffMultiplier,
      autoReconnect: autoReconnect,
      pingInterval: pingInterval,
      protocols: protocols,
    );
