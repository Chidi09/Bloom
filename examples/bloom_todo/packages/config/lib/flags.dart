class FeatureFlags {
  static const bool enableKarma = bool.fromEnvironment(
    'FF_KARMA',
    defaultValue: true,
  );

  static const bool enableCalendarView = bool.fromEnvironment(
    'FF_CALENDAR_VIEW',
    defaultValue: true,
  );

  static const bool enableBoardView = bool.fromEnvironment(
    'FF_BOARD_VIEW',
    defaultValue: true,
  );

  static const bool enableOfflineQueue = bool.fromEnvironment(
    'FF_OFFLINE_QUEUE',
    defaultValue: true,
  );

  static const bool enablePushNotifications = bool.fromEnvironment(
    'FF_PUSH_NOTIFICATIONS',
    defaultValue: true,
  );

  static const bool enableAiNaturalLanguage = bool.fromEnvironment(
    'FF_AI_NATURAL_LANGUAGE',
    defaultValue: true,
  );
}
