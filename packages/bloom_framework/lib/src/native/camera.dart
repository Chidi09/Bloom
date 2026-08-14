// lib/src/native/camera.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/logger.dart';
import 'permissions.dart';

class BloomCapturedPhoto {
  final String path;
  final Uint8List? bytes;
  final int? width;
  final int? height;
  final String mimeType;

  const BloomCapturedPhoto({
    required this.path,
    this.bytes,
    this.width,
    this.height,
    this.mimeType = 'image/jpeg',
  });
}

/// Camera capture and media interface for Bloom applications wrapping `image_picker`.
class BloomCamera {
  final ImagePicker _picker;
  bool _isInitialized = false;

  BloomCamera([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  /// Initialize and verify camera hardware access permissions.
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

  /// Capture a real photo using native OS camera interface.
  /// Returns `null` if the user cancels or if permission is not granted.
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

  /// Select a photo from the device photo library.
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
