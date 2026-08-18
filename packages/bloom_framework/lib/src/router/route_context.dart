// lib/src/router/route_context.dart

/// Route execution context provided to loaders, actions, and metadata builders.
class BloomRouteContext {
  /// Extracted path parameters from the current URL match.
  final Map<String, String> params;

  /// Parsed query parameters from the current request URL.
  final Map<String, String> queryParams;

  /// Full URL of the matched route.
  final Uri url;

  /// Optional contextual data passed to the route loader or action.
  final dynamic data;

  /// Creates a [BloomRouteContext] with the given parameters and URL.
  const BloomRouteContext({
    this.params = const {},
    this.queryParams = const {},
    required this.url,
    this.data,
  });

  /// Constructs a [BloomRouteContext] by parsing a [path] string and optional [params].
  factory BloomRouteContext.fromPath(String path, {Map<String, String> params = const {}, dynamic data}) {
    final uri = Uri.parse(path);
    return BloomRouteContext(
      params: params,
      queryParams: uri.queryParameters,
      url: uri,
      data: data,
    );
  }
}

/// Result returned from a route form action handler.
class ActionResult {
  /// Whether the action executed successfully.
  final bool isSuccess;

  /// Top-level error message if the action failed.
  final String? errorMessage;

  /// Optional payload returned from successful execution.
  final dynamic data;

  /// Per-field validation error messages.
  final Map<String, List<String>> fieldErrors;

  const ActionResult._({
    required this.isSuccess,
    this.errorMessage,
    this.data,
    this.fieldErrors = const {},
  });

  /// Creates a successful [ActionResult] with optional return [data].
  factory ActionResult.success([dynamic data]) {
    return ActionResult._(isSuccess: true, data: data);
  }

  /// Creates a failed [ActionResult] with an [errorMessage] and optional [fieldErrors].
  factory ActionResult.error(String message, {Map<String, List<String>> fieldErrors = const {}}) {
    return ActionResult._(isSuccess: false, errorMessage: message, fieldErrors: fieldErrors);
  }
}
