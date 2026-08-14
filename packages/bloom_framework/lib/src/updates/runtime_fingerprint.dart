// lib/src/updates/runtime_fingerprint.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/platform_info.dart';

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

  /// Derives runtime fingerprint dynamically from current environment or BloomConfig.
  factory BloomRuntimeFingerprint.current({
    String bloomVersion = '1.0.0',
    String? flutterRevision,
    Map<String, String> moduleFingerprints = const {},
    List<String> permissions = const [],
  }) {
    final dartVer = getDartSdkVersion();
    return BloomRuntimeFingerprint(
      bloomVersion: bloomVersion,
      flutterEngineRevision: flutterRevision ?? '3.27.0',
      dartSdkVersion: dartVer,
      nativeModuleFingerprints: moduleFingerprints,
      permissions: permissions,
    );
  }

  /// Creates a runtime fingerprint from a [BloomConfig] object and native module fingerprints.
  factory BloomRuntimeFingerprint.fromConfig(
    dynamic config, {
    Map<String, String> moduleFingerprints = const {},
    String? flutterRevision,
  }) {
    final dartVer = getDartSdkVersion();
    var version = '1.0.0';
    final perms = <String>[];

    if (config != null) {
      try {
        version = config.version?.toString() ?? '1.0.0';
        if (config.plugins is Map) {
          perms.addAll((config.plugins as Map).keys.map((k) => k.toString()));
        }
      } catch (_) {}
    }

    return BloomRuntimeFingerprint(
      bloomVersion: version,
      flutterEngineRevision: flutterRevision ?? '3.27.0',
      dartSdkVersion: dartVer,
      nativeModuleFingerprints: moduleFingerprints,
      permissions: perms,
    );
  }

  /// Computes the canonical deterministic SHA-256 runtime fingerprint hash string.
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
    final rawPerms = map['permissions'] ?? map['plugins'];
    if (rawPerms is List) {
      for (final p in rawPerms) {
        perms.add(p.toString());
      }
    }

    return BloomRuntimeFingerprint(
      bloomVersion: map['bloom_version']?.toString() ?? '1.0.0',
      flutterEngineRevision: map['flutter_engine']?.toString() ?? map['flutter_version']?.toString() ?? '3.27.0',
      dartSdkVersion: map['dart_sdk']?.toString() ?? map['dart_version']?.toString() ?? '3.6.0',
      nativeModuleFingerprints: modules,
      permissions: perms,
    );
  }
}
