// lib/src/router/route_context.dart

/// Route context and action execution models for Bloom routing.
library;

/// Route execution context provided to loaders, actions, and metadata builders.
///
/// Contains path parameters, parsed query parameters, the full URL, and any contextual data.
///
/// Example:
/// ```dart
/// Future<UserData> loadUser(BloomRouteContext context) async {
///   final userId = context.params['id'];
///   return fetchUser(userId!);
/// }
/// ```
class BloomRouteContext {
  /// Extracted path parameters from dynamic route segments (e.g. `{'id': '42'}`).
  final Map<String, String> params;

  /// Parsed query parameters from the request URL (e.g. `{'tab': 'settings'}`).
  final Map<String, String> queryParams;

  /// Full [Uri] of the matched route.
  final Uri url;

  /// Optional contextual payload passed to the route loader or action.
  final dynamic data;

  /// Creates a [BloomRouteContext] with the given parameters and URL.
  const BloomRouteContext({
    this.params = const {},
    this.queryParams = const {},
    required this.url,
    this.data,
  });

  /// Constructs a [BloomRouteContext] by parsing a [path] string and optional [params].
  ///
  /// Example:
  /// ```dart
  /// final ctx = BloomRouteContext.fromPath('/users/42?tab=activity', params: {'id': '42'});
  /// ```
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
///
/// Encapsulates success state, optional response data, and field-level validation errors.
///
/// Example:
/// ```dart
/// Future<ActionResult> handleSave(BloomRouteContext ctx) async {
///   if (name.isEmpty) {
///     return ActionResult.error('Validation failed', fieldErrors: {'name': ['Name required']});
///   }
///   return ActionResult.success({'id': 123});
/// }
/// ```
class ActionResult {
  /// Whether the action executed successfully.
  final bool isSuccess;

  /// Top-level error message if the action failed.
  final String? errorMessage;

  /// Optional payload returned from successful execution.
  final dynamic data;

  /// Per-field validation error messages mapping field names to lists of errors.
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
