// lib/src/data/storage.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import '../core/logger.dart';

/// Abstract storage adapter contract for key-value persistence.
///
/// Defines synchronous or asynchronous primitives for reading, writing, deleting,
/// checking existence, and purging stored string keys.
///
/// Example:
/// ```dart
/// class MyDatabaseStorageAdapter implements BloomStorageAdapter { ... }
/// ```
abstract class BloomStorageAdapter {
  /// Reads raw string value associated with [key], or `null` if absent.
  FutureOr<String?> read(String key);

  /// Writes [value] string associated with [key].
  FutureOr<void> write(String key, String value);

  /// Deletes stored value associated with [key].
  FutureOr<void> delete(String key);

  /// Checks whether [key] exists in storage.
  FutureOr<bool> containsKey(String key);

  /// Clears all entries in this storage adapter.
  FutureOr<void> clear();
}

/// In-memory storage adapter for testing and rapid prototyping.
///
/// Stores all data in a transient in-memory map without filesystem or native I/O.
///
/// Example:
/// ```dart
/// final memoryStorage = InMemoryStorageAdapter();
/// await memoryStorage.write('theme', 'dark');
/// print(await memoryStorage.read('theme')); // 'dark'
/// ```
class InMemoryStorageAdapter implements BloomStorageAdapter {
  final Map<String, String> _store = HashMap<String, String>();

  /// Creates an [InMemoryStorageAdapter] instance.
  InMemoryStorageAdapter();

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
///
/// Persists individual keys as JSON files inside [baseDirectory] (defaulting to system temp directory).
///
/// Example:
/// ```dart
/// final fileStorage = FileStorageAdapter(Directory('/var/app/data'));
/// await fileStorage.write('settings', '{"autoSync": true}');
/// ```
class FileStorageAdapter implements BloomStorageAdapter {
  /// Base directory path where JSON storage files are persisted.
  final Directory baseDirectory;
  final Map<String, String> _memoryCache = HashMap<String, String>();
  bool _isLoaded = false;

  /// Creates a [FileStorageAdapter] with an optional [baseDirectory].
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

  /// Reads string value associated with [key] from disk.
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

  /// Writes [value] string associated with [key] to disk.
  @override
  Future<void> write(String key, String value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    final file = _getFile(key);
    await file.writeAsString(value, flush: true);
  }

  /// Deletes file and in-memory cache associated with [key].
  @override
  Future<void> delete(String key) async {
    await _ensureLoaded();
    _memoryCache.remove(key);
    final file = _getFile(key);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Checks whether a persisted file exists for [key].
  @override
  Future<bool> containsKey(String key) async {
    await _ensureLoaded();
    if (_memoryCache.containsKey(key)) return true;
    final file = _getFile(key);
    return file.existsSync();
  }

  /// Purges all persisted files and in-memory cache.
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
///
/// Encapsulates serialization and deserialization of typed JSON records
/// with automatic expiration pruning.
///
/// Example:
/// ```dart
/// final jsonStorage = BloomJsonStorage(FileStorageAdapter());
/// await jsonStorage.set('user_profile', {'name': 'Alice', 'role': 'admin'}, ttl: const Duration(hours: 1));
/// final profile = await jsonStorage.get<Map<String, dynamic>>('user_profile');
/// ```
class BloomJsonStorage {
  /// The underlying key-value storage adapter.
  final BloomStorageAdapter adapter;

  /// Creates a [BloomJsonStorage] instance with an optional [adapter] (defaults to [FileStorageAdapter]).
  BloomJsonStorage([BloomStorageAdapter? adapter])
      : adapter = adapter ?? FileStorageAdapter();

  /// Stores a JSON-encodable [value] with optional [ttl] or [expiresIn] duration.
  ///
  /// Example:
  /// ```dart
  /// await storage.set('cart', {'items': [1, 2, 3]}, ttl: const Duration(days: 7));
  /// ```
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

  /// Alias for [set] to store a JSON object.
  Future<void> writeJson<T>(String key, T value, {Duration? ttl, Duration? expiresIn}) =>
      set<T>(key, value, ttl: ttl, expiresIn: expiresIn);

  /// Retrieves and decodes a stored JSON object. Returns `null` if absent or expired.
  ///
  /// Example:
  /// ```dart
  /// final data = await storage.get<Map<String, dynamic>>('cart');
  /// ```
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

  /// Alias for [get] to retrieve a stored JSON object.
  Future<T?> readJson<T>(String key) => get<T>(key);

  /// Deletes a key from storage.
  ///
  /// Example:
  /// ```dart
  /// await storage.delete('cart');
  /// ```
  Future<void> delete(String key) async {
    await adapter.delete(key);
  }

  /// Checks if a key exists in storage.
  ///
  /// Example:
  /// ```dart
  /// final exists = await storage.contains('cart');
  /// ```
  Future<bool> contains(String key) async {
    final result = await adapter.containsKey(key);
    return result;
  }

  /// Clears all stored data in the underlying adapter.
  ///
  /// Example:
  /// ```dart
  /// await storage.clear();
  /// ```
  Future<void> clear() async {
    await adapter.clear();
  }
}
