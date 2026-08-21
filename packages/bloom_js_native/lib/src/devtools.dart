/// Runtime diagnostics and DevTools inspection hooks for Bloom JS Native.
class BloomJsDevTools {
  BloomJsDevTools._();

  static int activeRegionCount = 0;
  static int activeSentinelCount = 0;

  static final List<void Function(String event, Map<String, dynamic> data)>
      _listeners = [];

  /// Register a diagnostics event listener. Returns an unregister callback.
  static void Function() addListener(
      void Function(String event, Map<String, dynamic> data) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Dispatches a diagnostic event to all registered listeners.
  static void notify(String event, Map<String, dynamic> data) {
    for (final listener in List.of(_listeners)) {
      try {
        listener(event, data);
      } catch (_) {}
    }
  }
}
