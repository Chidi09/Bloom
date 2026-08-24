/// Application lifecycle observation and management subsystem.
library;

import 'package:flutter/widgets.dart';
import '../core/logger.dart';

/// Mixin for classes that observe Flutter application lifecycle transitions.
///
/// Implement any of the lifecycle hooks to handle backgrounding, pausing, or resuming.
///
/// Example:
/// ```dart
/// class SyncManager with BloomLifecycleObserver {
///   @override
///   void onAppResumed() {
///     // Refresh pending data when returning to foreground
///   }
/// }
/// ```
mixin BloomLifecycleObserver {
  /// Called when the application transitions to the foreground resumed state.
  void onAppResumed() {}

  /// Called when the application enters an inactive state (e.g. phone call or system dialog).
  void onAppInactive() {}

  /// Called when the application is backgrounded and paused.
  void onAppPaused() {}

  /// Called when the application engine is detached from the host platform.
  void onAppDetached() {}

  /// Called when all application views are hidden.
  void onAppHidden() {}
}

/// Central manager coordinating application-wide lifecycle events.
///
/// Listens to Flutter's [WidgetsBindingObserver] and dispatches state transitions
/// to all registered [BloomLifecycleObserver] instances.
///
/// Example:
/// ```dart
/// BloomLifecycleManager.instance.initialize();
/// BloomLifecycleManager.instance.addObserver(myObserver);
/// ```
class BloomLifecycleManager with WidgetsBindingObserver {
  /// Global singleton instance.
  static final BloomLifecycleManager instance = BloomLifecycleManager._();
  BloomLifecycleManager._();

  final List<BloomLifecycleObserver> _observers = [];
  bool _isListening = false;

  /// Initializes lifecycle listening by attaching to Flutter's [WidgetsBinding].
  void initialize() {
    if (_isListening) return;
    WidgetsBinding.instance.addObserver(this);
    _isListening = true;
  }

  /// Registers a [BloomLifecycleObserver] to receive lifecycle events.
  void addObserver(BloomLifecycleObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  /// Unregisters a previously added [BloomLifecycleObserver].
  void removeObserver(BloomLifecycleObserver observer) {
    _observers.remove(observer);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    logger.debug('App lifecycle state changed to: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        for (final obs in List<BloomLifecycleObserver>.from(_observers)) {
          obs.onAppResumed();
        }
        break;
      case AppLifecycleState.inactive:
        for (final obs in List<BloomLifecycleObserver>.from(_observers)) {
          obs.onAppInactive();
        }
        break;
      case AppLifecycleState.paused:
        for (final obs in List<BloomLifecycleObserver>.from(_observers)) {
          obs.onAppPaused();
        }
        break;
      case AppLifecycleState.detached:
        for (final obs in List<BloomLifecycleObserver>.from(_observers)) {
          obs.onAppDetached();
        }
        break;
      case AppLifecycleState.hidden:
        for (final obs in List<BloomLifecycleObserver>.from(_observers)) {
          obs.onAppHidden();
        }
        break;
    }
  }

  /// Disposes lifecycle listening and unregisters from Flutter bindings.
  void dispose() {
    if (_isListening) {
      WidgetsBinding.instance.removeObserver(this);
      _isListening = false;
    }
    _observers.clear();
  }
}
