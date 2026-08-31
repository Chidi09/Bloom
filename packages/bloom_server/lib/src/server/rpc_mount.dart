// lib/src/server/rpc_mount.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'api_router.dart';
import 'bloom_middleware.dart';
import 'bloom_request.dart';
import 'bloom_response.dart';

/// Mounts a [BloomRpcRouter] onto a [BloomApiRouter] under [basePath].
///
/// This provides Backend-for-Frontend (BFF) RPC support, bridging typed [BloomRpcContract]
/// definitions from `package:bloom_js_native` directly onto the server's HTTP router.
///
/// ### Architectural Contract
/// - **Request Translation**: Adapts incoming [BloomRequest] instances into [BloomRpcServerRequest]
///   values, extracting query parameters, headers, and decoded JSON or text bodies.
/// - **Contract Dispatch**: Dispatches requests to matching typed [BloomRpcBinding] handlers registered
///   in [rpcRouter], and converts the returned [BloomRpcServerResponse] back into a [BloomResponse].
/// - **Error Mapping & Safety**: Maps strongly-typed RPC errors cleanly without leaking internal stack traces:
///   - [BloomRpcValidationErrors] -> HTTP 422 Unprocessable Entity with structured field errors.
///   - [BloomRpcHttpException] -> Specified `statusCode` and JSON payload.
///   - Unhandled exceptions -> HTTP 500 Internal Server Error with sanitized error message.
/// - **OpenAPI Integration**: Registers every bound RPC contract explicitly on [router], ensuring they
///   are fully documented in OpenAPI 3.1 specifications generated via [BloomApiRouter.toOpenApiSpec].
/// - **Fallback Routing**: Automatically registers a catch-all route under `$basePath/*` so unhandled
///   sub-paths return HTTP 404 without leaking server internals.
///
/// ### Example
/// ```dart
/// final rpcRouter = BloomRpcRouter();
///
/// // Bind typed RPC contracts
/// rpcRouter.bind(getTaskContract, (ctx, input) async {
///   final taskId = ctx.pathParams['id']!;
///   return taskService.getTask(taskId);
/// });
///
/// final router = BloomApiRouter();
/// mountBloomRpc(router, rpcRouter, basePath: '/api/rpc');
/// ```
void mountBloomRpc(
  BloomApiRouter router,
  BloomRpcRouter rpcRouter, {
  String basePath = '/api/rpc',
  List<BloomMiddleware> middlewares = const [],
}) {
  final cleanBase = basePath.endsWith('/') && basePath.length > 1
      ? basePath.substring(0, basePath.length - 1)
      : (basePath == '/' ? '' : basePath);

  // 1. Register an endpoint handler on the router for each bound RPC contract
  for (final binding in rpcRouter.bindings) {
    final contract = binding.contract;
    final pathTemplate = contract.pathTemplate.startsWith('/')
        ? contract.pathTemplate
        : '/${contract.pathTemplate}';
    final fullPath = '$cleanBase$pathTemplate';
    final method = contract.method.value.toUpperCase();

    _registerRoute(router, method, fullPath, (req) async {
      return _dispatchRpcRequest(rpcRouter, req, cleanBase);
    }, middlewares: middlewares);
  }

  // 2. Also register a fallback route for the base path tree to ensure unhandled RPC endpoints return 404
  final catchAllPath = cleanBase.isEmpty ? '/*' : '$cleanBase/*';
  _registerRoute(router, '*', catchAllPath, (req) async {
    return _dispatchRpcRequest(rpcRouter, req, cleanBase);
  }, middlewares: middlewares);
}

void _registerRoute(
  BloomApiRouter router,
  String method,
  String path,
  BloomRouteHandler handler, {
  List<BloomMiddleware> middlewares = const [],
}) {
  switch (method) {
    case 'GET':
      router.get(path, handler, middlewares: middlewares);
    case 'POST':
      router.post(path, handler, middlewares: middlewares);
    case 'PUT':
      router.put(path, handler, middlewares: middlewares);
    case 'DELETE':
      router.delete(path, handler, middlewares: middlewares);
    case 'PATCH':
      router.patch(path, handler, middlewares: middlewares);
    case '*':
      router.all(path, handler, middlewares: middlewares);
    default:
      router.all(path, handler, middlewares: middlewares);
  }
}

