/// Flutter client-only query cache invalidation extras for bloom_realtime.
///
/// Bridges channel broadcasts directly to the `BloomData` client query cache
/// (which depends on `package:flutter` via `signals_flutter`).
///
/// Import this library from Flutter client applications only — never from pure-Dart
/// server entrypoints. Servers should import `package:bloom_realtime/bloom_realtime.dart` instead.
library;

export 'bloom_realtime.dart';
export 'src/client/query_bridge.dart';

