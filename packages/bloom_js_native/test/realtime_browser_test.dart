@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';

void main() {
  group('BrowserRealtimeClient configuration and defaults', () {
    test('initializes with default options', () {
      final uri = Uri.parse('wss://example.com/ws');
      final client = BrowserRealtimeClient(uri: uri);
      expect(client.uri, uri);
      expect(client.state, RealtimeConnectionState.disconnected);
      expect(client.isConnected, isFalse);
      expect(
          client.initialReconnectDelay, defaultRealtimeInitialReconnectDelay);
      expect(client.maxReconnectDelay, defaultRealtimeMaxReconnectDelay);
      expect(client.backoffMultiplier, defaultRealtimeBackoffMultiplier);
      expect(client.autoReconnect, isTrue);
      expect(client.pingInterval, defaultRealtimePingInterval);
      expect(client.protocols, isNull);
      client.dispose();
    });

    test('browserRealtimeClient helper initializes properly', () {
      final uri = Uri.parse('wss://example.com/ws');
      final client = browserRealtimeClient(
        uri: uri,
        initialReconnectDelay: const Duration(milliseconds: 200),
        maxReconnectDelay: const Duration(seconds: 5),
        backoffMultiplier: 2.0,
        autoReconnect: false,
        pingInterval: const Duration(seconds: 10),
        protocols: ['bloom-v1'],
      );
      expect(client.uri, uri);
      expect(client.initialReconnectDelay, const Duration(milliseconds: 200));
      expect(client.maxReconnectDelay, const Duration(seconds: 5));
      expect(client.backoffMultiplier, 2.0);
      expect(client.autoReconnect, isFalse);
      expect(client.pingInterval, const Duration(seconds: 10));
      expect(client.protocols, ['bloom-v1']);
      client.dispose();
    });
  });

  group('BrowserRealtimeClient channel multiplexing and streams', () {
    late BrowserRealtimeClient client;

    setUp(() {
      client = BrowserRealtimeClient(
        uri: Uri.parse('ws://localhost:9999/invalid-ws'),
        autoReconnect: false,
      );
    });

    tearDown(() {
      client.dispose();
    });

    test('subscribe returns same broadcast stream on multiple calls', () {
      final stream1 = client.subscribe('todos');
      final stream2 = client.subscribe('todos');
      expect(stream1.isBroadcast, isTrue);
      expect(identical(stream1, stream2), isTrue);
    });

    test('joinPresence returns same broadcast stream on multiple calls', () {
      final stream1 = client.joinPresence('room-1', {'name': 'Alice'});
      final stream2 = client.joinPresence('room-1', {'name': 'Alice'});
      expect(stream1.isBroadcast, isTrue);
      expect(identical(stream1, stream2), isTrue);
    });

    test('unsubscribe cleans up streams and does not throw', () {
      client.subscribe('todos');
      client.joinPresence('todos', {'name': 'Bob'});
      expect(() => client.unsubscribe('todos'), returnsNormally);
    });

    test('leavePresence cleans up presence store and does not throw', () {
      client.joinPresence('room-1', {'name': 'Bob'});
      expect(() => client.leavePresence('room-1'), returnsNormally);
    });

    test('send returns false when disconnected', () {
      final result = client.send(RealtimeMessage.subscribe('test'));
      expect(result, isFalse);
    });

    test('connect() is safe to call repeatedly', () async {
      // Connect to unreachable address without crashing
      await client.connect();
      await client.connect();
      expect(
          client.state,
          anyOf(RealtimeConnectionState.connecting,
              RealtimeConnectionState.disconnected));
    });

    test('integrates with BloomRealtimeBinding seamlessly', () async {
      final binding = BloomRealtimeBinding(client: client);
      expect(
          binding.connectionState.value, RealtimeConnectionState.disconnected);

      final chan = binding.channel('notifications');
      expect(chan.value, isNull);

      final pres = binding.presence('chat', userInfo: {'user': 'test'});
      expect(pres.value, isEmpty);

      await binding.dispose();
    });

    test('dispose cleans up timers, controllers, and updates state', () {
      final stateEvents = <RealtimeConnectionState>[];
      final sub = client.onStateChanged.listen(stateEvents.add);
      addTearDown(sub.cancel);

      client.subscribe('todos');
      client.joinPresence('room', {'name': 'Alice'});
      client.dispose();

      expect(client.state, RealtimeConnectionState.disconnected);
      expect(() => client.dispose(), returnsNormally);
    });
  });

  group('BrowserRealtimeClient live WebSocket wire frame multiplexing', () {
    test(
        'captures frames and verifies multiplexing for subscribe, joinPresence, and unsubscribe',
        () async {
      final hybridChannel = spawnHybridCode(_wsServerCode);
      final receivedFrames = <Map<String, dynamic>>[];
      final readyCompleter = Completer<int>();
      Completer<void>? frameTargetCompleter;
      var targetFrameCount = 0;

      Future<void> waitForFrames(int count,
          {Duration timeout = const Duration(seconds: 5)}) async {
        if (receivedFrames.length >= count) return;
        targetFrameCount = count;
        frameTargetCompleter = Completer<void>();
        await frameTargetCompleter!.future.timeout(timeout);
      }

      final sub = hybridChannel.stream.listen((dynamic msg) {
        if (msg is Map) {
          if (msg['event'] == 'ready') {
            readyCompleter.complete(msg['port'] as int);
          } else if (msg['event'] == 'frame') {
            final frameStr = msg['frame'] as String;
            final decoded = jsonDecode(frameStr) as Map<String, dynamic>;
            receivedFrames.add(decoded);
            if (frameTargetCompleter != null &&
                !frameTargetCompleter!.isCompleted &&
                receivedFrames.length >= targetFrameCount) {
              frameTargetCompleter!.complete();
            }
          }
        }
      });

      final port = await readyCompleter.future;
      final client = BrowserRealtimeClient(
        uri: Uri.parse('ws://127.0.0.1:$port'),
        autoReconnect: false,
        pingInterval: Duration.zero,
      );

      await client.connect();
      if (!client.isConnected) {
        await client.onStateChanged
            .firstWhere((s) => s == RealtimeConnectionState.connected);
      }
      expect(client.isConnected, isTrue);

      // 1. Repeated subscribe calls on 'todos' produce exactly one subscribe frame
      final stream1 = client.subscribe('todos');
      final stream2 = client.subscribe('todos');
      expect(identical(stream1, stream2), isTrue);

      await waitForFrames(1);
      expect(receivedFrames.length, 1);
      expect(receivedFrames[0]['type'], RealtimeMessage.typeSubscribe);
      expect(receivedFrames[0]['channel'], 'todos');

      // 2. joinPresence on the same channel does not add duplicate subscription frame
      final presStream = client.joinPresence('todos', {'name': 'Alice'});
      expect(presStream.isBroadcast, isTrue);

      await waitForFrames(2);
      expect(receivedFrames.length, 2);
      expect(receivedFrames[1]['type'], RealtimeMessage.typePresenceJoin);
      expect(receivedFrames[1]['channel'], 'todos');
      expect(receivedFrames[1]['payload'], {'name': 'Alice'});

      // 3. Unsubscribe produces exactly one unsubscribe frame; duplicate call sends nothing
      client.unsubscribe('todos');
      client.unsubscribe('todos');

      await waitForFrames(3);
      expect(receivedFrames.length, 3);
      expect(receivedFrames[2]['type'], RealtimeMessage.typeUnsubscribe);
      expect(receivedFrames[2]['channel'], 'todos');

      // 4. Joining presence on a new channel ensures channel has one subscription before presence frame
      client.joinPresence('presence-room', {'name': 'Bob'});

      await waitForFrames(5);
      expect(receivedFrames.length, 5);
      expect(receivedFrames[3]['type'], RealtimeMessage.typeSubscribe);
      expect(receivedFrames[3]['channel'], 'presence-room');
      expect(receivedFrames[4]['type'], RealtimeMessage.typePresenceJoin);
      expect(receivedFrames[4]['channel'], 'presence-room');
      expect(receivedFrames[4]['payload'], {'name': 'Bob'});

      // 5. Subsequent subscribe on 'presence-room' does not add duplicate subscription
      final stream3 = client.subscribe('presence-room');
      expect(stream3.isBroadcast, isTrue);

      // Yield event loop briefly to ensure no extraneous frames were queued
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(receivedFrames.length, 5); // No new frames sent

      // Cleanup
      client.dispose();
      hybridChannel.sink.add({'action': 'close'});
      await sub.cancel();
    });

    test(
        'reconnect sends one subscribe per desired channel followed by presence joins',
        () async {
      final hybridChannel = spawnHybridCode(_wsServerCode);
      final receivedFrames = <Map<String, dynamic>>[];
      final readyCompleter = Completer<int>();
      Completer<void>? frameTargetCompleter;
      var targetFrameCount = 0;

      Future<void> waitForFrames(int count,
          {Duration timeout = const Duration(seconds: 5)}) async {
        if (receivedFrames.length >= count) return;
        targetFrameCount = count;
        frameTargetCompleter = Completer<void>();
        await frameTargetCompleter!.future.timeout(timeout);
      }

      final sub = hybridChannel.stream.listen((dynamic msg) {
        if (msg is Map) {
          if (msg['event'] == 'ready') {
            readyCompleter.complete(msg['port'] as int);
          } else if (msg['event'] == 'frame') {
            final frameStr = msg['frame'] as String;
            final decoded = jsonDecode(frameStr) as Map<String, dynamic>;
            receivedFrames.add(decoded);
            if (frameTargetCompleter != null &&
                !frameTargetCompleter!.isCompleted &&
                receivedFrames.length >= targetFrameCount) {
              frameTargetCompleter!.complete();
            }
          }
        }
      });

      final port = await readyCompleter.future;
      final client = BrowserRealtimeClient(
        uri: Uri.parse('ws://127.0.0.1:$port'),
        autoReconnect: true,
        initialReconnectDelay: const Duration(milliseconds: 20),
        maxReconnectDelay: const Duration(milliseconds: 100),
        pingInterval: Duration.zero,
      );

      // Pre-subscribe while disconnected
      client.subscribe('feed');
      client.subscribe('feed'); // duplicate subscribe call
      client.joinPresence('room-a', {'user': 'charlie'});

      await client.connect();
      if (!client.isConnected) {
        await client.onStateChanged
            .firstWhere((s) => s == RealtimeConnectionState.connected);
      }
      expect(client.isConnected, isTrue);

      // Wait for initial connection frames
      await waitForFrames(3);
      expect(receivedFrames.length, 3);
      expect(receivedFrames[0]['type'], RealtimeMessage.typeSubscribe);
      expect(receivedFrames[0]['channel'], 'feed');
      expect(receivedFrames[1]['type'], RealtimeMessage.typeSubscribe);
      expect(receivedFrames[1]['channel'], 'room-a');
      expect(receivedFrames[2]['type'], RealtimeMessage.typePresenceJoin);
      expect(receivedFrames[2]['channel'], 'room-a');
      expect(receivedFrames[2]['payload'], {'user': 'charlie'});

      // Clear frames received on initial connection
      receivedFrames.clear();

      // Trigger unexpected socket disconnect from server side
      hybridChannel.sink.add({'action': 'drop'});

      // Wait for replacement connection to re-establish and re-subscribe
      await waitForFrames(3);
      expect(receivedFrames.length, 3);
      // Desired channels are 'feed' and 'room-a'
      expect(receivedFrames[0]['type'], RealtimeMessage.typeSubscribe);
      expect(receivedFrames[0]['channel'], 'feed');
      expect(receivedFrames[1]['type'], RealtimeMessage.typeSubscribe);
      expect(receivedFrames[1]['channel'], 'room-a');
      // Presence join follows
      expect(receivedFrames[2]['type'], RealtimeMessage.typePresenceJoin);
      expect(receivedFrames[2]['channel'], 'room-a');
      expect(receivedFrames[2]['payload'], {'user': 'charlie'});
      expect(client.isConnected, isTrue);

      client.dispose();
      hybridChannel.sink.add({'action': 'close'});
      await sub.cancel();
    });
  });
}

const _wsServerCode = r'''
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:stream_channel/stream_channel.dart';

void hybridMain(StreamChannel<dynamic> channel) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final connections = <WebSocket>[];

  server.transform(WebSocketTransformer()).listen((WebSocket ws) {
    connections.add(ws);
    ws.listen((dynamic data) {
      final text = data is String ? data : utf8.decode(data as List<int>);
      channel.sink.add({'event': 'frame', 'frame': text});
    }, onDone: () {
      connections.remove(ws);
    });
  });

  channel.stream.listen((dynamic msg) async {
    if (msg is Map) {
      if (msg['action'] == 'drop') {
        final sockets = List<WebSocket>.from(connections);
        for (final ws in sockets) {
          await ws.close();
        }
        channel.sink.add({'event': 'dropped'});
      } else if (msg['action'] == 'close') {
        final sockets = List<WebSocket>.from(connections);
        for (final ws in sockets) {
          await ws.close();
        }
        await server.close(force: true);
        channel.sink.add({'event': 'closed'});
      }
    }
  });

  channel.sink.add({'event': 'ready', 'port': server.port});
}
''';
