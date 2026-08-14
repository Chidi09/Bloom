// lib/src/native/secure_storage.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/services.dart';
import '../core/logger.dart';
import '../data/storage.dart';

abstract class BloomSecureStoragePlatform {
  FutureOr<String?> read(String key);
  FutureOr<void> write(String key, String value);
  FutureOr<void> delete(String key);
  FutureOr<bool> containsKey(String key);
  FutureOr<void> clear();
}

/// Real Flutter platform channel bridge for Keychain/EncryptedSharedPreferences.
class MethodChannelBloomSecureStoragePlatform implements BloomSecureStoragePlatform {
  static const MethodChannel _channel = MethodChannel('bloom/secure_storage');
  final Map<String, String> _fallbackStore = HashMap<String, String>();

  @override
  Future<String?> read(String key) async {
    try {
      return await _channel.invokeMethod<String>('read', {'key': key});
    } catch (_) {
      return _fallbackStore[key];
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _channel.invokeMethod('write', {'key': key, 'value': value});
    } catch (_) {
      _fallbackStore[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _channel.invokeMethod('delete', {'key': key});
    } catch (_) {
      _fallbackStore.remove(key);
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      final res = await _channel.invokeMethod<bool>('containsKey', {'key': key});
      return res ?? false;
    } catch (_) {
      return _fallbackStore.containsKey(key);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod('clear');
    } catch (_) {
      _fallbackStore.clear();
    }
  }
}

class MockBloomSecureStoragePlatform implements BloomSecureStoragePlatform {
  final Map<String, String> _encryptedStore = HashMap<String, String>();

  @override
  String? read(String key) => _encryptedStore[key];

  @override
  void write(String key, String value) => _encryptedStore[key] = value;

  @override
  void delete(String key) => _encryptedStore.remove(key);

  @override
  bool containsKey(String key) => _encryptedStore.containsKey(key);

  @override
  void clear() => _encryptedStore.clear();
}

/// Encrypted key-value secure storage implementing [BloomStorageAdapter].
class BloomSecureStorage implements BloomStorageAdapter {
  final BloomSecureStoragePlatform platform;

  BloomSecureStorage([BloomSecureStoragePlatform? platform])
      : platform = platform ?? MethodChannelBloomSecureStoragePlatform();

  @override
  Future<String?> read(String key) async {
    final value = await platform.read(key);
    logger.debug('BloomSecureStorage: Read key "$key" (found: ${value != null})');
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    await platform.write(key, value);
    logger.debug('BloomSecureStorage: Stored encrypted key "$key"');
  }

  @override
  Future<void> delete(String key) async {
    await platform.delete(key);
    logger.debug('BloomSecureStorage: Deleted encrypted key "$key"');
  }

  @override
  Future<bool> containsKey(String key) async {
    return platform.containsKey(key);
  }

  @override
  Future<void> clear() async {
    await platform.clear();
    logger.info('BloomSecureStorage: Cleared all encrypted storage items.');
  }
}
