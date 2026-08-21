// lib/src/data/repository.dart
import '../di/container.dart';
import 'http_client.dart';

/// Base repository pattern class for encapsulating API communication.
abstract class BloomRepository {
  /// The [BloomHttpClient] instance used by this repository.
  late final BloomHttpClient http;

  /// Creates a [BloomRepository] with an optional [client] or resolving one from [container].
  BloomRepository([BloomHttpClient? client, BloomContainer? container]) {
    final c = container ?? globalContainer;
    http = client ?? (c.injectOrNull<BloomHttpClient>() ?? BloomHttpClient());
  }
}

/// Lean read-only repository interface for query-only data access (Interface Segregation Principle).
abstract class BloomReadOnlyRepository<T, ID> {
  /// Retrieves all records of entity type [T].
  Future<List<T>> findAll();

  /// Retrieves a single record of entity type [T] matching [id], or null if not found.
  Future<T?> findById(ID id);
}

/// Lean write-only/mutation repository interface (Interface Segregation Principle).
abstract class BloomWriteRepository<T, ID> {
  /// Creates and stores a new entity [item].
  Future<T> create(T item);

  /// Updates an existing entity [item] identified by [id].
  Future<T> update(ID id, T item);

  /// Deletes an entity identified by [id]. Returns true if deleted.
  Future<bool> delete(ID id);
}

/// Generic CRUD repository interface for typed entities composing read and write contracts.
abstract class BloomCrudRepository<T, ID>
    implements BloomReadOnlyRepository<T, ID>, BloomWriteRepository<T, ID> {
  @override
  Future<List<T>> findAll();

  @override
  Future<T?> findById(ID id);

  @override
  Future<T> create(T item);

  @override
  Future<T> update(ID id, T item);

  @override
  Future<bool> delete(ID id);
}
