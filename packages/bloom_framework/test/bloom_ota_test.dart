// test/bloom_ota_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Bloom.reset();
    BloomOTA.reset();
  });

  group('Phase 7: BloomOTA Updates & Lifecycle', () {
    test('initializes with channel and current patch number', () async {
      await BloomOTA.initialize(channel: 'staging', currentPatch: 3);

      expect(BloomOTA.activeChannel, 'staging');
      expect(BloomOTA.currentPatchNumber, 3);
      expect(BloomOTA.currentStatus, BloomOtaStatus.idle);
    });

    test('checks for update and transitions status on new patch available', () async {
      await BloomOTA.initialize(channel: 'production', currentPatch: 1);

      final statusUpdates = <BloomOtaStatus>[];
      final sub = BloomOTA.onStatusChanged.listen(statusUpdates.add);

      final hasUpdate = await BloomOTA.checkForUpdate(
        customChecker: () async => BloomOtaPatch(
          patchNumber: 2,
          channel: 'production',
          releasedAt: DateTime.now(),
          releaseNotes: 'Fixed offline caching race condition',
        ),
      );

      expect(hasUpdate, true);
      expect(BloomOTA.availablePatch?.patchNumber, 2);
      expect(BloomOTA.currentStatus, BloomOtaStatus.updateAvailable);

      // Trigger download
      final downloaded = await BloomOTA.downloadUpdate(
        customDownloader: () async => true,
      );

      expect(downloaded, true);
      expect(BloomOTA.currentStatus, BloomOtaStatus.updateReady);

      await sub.cancel();
    });

    test('reports upToDate when no newer patch exists', () async {
      await BloomOTA.initialize(channel: 'production', currentPatch: 5);

      final hasUpdate = await BloomOTA.checkForUpdate(
        customChecker: () async => BloomOtaPatch(
          patchNumber: 5,
          channel: 'production',
          releasedAt: DateTime.now(),
        ),
      );

      expect(hasUpdate, false);
      expect(BloomOTA.currentStatus, BloomOtaStatus.upToDate);
    });
  });
}
