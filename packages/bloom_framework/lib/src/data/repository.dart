// lib/src/data/repository.dart
import '../di/container.dart';
import 'http_client.dart';

/// Base repository pattern class for encapsulating API communication.
abstract class BloomRepository {
  late final BloomHttpClient http;

  BloomRepository([BloomHttpClient? client, BloomContainer? container]) {
    final c = container ?? globalContainer;
    http = client ?? (c.injectOrNull<BloomHttpClient>() ?? BloomHttpClient());
  }
}

/// Generic CRUD repository interface for typed entities.
abstract class BloomCrudRepository<T, ID> {
  Future<List<T>> findAll();
  Future<T?> findById(ID id);
  Future<T> create(T item);
  Future<T> update(ID id, T item);
  Future<bool> delete(ID id);
}
