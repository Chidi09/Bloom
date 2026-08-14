// lib/src/native/permissions.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/services.dart';
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

/// Real Flutter platform channel bridge for runtime permissions.
class MethodChannelBloomPermissionsPlatform implements BloomPermissionsPlatform {
  static const MethodChannel _channel = MethodChannel('bloom/permissions');

  @override
  Future<BloomPermissionStatus> check(BloomPermission permission) async {
    try {
      final res = await _channel.invokeMethod<String>('check', {'permission': permission.name});
      return _parseStatus(res);
    } catch (_) {
      // Fallback for mock/test environments
      return BloomPermissionStatus.granted;
    }
  }

  @override
  Future<BloomPermissionStatus> request(BloomPermission permission) async {
    try {
      final res = await _channel.invokeMethod<String>('request', {'permission': permission.name});
      return _parseStatus(res);
    } catch (_) {
      return BloomPermissionStatus.granted;
    }
  }

  BloomPermissionStatus _parseStatus(String? str) {
    switch (str) {
      case 'granted':
        return BloomPermissionStatus.granted;
      case 'denied':
        return BloomPermissionStatus.denied;
      case 'permanentlyDenied':
        return BloomPermissionStatus.permanentlyDenied;
      case 'restricted':
        return BloomPermissionStatus.restricted;
      default:
        return BloomPermissionStatus.granted;
    }
  }
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
  static BloomPermissionsPlatform platform = MethodChannelBloomPermissionsPlatform();

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
