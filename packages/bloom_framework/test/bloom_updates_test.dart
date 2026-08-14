// test/bloom_updates_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom_updates.dart';

void main() {
  setUp(() {
    BloomUpdates.reset();
  });

  group('Phase 11: Cryptographic Runtime Fingerprinting', () {
    test('Computes deterministic SHA-256 fingerprint hash', () {
      const fp1 = BloomRuntimeFingerprint(
        bloomVersion: '1.0.0',
        flutterEngineRevision: '3.27.0-abc',
        dartSdkVersion: '3.6.0',
        nativeModuleFingerprints: {
          'camera': 'hash_cam_123',
          'secure_storage': 'hash_sec_456',
        },
        permissions: ['CAMERA', 'STORAGE'],
      );

      const fp2 = BloomRuntimeFingerprint(
        bloomVersion: '1.0.0',
        flutterEngineRevision: '3.27.0-abc',
        dartSdkVersion: '3.6.0',
        nativeModuleFingerprints: {
          'secure_storage': 'hash_sec_456',
          'camera': 'hash_cam_123',
        },
        permissions: ['STORAGE', 'CAMERA'],
      );

      // Deterministic sorted output ensures hashes match regardless of map/list insertion order
      expect(fp1.computeHash(), fp2.computeHash());
      expect(fp1.isCompatibleWith(fp2.computeHash()), isTrue);
      expect(fp1.isCompatibleWith('incompatible_hash_xyz'), isFalse);
    });
  });

  group('Phase 11: Staged Percentage Rollouts', () {
    test('Deterministically buckets devices between 0 and 99', () {
      final bucket1 = StagedRolloutEvaluator.getDeviceBucket('device_alpha', 'upd_100');
      final bucket2 = StagedRolloutEvaluator.getDeviceBucket('device_alpha', 'upd_100');
      final bucket3 = StagedRolloutEvaluator.getDeviceBucket('device_beta', 'upd_100');

      expect(bucket1, bucket2);
      expect(bucket1 >= 0 && bucket1 < 100, isTrue);
      expect(bucket3 >= 0 && bucket3 < 100, isTrue);

      expect(StagedRolloutEvaluator.isEligible(
        deviceId: 'device_alpha',
        updateId: 'upd_100',
        rolloutPercentage: 100,
      ), isTrue);

      expect(StagedRolloutEvaluator.isEligible(
        deviceId: 'device_alpha',
        updateId: 'upd_100',
        rolloutPercentage: 0,
      ), isFalse);
    });
  });

  group('Phase 11: Startup Crash Watchdog & Self-Healing Rollback', () {
    test('Healthy startup stabilizes after duration and clears crash count', () async {
      final storage = InMemoryWatchdogStorage();
      final watchdog = StartupCrashWatchdog(
        storage: storage,
        maxCrashThreshold: 2,
        healthyThresholdDuration: const Duration(milliseconds: 50),
      );

      storage.setConsecutiveCrashes('upd_patch_1', 1);
      watchdog.recordAppLaunch('upd_patch_1');

      await Future.delayed(const Duration(milliseconds: 70));
      expect(watchdog.isHealthy, isTrue);
      expect(storage.getConsecutiveCrashes('upd_patch_1'), 0);
      watchdog.dispose();
    });

    test('Consecutive startup crashes trigger self-healing rollback to base binary', () {
      final storage = InMemoryWatchdogStorage();
      String? rolledBackPatch;
      String? rollbackReason;

      final watchdog = StartupCrashWatchdog(
        storage: storage,
        maxCrashThreshold: 2,
        onRollbackTriggered: (patchId, reason) {
          rolledBackPatch = patchId;
          rollbackReason = reason;
        },
      );

      // First crash
      watchdog.recordAppLaunch('bad_patch_99');
      watchdog.recordStartupCrash();
      expect(storage.getConsecutiveCrashes('bad_patch_99'), 1);
      expect(rolledBackPatch, isNull);

      // Second crash (reaches threshold of 2)
      watchdog.recordStartupCrash();
      expect(rolledBackPatch, 'bad_patch_99');
      expect(rollbackReason, contains('Exceeded 2 consecutive crashes'));
      watchdog.dispose();
    });
  });

  group('Phase 11: BloomUpdates Client API & Reactive Signals', () {
    test('Rejects updates with incompatible native runtime fingerprints', () async {
      final mockAdapter = MockBloomUpdateClientAdapter(
        mockAvailableManifest: const UpdateManifest(
          id: 'upd_camera_v2',
          version: '2.0.0',
          runtimeFingerprint: 'incompatible_native_hash_999',
        ),
      );

      await BloomUpdates.initialize(
        channel: 'production',
        runtimeFingerprint: 'local_hash_111',
        adapter: mockAdapter,
      );

      final result = await BloomUpdates.checkForUpdate();
      expect(result.isAvailable, isFalse);
      expect(result.isCompatible, isFalse);
      expect(result.rejectionReason, contains('Incompatible native runtime fingerprint'));
      expect(BloomUpdates.isAvailable.value, isFalse);
    });

    test('Rejects devices excluded from staged percentage rollout', () async {
      // Find a device ID that falls in bucket >= 10
      String excludedDeviceId = 'dev_excluded';
      while (StagedRolloutEvaluator.getDeviceBucket(excludedDeviceId, 'upd_staged') < 10) {
        excludedDeviceId += '_';
      }

      final mockAdapter = MockBloomUpdateClientAdapter(
        mockAvailableManifest: const UpdateManifest(
          id: 'upd_staged',
          version: '1.5.0',
          runtimeFingerprint: 'matching_hash_123',
          rolloutPercentage: 10,
        ),
      );

      await BloomUpdates.initialize(
        channel: 'production',
        deviceId: excludedDeviceId,
        runtimeFingerprint: 'matching_hash_123',
        adapter: mockAdapter,
      );

      final result = await BloomUpdates.checkForUpdate();
      expect(result.isAvailable, isFalse);
      expect(result.rejectionReason, contains('excluded by staged rollout window'));
      expect(BloomUpdates.isAvailable.value, isFalse);
    });

    test('Downloads update with fine-grained reactive progress, stages, and reloads', () async {
      final mockAdapter = MockBloomUpdateClientAdapter(
        mockAvailableManifest: const UpdateManifest(
          id: 'upd_valid_patch',
          version: '1.2.0',
          runtimeFingerprint: 'matching_hash_123',
          rolloutPercentage: 100,
          releaseNotes: 'Fixed camera focus latency',
        ),
      );

      await BloomUpdates.initialize(
        channel: 'production',
        runtimeFingerprint: 'matching_hash_123',
        adapter: mockAdapter,
      );

      // 1. Check
      final check = await BloomUpdates.checkForUpdate();
      expect(check.isAvailable, isTrue);
      expect(BloomUpdates.isAvailable.value, isTrue);

      // 2. Fetch
      final progressValues = <double>[];
      final fetched = await BloomUpdates.fetchUpdate(
        onProgress: (p) => progressValues.add(p),
      );

      expect(fetched, isTrue);
      expect(BloomUpdates.isReady.value, isTrue);
      expect(BloomUpdates.downloadProgress.value, 1.0);
      expect(progressValues.isNotEmpty, isTrue);

      // 3. Reload
      await BloomUpdates.reload();
      expect(mockAdapter.reloadTriggered, isTrue);
      expect(BloomUpdates.currentPatch.value?.id, 'upd_valid_patch');
    });

    test('Rollback purges patch and resets state', () async {
      final mockAdapter = MockBloomUpdateClientAdapter();
      await BloomUpdates.initialize(adapter: mockAdapter);

      await BloomUpdates.rollback(reason: 'Test rollback');
      expect(mockAdapter.purgeTriggered, isTrue);
      expect(BloomUpdates.currentPatch.value, isNull);
    });
  });

  group('Phase 11: In-App Update UI Widgets', () {
    testWidgets('BloomUpdateBanner reacts to downloading and ready signals', (tester) async {
      final mockAdapter = MockBloomUpdateClientAdapter(
        mockAvailableManifest: const UpdateManifest(
          id: 'upd_ui_test',
          version: '2.1.0',
          runtimeFingerprint: 'matching_hash_123',
        ),
      );

      await BloomUpdates.initialize(
        runtimeFingerprint: 'matching_hash_123',
        adapter: mockAdapter,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BloomUpdateBanner(),
          ),
        ),
      );

      // Initially empty
      expect(find.text('RESTART NOW'), findsNothing);

      // Check & Fetch
      await BloomUpdates.checkForUpdate();
      await BloomUpdates.fetchUpdate();
      await tester.pump();

      // Ready banner visible
      expect(find.text('RESTART NOW'), findsOneWidget);
      expect(find.text('A new update is ready! Restart to apply changes.'), findsOneWidget);

      // Tap restart
      await tester.tap(find.text('RESTART NOW'));
      await tester.pump();
      expect(mockAdapter.reloadTriggered, isTrue);
    });

    testWidgets('BloomUpdateDialog displays release notes and download button', (tester) async {
      final mockAdapter = MockBloomUpdateClientAdapter(
        mockAvailableManifest: const UpdateManifest(
          id: 'upd_dialog_test',
          version: '3.0.0',
          runtimeFingerprint: 'matching_hash_123',
          releaseNotes: 'Brand new dark mode theme',
        ),
      );

      await BloomUpdates.initialize(
        runtimeFingerprint: 'matching_hash_123',
        adapter: mockAdapter,
      );

      await BloomUpdates.checkForUpdate();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BloomUpdateDialog(
              releaseNotes: 'Brand new dark mode theme',
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('Brand new dark mode theme'), findsOneWidget);
      expect(find.text('DOWNLOAD'), findsOneWidget);

      await tester.tap(find.text('DOWNLOAD'));
      await tester.pump();

      expect(find.text('RESTART NOW'), findsOneWidget);
    });
  });
}
