// lib/src/native/secure_storage.dart
import 'dart:async';
import 'dart:collection';
import '../core/logger.dart';
import '../data/storage.dart';

abstract class BloomSecureStoragePlatform {
  FutureOr<String?> read(String key);
  FutureOr<void> write(String key, String value);
  FutureOr<void> delete(String key);
  FutureOr<bool> containsKey(String key);
  FutureOr<void> clear();
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
      : platform = platform ?? MockBloomSecureStoragePlatform();

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
