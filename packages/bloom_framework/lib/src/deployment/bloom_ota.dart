// lib/src/deployment/bloom_ota.dart
import 'dart:async';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../core/logger.dart';

/// Status events emitted during OTA code patch life-cycle.
enum BloomOtaStatus {
  idle,
  checkingForUpdate,
  updateAvailable,
  upToDate,
  downloading,
  updateReady,
  error,
}

/// Represents an available OTA patch descriptor.
class BloomOtaPatch {
  final int patchNumber;
  final String channel;
  final DateTime releasedAt;
  final String? releaseNotes;

  const BloomOtaPatch({
    required this.patchNumber,
    required this.channel,
    required this.releasedAt,
    this.releaseNotes,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'patchNumber': patchNumber,
      'channel': channel,
      'releasedAt': releasedAt.toIso8601String(),
    };
    if (releaseNotes != null) {
      map['releaseNotes'] = releaseNotes;
    }
    return map;
  }
}

/// Over-The-Air (OTA) update and code-push controller powered by Shorebird.
class BloomOTA {
  static final ShorebirdUpdater _updater = ShorebirdUpdater();
  static final StreamController<BloomOtaStatus> _statusController =
      StreamController<BloomOtaStatus>.broadcast();

  static BloomOtaStatus _currentStatus = BloomOtaStatus.idle;
  static int? _currentPatchNumber;
  static String _activeChannel = 'production';
  static BloomOtaPatch? _availablePatch;

  /// Stream of OTA status updates.
  static Stream<BloomOtaStatus> get onStatusChanged => _statusController.stream;

  /// Current OTA status.
  static BloomOtaStatus get currentStatus => _currentStatus;

  /// Currently active Shorebird patch number (null if running vanilla release).
  static int? get currentPatchNumber => _currentPatchNumber;

  /// Active Shorebird patch identifier string (e.g. "patch_1", or null if base release).
  static String? get activePatchId =>
      _currentPatchNumber != null ? 'patch_$_currentPatchNumber' : null;

  /// Whether the app is currently running on the Shorebird engine with OTA support.
  static bool get isAvailable => _updater.isAvailable;

  /// Active OTA deployment channel.
  static String get activeChannel => _activeChannel;

  /// The latest available patch (if downloaded or available).
  static BloomOtaPatch? get availablePatch => _availablePatch;

  /// Initialize OTA runtime with active deployment channel and read installed patch.
  static Future<void> initialize({
    String channel = 'production',
    int? currentPatch,
  }) async {
    _activeChannel = channel;
    if (currentPatch != null) {
      _currentPatchNumber = currentPatch;
    } else if (_updater.isAvailable) {
      try {
        final patch = await _updater.readCurrentPatch();
        _currentPatchNumber = patch?.number;
      } catch (e) {
        logger.debug('BloomOTA: Could not read installed patch number: $e');
      }
    }

    logger.info('BloomOTA: Initialized on channel "$_activeChannel" (Current patch: ${_currentPatchNumber ?? "base"}) [Shorebird Engine: ${_updater.isAvailable}]');
  }

  /// Sets status internally and notifies listeners.
  static void _setStatus(BloomOtaStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
    logger.debug('BloomOTA: Status -> ${status.name}');
  }

  /// Check if a newer OTA code-push patch is available on the active channel.
  static Future<bool> checkForUpdate({
    Future<BloomOtaPatch?> Function()? customChecker,
  }) async {
    _setStatus(BloomOtaStatus.checkingForUpdate);

    try {
      if (customChecker != null) {
        final patch = await customChecker();
        if (patch != null && (_currentPatchNumber == null || patch.patchNumber > _currentPatchNumber!)) {
          _availablePatch = patch;
          _setStatus(BloomOtaStatus.updateAvailable);
          return true;
        }
        _setStatus(BloomOtaStatus.upToDate);
        return false;
      }

      if (_updater.isAvailable) {
        final status = await _updater.checkForUpdate();
        if (status == UpdateStatus.outdated) {
          _setStatus(BloomOtaStatus.updateAvailable);
          return true;
        } else if (status == UpdateStatus.restartRequired) {
          _setStatus(BloomOtaStatus.updateReady);
          return true;
        } else {
          _setStatus(BloomOtaStatus.upToDate);
          return false;
        }
      }

      // If running in development without Shorebird engine
      _setStatus(BloomOtaStatus.upToDate);
      return false;
    } catch (e) {
      logger.error('BloomOTA check failed: $e');
      _setStatus(BloomOtaStatus.error);
      return false;
    }
  }

  /// Trigger patch download and staging using the Shorebird engine.
  static Future<bool> downloadUpdate({
    Future<bool> Function()? customDownloader,
  }) async {
    _setStatus(BloomOtaStatus.downloading);

    try {
      if (customDownloader != null) {
        final success = await customDownloader();
        if (success) {
          _setStatus(BloomOtaStatus.updateReady);
          return true;
        }
        _setStatus(BloomOtaStatus.error);
        return false;
      }

      if (_updater.isAvailable) {
        await _updater.update();
        _setStatus(BloomOtaStatus.updateReady);
        return true;
      }

      logger.warn('BloomOTA: Cannot download update because app is not running on Shorebird engine.');
      _setStatus(BloomOtaStatus.error);
      return false;
    } catch (e) {
      logger.error('BloomOTA download failed: $e');
      _setStatus(BloomOtaStatus.error);
      return false;
    }
  }

  /// Reset internal state (useful in testing).
  static void reset() {
    _currentStatus = BloomOtaStatus.idle;
    _currentPatchNumber = null;
    _activeChannel = 'production';
    _availablePatch = null;
  }
}
