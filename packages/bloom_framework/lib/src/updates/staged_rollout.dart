// lib/src/updates/staged_rollout.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Evaluates deterministic staged percentage rollouts for OTA updates.
class StagedRolloutEvaluator {
  /// Computes a deterministic integer bucket [0..99] for a given device and update ID.
  static int getDeviceBucket(String deviceId, String updateId) {
    final seed = utf8.encode('$deviceId:$updateId');
    final digest = sha256.convert(seed);
    final byteData = ByteData.sublistView(Uint8List.fromList(digest.bytes.sublist(0, 8)));
    final value = byteData.getUint64(0);
    return (value % 100).toInt();
  }

  /// Determines whether a device falls within the staged percentage rollout window [1..100].
  static bool isEligible({
    required String deviceId,
    required String updateId,
    required int rolloutPercentage,
  }) {
    if (rolloutPercentage >= 100) return true;
    if (rolloutPercentage <= 0) return false;

    final bucket = getDeviceBucket(deviceId, updateId);
    return bucket < rolloutPercentage;
  }
}
