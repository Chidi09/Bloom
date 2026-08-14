// lib/src/native/camera.dart
import 'dart:async';
import 'dart:typed_data';
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

abstract class BloomCameraPlatform {
  FutureOr<bool> initialize();
  FutureOr<BloomCapturedPhoto> takePicture();
}

class MockBloomCameraPlatform implements BloomCameraPlatform {
  bool isInitialized = false;

  @override
  bool initialize() {
    isInitialized = true;
    return true;
  }

  @override
  BloomCapturedPhoto takePicture() {
    return BloomCapturedPhoto(
      path: '/tmp/bloom_camera_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]), // Sample JPEG header
      width: 1920,
      height: 1080,
    );
  }
}

/// Camera capture and media interface for Bloom applications.
class BloomCamera {
  final BloomCameraPlatform platform;
  bool _initialized = false;

  BloomCamera([BloomCameraPlatform? platform])
      : platform = platform ?? MockBloomCameraPlatform();

  /// Initialize the camera hardware preview and sensors.
  Future<bool> initialize() async {
    final status = await BloomPermissions.request(BloomPermission.camera);
    if (!status.isGranted) {
      logger.warn('BloomCamera: Camera permission denied.');
      return false;
    }
    _initialized = await platform.initialize();
    logger.info('BloomCamera: Initialized camera hardware.');
    return _initialized;
  }

  /// Capture a still photo.
  Future<BloomCapturedPhoto?> takePicture() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return null;
    }
    logger.info('BloomCamera: Taking picture...');
    final photo = await platform.takePicture();
    logger.info('BloomCamera: Captured photo saved to: ${photo.path}');
    return photo;
  }
}
