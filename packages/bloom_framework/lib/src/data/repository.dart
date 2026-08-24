// lib/src/data/repository.dart
import '../di/container.dart';
import 'http_client.dart';

/// Base repository pattern class for encapsulating API communication.
///
/// Automatically acquires or injects a configured [BloomHttpClient] from the dependency container.
///
/// Example:
/// ```dart
/// class UserRepository extends BloomRepository {
///   Future<List<User>> getUsers() => http.get<List<User>>('/users');
/// }
/// ```
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
///
/// Example:
/// ```dart
/// class ReadOnlyUserRepo implements BloomReadOnlyRepository<User, int> {
///   @override
///   Future<List<User>> findAll() async => ...;
///   @override
///   Future<User?> findById(int id) async => ...;
/// }
/// ```
abstract class BloomReadOnlyRepository<T, ID> {
  /// Retrieves all records of entity type [T].
  Future<List<T>> findAll();

  /// Retrieves a single record of entity type [T] matching [id], or `null` if not found.
  Future<T?> findById(ID id);
}

/// Lean write-only/mutation repository interface (Interface Segregation Principle).
///
/// Example:
/// ```dart
/// class UserWriteRepo implements BloomWriteRepository<User, int> {
///   @override
///   Future<User> create(User item) async => ...;
///   @override
///   Future<User> update(int id, User item) async => ...;
///   @override
///   Future<bool> delete(int id) async => ...;
/// }
/// ```
abstract class BloomWriteRepository<T, ID> {
  /// Creates and stores a new entity [item].
  Future<T> create(T item);

  /// Updates an existing entity [item] identified by [id].
  Future<T> update(ID id, T item);

  /// Deletes an entity identified by [id]. Returns `true` if deleted.
  Future<bool> delete(ID id);
}

/// Generic CRUD repository interface for typed entities composing read and write contracts.
///
/// Example:
/// ```dart
/// class TaskRepository extends BloomRepository
///     implements BloomCrudRepository<Task, String> {
///   @override
///   Future<List<Task>> findAll() => http.get<List<Task>>('/tasks');
///   @override
///   Future<Task?> findById(String id) => http.get<Task?>('/tasks/$id');
///   @override
///   Future<Task> create(Task item) => http.post<Task>('/tasks', body: item.toMap());
///   @override
///   Future<Task> update(String id, Task item) => http.put<Task>('/tasks/$id', body: item.toMap());
///   @override
///   Future<bool> delete(String id) async {
///     await http.delete<void>('/tasks/$id');
///     return true;
///   }
/// }
/// ```
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
