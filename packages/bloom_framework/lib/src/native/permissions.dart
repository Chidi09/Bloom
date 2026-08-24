// lib/src/native/permissions.dart
import 'package:permission_handler/permission_handler.dart' as ph;
import '../core/logger.dart';

/// Native hardware and system permission types supported by Bloom applications.
///
/// Example:
/// ```dart
/// final status = await BloomPermissions.check(BloomPermission.camera);
/// ```
enum BloomPermission {
  /// Camera hardware capture permission.
  camera,

  /// Push and local notifications alert permission.
  notifications,

  /// Device filesystem and photo gallery storage permission.
  storage,

  /// Audio microphone recording permission.
  microphone,

  /// Device GPS and fine/coarse location access permission.
  location,
}

/// Permission authorization status returned by host platforms.
///
/// Example:
/// ```dart
/// final status = await BloomPermissions.request(BloomPermission.location);
/// if (status.isGranted) {
///   // Access GPS coordinates
/// }
/// ```
enum BloomPermissionStatus {
  /// Permission has been explicitly granted by the user.
  granted,

  /// Permission was denied by the user.
  denied,

  /// Permission was permanently denied (user must manually enable in OS settings).
  permanentlyDenied,

  /// Permission is restricted by OS policies (e.g. parental controls or enterprise MDM).
  restricted,

  /// Limited access granted (e.g. iOS limited photo library selection).
  limited,

  /// Permission status is unknown or uninitialized.
  unknown;

  /// Whether the permission status allows resource access (either [granted] or [limited]).
  bool get isGranted => this == BloomPermissionStatus.granted || this == BloomPermissionStatus.limited;

  /// Whether the permission is in a denied state ([denied] or [permanentlyDenied]).
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
///
/// Supports runtime permission checks, interactive authorization prompts, OS settings navigation,
/// and test mock simulations without platform channel invocations.
///
/// Example:
/// ```dart
/// final status = await BloomPermissions.request(BloomPermission.camera);
/// if (status.isDenied) {
///   await BloomPermissions.openAppSettings();
/// }
/// ```
class BloomPermissions {
  static final Map<BloomPermission, BloomPermissionStatus> _simulatedPermissions = {};

  /// Simulates a permission status response without invoking host platform channels.
  ///
  /// Useful in automated tests to simulate granted, denied, or restricted permission states.
  ///
  /// Example:
  /// ```dart
  /// BloomPermissions.simulate(
  ///   permission: BloomPermission.camera,
  ///   status: BloomPermissionStatus.granted,
  /// );
  /// ```
  static void simulate({
    required BloomPermission permission,
    required BloomPermissionStatus status,
  }) {
    _simulatedPermissions[permission] = status;
    logger.debug('BloomPermissions: Simulated $permission -> $status');
  }

  /// Clears all simulated permission overrides and restores platform channel dispatching.
  ///
  /// Example:
  /// ```dart
  /// BloomPermissions.resetSimulation();
  /// ```
  static void resetSimulation() {
    _simulatedPermissions.clear();
  }

  /// Checks current permission status without prompting the user.
  ///
  /// Example:
  /// ```dart
  /// final status = await BloomPermissions.check(BloomPermission.location);
  /// ```
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

  /// Requests runtime permission authorization from the user.
  ///
  /// Displays the host OS permission dialog if not previously determined.
  ///
  /// Example:
  /// ```dart
  /// final status = await BloomPermissions.request(BloomPermission.camera);
  /// ```
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

  /// Opens the device application settings screen so the user can manually enable permissions.
  ///
  /// Returns `true` if the settings screen could be opened.
  ///
  /// Example:
  /// ```dart
  /// await BloomPermissions.openAppSettings();
  /// ```
  static Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }
}
