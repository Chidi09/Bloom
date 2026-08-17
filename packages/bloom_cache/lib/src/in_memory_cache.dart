// lib/src/in_memory_cache.dart
import 'dart:collection';
import 'dart:convert';
import 'cache.dart';

/// Entry wrapper storing cached JSON payload and absolute expiration timestamp.
class _MemoryEntry {
  final String jsonPayload;
  final DateTime? expiresAt;

  const _MemoryEntry({
    required this.jsonPayload,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(expiresAt!);
  }
}

/// A fast, capacity-bounded in-memory [BloomCache] with Least-Recently-Used (LRU) eviction.
///
/// **LRU Eviction Algorithm & Data Structure**:
/// - Backed by Dart's [LinkedHashMap], which maintains a predictable insertion-ordered
///   doubly-linked hash map internally.
/// - On every cache hit via [get], the accessed entry is removed and re-inserted at the tail,
///   marking it as the Most Recently Used (MRU).
/// - When [set] is called and the cache is at or above [maxCapacity], the entry at the head
///   of the map (`_entries.keys.first`), representing the Least Recently Used (LRU) entry,
///   is evicted in O(1) time before inserting the new entry at the tail.
/// - Time-to-live (TTL) expiration is actively enforced on [get] reads, returning `null` and
///   evicting stale entries.
class InMemoryCache extends BloomCache {
  /// Maximum number of items this cache can hold before LRU eviction occurs.
  final int maxCapacity;

  /// Ordered map of cache keys to their entries (head = LRU, tail = MRU).
  final LinkedHashMap<String, _MemoryEntry> _entries = LinkedHashMap<String, _MemoryEntry>();

  /// Creates a new [InMemoryCache] instance.
  ///
  /// [maxCapacity] defaults to 10,000 entries.
  InMemoryCache({this.maxCapacity = 10000}) {
    if (maxCapacity <= 0) {
      throw ArgumentError.value(maxCapacity, 'maxCapacity', 'maxCapacity must be greater than 0');
    }
  }

  /// Current number of entries currently stored in the cache (including unpruned expired ones).
  int get size => _entries.length;

  /// Returns an unmodifiable snapshot of keys currently in the cache, ordered from LRU to MRU.
  List<String> get keys => List.unmodifiable(_entries.keys);

  @override
  Future<T?> get<T>(String key) async {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }

    // TTL Expiration Check on Read
    if (entry.isExpired) {
      _entries.remove(key);
      return null;
    }

    // Refresh LRU order: re-insert at the tail as Most Recently Used (MRU)
    _entries.remove(key);
    _entries[key] = entry;

    return decodeCacheValue<T>(entry.jsonPayload);
  }

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    final payload = jsonEncode(value);
    final expiresAt = ttl != null ? DateTime.now().toUtc().add(ttl) : null;
    final newEntry = _MemoryEntry(jsonPayload: payload, expiresAt: expiresAt);

    // If key already exists, remove it first so re-insertion places it at the MRU tail
    if (_entries.containsKey(key)) {
      _entries.remove(key);
    } else {
      // Evict Least Recently Used (LRU) item from head if over capacity
      while (_entries.length >= maxCapacity && _entries.isNotEmpty) {
        final oldestKey = _entries.keys.first;
        _entries.remove(oldestKey);
      }
    }

    _entries[key] = newEntry;
  }

  @override
  Future<void> delete(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  /// Actively scans and evicts all expired entries from memory.
  void pruneExpired() {
    final expiredKeys = <String>[];
    for (final entry in _entries.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    for (final k in expiredKeys) {
      _entries.remove(k);
    }
  }
}
