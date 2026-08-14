// lib/src/native/notifications.dart
import 'dart:async';
import '../core/logger.dart';
import 'permissions.dart';

enum NotificationImportance { low, medium, high, max }

class BloomNotificationChannel {
  final String id;
  final String name;
  final String? description;
  final NotificationImportance importance;

  const BloomNotificationChannel({
    required this.id,
    required this.name,
    this.description,
    this.importance = NotificationImportance.high,
  });
}

class BloomNotificationItem {
  final int id;
  final String title;
  final String body;
  final String? payload;
  final String? channelId;
  final DateTime timestamp;

  const BloomNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
    this.channelId,
    required this.timestamp,
  });
}

abstract class BloomNotificationsPlatform {
  FutureOr<void> initialize({List<BloomNotificationChannel> channels = const []});
  FutureOr<bool> requestPermissions();
  FutureOr<void> show(BloomNotificationItem item);
  FutureOr<void> cancel(int id);
  FutureOr<void> cancelAll();
}

class MockBloomNotificationsPlatform implements BloomNotificationsPlatform {
  final List<BloomNotificationItem> postedNotifications = [];
  final List<BloomNotificationChannel> registeredChannels = [];
  bool permissionsGranted = true;

  @override
  void initialize({List<BloomNotificationChannel> channels = const []}) {
    registeredChannels.addAll(channels);
  }

  @override
  bool requestPermissions() => permissionsGranted;

  @override
  void show(BloomNotificationItem item) {
    postedNotifications.add(item);
  }

  @override
  void cancel(int id) {
    postedNotifications.removeWhere((item) => item.id == id);
  }

  @override
  void cancelAll() {
    postedNotifications.clear();
  }
}

/// Cross-platform push and local notifications manager.
class BloomNotifications {
  final BloomNotificationsPlatform platform;
  int _idCounter = 1;

  BloomNotifications([BloomNotificationsPlatform? platform])
      : platform = platform ?? MockBloomNotificationsPlatform();

  /// Initialize notification subsystem and register notification channels.
  Future<void> initialize({List<BloomNotificationChannel> channels = const []}) async {
    logger.info('BloomNotifications: Initializing with ${channels.length} channels.');
    await platform.initialize(channels: channels);
  }

  /// Request notification authorization.
  Future<bool> requestPermissions() async {
    final status = await BloomPermissions.request(BloomPermission.notifications);
    return status.isGranted;
  }

  /// Display a local notification.
  Future<int> show({
    required String title,
    required String body,
    String? payload,
    String? channelId,
    int? id,
  }) async {
    final notificationId = id ?? _idCounter++;
    final item = BloomNotificationItem(
      id: notificationId,
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
      timestamp: DateTime.now(),
    );

    logger.info('BloomNotifications: Displaying notification [$notificationId] "$title"');
    await platform.show(item);
    return notificationId;
  }

  /// Cancel notification by ID.
  Future<void> cancel(int id) async {
    await platform.cancel(id);
    logger.debug('BloomNotifications: Cancelled notification [$id]');
  }

  /// Cancel all active notifications.
  Future<void> cancelAll() async {
    await platform.cancelAll();
    logger.info('BloomNotifications: Cancelled all notifications.');
  }
}
