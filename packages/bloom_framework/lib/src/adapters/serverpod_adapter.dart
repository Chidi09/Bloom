import 'dart:async';
import '../core/logger.dart';
import '../data/repository.dart';
import '../state/signals.dart';

/// Serverpod streaming connection status.
enum BloomServerpodConnectionStatus {
  disconnected,
  connecting,
  connected,
}

/// Official Bloom client adapter for Serverpod backend connections.
class BloomServerpodClient {
  final String serverUrl;
  final Map<String, String> defaultHeaders;
  String? _authKey;

  BloomServerpodConnectionStatus _status =
      BloomServerpodConnectionStatus.disconnected;

  BloomServerpodClient({
    required this.serverUrl,
    this.defaultHeaders = const {},
    String? initialAuthKey,
  }) : _authKey = initialAuthKey;

  /// Connection status.
  BloomServerpodConnectionStatus get status => _status;

  /// Active authentication key.
  String? get authKey => _authKey;

  /// Update authentication key.
  void setAuthKey(String? key) {
    _authKey = key;
    logger.debug('BloomServerpodClient: Updated authentication key.');
  }

  /// Creates a reactive [Signal<T>] whose value updates automatically from a Serverpod streaming subscription.
  Signal<T> signalFromStream<T>({
    required Stream<T> stream,
    required T initialValue,
  }) {
    final sig = signal<T>(initialValue);
    stream.listen(
      (data) => sig.value = data,
      onError: (err) => logger.error('BloomServerpodClient: Stream error: $err'),
    );
    return sig;
  }
}

/// CRUD repository adapter bridging Serverpod endpoint delegates to Bloom Data conventions.
class BloomServerpodRepository<T> implements BloomCrudRepository<T, int> {
  final Future<List<T>> Function() getAllDelegate;
  final Future<T?> Function(int id) getByIdDelegate;
  final Future<T> Function(T item) insertDelegate;
  final Future<T> Function(T item) updateDelegate;
  final Future<bool> Function(int id) deleteDelegate;

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
  Future<T> update(int id, T item) => updateDelegate(item);

  @override
  Future<bool> delete(int id) => deleteDelegate(id);
}
