import 'dart:async';
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomRealtimeBinding', () {
    late _FakeRealtimeClient fakeClient;
    late BloomRealtimeBinding binding;

    setUp(() {
      fakeClient = _FakeRealtimeClient();
      binding = BloomRealtimeBinding(client: fakeClient);
    });

    tearDown(() async => binding.dispose());

    test('connectionState starts as disconnected', () {
      expect(binding.connectionState.value,
          RealtimeConnectionState.disconnected);
    });

    test('connectionState updates when client state changes', () async {
      fakeClient.emitState(RealtimeConnectionState.connected);
      await Future.microtask(() {});
      expect(binding.connectionState.value,
          RealtimeConnectionState.connected);
    });

    test('channel() returns ReadonlySignal starting as null', () {
      final sig = binding.channel('todos');
      expect(sig.value, isNull);
    });

    test('channel() signal updates on client broadcast', () async {
      final sig = binding.channel('todos');
      fakeClient.emitMessage('todos', {'id': 1, 'title': 'Buy milk'});
      await Future.microtask(() {});
      expect(sig.value, {'id': 1, 'title': 'Buy milk'});
    });

    test('same channel() call returns same signal instance', () {
      final a = binding.channel('chat');
      final b = binding.channel('chat');
      expect(identical(a, b), isTrue);
    });

    test('presence() returns ReadonlySignal starting as empty list', () {
      final sig = binding.presence('room-1');
      expect(sig.value, isEmpty);
    });

    test('presence() signal updates on client presence event', () async {
      final sig = binding.presence('room-1');
      fakeClient.emitPresence('room-1', [
        {'id': 'u1', 'name': 'Alice'},
        {'id': 'u2', 'name': 'Bob'},
      ]);
      await Future.microtask(() {});
      expect(sig.value.length, 2);
      expect(sig.value.first['name'], 'Alice');
    });

    test('dispose() closes without error', () async {
      binding.channel('ch1');
      binding.presence('p1');
      expect(() => binding.dispose(), returnsNormally);
    });
  });

  group('realtimeBinding() helper', () {
    test('creates a BloomRealtimeBinding', () {
      final client = _FakeRealtimeClient();
      final b = realtimeBinding(client);
      expect(b, isA<BloomRealtimeBinding>());
      b.dispose();
    });
  });

  group('RealtimeMessage wire protocol', () {
    test('subscribe() factory sets type and channel', () {
      final msg = RealtimeMessage.subscribe('todos');
      expect(msg.type, RealtimeMessage.typeSubscribe);
      expect(msg.channel, 'todos');
    });

    test('encode/tryParse round-trips a broadcast message', () {
      final msg = RealtimeMessage.broadcast('todos', {'id': 1, 'title': 'x'});
      final encoded = msg.encode();
      final parsed = RealtimeMessage.tryParse(encoded)!;
      expect(parsed.type, RealtimeMessage.typeBroadcast);
      expect(parsed.channel, 'todos');
      expect(parsed.payload, {'id': 1, 'title': 'x'});
    });

    test('tryParse returns null for invalid JSON', () {
      expect(RealtimeMessage.tryParse('not json{{{'), isNull);
    });
  });
}

/// Fake [BloomRealtimeChannelClient] for testing — no real network I/O.
class _FakeRealtimeClient implements BloomRealtimeChannelClient {
  final _stateCtrl = StreamController<RealtimeConnectionState>.broadcast();
  final _msgCtrls = <String, StreamController<Map<String, dynamic>>>{};
  final _presenceCtrls = <String, StreamController<List<Map<String, dynamic>>>>{};

  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;

  @override
  RealtimeConnectionState get state => _state;

  @override
  Stream<RealtimeConnectionState> get onStateChanged => _stateCtrl.stream;

  void emitState(RealtimeConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void emitMessage(String channel, Map<String, dynamic> msg) =>
      _msgCtrls[channel]?.add(msg);

  void emitPresence(String channel, List<Map<String, dynamic>> users) =>
      _presenceCtrls[channel]?.add(users);

  @override
  Stream<Map<String, dynamic>> subscribe(String channel) {
    return (_msgCtrls[channel] ??=
            StreamController<Map<String, dynamic>>.broadcast())
        .stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> joinPresence(
      String channel, Map<String, dynamic> userInfo) {
    return (_presenceCtrls[channel] ??=
            StreamController<List<Map<String, dynamic>>>.broadcast())
        .stream;
  }

  @override
  void unsubscribe(String channel) {
    _msgCtrls[channel]?.close();
    _msgCtrls.remove(channel);
    _presenceCtrls[channel]?.close();
    _presenceCtrls.remove(channel);
  }

  @override
  void dispose() {
    _stateCtrl.close();
    for (final c in _msgCtrls.values) {
      c.close();
    }
    for (final c in _presenceCtrls.values) {
      c.close();
    }
  }
}
