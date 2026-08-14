// lib/src/updates/bloom_updates.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/logger.dart';
import '../state/signals.dart';
import 'crash_watchdog.dart';
import 'runtime_fingerprint.dart';
import 'staged_rollout.dart';
import 'update_manifest.dart';

/// Network and platform adapter for fetching and applying OTA updates.
abstract class BloomUpdateClientAdapter {
  Future<UpdateManifest?> checkServerForUpdate({
    required String channel,
    required String branch,
    required String runtimeFingerprint,
    required String deviceId,
  });

  Future<bool> downloadPatchAssets({
    required UpdateManifest manifest,
    required void Function(double progress) onProgress,
  });

  Future<void> triggerAppReload();
  Future<void> purgeActivePatch();
}

/// In-memory mock client adapter used in development and tests.
class MockBloomUpdateClientAdapter implements BloomUpdateClientAdapter {
  UpdateManifest? mockAvailableManifest;
  bool downloadShouldSucceed = true;
  bool reloadTriggered = false;
  bool purgeTriggered = false;

  MockBloomUpdateClientAdapter({this.mockAvailableManifest});

  @override
  Future<UpdateManifest?> checkServerForUpdate({
    required String channel,
    required String branch,
    required String runtimeFingerprint,
    required String deviceId,
  }) async {
    return mockAvailableManifest;
  }

  @override
  Future<bool> downloadPatchAssets({
    required UpdateManifest manifest,
    required void Function(double progress) onProgress,
  }) async {
    for (int i = 1; i <= 10; i++) {
      onProgress(i / 10.0);
    }
    return downloadShouldSucceed;
  }

  @override
  Future<void> triggerAppReload() async {
    reloadTriggered = true;
  }

  @override
  Future<void> purgeActivePatch() async {
    purgeTriggered = true;
  }
}

/// Enterprise-grade Over-The-Air (OTA) Updates & Runtime Fingerprint Engine.
class BloomUpdates {
  static final Signal<bool> _isChecking = signal(false);
  static final Signal<bool> _isAvailable = signal(false);
  static final Signal<bool> _isDownloading = signal(false);
  static final Signal<bool> _isReady = signal(false);
  static final Signal<double> _downloadProgress = signal(0.0);
  static final Signal<Object?> _error = signal(null);
  static final Signal<UpdateManifest?> _currentPatch = signal(null);

  // Read-only public signal accessors
  static ReadonlySignal<bool> get isChecking => _isChecking;
  static ReadonlySignal<bool> get isAvailable => _isAvailable;
  static ReadonlySignal<bool> get isDownloading => _isDownloading;
  static ReadonlySignal<bool> get isReady => _isReady;
  static ReadonlySignal<double> get downloadProgress => _downloadProgress;
  static ReadonlySignal<Object?> get error => _error;
  static ReadonlySignal<UpdateManifest?> get currentPatch => _currentPatch;

  static String _activeChannel = 'production';
  static String _activeBranch = 'main';
  static String _deviceId = 'device_anon';
  static String _localRuntimeFingerprint = '';
  static BloomUpdateClientAdapter _adapter = MockBloomUpdateClientAdapter();
  static late StartupCrashWatchdog _watchdog;
  static UpdateManifest? _pendingStagedManifest;

  static StartupCrashWatchdog get watchdog => _watchdog;
  static String get activeChannel => _activeChannel;
  static String get activeBranch => _activeBranch;
  static String get localRuntimeFingerprint => _localRuntimeFingerprint;

  /// Initializes BloomUpdates runtime engine.
  static Future<void> initialize({
    String channel = 'production',
    String branch = 'main',
    String? deviceId,
    String? runtimeFingerprint,
    BloomUpdateClientAdapter? adapter,
    WatchdogStorage? watchdogStorage,
    String? currentPatchId,
    bool autoHookErrorHandlers = true,
  }) async {
    _activeChannel = channel;
    _activeBranch = branch;
    _deviceId = deviceId ?? _deviceId;
    
    // Automatically derive runtime fingerprint from environment if not explicitly provided
    _localRuntimeFingerprint = runtimeFingerprint ??
        BloomRuntimeFingerprint.current().computeHash();

    if (adapter != null) _adapter = adapter;

    _watchdog = StartupCrashWatchdog(
      storage: watchdogStorage,
      onRollbackTriggered: (faultyId, reason) {
        rollback(reason: reason);
      },
    );

    _watchdog.recordAppLaunch(currentPatchId);

    // Auto-hook startup error handlers for crash detection
    if (autoHookErrorHandlers) {
      _hookStartupErrorHandlers();
    }

    logger.info('BloomUpdates: Initialized (Channel: "$_activeChannel", Fingerprint: "${_localRuntimeFingerprint.length >= 8 ? _localRuntimeFingerprint.substring(0, 8) : _localRuntimeFingerprint}...")');
  }

