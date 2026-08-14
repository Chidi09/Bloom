# 22. Storage Adapters & TTL Persistence

Bloom provides a unified key-value storage abstraction (`BloomStorageAdapter`) with multiple pluggable storage engines.

---

## 🔌 The `BloomStorageAdapter` Interface

```dart
abstract class BloomStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}
```

---

## 💾 Available Storage Engines

### 1. `BloomSecureStorage`
Utilizes hardware-backed encryption (iOS Keychain / Android EncryptedSharedPreferences):
```dart
final secureStorage = BloomSecureStorage();
await secureStorage.write('api_token', 'secret_jwt_value');
final token = await secureStorage.read('api_token');
```

### 2. `InMemoryStorageAdapter`
High-speed in-memory key-value store ideal for unit and widget testing:
```dart
final testStorage = InMemoryStorageAdapter();
```

### 3. `BloomJsonStorage` with TTL Expiration
A JSON-serializing storage wrapper that supports automatic entry expiration based on Time-To-Live (TTL):

```dart
final jsonStorage = BloomJsonStorage(adapter: secureStorage);

// Write value with a 30-minute expiration
await jsonStorage.writeJson(
  'user_session',
  {'userId': 'user_123', 'name': 'Alice'},
  ttl: const Duration(minutes: 30),
);

// Returns null automatically if the TTL duration has elapsed!
final session = await jsonStorage.readJson('user_session');
```
