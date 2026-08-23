// lib/bloom_server.dart
//
// The server core lives in `package:bloom_server`, which is Flutter-free so
// that pure-Dart backends can `dart compile exe` without the Flutter SDK.
// This barrel re-exports it so Flutter consumers keep a single import.
//
// The dependency runs one way only: bloom_framework depends on bloom_server,
// never the reverse. Reversing it would drag `package:flutter` into every
// backend. See test/no_duplication_test.dart, which enforces this.
export 'bloom_core.dart';

export 'package:bloom_server/src/server/api_router.dart';
export 'package:bloom_server/src/server/bloom_middleware.dart';
export 'package:bloom_server/src/server/bloom_request.dart';
export 'package:bloom_server/src/server/bloom_response.dart';
export 'package:bloom_server/src/server/rpc_mount.dart';
