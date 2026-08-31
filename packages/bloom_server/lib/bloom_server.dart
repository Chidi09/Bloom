/// High-performance, Flutter-free HTTP server framework for Bloom applications.
///
/// This barrel is the primary entry point for Bloom backend servers, API microservices,
/// Backend-for-Frontend (BFF) gateways, and full-stack Server-Side Rendered (SSR) apps.
///
/// It re-exports [bloom_core] ([BloomEnv], [BloomLogger], [BloomContainer], [BloomTestScope])
/// and provides the full HTTP server runtime:
/// - **HTTP Routing**: [BloomApiRouter] with fast regex routing, specificity sorting,
///   wildcard captures, path parameters (`:id`), and graceful shutdown draining.
/// - **Request & Response**: [BloomRequest] and [BloomResponse] abstractions for JSON,
///   HTML, redirects, binary payloads, incremental body streaming ([BloomResponse.stream],
///   [BloomResponse.file]), and streaming multipart uploads ([BloomMultipartPart], [BloomMultipartField],
///   [BloomMultipartFile]).
/// - **Middleware Pipeline**: [BloomMiddleware], [FunctionalBloomMiddleware], and built-in
///   [BloomCorsMiddleware] for composable request/response interceptors.
/// - **Server-Side Rendering (SSR)**: High-speed [BloomNode] rendering with [BloomApiRouter.ssr]
///   and SEO head management (<1ms response time, zero JS runtime overhead).
/// - **OpenAPI 3.1 & Interactive Docs**: [BloomApiRouter.enableOpenApi] to auto-generate OpenAPI
///   specifications with built-in Scalar and Swagger UI documentation endpoints.
/// - **Backend-for-Frontend (BFF) RPC**: [mountBloomRpc] and [BloomRpcMountExtension.mountRpc]
///   for mounting typed, end-to-end type-safe RPC routers directly on HTTP routes.
///
/// ### Example
/// ```dart
/// import 'dart:io';
/// import 'package:bloom_server/bloom_server.dart';
///
/// void main() async {
///   final router = BloomApiRouter();
///
///   // Register global CORS middleware
///   router.use(BloomCorsMiddleware());
///
///   // Enable interactive API documentation at /api/docs and /api/swagger
///   router.enableOpenApi(title: 'My Service API', version: '1.0.0');
///
///   // Define JSON API routes
///   router.get('/api/health', (req) async => BloomResponse.json({'status': 'ok'}));
///   router.get('/api/tasks/:id', (req) async {
///     final id = req.params['id'];
///     return BloomResponse.json({'id': id, 'title': 'Sample Task'});
///   });
///
///   // Start listening on port 8080
///   final server = await router.serve(port: 8080);
///   print('Server listening on http://localhost:${server.port}');
/// }
/// ```
library bloom_server;

export 'bloom_core.dart';
export 'src/server/api_router.dart';
export 'src/server/bloom_middleware.dart';
export 'src/server/bloom_multipart.dart';
export 'src/server/bloom_request.dart';
export 'src/server/bloom_response.dart';
export 'src/server/rpc_mount.dart';
