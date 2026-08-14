// test/bloom_native_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  setUp(() {
    Bloom.reset();
  });

  group('Phase 3: BloomPermissions', () {
    test('checks and requests permissions via platform', () async {
      final mockPlatform = MockBloomPermissionsPlatform();
      BloomPermissions.platform = mockPlatform;

      mockPlatform.setStatus(BloomPermission.camera, BloomPermissionStatus.denied);
      var status = await BloomPermissions.check(BloomPermission.camera);
      expect(status, BloomPermissionStatus.denied);
      expect(status.isGranted, false);

      mockPlatform.setStatus(BloomPermission.camera, BloomPermissionStatus.granted);
      status = await BloomPermissions.request(BloomPermission.camera);
      expect(status, BloomPermissionStatus.granted);
      expect(status.isGranted, true);
    });
  });

  group('Phase 3: BloomSecureStorage', () {
    test('performs encrypted key-value operations', () async {
      final storage = BloomSecureStorage();

      expect(await storage.containsKey('secret_key'), false);
      expect(await storage.read('secret_key'), null);

      await storage.write('secret_key', 'super_secure_value');
      expect(await storage.containsKey('secret_key'), true);
      expect(await storage.read('secret_key'), 'super_secure_value');

      await storage.delete('secret_key');
      expect(await storage.containsKey('secret_key'), false);
      expect(await storage.read('secret_key'), null);

      await storage.write('key1', 'val1');
      await storage.write('key2', 'val2');
      await storage.clear();
      expect(await storage.containsKey('key1'), false);
      expect(await storage.containsKey('key2'), false);
    });
  });

  group('Phase 3: BloomNotifications', () {
    test('initializes channels and manages notification lifecycle', () async {
      final mockPlatform = MockBloomNotificationsPlatform();
      final notifications = BloomNotifications(mockPlatform);

      const channel = BloomNotificationChannel(
        id: 'alerts',
        name: 'Urgent Alerts',
        importance: NotificationImportance.max,
      );

      await notifications.initialize(channels: [channel]);
      expect(mockPlatform.registeredChannels.length, 1);
      expect(mockPlatform.registeredChannels.first.id, 'alerts');

      final id = await notifications.show(
        title: 'Order Confirmed',
        body: 'Your package is on the way!',
        channelId: 'alerts',
      );

      expect(id, 1);
      expect(mockPlatform.postedNotifications.length, 1);
      expect(mockPlatform.postedNotifications.first.title, 'Order Confirmed');

      await notifications.cancel(id);
      expect(mockPlatform.postedNotifications.isEmpty, true);

      await notifications.show(title: 'Note 1', body: 'Body 1');
      await notifications.show(title: 'Note 2', body: 'Body 2');
      expect(mockPlatform.postedNotifications.length, 2);

      await notifications.cancelAll();
      expect(mockPlatform.postedNotifications.isEmpty, true);
    });
  });

  group('Phase 3: BloomCamera', () {
    test('initializes and captures photo', () async {
      final mockPlatform = MockBloomCameraPlatform();
      final camera = BloomCamera(mockPlatform);

      final ok = await camera.initialize();
      expect(ok, true);

      final photo = await camera.takePicture();
      expect(photo, isNotNull);
      expect(photo!.path.contains('.jpg'), true);
      expect(photo.width, 1920);
      expect(photo.height, 1080);
    });
  });
}
