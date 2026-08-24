/// Flutter-independent core primitives for Bloom (environment config, DI container, structured logger).
///
/// These primitives are defined in `package:bloom_server` and re-exported here so both
/// Flutter applications and pure-Dart backend microservices share identical definitions
/// without code drift or dependencies on `dart:ui`.
///
/// Never import `bloom.dart` from a server entrypoint — that barrel pulls in `package:flutter`.
/// Use [bloom_core] or `bloom_server.dart` instead.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_core.dart';
///
/// void main() {
///   BloomEnv.load();
///   BloomLogger.info('Core runtime initialized.');
/// }
/// ```
library bloom_core;

export 'package:bloom_server/src/core/env.dart';
export 'package:bloom_server/src/core/logger.dart';
export 'package:bloom_server/src/di/container.dart';
export 'package:bloom_server/src/di/scope.dart';