Future<BloomResponse> _dispatchRpcRequest(
  BloomRpcRouter rpcRouter,
  BloomRequest request,
  String cleanBase,
) async {
  // Strip basePath from request path to obtain the RPC contract path
  var rpcPath = request.path;
  if (cleanBase.isNotEmpty && rpcPath.startsWith(cleanBase)) {
    rpcPath = rpcPath.substring(cleanBase.length);
  }
  if (rpcPath.isEmpty) {
    rpcPath = '/';
  } else if (!rpcPath.startsWith('/')) {
    rpcPath = '/$rpcPath';
  }

  final rpcRequest = BloomRpcServerRequest(
    method: request.method,
    path: rpcPath,
    headers: request.headers,
    queryParams: request.queryParams,
    body: request.bodyJson ??
        (request.rawBody.isNotEmpty ? request.text() : null),
    rawRequest: request,
    context: {'request': request},
  );

  BloomRpcServerResponse rpcResponse;
  try {
    rpcResponse = await rpcRouter.handle(rpcRequest);
    // Note: validation errors are NOT caught here. BloomRpcBinding.execute
    // already converts a thrown BloomRpcValidationErrors into a 422 response
    // before it can propagate this far, so a catch clause for it here would be
    // unreachable. The same applies to most handler faults; the clauses below
    // exist for failures raised while routing, outside any binding.
  } on BloomRpcHttpException catch (e) {
    rpcResponse = BloomRpcServerResponse(
      statusCode: e.statusCode,
      body: e.responseBody ?? {'error': e.message, 'statusCode': e.statusCode},
      headers: e.responseHeaders ??
          const {'content-type': 'application/json; charset=utf-8'},
    );
  } on Exception catch (e) {
    rpcResponse = BloomRpcServerResponse.serverError(e.toString());
  } catch (_) {
    rpcResponse = BloomRpcServerResponse.serverError('Internal Server Error');
  }

  return _toBloomResponse(rpcResponse);
}

BloomResponse _toBloomResponse(BloomRpcServerResponse rpcResponse) {
  final headers = Map<String, String>.from(rpcResponse.headers);
  final body = rpcResponse.body;

  if (body == null) {
    return BloomResponse(
      statusCode: rpcResponse.statusCode,
      headers: headers,
      body: Uint8List(0),
    );
  }

  if (body is Uint8List) {
    return BloomResponse(
      statusCode: rpcResponse.statusCode,
      headers: headers,
      body: body,
    );
  }

  if (body is List<int>) {
    return BloomResponse(
      statusCode: rpcResponse.statusCode,
      headers: headers,
      body: Uint8List.fromList(body),
    );
  }

  if (body is String) {
    headers.putIfAbsent('content-type', () => 'text/plain; charset=utf-8');
    return BloomResponse(
      statusCode: rpcResponse.statusCode,
      headers: headers,
      body: Uint8List.fromList(utf8.encode(body)),
    );
  }

  headers['content-type'] = 'application/json; charset=utf-8';
  return BloomResponse(
    statusCode: rpcResponse.statusCode,
    headers: headers,
    body: Uint8List.fromList(utf8.encode(jsonEncode(body))),
  );
}

/// Extension on [BloomApiRouter] providing fluent RPC router mounting.
extension BloomRpcMountExtension on BloomApiRouter {
  /// Mounts a [BloomRpcRouter] under [basePath] (default `'/api/rpc'`) with optional [middlewares].
  ///
  /// Convenience method that delegates to [mountBloomRpc].
  ///
  /// ### Example
  /// ```dart
  /// final rpcRouter = BloomRpcRouter();
  /// rpcRouter.bind(getTaskContract, (ctx, input) async => taskDb.find(ctx.pathParams['id']!));
  ///
  /// final apiRouter = BloomApiRouter();
  /// apiRouter.mountRpc(rpcRouter, basePath: '/api/v1/rpc');
  /// ```
  void mountRpc(
    BloomRpcRouter rpcRouter, {
    String basePath = '/api/rpc',
    List<BloomMiddleware> middlewares = const [],
  }) {
    mountBloomRpc(this, rpcRouter,
        basePath: basePath, middlewares: middlewares);
  }
}
