// lib/src/native/secure_storage.dart
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/logger.dart';
import '../data/storage.dart';

/// Encrypted key-value secure storage wrapping `flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPreferences).
/// Implements [BloomStorageAdapter] for seamless integration with [BloomAuth] and [BloomJsonStorage].
class BloomSecureStorage implements BloomStorageAdapter {
  final FlutterSecureStorage _storage;

  BloomSecureStorage({
    FlutterSecureStorage? storage,
    AndroidOptions? androidOptions,
    IOSOptions? iosOptions,
  }) : _storage = storage ??
            FlutterSecureStorage(
              aOptions: androidOptions ??
                  const AndroidOptions(
                    encryptedSharedPreferences: true,
                  ),
              iOptions: iosOptions ??
                  const IOSOptions(
                    accessibility: KeychainAccessibility.first_unlock,
                  ),
            );

  @override
  Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      logger.debug('BloomSecureStorage: Read key "$key" (found: ${value != null})');
      return value;
    } catch (e) {
      logger.error('BloomSecureStorage: Error reading key "$key": $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      logger.debug('BloomSecureStorage: Stored encrypted key "$key"');
    } catch (e) {
      logger.error('BloomSecureStorage: Error writing key "$key": $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
      logger.debug('BloomSecureStorage: Deleted encrypted key "$key"');
    } catch (e) {
      logger.error('BloomSecureStorage: Error deleting key "$key": $e');
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.deleteAll();
      logger.info('BloomSecureStorage: Cleared all encrypted storage items.');
    } catch (e) {
      logger.error('BloomSecureStorage: Error clearing storage: $e');
    }
  }
}
