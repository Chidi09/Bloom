// lib/src/lifecycle/lifecycle.dart
import 'package:flutter/widgets.dart';
import '../core/logger.dart';

/// Mixin for classes that wish to observe application lifecycle events.
mixin BloomLifecycleObserver {
  /// Called when application transitions to foreground resumed state.
  void onAppResumed() {}

  /// Called when application enters an inactive state (e.g. phone call received).
  void onAppInactive() {}

  /// Called when application is backgrounded and paused.
  void onAppPaused() {}

  /// Called when application engine is detached from host.
  void onAppDetached() {}

  /// Called when all application views are hidden.
  void onAppHidden() {}
}

/// Central manager coordinating application-wide lifecycle events.
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
