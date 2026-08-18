// lib/bloom_realtime_client.dart
//
// Flutter-app-only extras for bloom_realtime: bridges channel broadcasts to
// the `BloomData` client query cache (which depends on `package:flutter`
// via `signals_flutter`). Import this from Flutter client apps only —
// never from a pure-Dart server entrypoint. Servers should import
// `bloom_realtime.dart` instead, which is Flutter-free.

export 'bloom_realtime.dart';
export 'src/client/query_bridge.dart';
