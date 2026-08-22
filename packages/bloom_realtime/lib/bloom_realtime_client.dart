/// Query cache invalidation extras for bloom_realtime.
///
/// Bridges channel broadcasts directly to `bloom_js_native`'s pure-Dart
/// `BloomData` client query cache (signals-backed, no Flutter dependency).
///
/// Import this library from `bloom_js_native` client applications that use
/// `BloomQuery`/`BloomData`. Pure server entrypoints that don't need the
/// client query-invalidation bridge can import
/// `package:bloom_realtime/bloom_realtime.dart` instead.
library;

export 'bloom_realtime.dart';
export 'src/client/query_bridge.dart';

