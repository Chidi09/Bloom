// lib/src/deployment/bloom_ota.dart
import 'dart:async';
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

  Map<String, dynamic> toJson() => {
    'patchNumber': patchNumber,
    'channel': channel,
    'releasedAt': releasedAt.toIso8601String(),
    'releaseNotes': releaseNotes,
  };
}

/// Over-The-Air (OTA) update and code-push controller powered by Shorebird.
class BloomOTA {
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

  /// Active OTA deployment channel.
  static String get activeChannel => _activeChannel;

  /// The latest available patch (if downloaded or available).
  static BloomOtaPatch? get availablePatch => _availablePatch;

  /// Initialize OTA runtime with active deployment channel.
  static Future<void> initialize({
    String channel = 'production',
    int? currentPatch,
  }) async {
    _activeChannel = channel;
    _currentPatchNumber = currentPatch;
    logger.info('BloomOTA: Initialized on channel "$_activeChannel" (Current patch: ${_currentPatchNumber ?? "base"})');
  }

  /// Sets status internally and notifies listeners.
  static void _setStatus(BloomOtaStatus status) {
    _currentStatus = status;
    _statusController.add(status);
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
      }

      _setStatus(BloomOtaStatus.upToDate);
      return false;
    } catch (e) {
      logger.error('BloomOTA check failed: $e');
      _setStatus(BloomOtaStatus.error);
      return false;
    }
  }

  /// Simulate or trigger patch download and staging.
  static Future<bool> downloadUpdate({
    Future<bool> Function()? customDownloader,
  }) async {
    if (_availablePatch == null && customDownloader == null) {
      return false;
    }

    _setStatus(BloomOtaStatus.downloading);

    try {
      if (customDownloader != null) {
        final success = await customDownloader();
        if (success) {
          _setStatus(BloomOtaStatus.updateReady);
          return true;
        }
      } else {
        _setStatus(BloomOtaStatus.updateReady);
        return true;
      }

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
