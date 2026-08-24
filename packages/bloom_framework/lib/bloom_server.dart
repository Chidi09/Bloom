/// Flutter-free server core and HTTP API routing layer for Bloom backend services.
///
/// Re-exports `bloom_core.dart` (environment, DI, logger) alongside HTTP routing primitives
/// ([ApiRouter], [BloomRequest], [BloomResponse], and [BloomMiddleware]) from `package:bloom_server`.
///
/// This barrel is strictly Flutter-free, allowing backend services and Server-Side Rendering (SSR)
/// daemons to compile directly to native binaries (`dart compile exe`) without the Flutter engine.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_server.dart';
///
/// void main() {
///   final router = ApiRouter();
///   router.get('/health', (req) => BloomResponse.json({'status': 'ok'}));
/// }
/// ```
library bloom_server;

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
