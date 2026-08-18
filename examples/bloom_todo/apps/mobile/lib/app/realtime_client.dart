import 'dart:async';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_config/config.dart';

class RealtimeClient {
  final String wsUrl;
  final _eventController = StreamController<DeltaEvent>.broadcast();

  RealtimeClient({String? wsUrl}) : wsUrl = wsUrl ?? Env.wsUrl;

  Stream<DeltaEvent> get events => _eventController.stream;

  Future<void> connect(String token) async {
    // WebSocket connection logic with exponential backoff
  }

  void subscribe(String channel) {
    // Subscribe to workspace/project channel
  }

  void disconnect() {
    // Disconnect websocket
  }

  void dispose() {
    _eventController.close();
  }
}
