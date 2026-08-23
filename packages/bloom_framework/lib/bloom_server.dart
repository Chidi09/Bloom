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

// rpc_mount.dart is deliberately NOT exported yet.
//
// It exists only in the local bloom_server; the published 0.1.0 on pub.dev
// does not contain it. Consumers outside this workspace -- a scaffolded
// module, a freshly created app -- resolve bloom_server from pub.dev, so
// exporting it here made bloom_framework fail to COMPILE for them with
// "Error when reading .../bloom_server-0.1.0/lib/src/server/rpc_mount.dart".
// Every other export above resolves fine against 0.1.0.
//
// Re-add this line once a bloom_server release containing rpc_mount.dart is
// published and the constraint in pubspec.yaml is raised to require it.
// Until then the generated SSR server keeps importing rpc_mount from
// package:bloom_server directly, as it already did.
