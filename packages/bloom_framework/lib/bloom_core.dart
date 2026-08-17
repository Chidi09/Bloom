// lib/bloom_core.dart
//
// Flutter-independent core primitives (env config, DI container, logger).
// Import this from pure-Dart backends via `bloom_server.dart`, which
// re-exports it. Never import `bloom.dart` from a server entrypoint —
// that barrel pulls in `package:flutter` (and transitively `dart:ui`),
// which cannot be resolved under a plain `dart run`/`dart compile` process.
library bloom_core;

export 'src/core/env.dart';
export 'src/core/logger.dart';
export 'src/di/container.dart';
export 'src/di/scope.dart';
