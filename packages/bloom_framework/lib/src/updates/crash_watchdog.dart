/// Self-healing startup watchdog and crash loop prevention engine for OTA updates.
library;

import 'dart:async';
import '../core/logger.dart';

/// Delegate interface for persisting watchdog crash counts and active patch states across restarts.
abstract class WatchdogStorage {
  /// Returns the consecutive crash count for the given [patchId].
  int getConsecutiveCrashes(String patchId);

  /// Stores consecutive crash [count] for [patchId].
  void setConsecutiveCrashes(String patchId, int count);

  /// Clears stored crash records for [patchId].
  void clearPatch(String patchId);
}

/// In-memory default implementation of [WatchdogStorage] (useful for testing).
class InMemoryWatchdogStorage implements WatchdogStorage {
  final Map<String, int> _crashes = {};

  /// Creates an [InMemoryWatchdogStorage].
  InMemoryWatchdogStorage();

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
///
/// If an app crashes consecutively [maxCrashThreshold] times during the initial
/// [healthyThresholdDuration] launch window, the watchdog triggers [onRollbackTriggered]
/// to purge the faulty patch.
///
/// Example:
/// ```dart
/// final watchdog = StartupCrashWatchdog(
///   maxCrashThreshold: 2,
///   healthyThresholdDuration: const Duration(seconds: 5),
///   onRollbackTriggered: (patchId, reason) {
///     print('Rolling back faulty patch $patchId: $reason');
///   },
/// );
/// watchdog.recordAppLaunch('patch_12');
/// ```
class StartupCrashWatchdog {
  /// Persistence storage delegate for crash metrics.
  final WatchdogStorage storage;

  /// Maximum permitted startup crashes before initiating automatic rollback.
  final int maxCrashThreshold;

  /// Duration after launch after which startup is considered healthy.
  final Duration healthyThresholdDuration;

  Timer? _healthTimer;
  String? _activePatchId;
  bool _isHealthy = false;

  /// Callback triggered when self-healing rollback occurs.
  void Function(String faultyPatchId, String reason)? onRollbackTriggered;

  /// Creates a [StartupCrashWatchdog].
  StartupCrashWatchdog({
    WatchdogStorage? storage,
    this.maxCrashThreshold = 2,
    this.healthyThresholdDuration = const Duration(seconds: 5),
    this.onRollbackTriggered,
  }) : storage = storage ?? InMemoryWatchdogStorage();


  /// Whether current startup has stabilized and reached healthy state.
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
