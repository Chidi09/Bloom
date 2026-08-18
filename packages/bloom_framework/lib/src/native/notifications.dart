// lib/src/native/notifications.dart
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/logger.dart';
import 'permissions.dart';

/// Importance levels for notification priority and alerts.
enum NotificationImportance {
  /// Low importance notification with no sound or vibration.
  low(Importance.low, Priority.low),
  /// Default notification importance.
  medium(Importance.defaultImportance, Priority.defaultPriority),
  /// High importance notification with sound and banner.
  high(Importance.high, Priority.high),
  /// Maximum importance notification with heads-up display.
  max(Importance.max, Priority.max);

  /// Underlying [Importance] level.
  final Importance importance;

  /// Underlying [Priority] level.
  final Priority priority;

  const NotificationImportance(this.importance, this.priority);
}

/// Represents an Android notification channel configuration.
class BloomNotificationChannel {
  /// Unique channel ID.
  final String id;

  /// User-visible channel name.
  final String name;

  /// User-visible channel description.
  final String? description;

  /// Importance level of notifications posted to this channel.
  final NotificationImportance importance;

  /// Creates a [BloomNotificationChannel] definition.
  const BloomNotificationChannel({
    required this.id,
    required this.name,
    this.description,
    this.importance = NotificationImportance.high,
  });

  /// Converts this definition to a Flutter [AndroidNotificationChannel].
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

  /// Creates a [BloomNotifications] manager with an optional [plugin] instance.
  BloomNotifications([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Initialize notification subsystem, request permissions, and register notification channels.
  Future<void> initialize({
    List<BloomNotificationChannel> channels = const [],
    String defaultAndroidIcon = '@mipmap/ic_launcher',
    bool requestPermissions = true,
    void Function(NotificationResponse response)? onNotificationTap,
  }) async {
    if (_isInitialized) return;

    logger.info('BloomNotifications: Initializing native notifications with ${channels.length} channel(s)...');

    final initSettings = InitializationSettings(
      android: AndroidInitializationSettings(defaultAndroidIcon),
      iOS: const DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      linux: const LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
      );

      // Create Android Notification Channels (Always includes fallback default_channel for Android 8+)
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // 1. Create fallback default channel
        const defaultChannel = BloomNotificationChannel(
          id: 'default_channel',
          name: 'General Notifications',
          description: 'General system and application alerts',
          importance: NotificationImportance.high,
        );
        await androidPlugin.createNotificationChannel(defaultChannel.toAndroidChannel());

        // 2. Create user-specified channels
        for (final ch in channels) {
          await androidPlugin.createNotificationChannel(ch.toAndroidChannel());
          logger.debug('BloomNotifications: Registered Android channel "${ch.id}"');
        }
      }

      if (requestPermissions) {
        await this.requestPermissions();
      }

      _isInitialized = true;
    } catch (e) {
      logger.warn('BloomNotifications: Initialization note: $e');
    }
  }

  /// Request notification authorization from the user.
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
