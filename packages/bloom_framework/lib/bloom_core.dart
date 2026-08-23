// lib/bloom_core.dart
//
// Flutter-independent core primitives (env config, DI container, logger).
// These are defined once in `package:bloom_server` and re-exported here, so
// a Flutter app and a pure-Dart backend share one definition rather than two
// copies that drift.
//
// Never import `bloom.dart` from a server entrypoint — that barrel pulls in
// `package:flutter` (and transitively `dart:ui`), which cannot be resolved
// under a plain `dart run` / `dart compile` process.
library bloom_core;

export 'package:bloom_server/src/core/env.dart';
export 'package:bloom_server/src/core/logger.dart';
export 'package:bloom_server/src/di/container.dart';
export 'package:bloom_server/src/di/scope.dart';
