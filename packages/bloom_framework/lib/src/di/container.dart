// lib/src/di/container.dart
//
// Re-export shim, not a copy. The implementation lives exactly once in
// `package:bloom_server`, which is Flutter-free so pure-Dart backends can
// compile without the Flutter SDK.
//
// This file exists only so the files inside bloom_framework that import
// 'container.dart' by relative path keep resolving. It holds no logic of
// its own, so there is nothing here that can drift from the real definition.
export 'package:bloom_server/src/di/container.dart';
