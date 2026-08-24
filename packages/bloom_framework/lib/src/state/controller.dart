// lib/src/state/controller.dart
import 'package:flutter/foundation.dart';
import '../core/logger.dart';
import 'signals.dart';

/// Base class for Bloom state controllers.
///
/// Manages reactive state lifecycle, automated effect disposal, and DI integration.
/// Subclasses can define signals, register side-effects with [addEffect], and perform
/// cleanup in [onDispose].
///
/// Example:
/// ```dart
/// class CounterController extends BloomController {
///   final count = signal(0);
///
///   @override
///   void onInit() {
///     super.onInit();
///     addEffect(() => print('Counter: ${count.value}'));
///   }
///
///   void increment() => count.value++;
/// }
/// ```
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
  ///
  /// Override this method to perform initialization logic and register reactive effects.
  @mustCallSuper
  void onInit() {
    logger.debug('$runtimeType initialized');
  }

  /// Registers an [effectCb] that will automatically be disposed when this controller is disposed.
  ///
  /// Parameters:
  /// - [effectCb]: The reactive callback to execute whenever its read signals change.
  /// - [debugLabel]: Optional debugging label for DevTools inspection.
  void addEffect(void Function() effectCb, {String? debugLabel}) {
    if (_isDisposed) return;
    final dispose = effect(effectCb, debugLabel: debugLabel ?? '$runtimeType.effect');
    _disposers.add(dispose);
  }

  /// Registers a custom [cleanup] callback to run when this controller is disposed.
  ///
  /// Useful for closing streams, timers, or unregistering platform listeners.
  void autoDispose(void Function() cleanup) {
    if (_isDisposed) return;
    _disposers.add(cleanup);
  }

  /// Disposes all registered effects, listeners, and resources.
  ///
  /// Called when the controller is removed from the DI container or widget lifecycle.
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
