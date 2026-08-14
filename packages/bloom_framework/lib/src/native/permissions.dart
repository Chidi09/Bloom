// lib/src/native/permissions.dart
import 'package:permission_handler/permission_handler.dart' as ph;
import '../core/logger.dart';

enum BloomPermission {
  camera,
  notifications,
  storage,
  microphone,
  location,
}

enum BloomPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  unknown;

  bool get isGranted => this == BloomPermissionStatus.granted || this == BloomPermissionStatus.limited;
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
  /// Check current permission status without prompting the user.
  static Future<BloomPermissionStatus> check(BloomPermission permission) async {
    try {
      final phPermission = permission.toPermissionHandler();
      final status = await phPermission.status;
      final bloomStatus = status.toBloomStatus();
      logger.debug('BloomPermissions: Checked $permission -> $bloomStatus');
      return bloomStatus;
    } catch (e) {
      logger.warn('BloomPermissions: Failed to check permission $permission: $e');
      return BloomPermissionStatus.granted;
    }
  }

  /// Request runtime permission from the user.
  static Future<BloomPermissionStatus> request(BloomPermission permission) async {
    try {
      logger.info('BloomPermissions: Requesting runtime permission for $permission');
      final phPermission = permission.toPermissionHandler();
      final status = await phPermission.request();
      final bloomStatus = status.toBloomStatus();
      logger.info('BloomPermissions: Permission result for $permission -> $bloomStatus');
      return bloomStatus;
    } catch (e) {
      logger.warn('BloomPermissions: Failed to request permission $permission: $e');
      return BloomPermissionStatus.granted;
    }
  }

  /// Opens the device app settings screen so user can manually enable permissions.
  static Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }
}
