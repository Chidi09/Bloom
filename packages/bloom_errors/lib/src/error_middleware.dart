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
/// Masking is **deny-by-default**: unmapped or unexpected internal exceptions
/// are masked with a generic `"Internal Server Error"` message unless the
/// environment is an explicit dev value. Recognized verbose (unmasked) values:
/// `'local'`, `'dev'`, `'development'`, `'test'`.
/// Every other value — including `'production'`, `'prod'`, `'staging'`,
/// `'qa'`, `'preview'` — produces masked 500s with no raw exception strings
/// or stack traces. In verbose environments full exception details and stack
/// traces are included to assist debugging.
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
  ///
  /// For request context (correlation), use [onErrorWithContext] instead, which
  /// additionally receives the originating [BloomRequest].
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Optional callback invoked whenever an error is intercepted, with request context.
  ///
  /// Receives the intercepted error object, the accompanying stack trace, and the
  /// originating [BloomRequest] (usable for correlation — e.g. its method and URI).
  /// Mutually independent from [onError]; set either or both.
  final void Function(Object error, StackTrace stackTrace, BloomRequest request)?
      onErrorWithContext;

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
    this.onErrorWithContext,
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
      // Observability must never break the response: a throwing onError
      // callback is swallowed (after being logged to the console).
      if (onError != null || onErrorWithContext != null) {
        try {
          onError?.call(error, stackTrace);
          onErrorWithContext?.call(error, stackTrace, request);
        } catch (callbackError, callbackStackTrace) {
          // ignore: avoid_print
          print('BloomErrorMiddleware.onError callback threw: '
              '$callbackError\n$callbackStackTrace');
        }
      }
      return _renderErrorResponse(error, stackTrace);
    }
  }

  BloomResponse _renderErrorResponse(Object error, StackTrace stackTrace) {
    final env = (environment ?? _resolveAppEnv()).toLowerCase();
    // Deny by default: only explicit dev values get verbose output.
    // Staging mirrors (staging/prod/qa/preview/…) must never leak internals.
    const verboseEnvs = {'local', 'dev', 'development', 'test'};
    final isProduction = !verboseEnvs.contains(env);

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
