import 'dart:async';
import '../core/logger.dart';
import '../data/repository.dart';
import '../state/signals.dart';

/// Serverpod streaming connection status.
enum BloomServerpodConnectionStatus {
  /// Not connected to Serverpod streaming endpoint.
  disconnected,
  /// Connection attempt in progress.
  connecting,
  /// Active connection established.
  connected,
}

/// A reactive signal bound to a real-time stream subscription with explicit lifecycle disposal.
class BloomStreamSignal<T> {
  /// The underlying reactive [Signal].
  final Signal<T> signal;

  /// Active stream subscription feeding data into [signal].
  final StreamSubscription<T> subscription;

  /// Creates a [BloomStreamSignal] wrapping [signal] and [subscription].
  BloomStreamSignal({
    required this.signal,
    required this.subscription,
  });

  /// Current value held by the underlying signal.
  T get value => signal.value;
  set value(T val) => signal.value = val;

  /// Returns a read-only view of the underlying signal.
  ReadonlySignal<T> readonly() => signal.readonly();

  /// Cancel stream subscription and release resources.
  Future<void> dispose() async {
    await subscription.cancel();
  }
}

/// Official Bloom client adapter for Serverpod backend connections.
class BloomServerpodClient {
  /// Base URL of the Serverpod backend.
  final String serverUrl;

  /// Default HTTP headers attached to requests.
  final Map<String, String> defaultHeaders;
  String? _authKey;

  BloomServerpodConnectionStatus _status =
      BloomServerpodConnectionStatus.disconnected;

  /// Creates a [BloomServerpodClient] instance.
  BloomServerpodClient({
    required this.serverUrl,
    this.defaultHeaders = const {},
    String? initialAuthKey,
  }) : _authKey = initialAuthKey;

  /// Connection status.
  BloomServerpodConnectionStatus get status => _status;

  /// Update connection status.
  void setStatus(BloomServerpodConnectionStatus newStatus) {
    _status = newStatus;
  }

  /// Active authentication key.
  String? get authKey => _authKey;

  /// Update authentication key.
  void setAuthKey(String? key) {
    _authKey = key;
    logger.debug('BloomServerpodClient: Updated authentication key.');
  }

  /// Creates a reactive [BloomStreamSignal<T>] whose value updates automatically from a Serverpod streaming subscription.
  BloomStreamSignal<T> signalFromStream<T>({
    required Stream<T> stream,
    required T initialValue,
  }) {
    final sig = signal<T>(initialValue);
    final sub = stream.listen(
      (data) => sig.value = data,
      onError: (err) => logger.error('BloomServerpodClient: Stream error: $err'),
    );
    return BloomStreamSignal<T>(signal: sig, subscription: sub);
  }
}

/// CRUD repository adapter bridging Serverpod endpoint delegates to Bloom Data conventions.
class BloomServerpodRepository<T> implements BloomCrudRepository<T, int> {
  /// Endpoint delegate fetching all records.
  final Future<List<T>> Function() getAllDelegate;

  /// Endpoint delegate fetching a record by numeric ID.
  final Future<T?> Function(int id) getByIdDelegate;

  /// Endpoint delegate creating a new record.
  final Future<T> Function(T item) insertDelegate;

  /// Endpoint delegate updating an existing record.
  final Future<T> Function(int id, T item) updateDelegate;

  /// Endpoint delegate deleting a record by numeric ID.
  final Future<bool> Function(int id) deleteDelegate;

  /// Creates a [BloomServerpodRepository] wrapping Serverpod endpoint delegates.
  const BloomServerpodRepository({
    required this.getAllDelegate,
    required this.getByIdDelegate,
    required this.insertDelegate,
    required this.updateDelegate,
    required this.deleteDelegate,
  });

  @override
  Future<List<T>> findAll() => getAllDelegate();

  @override
  Future<T?> findById(int id) => getByIdDelegate(id);

  @override
  Future<T> create(T item) => insertDelegate(item);

  @override
  Future<T> update(int id, T item) => updateDelegate(id, item);

  @override
  Future<bool> delete(int id) => deleteDelegate(id);
}
