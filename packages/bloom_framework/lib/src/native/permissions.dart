// lib/src/native/permissions.dart
import 'package:permission_handler/permission_handler.dart' as ph;
import '../core/logger.dart';

/// Native hardware and system permission types supported by Bloom.
enum BloomPermission {
  /// Camera capture permission.
  camera,
  /// Push / local notifications permission.
  notifications,
  /// Device filesystem / photos storage permission.
  storage,
  /// Audio microphone recording permission.
  microphone,
  /// Device GPS / location access permission.
  location,
}

/// Permission authorization status.
enum BloomPermissionStatus {
  /// Permission has been granted by user.
  granted,
  /// Permission was denied by user.
  denied,
  /// Permission was permanently denied (must enable via OS settings).
  permanentlyDenied,
  /// Permission restricted by OS policies (parental controls, MDM).
  restricted,
  /// Limited access granted (e.g. iOS limited photo library).
  limited,
  /// Permission status is unknown or uninitialized.
  unknown;

  /// Whether permission allows access (either granted or limited).
  bool get isGranted => this == BloomPermissionStatus.granted || this == BloomPermissionStatus.limited;

  /// Whether permission is denied or permanently denied.
  bool get isDenied => this == BloomPermissionStatus.denied || this == BloomPermissionStatus.permanentlyDenied;
}

extension _BloomPermissionMapper on BloomPermission {
  ph.Permission toPermissionHandler() {
    switch (this) {
      case BloomPermission.camera:
        return ph.Permission.camera;
      case BloomPermission.notifications:
        return ph.Permission.notification;
      case BloomPermission.storage:
        return ph.Permission.storage;
      case BloomPermission.microphone:
        return ph.Permission.microphone;
      case BloomPermission.location:
        return ph.Permission.location;
    }
  }
}

extension _PermissionStatusMapper on ph.PermissionStatus {
  BloomPermissionStatus toBloomStatus() {
    switch (this) {
      case ph.PermissionStatus.granted:
        return BloomPermissionStatus.granted;
      case ph.PermissionStatus.denied:
        return BloomPermissionStatus.denied;
      case ph.PermissionStatus.permanentlyDenied:
        return BloomPermissionStatus.permanentlyDenied;
      case ph.PermissionStatus.restricted:
        return BloomPermissionStatus.restricted;
      case ph.PermissionStatus.limited:
        return BloomPermissionStatus.limited;
      case ph.PermissionStatus.provisional:
        return BloomPermissionStatus.granted;
    }
  }
}

/// Central native permissions manager for Bloom applications wrapping `permission_handler`.
class BloomPermissions {
  static final Map<BloomPermission, BloomPermissionStatus> _simulatedPermissions = {};

  /// Simulates a permission status response without invoking platform channels.
  static void simulate({
    required BloomPermission permission,
    required BloomPermissionStatus status,
  }) {
    _simulatedPermissions[permission] = status;
    logger.debug('BloomPermissions: Simulated $permission -> $status');
  }

  /// Clears all simulated permission overrides.
  static void resetSimulation() {
    _simulatedPermissions.clear();
  }

  /// Check current permission status without prompting the user.
  static Future<BloomPermissionStatus> check(BloomPermission permission) async {
    if (_simulatedPermissions.containsKey(permission)) {
      final sim = _simulatedPermissions[permission]!;
      logger.debug('BloomPermissions: [SIMULATED] Checked $permission -> $sim');
      return sim;
    }

    try {
      final phPermission = permission.toPermissionHandler();
      final status = await phPermission.status;
      final bloomStatus = status.toBloomStatus();
      logger.debug('BloomPermissions: Checked $permission -> $bloomStatus');
      return bloomStatus;
    } catch (e) {
      logger.warn('BloomPermissions: Failed to check permission $permission: $e');
      return BloomPermissionStatus.unknown;
    }
  }

  /// Request runtime permission from the user.
  static Future<BloomPermissionStatus> request(BloomPermission permission) async {
    if (_simulatedPermissions.containsKey(permission)) {
      final sim = _simulatedPermissions[permission]!;
      logger.info('BloomPermissions: [SIMULATED] Permission result for $permission -> $sim');
      return sim;
    }

    try {
      logger.info('BloomPermissions: Requesting runtime permission for $permission');
      final phPermission = permission.toPermissionHandler();
      final status = await phPermission.request();
      final bloomStatus = status.toBloomStatus();
      logger.info('BloomPermissions: Permission result for $permission -> $bloomStatus');
      return bloomStatus;
    } catch (e) {
      logger.warn('BloomPermissions: Failed to request permission $permission: $e');
      return BloomPermissionStatus.denied;
    }
  }

  /// Opens the device app settings screen so user can manually enable permissions.
  static Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }
}
