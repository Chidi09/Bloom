// lib/src/updates/runtime_fingerprint.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cryptographic Runtime Fingerprint generator and validator.
///
/// Ensures Over-The-Air (OTA) patches are only applied to native binaries
/// with identical Dart SDK, Flutter engine, and native module capabilities.
class BloomRuntimeFingerprint {
  final String bloomVersion;
  final String flutterEngineRevision;
  final String dartSdkVersion;
  final Map<String, String> nativeModuleFingerprints;
  final List<String> permissions;

  const BloomRuntimeFingerprint({
    required this.bloomVersion,
    required this.flutterEngineRevision,
    required this.dartSdkVersion,
    this.nativeModuleFingerprints = const {},
    this.permissions = const [],
  });

  /// Computes the deterministic SHA-256 runtime fingerprint hash string.
  String computeHash() {
    final buffer = StringBuffer();
    buffer.writeln('bloom_version:$bloomVersion');
    buffer.writeln('flutter_engine:$flutterEngineRevision');
    buffer.writeln('dart_sdk:$dartSdkVersion');

    // Sort native modules deterministically
    final sortedModules = nativeModuleFingerprints.keys.toList()..sort();
    for (final mod in sortedModules) {
      buffer.writeln('module:$mod:${nativeModuleFingerprints[mod]}');
    }

    // Sort permissions deterministically
    final sortedPerms = List<String>.from(permissions)..sort();
    for (final p in sortedPerms) {
      buffer.writeln('permission:$p');
    }

    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  /// Validates whether a remote patch runtime fingerprint matches the local binary.
  bool isCompatibleWith(String patchRuntimeFingerprint) {
    return computeHash().toLowerCase() == patchRuntimeFingerprint.trim().toLowerCase();
  }

  /// Creates a fingerprint from raw manifest/lockfile JSON or Map data.
  factory BloomRuntimeFingerprint.fromMap(Map<String, dynamic> map) {
    final modules = <String, String>{};
    final rawModules = map['native_modules'] ?? map['nativeModuleFingerprints'];
    if (rawModules is Map) {
      rawModules.forEach((k, v) {
        if (v is Map && v['fingerprint'] != null) {
          modules[k.toString()] = v['fingerprint'].toString();
        } else if (v is String) {
          modules[k.toString()] = v;
        }
      });
    }

    final perms = <String>[];
    final rawPerms = map['permissions'];
    if (rawPerms is List) {
      for (final p in rawPerms) {
        perms.add(p.toString());
      }
    }

    return BloomRuntimeFingerprint(
      bloomVersion: map['bloom_version']?.toString() ?? '1.0.0',
      flutterEngineRevision: map['flutter_engine']?.toString() ?? 'unknown',
      dartSdkVersion: map['dart_sdk']?.toString() ?? 'unknown',
      nativeModuleFingerprints: modules,
      permissions: perms,
    );
  }
}
