// lib/src/data/storage.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import '../core/logger.dart';

/// Abstract storage adapter contract for key-value persistence.
abstract class BloomStorageAdapter {
  FutureOr<String?> read(String key);
  FutureOr<void> write(String key, String value);
  FutureOr<void> delete(String key);
  FutureOr<bool> containsKey(String key);
  FutureOr<void> clear();
}

/// In-memory storage adapter for testing and rapid prototyping.
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

/// File-based storage adapter providing real persistence on disk across application restarts.
class FileStorageAdapter implements BloomStorageAdapter {
  final Directory baseDirectory;
  final Map<String, String> _memoryCache = HashMap<String, String>();
  bool _isLoaded = false;

  FileStorageAdapter([Directory? baseDirectory])
      : baseDirectory = baseDirectory ??
            Directory('${Directory.systemTemp.path}/bloom_storage');

  File _getFile(String key) {
    final sanitizedKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${baseDirectory.path}/$sanitizedKey.json');
  }

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    if (!baseDirectory.existsSync()) {
      baseDirectory.createSync(recursive: true);
    }
    _isLoaded = true;
  }

  @override
  Future<String?> read(String key) async {
    await _ensureLoaded();
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    final file = _getFile(key);
    if (file.existsSync()) {
      final content = await file.readAsString();
      _memoryCache[key] = content;
      return content;
    }
    return null;
  }

  @override
  Future<void> write(String key, String value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    final file = _getFile(key);
    await file.writeAsString(value, flush: true);
  }

  @override
  Future<void> delete(String key) async {
    await _ensureLoaded();
    _memoryCache.remove(key);
    final file = _getFile(key);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureLoaded();
    if (_memoryCache.containsKey(key)) return true;
    final file = _getFile(key);
    return file.existsSync();
  }

  @override
  Future<void> clear() async {
    await _ensureLoaded();
    _memoryCache.clear();
    if (baseDirectory.existsSync()) {
      baseDirectory.deleteSync(recursive: true);
      baseDirectory.createSync(recursive: true);
    }
  }
}

/// JSON object storage with optional TTL expiration.
class BloomJsonStorage {
  final BloomStorageAdapter adapter;

  BloomJsonStorage([BloomStorageAdapter? adapter])
      : adapter = adapter ?? FileStorageAdapter();

  /// Store a JSON-encodable [value] with optional [ttl] or [expiresIn].
  Future<void> set<T>(String key, T value, {Duration? ttl, Duration? expiresIn}) async {
    final effectiveTtl = ttl ?? expiresIn;
    final now = DateTime.now();
    final wrapper = {
      'data': value,
      'savedAt': now.toIso8601String(),
      'expiresAt': effectiveTtl != null ? now.add(effectiveTtl).toIso8601String() : null,
    };
    final serialized = jsonEncode(wrapper);
    await adapter.write(key, serialized);
  }

  /// Alias for set()
  Future<void> writeJson<T>(String key, T value, {Duration? ttl, Duration? expiresIn}) =>
      set<T>(key, value, ttl: ttl, expiresIn: expiresIn);

  /// Retrieve and decode a stored JSON object. Returns `null` if expired.
  Future<T?> get<T>(String key) async {
    final serialized = await adapter.read(key);
    if (serialized == null) return null;

    try {
      final decoded = jsonDecode(serialized) as Map<String, dynamic>;
      final expiresAtStr = decoded['expiresAt'] as String?;
      if (expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        if (DateTime.now().isAfter(expiresAt)) {
          logger.debug('BloomJsonStorage: Expired entry for key "$key". Removing...');
          await adapter.delete(key);
          return null;
        }
      }
      return decoded['data'] as T?;
    } catch (e) {
      logger.error('BloomJsonStorage: Failed to decode value for key "$key": $e');
      return null;
    }
  }

  /// Alias for get()
  Future<T?> readJson<T>(String key) => get<T>(key);

  /// Delete a key from storage.
  Future<void> delete(String key) async {
    await adapter.delete(key);
  }

  /// Check if a key exists in storage.
  Future<bool> contains(String key) async {
    final result = await adapter.containsKey(key);
    return result;
  }

  /// Clear all stored data.
  Future<void> clear() async {
    await adapter.clear();
  }
}
