// lib/src/updates/crash_watchdog.dart
import 'dart:async';
import '../core/logger.dart';

/// Delegate interface for persisting watchdog crash counts and active patch states.
abstract class WatchdogStorage {
  int getConsecutiveCrashes(String patchId);
  void setConsecutiveCrashes(String patchId, int count);
  void clearPatch(String patchId);
}

/// In-memory default implementation of WatchdogStorage.
class InMemoryWatchdogStorage implements WatchdogStorage {
  final Map<String, int> _crashes = {};

  @override
  int getConsecutiveCrashes(String patchId) => _crashes[patchId] ?? 0;

  @override
  void setConsecutiveCrashes(String patchId, int count) {
    _crashes[patchId] = count;
  }

  @override
  void clearPatch(String patchId) {
    _crashes.remove(patchId);
  }
}

/// Self-healing startup watchdog that detects crash loops on downloaded OTA patches
/// and automatically falls back to the embedded base binary.
class StartupCrashWatchdog {
  final WatchdogStorage storage;
  final int maxCrashThreshold;
  final Duration healthyThresholdDuration;

  Timer? _healthTimer;
  String? _activePatchId;
  bool _isHealthy = false;

  void Function(String faultyPatchId, String reason)? onRollbackTriggered;

  StartupCrashWatchdog({
    WatchdogStorage? storage,
    this.maxCrashThreshold = 2,
    this.healthyThresholdDuration = const Duration(seconds: 5),
    this.onRollbackTriggered,
  }) : storage = storage ?? InMemoryWatchdogStorage();

  bool get isHealthy => _isHealthy;

  /// Starts monitoring application startup for the given [patchId].
  void recordAppLaunch(String? patchId) {
    _activePatchId = patchId;
    _isHealthy = false;
    _healthTimer?.cancel();

    if (patchId == null || patchId.isEmpty) {
      // Running on clean base binary, inherently healthy
      _isHealthy = true;
      return;
    }

    final currentCrashes = storage.getConsecutiveCrashes(patchId);
    logger.debug('Watchdog: Launching patch "$patchId" (consecutive crashes: $currentCrashes)');

    if (currentCrashes >= maxCrashThreshold) {
      _triggerSelfHealingRollback(patchId, 'Consecutive startup crash limit ($maxCrashThreshold) exceeded on launch');
      return;
    }

    // Schedule healthy confirmation timer
    _healthTimer = Timer(healthyThresholdDuration, () {
      _isHealthy = true;
      storage.setConsecutiveCrashes(patchId, 0);
      logger.info('Watchdog: App startup confirmed stable for patch "$patchId". Crash counters reset.');
    });
  }

  /// Manually or automatically record an unhandled startup crash.
  void recordStartupCrash() {
    if (_isHealthy || _activePatchId == null) return;

    final patchId = _activePatchId!;
    _healthTimer?.cancel();
    final newCount = storage.getConsecutiveCrashes(patchId) + 1;
    storage.setConsecutiveCrashes(patchId, newCount);

    logger.error('Watchdog: Startup crash recorded for patch "$patchId" (Count: $newCount/$maxCrashThreshold)');

    if (newCount >= maxCrashThreshold) {
      _triggerSelfHealingRollback(patchId, 'Exceeded $maxCrashThreshold consecutive crashes during launch');
    }
  }

  void _triggerSelfHealingRollback(String patchId, String reason) {
    logger.warn('Watchdog: 🚨 Self-healing rollback triggered for patch "$patchId"! Reason: $reason');
    storage.clearPatch(patchId);
    onRollbackTriggered?.call(patchId, reason);
  }

  void dispose() {
    _healthTimer?.cancel();
  }
}
