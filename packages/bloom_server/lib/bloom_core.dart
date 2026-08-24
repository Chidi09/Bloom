/// Flutter-independent core primitives for Bloom applications and servers.
///
/// This barrel exports foundational utilities that have zero dependencies on the
/// Flutter SDK or `dart:ui`:
/// - **Environment Configuration**: [BloomEnv] for type-safe `.env` parsing,
///   system variable resolution, and `--dart-define` compilation values.
/// - **Structured Logging**: [BloomLogger] and [BloomLogLevel] for colorized,
///   context-tagged console output and custom log writers.
/// - **Dependency Injection**: [BloomContainer] and [BloomTestScope] for hierarchical
///   service resolution, transient/singleton factories, and isolated unit test mocking.
///
/// ### Why Two Barrel Files?
/// Bloom provides two separate server-side entry points:
/// 1. `package:bloom_server/bloom_core.dart` (this barrel): Lightweight core
///    utilities with no HTTP server bindings. Ideal for CLI tools, background workers,
///    isomorphic libraries, or standalone pure-Dart business logic.
/// 2. `package:bloom_server/bloom_server.dart`: The complete full-stack server runtime,
///    which re-exports `bloom_core.dart` along with HTTP routing ([BloomApiRouter]),
///    request/response models ([BloomRequest], [BloomResponse]), middleware, SSR, and RPC.
///
/// Neither barrel imports `package:flutter`, making them safe to execute in any
/// standard `dart run` or `dart compile exe` process.
///
/// ### Example
/// ```dart
/// import 'package:bloom_server/bloom_core.dart';
///
/// void main() {
///   // Configure environment
///   BloomEnv.loadContent('PORT=8080\nDEBUG=true');
///
///   // Register dependencies
///   provideSingleton<BloomLogger>(() => BloomLogger(context: 'APP'));
///
///   // Resolve and use
///   final appLogger = inject<BloomLogger>();
///   appLogger.info('Core runtime initialized on port ${BloomEnv.getInt('PORT')}');
/// }
/// ```
library bloom_core;

export 'src/core/env.dart';
export 'src/core/logger.dart';
export 'src/di/container.dart';
export 'src/di/scope.dart';
