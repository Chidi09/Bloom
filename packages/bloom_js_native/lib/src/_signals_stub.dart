/// Stub implementation of hot-reload signal preservation on Dart VM / SSR.
library;

/// Mirrors the browser cap (`kMaxSignalRegistryEntries` in
/// `_signals_browser.dart`); unused on the VM, where the registry is always
/// `null`.
const int kMaxSignalRegistryEntries = 512;

bool isBrowserHotReloadActive() => false;

Map<String, Object?>? getBrowserSignalRegistry() => null;

void storeBrowserSignalValue(
  Map<String, Object?> registry,
  String key,
  Object? value,
) {
  // Never reached on the VM: getBrowserSignalRegistry() returns null.
}
