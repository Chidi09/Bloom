// lib/src/native/camera.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/logger.dart';
import 'permissions.dart';

/// Represents an image file captured from the device camera or picked from the gallery.
///
/// Encapsulates the absolute filesystem [path], optional raw image [bytes],
/// dimensions ([width], [height]), and MIME type.
///
/// Example:
/// ```dart
/// final photo = await camera.takePicture();
/// if (photo != null) {
///   print('Captured photo path: ${photo.path}, bytes: ${photo.bytes?.length}');
/// }
/// ```
class BloomCapturedPhoto {
  /// File system path to the saved image file on device.
  final String path;

  /// Raw image byte data in memory, if read.
  final Uint8List? bytes;

  /// Image pixel width if available.
  final int? width;

  /// Image pixel height if available.
  final int? height;

  /// MIME type string (defaults to `'image/jpeg'`).
  final String mimeType;

  /// Creates a [BloomCapturedPhoto] result instance.
  const BloomCapturedPhoto({
    required this.path,
    this.bytes,
    this.width,
    this.height,
    this.mimeType = 'image/jpeg',
  });
}

/// Camera capture and photo gallery interface for Bloom applications wrapping `image_picker`.
///
/// Automatically handles native camera permissions verification via [BloomPermissions]
/// before launching native capture interfaces.
///
/// Example:
/// ```dart
/// final camera = BloomCamera();
/// final authorized = await camera.initialize();
/// if (authorized) {
///   final photo = await camera.takePicture(
///     preferredCamera: CameraDevice.rear,
///     imageQuality: 85,
///   );
/// }
/// ```
class BloomCamera {
  final ImagePicker _picker;
  bool _isInitialized = false;

  /// Creates a [BloomCamera] interface with an optional custom [picker] instance for testing.
  BloomCamera([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  /// Initializes and verifies camera hardware access permissions.
  ///
  /// Requests [BloomPermission.camera] if not already granted. Returns `true` if authorized.
  ///
  /// Example:
  /// ```dart
  /// final ok = await camera.initialize();
  /// ```
  Future<bool> initialize() async {
    try {
      final status = await BloomPermissions.request(BloomPermission.camera);
      _isInitialized = status.isGranted;
      if (!_isInitialized) {
        logger.warn('BloomCamera: Camera permission denied by user.');
      } else {
        logger.info('BloomCamera: Camera hardware access authorized.');
      }
      return _isInitialized;
    } catch (e) {
      logger.error('BloomCamera: Failed to initialize camera hardware: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Captures a photo using the native OS camera interface.
  ///
  /// Requests camera permission if necessary. Returns `null` if the user cancels or permission is denied.
  ///
  /// Example:
  /// ```dart
  /// final photo = await camera.takePicture(
  ///   preferredCamera: CameraDevice.front,
  ///   maxWidth: 1024,
  ///   imageQuality: 90,
  /// );
  /// ```
  Future<BloomCapturedPhoto?> takePicture({
    CameraDevice preferredCamera = CameraDevice.rear,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final status = await BloomPermissions.request(BloomPermission.camera);
    if (!status.isGranted) {
      logger.warn('BloomCamera: Camera permission denied. Cannot take picture.');
      return null;
    }

    try {
      logger.info('BloomCamera: Launching native camera capture...');
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: preferredCamera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (file == null) {
        logger.info('BloomCamera: Capture cancelled by user.');
        return null;
      }

      final bytes = await file.readAsBytes();
      logger.info('BloomCamera: Captured photo saved to: ${file.path} (${bytes.length} bytes)');

      return BloomCapturedPhoto(
        path: file.path,
        bytes: bytes,
        mimeType: file.mimeType ?? 'image/jpeg',
      );
    } catch (e, st) {
      logger.error('BloomCamera: Camera capture failed: $e', e, st);
      return null;
    }
  }

  /// Selects a photo from the device photo gallery.
  ///
  /// Returns a [BloomCapturedPhoto] or `null` if cancelled.
  ///
  /// Example:
  /// ```dart
  /// final photo = await camera.pickFromGallery(imageQuality: 80);
  /// ```
  Future<BloomCapturedPhoto?> pickFromGallery({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (file == null) return null;
      final bytes = await file.readAsBytes();

      return BloomCapturedPhoto(
        path: file.path,
        bytes: bytes,
        mimeType: file.mimeType ?? 'image/jpeg',
      );
    } catch (e, st) {
      logger.error('BloomCamera: Gallery picker failed: $e', e, st);
      return null;
    }
  }
}
