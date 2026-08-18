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

/// Generic CRUD repository interface for typed entities.
abstract class BloomCrudRepository<T, ID> {
  /// Retrieves all records of entity type [T].
  Future<List<T>> findAll();

  /// Retrieves a single record of entity type [T] matching [id], or null if not found.
  Future<T?> findById(ID id);

  /// Creates and stores a new entity [item].
  Future<T> create(T item);

  /// Updates an existing entity [item] identified by [id].
  Future<T> update(ID id, T item);

  /// Deletes an entity identified by [id]. Returns true if deleted.
  Future<bool> delete(ID id);
}
