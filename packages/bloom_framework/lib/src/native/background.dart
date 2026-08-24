// lib/src/native/background.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/services.dart';
import '../core/logger.dart';

/// Callback signature for asynchronous background task execution.
///
/// Returns `true` if the background task completed successfully, or `false` on failure.
///
/// Example:
/// ```dart
/// Future<bool> mySyncTask(Map<String, dynamic> data) async {
///   await syncPendingData();
///   return true;
/// }
/// ```
typedef BackgroundTaskCallback = FutureOr<bool> Function(Map<String, dynamic> data);

/// Top-level background callback dispatcher for native OS background execution.
///
/// Registered as an entry point via `@pragma('vm:entry-point')` so host OS task runners
/// (WorkManager on Android, BGTaskScheduler on iOS) can invoke Dart execution in background isolates.
@pragma('vm:entry-point')
void bloomBackgroundCallbackDispatcher() {
  const MethodChannel backgroundChannel = MethodChannel('bloom/background_dispatcher');
  backgroundChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'execute') {
      final args = call.arguments is Map ? Map<String, dynamic>.from(call.arguments as Map) : <String, dynamic>{};
      final taskId = args['taskId']?.toString() ?? 'unknown';
      final data = args['data'] is Map ? Map<String, dynamic>.from(args['data'] as Map) : <String, dynamic>{};
      return await BloomBackground.executeTask(taskId, data);
    }
    return false;
  });
}

/// Manages background task execution and background periodic synchronization.
///
/// Integrates with native platform task schedulers (WorkManager on Android,
/// BGTaskScheduler on iOS) to run background sync, cache invalidation, and data prefetching.
///
/// Example:
/// ```dart
/// BloomBackground.registerTask('syncData', (data) async {
///   return await syncLatestUpdates();
/// });
///
/// await BloomBackground.schedulePeriodicTask(
///   taskId: 'syncData',
///   frequency: const Duration(hours: 1),
///   requiresNetwork: true,
/// );
/// ```
class BloomBackground {
  static const MethodChannel _channel = MethodChannel('bloom/background');
  static final Map<String, BackgroundTaskCallback> _registeredTasks =
      HashMap<String, BackgroundTaskCallback>();

  /// Registers a named background task [callback] handler matching [taskId].
  ///
  /// Example:
  /// ```dart
  /// BloomBackground.registerTask('dataSync', (data) async {
  ///   // Perform background fetch
  ///   return true;
  /// });
  /// ```
  static void registerTask(String taskId, BackgroundTaskCallback callback) {
    _registeredTasks[taskId] = callback;
    logger.debug('BloomBackground: Registered task handler for "$taskId"');
  }

  /// Schedules a periodic background task with native OS task schedulers.
  ///
  /// Returns `true` if successfully scheduled, `false` if unsupported or rejected by host OS.
  ///
  /// Example:
  /// ```dart
  /// final scheduled = await BloomBackground.schedulePeriodicTask(
  ///   taskId: 'syncTasks',
  ///   frequency: const Duration(minutes: 15),
  ///   requiresNetwork: true,
  ///   requiresCharging: false,
  /// );
  /// ```
  static Future<bool> schedulePeriodicTask({
    required String taskId,
    required Duration frequency,
    Map<String, dynamic> data = const {},
    bool requiresCharging = false,
    bool requiresNetwork = true,
  }) async {
    logger.info('BloomBackground: Scheduling periodic task "$taskId" every ${frequency.inMinutes}m');
    try {
      final res = await _channel.invokeMethod<bool>('schedulePeriodicTask', {
        'taskId': taskId,
        'frequencyMinutes': frequency.inMinutes,
        'data': data,
        'requiresCharging': requiresCharging,
        'requiresNetwork': requiresNetwork,
      });
      return res ?? false;
    } catch (e) {
      logger.warn('BloomBackground: Periodic task scheduling not supported on this platform: $e');
      return false;
    }
  }

  /// Cancels a scheduled background task by [taskId].
  ///
  /// Example:
  /// ```dart
  /// await BloomBackground.cancelTask('syncTasks');
  /// ```
  static Future<void> cancelTask(String taskId) async {
    logger.debug('BloomBackground: Cancelling background task "$taskId"');
    try {
      await _channel.invokeMethod('cancelTask', {'taskId': taskId});
    } catch (e) {
      logger.warn('BloomBackground: Cancel task note: $e');
    }
  }

  /// Executes a registered background task handler directly by [taskId] with optional [data].
  ///
  /// Returns the boolean status returned by the registered handler, or `false` if no handler exists or an error occurred.
  ///
  /// Example:
  /// ```dart
  /// final success = await BloomBackground.executeTask('syncTasks', {'scope': 'all'});
  /// ```
  static Future<bool> executeTask(String taskId, [Map<String, dynamic> data = const {}]) async {
    final handler = _registeredTasks[taskId];
    if (handler == null) {
      logger.warn('BloomBackground: No handler registered for background task "$taskId"');
      return false;
    }

    try {
      logger.info('BloomBackground: Executing task "$taskId"...');
      final result = await handler(data);
      logger.info('BloomBackground: Task "$taskId" completed with status: $result');
      return result;
    } catch (e, st) {
      logger.error('BloomBackground: Task "$taskId" threw an error: $e', e, st);
      return false;
    }
  }
}
