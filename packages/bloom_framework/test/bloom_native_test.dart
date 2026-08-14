import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    test('instantiates camera capture wrapper', () {
      final camera = BloomCamera();
      expect(camera, isNotNull);
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
