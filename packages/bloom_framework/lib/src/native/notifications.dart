// lib/src/native/notifications.dart
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/logger.dart';
import 'permissions.dart';

/// Importance levels for notification priority and alerts.
///
/// Maps directly to underlying Android `Importance` and `Priority` settings.
///
/// Example:
/// ```dart
/// const importance = NotificationImportance.high;
/// ```
enum NotificationImportance {
  /// Low importance notification with no sound or vibration.
  low(Importance.low, Priority.low),

  /// Default notification importance with standard sound/vibration.
  medium(Importance.defaultImportance, Priority.defaultPriority),

  /// High importance notification with audible sound and banner heads-up.
  high(Importance.high, Priority.high),

  /// Maximum importance notification with heads-up display and urgent alert behavior.
  max(Importance.max, Priority.max);

  /// Underlying Flutter Local Notifications [Importance] level.
  final Importance importance;

  /// Underlying Flutter Local Notifications [Priority] level.
  final Priority priority;

  /// Creates a [NotificationImportance] enum value with corresponding [importance] and [priority].
  const NotificationImportance(this.importance, this.priority);
}

/// Represents an Android notification channel configuration for Android 8.0 (API 26) and newer.
///
/// Example:
/// ```dart
/// const channel = BloomNotificationChannel(
///   id: 'messages',
///   name: 'Chat Messages',
///   description: 'Direct messages and team mentions',
///   importance: NotificationImportance.high,
/// );
/// ```
class BloomNotificationChannel {
  /// Unique channel identifier (e.g. `'messages'`, `'updates'`).
  final String id;

  /// User-visible channel name shown in Android system notification settings.
  final String name;

  /// User-visible channel description.
  final String? description;

  /// Importance level of notifications posted to this channel (defaults to [NotificationImportance.high]).
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
///
/// Manages notification channels on Android, notification authorization permissions on iOS/Android,
/// and foreground/background local alerts.
///
/// Example:
/// ```dart
/// final notifications = BloomNotifications();
/// await notifications.initialize(
///   channels: [
///     const BloomNotificationChannel(id: 'reminders', name: 'Task Reminders'),
///   ],
/// );
///
/// await notifications.show(
///   title: 'Task Reminder',
///   body: 'Review deployment checklist',
/// );
/// ```
class BloomNotifications {
  final FlutterLocalNotificationsPlugin _plugin;
  int _idCounter = 1;
  bool _isInitialized = false;

  /// Creates a [BloomNotifications] manager with an optional custom [plugin] instance for testing.
  BloomNotifications([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Initializes notification subsystem, requests permissions if [requestPermissions] is true, and registers Android notification channels.
  ///
  /// Example:
  /// ```dart
  /// await notifications.initialize(
  ///   onNotificationTap: (response) => print('Tapped payload: ${response.payload}'),
  /// );
  /// ```
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

  /// Requests notification authorization from the user via [BloomPermissions].
  ///
  /// Returns `true` if notification permission is granted.
  Future<bool> requestPermissions() async {
    final status = await BloomPermissions.request(BloomPermission.notifications);
    return status.isGranted;
  }

  /// Displays a local notification with [title], [body], and optional [payload].
  ///
  /// Returns the integer ID assigned to the notification.
  ///
  /// Example:
  /// ```dart
  /// final id = await notifications.show(
  ///   title: 'Build Complete',
  ///   body: 'Your artifact is ready for download.',
  ///   channelId: 'builds',
  /// );
  /// ```
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

  /// Cancels an active or pending notification by [id].
  ///
  /// Example:
  /// ```dart
  /// await notifications.cancel(42);
  /// ```
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
      logger.debug('BloomNotifications: Cancelled notification [$id]');
    } catch (_) {}
  }

  /// Cancels all active and scheduled notifications.
  ///
  /// Example:
  /// ```dart
  /// await notifications.cancelAll();
  /// ```
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      logger.info('BloomNotifications: Cancelled all notifications.');
    } catch (_) {}
  }
}
