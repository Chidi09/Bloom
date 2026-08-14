// lib/src/native/background.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/services.dart';
import '../core/logger.dart';

typedef BackgroundTaskCallback = FutureOr<bool> Function(Map<String, dynamic> data);

/// Manages background task execution and background periodic synchronization.
class BloomBackground {
  static const MethodChannel _channel = MethodChannel('bloom/background');
  static final Map<String, BackgroundTaskCallback> _registeredTasks =
      HashMap<String, BackgroundTaskCallback>();

  /// Register a named background task handler.
  static void registerTask(String taskId, BackgroundTaskCallback callback) {
    _registeredTasks[taskId] = callback;
    logger.debug('BloomBackground: Registered task handler for "$taskId"');
  }

  /// Schedule a periodic background task with native OS task schedulers (WorkManager / BackgroundTasks).
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
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Cancel a scheduled background task by ID.
  static Future<void> cancelTask(String taskId) async {
    logger.debug('BloomBackground: Cancelling background task "$taskId"');
    try {
      await _channel.invokeMethod('cancelTask', {'taskId': taskId});
    } catch (_) {}
  }

  /// Execute a registered background task locally (or invoked from native callback dispatcher).
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
