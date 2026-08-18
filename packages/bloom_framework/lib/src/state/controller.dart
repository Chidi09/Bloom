// lib/src/state/controller.dart
import 'package:flutter/foundation.dart';
import '../core/logger.dart';
import 'signals.dart';

/// Base class for Bloom state controllers.
/// Manages reactive state lifecycle, automated effect disposal, and DI integration.
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
  @mustCallSuper
  void onInit() {
    logger.debug('$runtimeType initialized');
  }

  /// Register an effect that will automatically be disposed when this controller is disposed.
  void addEffect(void Function() effectCb, {String? debugLabel}) {
    if (_isDisposed) return;
    final dispose = effect(effectCb, debugLabel: debugLabel ?? '$runtimeType.effect');
    _disposers.add(dispose);
  }

  /// Register a custom cleanup action to run on disposal.
  void autoDispose(void Function() cleanup) {
    if (_isDisposed) return;
    _disposers.add(cleanup);
  }

  /// Disposes all registered effects, listeners, and resources.
  @mustCallSuper
  void onDispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final dispose in _disposers) {
      try {
        dispose();
      } catch (e, st) {
        logger.error('Error during $runtimeType cleanup: $e', e, st);
      }
    }
    _disposers.clear();
    logger.debug('$runtimeType disposed');
  }
}
