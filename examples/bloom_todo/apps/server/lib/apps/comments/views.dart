import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_todo_core/core.dart';

class CommentViews {
  static final List<ActivityEvent> _inMemoryEvents = [];

  static Future<BloomResponse> list(BloomRequest req) async {
    final taskId = req.queryParams['taskId'];
    var results = _inMemoryEvents;
    if (taskId != null) {
      results = results.where((e) => e.taskId == taskId).toList();
    }
    return BloomResponse.json(results.map((e) => e.toJson()).toList());
  }

  static Future<BloomResponse> create(BloomRequest req) async {
    final body = await req.json();
    final event = ActivityEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      taskId: body['taskId'] as String,
      workspaceId: body['workspaceId'] as String? ?? 'ws_1',
      actorId: req.headers['x-user-id'] ?? 'usr_demo_123',
      type: EventType.commentAdded,
      body: body['body'] as String?,
      createdAt: DateTime.now().toUtc(),
    );

    _inMemoryEvents.add(event);
    return BloomResponse.json(event.toJson(), statusCode: 201);
  }
}
