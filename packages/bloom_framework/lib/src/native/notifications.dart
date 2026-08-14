// lib/src/native/notifications.dart
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/logger.dart';
import 'permissions.dart';

enum NotificationImportance {
  low(Importance.low, Priority.low),
  medium(Importance.defaultImportance, Priority.defaultPriority),
  high(Importance.high, Priority.high),
  max(Importance.max, Priority.max);

  final Importance importance;
  final Priority priority;
  const NotificationImportance(this.importance, this.priority);
}

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

  AndroidNotificationChannel toAndroidChannel() {
    return AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance.importance,
    );
  }
}

/// Cross-platform push and local notifications manager wrapping `flutter_local_notifications`.
class BloomNotifications {
  final FlutterLocalNotificationsPlugin _plugin;
  int _idCounter = 1;
  bool _isInitialized = false;

  BloomNotifications([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Initialize notification subsystem, request permissions, and register notification channels.
  Future<void> initialize({
    List<BloomNotificationChannel> channels = const [],
    String defaultAndroidIcon = '@mipmap/ic_launcher',
    void Function(NotificationResponse response)? onNotificationTap,
  }) async {
    if (_isInitialized) return;

    logger.info('BloomNotifications: Initializing native notifications with ${channels.length} channels.');

    final initSettings = InitializationSettings(
      android: AndroidInitializationSettings(defaultAndroidIcon),
      iOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: const LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
      );

      // Create Android Notification Channels
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        for (final ch in channels) {
          await androidPlugin.createNotificationChannel(ch.toAndroidChannel());
          logger.debug('BloomNotifications: Registered Android channel "${ch.id}"');
        }
      }
      _isInitialized = true;
    } catch (e) {
      logger.warn('BloomNotifications: Initialization note: $e');
    }
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
    String channelName = 'General',
    NotificationImportance importance = NotificationImportance.high,
    int? id,
  }) async {
    final notificationId = id ?? _idCounter++;

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId ?? 'default_channel',
        channelName,
        importance: importance.importance,
        priority: importance.priority,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    logger.info('BloomNotifications: Displaying notification [$notificationId] "$title"');
    try {
      await _plugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      logger.warn('BloomNotifications: Notification display note: $e');
    }
    return notificationId;
  }

  /// Cancel notification by ID.
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
      logger.debug('BloomNotifications: Cancelled notification [$id]');
    } catch (_) {}
  }

  /// Cancel all active notifications.
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      logger.info('BloomNotifications: Cancelled all notifications.');
    } catch (_) {}
  }
}
