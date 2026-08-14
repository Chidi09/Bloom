// lib/src/native/permissions.dart
import 'dart:async';
import 'dart:collection';
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
  unknown;

  bool get isGranted => this == BloomPermissionStatus.granted;
  bool get isDenied => this == BloomPermissionStatus.denied || this == BloomPermissionStatus.permanentlyDenied;
}

/// Abstract contract for runtime permissions handling.
abstract class BloomPermissionsPlatform {
  FutureOr<BloomPermissionStatus> check(BloomPermission permission);
  FutureOr<BloomPermissionStatus> request(BloomPermission permission);
}

/// In-memory permissions platform (used for testing, mock scopes, and headless environments).
class MockBloomPermissionsPlatform implements BloomPermissionsPlatform {
  final Map<BloomPermission, BloomPermissionStatus> _statuses =
      HashMap<BloomPermission, BloomPermissionStatus>();

  void setStatus(BloomPermission permission, BloomPermissionStatus status) {
    _statuses[permission] = status;
  }

  @override
  BloomPermissionStatus check(BloomPermission permission) {
    return _statuses[permission] ?? BloomPermissionStatus.granted;
  }

  @override
  BloomPermissionStatus request(BloomPermission permission) {
    final current = _statuses[permission] ?? BloomPermissionStatus.granted;
    return current;
  }
}

/// Central permissions manager for Bloom applications.
class BloomPermissions {
  static BloomPermissionsPlatform platform = MockBloomPermissionsPlatform();

  /// Check current permission status without prompting the user.
  static Future<BloomPermissionStatus> check(BloomPermission permission) async {
    final status = await platform.check(permission);
    logger.debug('BloomPermissions: Checked $permission -> $status');
    return status;
  }

  /// Request permission from the user if not already granted.
  static Future<BloomPermissionStatus> request(BloomPermission permission) async {
    logger.info('BloomPermissions: Requesting runtime permission for $permission');
    final status = await platform.request(permission);
    logger.info('BloomPermissions: Permission result for $permission -> $status');
    return status;
  }
}
