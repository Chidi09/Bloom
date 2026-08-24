/// Staged percentage rollout evaluator for OTA patch deployments.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Evaluates deterministic staged percentage rollouts for OTA updates.
///
/// Uses cryptographic hashing of device ID and update ID to consistently place
/// a device in a partition [0..99] without central coordination.
///
/// Example:
/// ```dart
/// final isEligible = StagedRolloutEvaluator.isEligible(
///   deviceId: 'device_xyz',
///   updateId: 'patch_12',
///   rolloutPercentage: 25,
/// );
/// ```
class StagedRolloutEvaluator {
  /// Computes a deterministic integer bucket [0..99] for a given [deviceId] and [updateId].
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