  static void _hookStartupErrorHandlers() {
    final originalFlutterError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _watchdog.recordStartupCrash();
      originalFlutterError?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _watchdog.recordStartupCrash();
      return false; // let unhandled error propagate
    };
  }

  /// Checks for compatible OTA updates on the active channel and branch.
  static Future<UpdateCheckResult> checkForUpdate({
    String? channel,
    String? branch,
  }) async {
    _isChecking.value = true;
    _error.value = null;

    final targetChannel = channel ?? _activeChannel;
    final targetBranch = branch ?? _activeBranch;

    try {
      final manifest = await _adapter.checkServerForUpdate(
        channel: targetChannel,
        branch: targetBranch,
        runtimeFingerprint: _localRuntimeFingerprint,
        deviceId: _deviceId,
      );

      if (manifest == null) {
        _isAvailable.value = false;
        _isChecking.value = false;
        return const UpdateCheckResult.upToDate();
      }

      // 1. Verify Cryptographic Runtime Fingerprint Compatibility
      if (manifest.runtimeFingerprint.isNotEmpty &&
          manifest.runtimeFingerprint.toLowerCase() != _localRuntimeFingerprint.toLowerCase()) {
        final remoteShort = manifest.runtimeFingerprint.length >= 8 ? manifest.runtimeFingerprint.substring(0, 8) : manifest.runtimeFingerprint;
        final localShort = _localRuntimeFingerprint.length >= 8 ? _localRuntimeFingerprint.substring(0, 8) : _localRuntimeFingerprint;
        final reason = 'Incompatible native runtime fingerprint: remote requires "$remoteShort...", local binary is "$localShort..."';
        logger.warn('BloomUpdates: OTA update "${manifest.id}" rejected! $reason');
        _isAvailable.value = false;
        _isChecking.value = false;
        return UpdateCheckResult.rejected(reason: reason, manifest: manifest);
      }

      // 2. Evaluate Staged Percentage Rollout
      if (manifest.rolloutPercentage < 100) {
        final eligible = StagedRolloutEvaluator.isEligible(
          deviceId: _deviceId,
          updateId: manifest.id,
          rolloutPercentage: manifest.rolloutPercentage,
        );

        if (!eligible) {
          final bucket = StagedRolloutEvaluator.getDeviceBucket(_deviceId, manifest.id);
          final reason = 'Device bucket ($bucket) excluded by staged rollout window (${manifest.rolloutPercentage}%)';
          logger.debug('BloomUpdates: Device not in rollout partition: $reason');
          _isAvailable.value = false;
          _isChecking.value = false;
          return UpdateCheckResult.rejected(reason: reason, manifest: manifest);
        }
      }

      _pendingStagedManifest = manifest;
      _isAvailable.value = true;
      _isChecking.value = false;
      return UpdateCheckResult.available(manifest);
    } catch (e, st) {
      logger.error('BloomUpdates: Check for update failed: $e', e, st);
      _error.value = e;
      _isAvailable.value = false;
      _isChecking.value = false;
      return UpdateCheckResult.rejected(reason: e.toString());
    }
  }

  /// Downloads patch assets in the background, reporting fine-grained progress.
  static Future<bool> fetchUpdate({
    void Function(double progress)? onProgress,
  }) async {
    final manifest = _pendingStagedManifest;
    if (manifest == null) {
      logger.warn('BloomUpdates: fetchUpdate called but no update is available.');
      return false;
    }

    _isDownloading.value = true;
    _downloadProgress.value = 0.0;
    _error.value = null;

    try {
      final success = await _adapter.downloadPatchAssets(
        manifest: manifest,
        onProgress: (p) {
          _downloadProgress.value = p;
          onProgress?.call(p);
        },
      );

      if (success) {
        _isDownloading.value = false;
        _isReady.value = true;
        _downloadProgress.value = 1.0;
        logger.info('BloomUpdates: Patch "${manifest.id}" successfully staged and ready for reload.');
        return true;
      } else {
        throw StateError('Patch download verification failed.');
      }
    } catch (e, st) {
      logger.error('BloomUpdates: Download failed: $e', e, st);
      _error.value = e;
      _isDownloading.value = false;
      _isReady.value = false;
      return false;
    }
  }

  /// Triggers runtime reload/hot-restart to apply staged patch.
  static Future<void> reload() async {
    if (_pendingStagedManifest != null) {
      _currentPatch.value = _pendingStagedManifest;
      _pendingStagedManifest = null;
    }
    _isReady.value = false;
    _isAvailable.value = false;
    await _adapter.triggerAppReload();
  }

  /// Rolls back to the embedded base release binary and purges faulty patches.
  static Future<void> rollback({String? reason}) async {
    logger.warn('BloomUpdates: Rolling back to base binary release. Reason: ${reason ?? "User / Watchdog request"}');
    _currentPatch.value = null;
    _pendingStagedManifest = null;
    _isReady.value = false;
    _isAvailable.value = false;
    _isDownloading.value = false;
    await _adapter.purgeActivePatch();
  }

  /// Resets internal static state (useful in unit testing).
  static void reset() {
    _isChecking.value = false;
    _isAvailable.value = false;
    _isDownloading.value = false;
    _isReady.value = false;
    _downloadProgress.value = 0.0;
    _error.value = null;
    _currentPatch.value = null;
    _pendingStagedManifest = null;
    _activeChannel = 'production';
    _activeBranch = 'main';
    _deviceId = 'device_anon';
    _localRuntimeFingerprint = '';
    _adapter = MockBloomUpdateClientAdapter();
  }
}
