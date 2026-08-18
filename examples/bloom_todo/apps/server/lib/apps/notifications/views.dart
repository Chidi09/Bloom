import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_todo_core/core.dart';

class NotificationViews {
  static final List<AppNotification> _inMemoryNotifications = [
    AppNotification(
      id: 'ntf_1',
      userId: 'usr_demo_123',
      title: 'Task Assigned',
      body: 'You were assigned to "Review Bloom architecture blueprint"',
      type: NotificationType.assignment,
      taskId: 'tsk_1',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  static Future<BloomResponse> list(BloomRequest req) async {
    return BloomResponse.json(_inMemoryNotifications.map((n) => n.toJson()).toList());
  }

  static Future<BloomResponse> markRead(BloomRequest req, String id) async {
    final idx = _inMemoryNotifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _inMemoryNotifications[idx] = _inMemoryNotifications[idx].copyWith(isRead: true);
    }
    return BloomResponse.json({'status': 'marked_read'});
  }

  static Future<BloomResponse> markAllRead(BloomRequest req) async {
    for (var i = 0; i < _inMemoryNotifications.length; i++) {
      _inMemoryNotifications[i] = _inMemoryNotifications[i].copyWith(isRead: true);
    }
    return BloomResponse.json({'status': 'all_marked_read'});
  }
}
