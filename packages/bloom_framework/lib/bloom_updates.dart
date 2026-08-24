/// Comprehensive in-app update and OTA management subsystem for Bloom applications.
///
/// Exports update manifests, staged rollout resolvers, crash watchdog self-healing,
/// runtime binary fingerprinting, HTTP update adapters, and update UI dialogs.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_updates.dart';
///
/// void main() async {
///   final updates = BloomUpdates();
///   final hasUpdate = await updates.checkForUpdate();
/// }
/// ```
library bloom_updates;

export 'src/updates/bloom_updates.dart';
export 'src/updates/crash_watchdog.dart';
export 'src/updates/http_update_adapter.dart';
export 'src/updates/runtime_fingerprint.dart';
export 'src/updates/staged_rollout.dart';
export 'src/updates/update_manifest.dart';
export 'src/updates/update_widgets.dart';
