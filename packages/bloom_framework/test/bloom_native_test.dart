import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TestCameraPlatform implements BloomCameraPlatform {
  bool initialized = false;

  @override
  bool initialize() {
    initialized = true;
    return true;
  }

  @override
  BloomCapturedPhoto takePicture() {
    return const BloomCapturedPhoto(
      path: '/data/user/0/com.example/app_flutter/test.jpg',
      width: 1920,
      height: 1080,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Bloom.reset();
  });

  group('Phase 3: BloomSecureStorage', () {
    test('instantiates with custom Android & iOS options', () {
      final storage = BloomSecureStorage(
        androidOptions: const AndroidOptions(encryptedSharedPreferences: true),
        iosOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
      expect(storage, isNotNull);
    });
  });

  group('Phase 3: BloomNotifications', () {
    test('defines channels with importance levels', () {
      const channel = BloomNotificationChannel(
        id: 'alerts',
        name: 'Urgent Alerts',
        description: 'Critical system alerts',
        importance: NotificationImportance.max,
      );

      expect(channel.id, 'alerts');
      expect(channel.importance, NotificationImportance.max);

      final androidChannel = channel.toAndroidChannel();
      expect(androidChannel.id, 'alerts');
      expect(androidChannel.name, 'Urgent Alerts');
      expect(androidChannel.importance, Importance.max);
    });

    test('instantiates notifications plugin wrapper', () {
      final notifications = BloomNotifications();
      expect(notifications, isNotNull);
    });
  });

  group('Phase 3: BloomCamera', () {
    test('initializes and captures photo via camera platform', () async {
      final testPlatform = TestCameraPlatform();
      final camera = BloomCamera(testPlatform);

      final ok = await camera.initialize();
      expect(ok, true);

      final photo = await camera.takePicture();
      expect(photo, isNotNull);
      expect(photo!.path, '/data/user/0/com.example/app_flutter/test.jpg');
      expect(photo.width, 1920);
      expect(photo.height, 1080);
    });
  });

  group('Phase 3: BloomPermissions', () {
    test('enumerates core mobile permissions', () {
      expect(BloomPermission.values.contains(BloomPermission.camera), true);
      expect(BloomPermission.values.contains(BloomPermission.notifications), true);
      expect(BloomPermission.values.contains(BloomPermission.storage), true);
      expect(BloomPermission.values.contains(BloomPermission.microphone), true);
      expect(BloomPermission.values.contains(BloomPermission.location), true);
    });
  });
}
