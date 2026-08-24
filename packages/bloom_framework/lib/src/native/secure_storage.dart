// lib/src/native/secure_storage.dart
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/logger.dart';
import '../data/storage.dart';

/// Encrypted key-value secure storage wrapping `flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPreferences).
///
/// Implements [BloomStorageAdapter] for seamless integration with [BloomAuth] session storage,
/// token caching, and encrypted offline queues.
///
/// Example:
/// ```dart
/// final secureStorage = BloomSecureStorage();
/// await secureStorage.write('access_token', 'jwt_secret_token');
/// final token = await secureStorage.read('access_token');
/// ```
class BloomSecureStorage implements BloomStorageAdapter {
  final FlutterSecureStorage _storage;

  /// Creates a [BloomSecureStorage] adapter with platform encryption options.
  ///
  /// Defaults to `encryptedSharedPreferences: true` on Android and
  /// `KeychainAccessibility.first_unlock` on iOS.
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

  /// Reads an encrypted string value associated with [key], or returns `null` if absent.
  ///
  /// Example:
  /// ```dart
  /// final secret = await secureStorage.read('api_key');
  /// ```
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

  /// Writes an encrypted [value] string associated with [key].
  ///
  /// Example:
  /// ```dart
  /// await secureStorage.write('refresh_token', 'token_value');
  /// ```
  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      logger.debug('BloomSecureStorage: Stored encrypted key "$key"');
    } catch (e) {
      logger.error('BloomSecureStorage: Error writing key "$key": $e');
    }
  }

  /// Deletes the encrypted entry associated with [key].
  ///
  /// Example:
  /// ```dart
  /// await secureStorage.delete('access_token');
  /// ```
  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
      logger.debug('BloomSecureStorage: Deleted encrypted key "$key"');
    } catch (e) {
      logger.error('BloomSecureStorage: Error deleting key "$key": $e');
    }
  }

  /// Checks whether an encrypted entry for [key] exists in storage.
  ///
  /// Example:
  /// ```dart
  /// final hasToken = await secureStorage.containsKey('access_token');
  /// ```
  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      return false;
    }
  }

  /// Clears all encrypted key-value entries in secure storage.
  ///
  /// Example:
  /// ```dart
  /// await secureStorage.clear();
  /// ```
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
