// lib/src/data/storage.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

/// Storage adapter contract for key-value persistence.
abstract class BloomStorageAdapter {
  FutureOr<String?> read(String key);
  FutureOr<void> write(String key, String value);
  FutureOr<void> delete(String key);
  FutureOr<bool> containsKey(String key);
  FutureOr<void> clear();
}

/// In-memory storage adapter (default when no native key-value storage plugin is registered).
class InMemoryStorageAdapter implements BloomStorageAdapter {
  final Map<String, String> _store = HashMap<String, String>();

  @override
  String? read(String key) => _store[key];

  @override
  void write(String key, String value) => _store[key] = value;

  @override
  void delete(String key) => _store.remove(key);

  @override
  bool containsKey(String key) => _store.containsKey(key);

  @override
  void clear() => _store.clear();
}

/// Strongly-typed JSON storage wrapper with TTL expiration and serialization helpers.
class BloomJsonStorage {
  final BloomStorageAdapter adapter;

  BloomJsonStorage([BloomStorageAdapter? adapter])
      : adapter = adapter ?? InMemoryStorageAdapter();

  /// Read and decode a JSON object. Returns null if missing or expired.
  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = await adapter.read(key);
    if (raw == null) return null;

    try {
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      if (doc.containsKey('_expiresAt')) {
        final expiresAt = DateTime.parse(doc['_expiresAt'] as String);
        if (DateTime.now().isAfter(expiresAt)) {
          await adapter.delete(key);
          return null;
        }
        final cleanDoc = Map<String, dynamic>.from(doc)..remove('_expiresAt');
        return cleanDoc;
      }
      return doc;
    } catch (_) {
      return null;
    }
  }

  /// Write a JSON object with optional TTL [expiresIn].
  Future<void> writeJson(
    String key,
    Map<String, dynamic> data, {
    Duration? expiresIn,
  }) async {
    final payload = Map<String, dynamic>.from(data);
    if (expiresIn != null) {
      payload['_expiresAt'] = DateTime.now().add(expiresIn).toIso8601String();
    }
    await adapter.write(key, jsonEncode(payload));
  }

  /// Delete a key.
  Future<void> delete(String key) async => adapter.delete(key);

  /// Clear all stored keys.
  Future<void> clear() async => adapter.clear();
}
