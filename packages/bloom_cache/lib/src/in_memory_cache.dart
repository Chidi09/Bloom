// lib/src/in_memory_cache.dart
import 'dart:collection';
import 'dart:convert';
import 'cache.dart';

/// Entry wrapper storing cached JSON payload, absolute expiration timestamp, and associated tags.
class _MemoryEntry {
  final String jsonPayload;
  final DateTime? expiresAt;
  final Set<String> tags;

  const _MemoryEntry({
    required this.jsonPayload,
    this.expiresAt,
    this.tags = const <String>{},
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
/// - Tag-to-keys reverse index enables O(1) tag-based invalidation.
class InMemoryCache extends BloomCache {
  /// Maximum number of items this cache can hold before LRU eviction occurs.
  final int maxCapacity;

  /// Ordered map of cache keys to their entries (head = LRU, tail = MRU).
  final LinkedHashMap<String, _MemoryEntry> _entries = LinkedHashMap<String, _MemoryEntry>();

  /// Reverse index mapping tags to the set of keys that carry them.
  final Map<String, Set<String>> _tagIndex = <String, Set<String>>{};

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
      _removeEntry(key);
      return null;
    }

    // Refresh LRU order: re-insert at the tail as Most Recently Used (MRU)
    _entries.remove(key);
    _entries[key] = entry;

    return decodeCacheValue<T>(entry.jsonPayload);
  }

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl, List<String>? tags}) async {
    final payload = jsonEncode(value);
    final expiresAt = ttl != null ? DateTime.now().toUtc().add(ttl) : null;
    final tagSet = tags != null ? Set<String>.from(tags) : <String>{};
    final newEntry = _MemoryEntry(jsonPayload: payload, expiresAt: expiresAt, tags: tagSet);

    // If key already exists, remove its old tag associations first
    if (_entries.containsKey(key)) {
      _removeTagAssociations(key, _entries[key]!.tags);
      _entries.remove(key);
    } else {
      // Evict Least Recently Used (LRU) item from head if over capacity
      while (_entries.length >= maxCapacity && _entries.isNotEmpty) {
        final oldestKey = _entries.keys.first;
        _removeEntry(oldestKey);
      }
    }

    _entries[key] = newEntry;
    _addTagAssociations(key, tagSet);
  }

  @override
  Future<void> delete(String key) async {
    _removeEntry(key);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _tagIndex.clear();
  }

  @override
  Future<void> invalidateTag(String tag) async {
    await invalidateTags([tag]);
  }

  @override
  Future<void> invalidateTags(List<String> tags) async {
    final keysToRemove = <String>{};
    for (final tag in tags) {
      final keys = _tagIndex[tag];
      if (keys != null) {
        keysToRemove.addAll(keys);
      }
    }
    for (final key in keysToRemove) {
      _removeEntry(key);
    }
  }

  /// Removes an entry and its tag associations.
  void _removeEntry(String key) {
    final entry = _entries.remove(key);
    if (entry != null) {
      _removeTagAssociations(key, entry.tags);
    }
  }

  /// Adds tag associations for a key.
  void _addTagAssociations(String key, Set<String> tags) {
    for (final tag in tags) {
      _tagIndex.putIfAbsent(tag, () => <String>{}).add(key);
    }
  }

  /// Removes tag associations for a key.
  void _removeTagAssociations(String key, Set<String> tags) {
    for (final tag in tags) {
      final keys = _tagIndex[tag];
      if (keys != null) {
        keys.remove(key);
        if (keys.isEmpty) {
          _tagIndex.remove(tag);
        }
      }
    }
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
      _removeEntry(k);
    }
  }
}
