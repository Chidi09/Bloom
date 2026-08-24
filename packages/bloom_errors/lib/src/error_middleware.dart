// lib/src/error_middleware.dart
import 'package:bloom_server/bloom_server.dart';
import 'error_mapper.dart';
import 'http_exception.dart';

/// Central HTTP error-rendering middleware for Bloom applications.
///
/// Designed to sit as the outermost global middleware in [BloomApiRouter] via
/// `router.use(const BloomErrorMiddleware())`. Catches all unhandled exceptions thrown by
/// subsequent middlewares or route handlers, converts them into strongly-typed
/// [BloomApiException] representations via [BloomErrorMapper], and formats a
/// consistent JSON error response:
///
/// ```json
/// {
///   "error": {
///     "code": "not_found",
///     "message": "User 42 not found",
///     "details": { ... }
///   }
/// }
/// ```
///
/// ### Environment-Aware Information Masking
/// In production (`APP_ENV=production`), unmapped or unexpected internal exceptions
/// are masked with a generic `"Internal Server Error"` message and do NOT expose
/// raw exception strings or stack traces. In non-production environments (`local`, `dev`),
/// full exception details and stack traces are included in the response to assist debugging.
/// Intentionally thrown [BloomApiException] instances always output their explicit
/// message and code regardless of environment.
///
/// Example:
/// ```dart
/// final router = BloomApiRouter();
///
/// router.use(BloomErrorMiddleware(
///   onError: (error, stackTrace) {
///     print('Intercepted error: $error\n$stackTrace');
///   },
/// ));
/// ```
class BloomErrorMiddleware implements BloomMiddleware {
  /// Optional callback invoked whenever an error is intercepted (e.g. for logging or APM).
  ///
  /// Receives the intercepted error object and the accompanying stack trace.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Optional override for the application environment string (e.g. `'production'`, `'local'`).
  ///
  /// If not supplied, defaults to the value read from `BloomEnv.get('APP_ENV', defaultValue: 'local')`.
  final String? environment;

  /// Creates a new [BloomErrorMiddleware] instance.
  ///
  /// Accepts an optional [onError] callback for external error tracking/logging and an
  /// optional [environment] override to control error payload masking.
  ///
  /// Example:
  /// ```dart
  /// const middleware = BloomErrorMiddleware(
  ///   environment: 'production',
  /// );
  /// ```
  const BloomErrorMiddleware({
    this.onError,
    this.environment,
  });

  /// Intercepts the HTTP pipeline execution for [request].
  ///
  /// Invokes [next] to execute subsequent middleware and route handlers. If an exception
  /// is thrown during execution, it is passed to [onError] (if provided) and translated
  /// into a structured [BloomResponse] via [BloomApiException.toResponse], [BloomErrorMapper.map],
  /// or an environment-masked 500 JSON response.
  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    try {
      final response = await next();
      return response;
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return _renderErrorResponse(error, stackTrace);
    }
  }

  BloomResponse _renderErrorResponse(Object error, StackTrace stackTrace) {
    final env = (environment ?? _resolveAppEnv()).toLowerCase();
    final isProduction = env == 'production';

    // 1. If it is already a BloomApiException (deliberately thrown by handler/middleware)
    if (error is BloomApiException) {
      return error.toResponse();
    }

    // 2. Try mapping via BloomErrorMapper registry & built-ins
    final mapped = BloomErrorMapper.map(error);
    if (mapped != null) {
      return mapped.toResponse();
    }

    // 3. Unmapped / unexpected error handling with environment-aware masking
    if (isProduction) {
      // Never leak internal error messages or stack traces in production
      return BloomResponse.json(
        {
          'error': {
            'code': 'internal_server_error',
            'message': 'Internal Server Error',
          },
        },
        statusCode: 500,
      );
    } else {
      // In local / development mode, provide rich debugging details
      return BloomResponse.json(
        {
          'error': {
            'code': 'internal_server_error',
            'message': error.toString(),
            'details': {
              'type': error.runtimeType.toString(),
              'stack_trace': stackTrace.toString(),
            },
          },
        },
        statusCode: 500,
      );
    }
  }

  static String _resolveAppEnv() {
    try {
      return BloomEnv.get('APP_ENV', defaultValue: 'local');
    } catch (_) {
      return 'local';
    }
  }
}
