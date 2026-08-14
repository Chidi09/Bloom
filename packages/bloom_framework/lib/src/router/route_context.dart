// lib/src/router/route_context.dart

/// Route execution context provided to loaders, actions, and metadata builders.
class BloomRouteContext {
  final Map<String, String> params;
  final Map<String, String> queryParams;
  final Uri url;
  final dynamic data;

  const BloomRouteContext({
    this.params = const {},
    this.queryParams = const {},
    required this.url,
    this.data,
  });

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
  final bool isSuccess;
  final String? errorMessage;
  final dynamic data;
  final Map<String, List<String>> fieldErrors;

  const ActionResult._({
    required this.isSuccess,
    this.errorMessage,
    this.data,
    this.fieldErrors = const {},
  });

  factory ActionResult.success([dynamic data]) {
    return ActionResult._(isSuccess: true, data: data);
  }

  factory ActionResult.error(String message, {Map<String, List<String>> fieldErrors = const {}}) {
    return ActionResult._(isSuccess: false, errorMessage: message, fieldErrors: fieldErrors);
  }
}
