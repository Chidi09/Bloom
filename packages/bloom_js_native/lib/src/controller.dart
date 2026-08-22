// lib/src/controller.dart
import 'package:signals/signals.dart';

/// Base class for Bloom state controllers.
/// Manages reactive state lifecycle, automated effect disposal, and DI integration.
/// Pure-Dart, zero Flutter SDK dependency.
abstract class BloomController {
  final List<void Function()> _disposers = [];
  bool _isDisposed = false;

  /// Whether this controller has been disposed.
  bool get isDisposed => _isDisposed;

  /// Creates a [BloomController] and immediately invokes [onInit].
  BloomController() {
    onInit();
  }

  /// Called immediately when the controller is constructed.
  void onInit() {}

  /// Register an effect that will automatically be disposed when this controller is disposed.
  void addEffect(void Function() effectCb, {String? debugLabel}) {
    if (_isDisposed) return;
    final dispose =
        effect(effectCb, debugLabel: debugLabel ?? '$runtimeType.effect');
    _disposers.add(dispose);
  }

  /// Register a custom cleanup action to run on disposal.
  void autoDispose(void Function() cleanup) {
    if (_isDisposed) return;
    _disposers.add(cleanup);
  }

  /// Disposes all registered effects, listeners, and resources.
  void onDispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final dispose in _disposers) {
      try {
        dispose();
      } catch (_) {
        // Best-effort cleanup: swallow errors during disposal
      }
    }
    _disposers.clear();
  }
}
