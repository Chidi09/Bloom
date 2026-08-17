// lib/src/in_memory_backend.dart
import 'backend.dart';
import 'message.dart';

/// An in-memory email backend for testing that records sent messages.
///
/// Exposes [sentMessages] for test assertions and allows clearing state
/// between test runs via [clear].
class BloomInMemoryBackend implements BloomMailBackend {
  final List<BloomMailMessage> _messages = [];

  /// Creates a new [BloomInMemoryBackend].
  BloomInMemoryBackend();

  /// Returns an unmodifiable snapshot of all email messages sent through this backend.
  List<BloomMailMessage> get sentMessages => List.unmodifiable(_messages);

  /// Clears all captured messages.
  void clear() {
    _messages.clear();
  }

  @override
  Future<void> send(BloomMailMessage message) async {
    _messages.add(message);
  }
}

/// Alias for [BloomInMemoryBackend].
typedef InMemoryBackend = BloomInMemoryBackend;

