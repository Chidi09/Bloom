// lib/src/rpc.dart
//
// Pure-Dart Type-Safe RPC module for Bloom JS Native.
// Enables end-to-end type safety across client and server boundaries.
// Safe for both SSR (VM) and browser environments (zero package:web dependency).

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'data.dart';
import 'env.dart';
import 'http.dart';
import 'mutation.dart';

// ─── HTTP Method Enum ────────────────────────────────────────────────────────

/// HTTP request method enum for [BloomRpcContract] definitions.
///
/// Defines standard HTTP verbs supported by RESTful and RPC endpoints.
///
/// ```dart
/// final method = BloomHttpMethod.get;
/// print(method.value); // 'GET'
/// ```
enum BloomHttpMethod {
  /// HTTP GET method for retrieving resources without side-effects.
  get('GET'),

  /// HTTP POST method for creating resources or executing side-effecting operations.
  post('POST'),

  /// HTTP PUT method for full replacement of a resource.
  put('PUT'),

  /// HTTP PATCH method for partial updates to a resource.
  patch('PATCH'),

  /// HTTP DELETE method for removing a resource.
  delete('DELETE'),

  /// HTTP HEAD method for retrieving response headers without body payload.
  head('HEAD'),

  /// HTTP OPTIONS method for describing communication options.
  options('OPTIONS');

  /// The uppercase HTTP verb string (e.g. `'GET'`, `'POST'`).
  final String value;

  const BloomHttpMethod(this.value);

  @override
  String toString() => value;
}

// ─── Default Codecs ─────────────────────────────────────────────────────────

T _defaultDecode<T>(dynamic json) => json as T;

// ─── RPC Contract ───────────────────────────────────────────────────────────

/// Strongly-typed specification of an RPC network endpoint.
///
/// [BloomRpcContract] defines the network boundary contract shared between client
/// applications and backend servers:
/// - **HTTP Method & Path**: Specifies the HTTP verb ([method]) and URL path template
///   ([pathTemplate]), supporting path parameter tokens (e.g. `'/users/:id/posts/:postId'`).
/// - **Input & Output Types**: Parameterized on [TInput] (request payload / query parameters)
///   and [TOutput] (decoded response payload).
/// - **Codecs**: Encodes inputs to JSON-compatible structures via [encodeInput] and decodes
///   server responses into strongly typed Dart objects via [decodeOutput].
/// - **Zero Transport Overhead**: A contract is a pure description, carrying no transport
///   or network logic itself. It can be declared as a compile-time `const` or top-level `final`.
///
/// ### End-to-End Type Safety Example
/// ```dart
/// // 1. Shared contract declaration (shared across client and server)
/// class CreateTaskInput {
///   final String title;
///   final bool completed;
///   CreateTaskInput({required this.title, this.completed = false});
///   Map<String, dynamic> toJson() => {'title': title, 'completed': completed};
/// }
///
/// class Task {
///   final String id;
///   final String title;
///   final bool completed;
///   Task({required this.id, required this.title, required this.completed});
///   factory Task.fromJson(Map<String, dynamic> json) => Task(
///     id: json['id'] as String,
///     title: json['title'] as String,
///     completed: json['completed'] as bool? ?? false,
///   );
/// }
///
/// const createTaskContract = BloomRpcContract<CreateTaskInput, Task>.post(
///   '/tasks',
///   encodeInput: (input) => input.toJson(),
///   decodeOutput: Task.fromJson,
/// );
///
/// // 2. Client-side execution with full type inference
/// final client = BloomRpcClient(baseUrl: 'https://api.example.com');
/// final Task createdTask = await client.call(
///   createTaskContract,
///   CreateTaskInput(title: 'Write unit tests'),
/// );
/// ```
///
/// See also:
/// - [BloomRpcClient], the client that executes contracts over HTTP.
/// - [rpcQuery], for binding contracts to reactive [BloomQuery] caches.
/// - [rpcMutation], for binding contracts to [BloomMutation] state machines.
/// - [BloomRpcRouter], for registering server-side handlers for contracts.
class BloomRpcContract<TInput, TOutput> {
  /// The HTTP verb used for this endpoint.
  final BloomHttpMethod method;

  /// The URL path template, optionally containing `:parameter` interpolation tokens.
  ///
  /// Example: `'/api/v1/projects/:projectId/tasks/:taskId'`
  final String pathTemplate;

  /// Optional function that transforms typed [TInput] into a JSON-encodable map, list, or primitive.
  ///
  /// For GET requests, if the encoded input is a Map, non-path parameter fields are serialized
  /// as URL query parameters. For POST/PUT/PATCH requests, the encoded value forms the JSON body.
  final dynamic Function(TInput input)? encodeInput;

  /// Optional function that transforms raw JSON/query map into typed [TInput] on the server side.
  final TInput Function(dynamic json)? decodeInput;

  /// Optional function that transforms typed [TOutput] into a JSON-encodable payload on the server side.
  final dynamic Function(TOutput output)? encodeOutput;

  /// Function that transforms decoded JSON response data into strongly typed [TOutput].
  /// Decodes the raw JSON response into [TOutput].
  ///
  /// Null means "no custom decoding": the raw decoded JSON is cast to
  /// [TOutput] directly. This is nullable rather than defaulted because a
  /// `const` constructor cannot use a generic function tear-off as a default
  /// value; the fallback is applied at the call site instead.
  final TOutput Function(dynamic json)? decodeOutput;

  /// Optional human-readable short summary of this endpoint.
  final String? summary;

  /// Optional detailed description of this endpoint's behavior.
  final String? description;

  /// Optional custom cache key generator overriding default RPC cache key derivation.
  final List<dynamic> Function(TInput input)? customCacheKey;

  /// Creates a [BloomRpcContract] with explicit [method], [pathTemplate], and codecs.
  ///
  /// ```dart
  /// const getUser = BloomRpcContract<void, User>(
  ///   method: BloomHttpMethod.get,
  ///   pathTemplate: '/users/:id',
  ///   decodeOutput: User.fromJson,
  /// );
  /// ```
  const BloomRpcContract({
    required this.method,
    required this.pathTemplate,
    this.encodeInput,
    this.decodeInput,
    this.encodeOutput,
    this.decodeOutput,
    this.summary,
    this.description,
    this.customCacheKey,
  });

  /// Shorthand constructor for an HTTP GET endpoint contract.
  ///
  /// ```dart
  /// const getPost = BloomRpcContract<void, Post>.get(
  ///   '/posts/:id',
  ///   decodeOutput: Post.fromJson,
  /// );
  /// ```
  const BloomRpcContract.get(
    String pathTemplate, {
    dynamic Function(TInput input)? encodeInput,
    TInput Function(dynamic json)? decodeInput,
    dynamic Function(TOutput output)? encodeOutput,
    TOutput Function(dynamic json)? decodeOutput,
    String? summary,
    String? description,
    List<dynamic> Function(TInput input)? customCacheKey,
  }) : this(
          method: BloomHttpMethod.get,
          pathTemplate: pathTemplate,
          encodeInput: encodeInput,
          decodeInput: decodeInput,
          encodeOutput: encodeOutput,
          decodeOutput: decodeOutput,
          summary: summary,
          description: description,
          customCacheKey: customCacheKey,
        );

  /// Shorthand constructor for an HTTP POST endpoint contract.
  ///
  /// ```dart
  /// const createPost = BloomRpcContract<CreatePostInput, Post>.post(
  ///   '/posts',
  ///   encodeInput: (input) => input.toJson(),
  ///   decodeOutput: Post.fromJson,
  /// );
  /// ```
  const BloomRpcContract.post(
    String pathTemplate, {
    dynamic Function(TInput input)? encodeInput,
    TInput Function(dynamic json)? decodeInput,
    dynamic Function(TOutput output)? encodeOutput,
    TOutput Function(dynamic json)? decodeOutput,
    String? summary,
    String? description,
    List<dynamic> Function(TInput input)? customCacheKey,
  }) : this(
          method: BloomHttpMethod.post,
          pathTemplate: pathTemplate,
          encodeInput: encodeInput,
          decodeInput: decodeInput,
          encodeOutput: encodeOutput,
          decodeOutput: decodeOutput,
          summary: summary,
          description: description,
          customCacheKey: customCacheKey,
        );

  /// Shorthand constructor for an HTTP PUT endpoint contract.
  ///
  /// ```dart
  /// const updatePost = BloomRpcContract<UpdatePostInput, Post>.put(
  ///   '/posts/:id',
  ///   encodeInput: (input) => input.toJson(),
  ///   decodeOutput: Post.fromJson,
  /// );
  /// ```
  const BloomRpcContract.put(
    String pathTemplate, {
    dynamic Function(TInput input)? encodeInput,
    TInput Function(dynamic json)? decodeInput,
    dynamic Function(TOutput output)? encodeOutput,
    TOutput Function(dynamic json)? decodeOutput,
    String? summary,
    String? description,
    List<dynamic> Function(TInput input)? customCacheKey,
  }) : this(
          method: BloomHttpMethod.put,
          pathTemplate: pathTemplate,
          encodeInput: encodeInput,
          decodeInput: decodeInput,
          encodeOutput: encodeOutput,
          decodeOutput: decodeOutput,
          summary: summary,
          description: description,
          customCacheKey: customCacheKey,
        );

  /// Shorthand constructor for an HTTP PATCH endpoint contract.
  ///
  /// ```dart
  /// const patchPost = BloomRpcContract<Map<String, dynamic>, Post>.patch(
  ///   '/posts/:id',
  ///   decodeOutput: Post.fromJson,
  /// );
  /// ```
  const BloomRpcContract.patch(
    String pathTemplate, {
    dynamic Function(TInput input)? encodeInput,
    TInput Function(dynamic json)? decodeInput,
    dynamic Function(TOutput output)? encodeOutput,
    TOutput Function(dynamic json)? decodeOutput,
    String? summary,
    String? description,
    List<dynamic> Function(TInput input)? customCacheKey,
  }) : this(
          method: BloomHttpMethod.patch,
          pathTemplate: pathTemplate,
          encodeInput: encodeInput,
          decodeInput: decodeInput,
          encodeOutput: encodeOutput,
          decodeOutput: decodeOutput,
          summary: summary,
          description: description,
          customCacheKey: customCacheKey,
        );

  /// Shorthand constructor for an HTTP DELETE endpoint contract.
  ///
  /// ```dart
  /// const deletePost = BloomRpcContract<void, void>.delete(
  ///   '/posts/:id',
  /// );
  /// ```
  const BloomRpcContract.delete(
    String pathTemplate, {
    dynamic Function(TInput input)? encodeInput,
    TInput Function(dynamic json)? decodeInput,
    dynamic Function(TOutput output)? encodeOutput,
    TOutput Function(dynamic json)? decodeOutput,
    String? summary,
    String? description,
    List<dynamic> Function(TInput input)? customCacheKey,
  }) : this(
          method: BloomHttpMethod.delete,
          pathTemplate: pathTemplate,
          encodeInput: encodeInput,
          decodeInput: decodeInput,
          encodeOutput: encodeOutput,
          decodeOutput: decodeOutput,
          summary: summary,
          description: description,
          customCacheKey: customCacheKey,
        );

  /// Extracts all path parameter names defined in [pathTemplate].
  ///
  /// Identifies tokens starting with `:` (e.g. `['userId', 'postId']` for `'/users/:userId/posts/:postId'`).
  ///
  /// ```dart
  /// final params = contract.pathParameters;
  /// ```
  List<String> get pathParameters {
    final matches =
        RegExp(r':([a-zA-Z_][a-zA-Z0-9_]*)').allMatches(pathTemplate);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// Interpolates path parameters into [pathTemplate], percent-encoding all parameter values.
  ///
  /// Looks up parameter values first in [pathParams], and falls back to inspecting fields
  /// in [input] when [input] is a Map.
  ///
  /// Throws a [BloomRpcPathParameterException] if any parameter defined in [pathTemplate]
  /// is missing or null, ensuring malformed URLs with literal `:param` tokens are never dispatched.
  ///
  /// ```dart
  /// final path = contract.resolvePath(pathParams: {'id': 'user 123'});
  /// // Produces: '/users/user%20123'
  /// ```
  String resolvePath({Map<String, dynamic>? pathParams, dynamic input}) {
    final params = pathParameters;
    if (params.isEmpty) {
      return pathTemplate;
    }

    Map<String, dynamic>? inputMap;
    if (input is Map<String, dynamic>) {
      inputMap = input;
    } else if (input is Map) {
      inputMap = Map<String, dynamic>.from(input);
    }

    var resolved = pathTemplate;
    for (final param in params) {
      dynamic val;
      if (pathParams != null && pathParams.containsKey(param)) {
        val = pathParams[param];
      } else if (inputMap != null && inputMap.containsKey(param)) {
        val = inputMap[param];
      }

      if (val == null) {
        throw BloomRpcPathParameterException(
          paramName: param,
          pathTemplate: pathTemplate,
          method: method.value,
        );
      }

      final encoded = Uri.encodeComponent(val.toString());
      resolved = resolved.replaceAll(':$param', encoded);
    }
    return resolved;
  }

  /// Matches an incoming [requestPath] against this contract's [pathTemplate] on the server side.
  ///
  /// If the path matches the template pattern, extracts and returns the percent-decoded path
  /// parameters as a `Map<String, String>`. Returns `null` if the path does not match.
  ///
  /// ```dart
  /// final params = contract.matchPath('/users/42/posts/100');
  /// // Returns: {'userId': '42', 'postId': '100'}
  /// ```
  Map<String, String>? matchPath(String requestPath) {
    // Strip query strings or trailing whitespace
    final cleanPath = requestPath.split('?').first.trim();

    final templateSegments = pathTemplate
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final actualSegments =
        cleanPath.split('/').where((s) => s.isNotEmpty).toList(growable: false);

    if (templateSegments.length != actualSegments.length) {
      return null;
    }

    final extracted = <String, String>{};
    for (var i = 0; i < templateSegments.length; i++) {
      final tSegment = templateSegments[i];
      final aSegment = actualSegments[i];

      if (tSegment.startsWith(':')) {
        final paramName = tSegment.substring(1);
        extracted[paramName] = Uri.decodeComponent(aSegment);
      } else if (tSegment != aSegment) {
        return null;
      }
    }

    return extracted;
  }

  /// Derives a structured cache key for integration with [BloomData] and [BloomQuery].
  ///
  /// Produces a deterministic key list formatted as `['rpc', method, resolvedPath, ...inputPayload]`
  /// that can be normalized via [BloomData.normalizeKey].
  ///
  /// ```dart
  /// final key = contract.cacheKey(
  ///   null,
  ///   pathParams: {'id': 123},
  /// );
  /// // Produces: ['rpc', 'get', '/users/123']
  /// ```
  List<dynamic> cacheKey(
    TInput input, {
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParameters,
  }) {
    if (customCacheKey != null) {
      return customCacheKey!(input);
    }

    final resolved = resolvePath(pathParams: pathParams, input: input);
    dynamic payloadPart;

    if (encodeInput != null) {
      try {
        payloadPart = encodeInput!(input);
      } catch (_) {
        payloadPart = input;
      }
    } else {
      payloadPart = input;
    }

    return [
      'rpc',
      method.value.toLowerCase(),
      resolved,
      if (payloadPart != null) payloadPart,
      if (queryParameters != null && queryParameters.isNotEmpty)
        queryParameters,
    ];
  }
}

/// Convenience factory function for declaring a [BloomRpcContract].
///
/// ```dart
/// final getUser = rpcContract<void, User>(
///   method: BloomHttpMethod.get,
///   pathTemplate: '/users/:id',
///   decodeOutput: User.fromJson,
/// );
/// ```
BloomRpcContract<TInput, TOutput> rpcContract<TInput, TOutput>({
  required BloomHttpMethod method,
  required String pathTemplate,
  dynamic Function(TInput input)? encodeInput,
  TInput Function(dynamic json)? decodeInput,
  dynamic Function(TOutput output)? encodeOutput,
  TOutput Function(dynamic json)? decodeOutput,
  String? summary,
  String? description,
  List<dynamic> Function(TInput input)? customCacheKey,
}) {
  return BloomRpcContract<TInput, TOutput>(
    method: method,
    pathTemplate: pathTemplate,
    encodeInput: encodeInput,
    decodeInput: decodeInput,
    encodeOutput: encodeOutput,
    decodeOutput: decodeOutput,
    summary: summary,
    description: description,
    customCacheKey: customCacheKey,
  );
}

// ─── Cancellation Token ─────────────────────────────────────────────────────

/// Cancellation token used to abort in-flight RPC requests.
///
/// Pass an instance of [BloomRpcCancelToken] to [BloomRpcClient.call].
/// Calling [cancel] immediately rejects pending request futures with a [BloomRpcCancelledException].
///
/// ```dart
/// final token = BloomRpcCancelToken();
///
/// // Start request
/// final future = client.call(fetchFeedContract, null, cancelToken: token);
///
/// // Cancel when user navigates away
/// token.cancel('User navigated away');
/// ```
class BloomRpcCancelToken {
  bool _isCancelled = false;
  String? _reason;
  final Completer<void> _cancelCompleter = Completer<void>();

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// The cancellation reason, or `null` if none was supplied.
  String? get reason => _reason;

  /// Future that completes when [cancel] is called.
  Future<void> get onCancelled => _cancelCompleter.future;

  /// Requests cancellation of any active requests bound to this token.
  void cancel([String? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason;
    if (!_cancelCompleter.isCompleted) {
      _cancelCompleter.complete();
    }
  }

  /// Throws a [BloomRpcCancelledException] if cancellation has already occurred.
  void throwIfCancelled(
      [BloomRpcContract<dynamic, dynamic>? contract, Uri? uri]) {
    if (_isCancelled) {
      throw BloomRpcCancelledException(
        reason: _reason ?? 'RPC request was cancelled',
        contract: contract,
        uri: uri,
      );
    }
  }
}

// ─── Structured Error Model ─────────────────────────────────────────────────

/// Structured field-level and general validation errors from an RPC error response.
///
/// Parses validation responses emitted by REST backends, including `bloom_rest`'s
/// `BloomValidationErrors` serializer output (`{"errors": {"field": "msg"}}` or `{"field": ["msg"]}`).
///
/// Provides field-level inspection methods and [flattenedErrors] for easy binding
/// to UI form fields.
///
/// ```dart
/// try {
///   await client.call(createUserContract, newUserData);
/// } on BloomRpcHttpException catch (e) {
///   if (e.isValidationError) {
///     final errors = e.validationErrors;
///     final emailError = errors?.firstError('email');
///     print('Email error: $emailError');
///   }
/// }
/// ```
class BloomRpcValidationErrors {
  final Map<String, List<String>> _fieldErrors;
  final List<String> _nonFieldErrors;

  /// Creates a [BloomRpcValidationErrors] with structured field and general errors.
  const BloomRpcValidationErrors({
    Map<String, List<String>> fieldErrors = const {},
    List<String> nonFieldErrors = const [],
  })  : _fieldErrors = fieldErrors,
        _nonFieldErrors = nonFieldErrors;

  /// Parses validation errors from decoded response JSON or error maps.
  ///
  /// Supports:
  /// - `{"errors": {"field": ["msg"]}}`
  /// - `{"field": "msg", "non_field_errors": ["general error"]}`
  /// - `{"error": "message"}` or `{"detail": "message"}`
  factory BloomRpcValidationErrors.fromResponse(dynamic data) {
    final fieldMap = <String, List<String>>{};
    final generalList = <String>[];

    if (data is Map) {
      dynamic targetMap = data;
      if (data.containsKey('errors') && data['errors'] is Map) {
        targetMap = data['errors'];
      } else if (data.containsKey('validation_errors') &&
          data['validation_errors'] is Map) {
        targetMap = data['validation_errors'];
      }

      for (final entry in (targetMap as Map).entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (key == 'non_field_errors' ||
            key == '__all__' ||
            key == 'general' ||
            key == 'error' ||
            key == 'detail' ||
            key == 'message') {
          if (value is Iterable) {
            generalList.addAll(value.map((v) => v.toString()));
          } else if (value != null) {
            generalList.add(value.toString());
          }
        } else {
          final list = fieldMap.putIfAbsent(key, () => []);
          if (value is Iterable) {
            list.addAll(value.map((v) => v.toString()));
          } else if (value != null) {
            list.add(value.toString());
          }
        }
      }
    } else if (data is String && data.isNotEmpty) {
      generalList.add(data);
    }

    return BloomRpcValidationErrors(
      fieldErrors: fieldMap,
      nonFieldErrors: generalList,
    );
  }

  /// Whether no validation errors were recorded.
  bool get isEmpty => _fieldErrors.isEmpty && _nonFieldErrors.isEmpty;

  /// Whether at least one validation error exists.
  bool get isNotEmpty => !isEmpty;

  /// Unmodifiable list of general / non-field validation errors.
  List<String> get nonFieldErrors => List.unmodifiable(_nonFieldErrors);

  /// First general error message, or `null` if none was recorded.
  String? get generalError =>
      _nonFieldErrors.isNotEmpty ? _nonFieldErrors.first : null;

  /// Unmodifiable map of all field-level validation errors.
  Map<String, List<String>> get fieldErrors => Map.unmodifiable(_fieldErrors);

  /// Flattened map containing only the first error string per field.
  ///
  /// Ideal for direct mapping to form input validation UI states.
  ///
  /// ```dart
  /// final formErrors = validationErrors.flattenedErrors;
  /// // e.g. {'email': 'Email is required', 'password': 'Too short'}
  /// ```
  Map<String, String> get flattenedErrors {
    final result = <String, String>{};
    for (final entry in _fieldErrors.entries) {
      if (entry.value.isNotEmpty) {
        result[entry.key] = entry.value.first;
      }
    }
    return result;
  }

  /// Whether validation errors exist for [field].
  bool hasError(String field) =>
      _fieldErrors.containsKey(field) && _fieldErrors[field]!.isNotEmpty;

  /// Returns the first error message for [field], or `null` if none exists.
  String? firstError(String field) {
    final list = _fieldErrors[field];
    return (list != null && list.isNotEmpty) ? list.first : null;
  }

  /// Returns all error messages recorded for [field], or `null` if none exist.
  List<String>? errorsFor(String field) => _fieldErrors[field];

  @override
  String toString() =>
      'BloomRpcValidationErrors(fields: $_fieldErrors, general: $_nonFieldErrors)';
}

/// Abstract base exception class for all RPC errors.
abstract class BloomRpcException implements Exception {
  /// Error summary message.
  String get message;

  /// The RPC contract that was executing when the error occurred, or `null`.
  BloomRpcContract<dynamic, dynamic>? get contract;

  /// The target URI of the failed request, or `null`.
  Uri? get uri;
}

/// Exception thrown when the server returns a non-2xx HTTP error status code.
///
/// Carries the HTTP [statusCode], the decoded [responseBody], and automatically
/// parses validation errors accessible via [validationErrors].
///
/// ```dart
/// try {
///   await client.call(getUserContract, null);
/// } on BloomRpcHttpException catch (e) {
///   if (e.isNotFound) {
///     print('User does not exist');
///   } else if (e.isServerError) {
///     print('Server returned error: ${e.statusCode}');
///   }
/// }
/// ```
class BloomRpcHttpException implements BloomRpcException {
  @override
  final String message;

  @override
  final BloomRpcContract<dynamic, dynamic>? contract;

  @override
  final Uri? uri;

  /// HTTP status code returned by the server (e.g. 400, 401, 403, 404, 422, 500).
  final int statusCode;

  /// Raw response body string or decoded JSON object.
  final dynamic responseBody;

  /// Outgoing response headers returned by the server.
  final Map<String, String>? responseHeaders;

  /// Lazily parsed validation errors when [responseBody] contains field validation failures.
  late final BloomRpcValidationErrors? validationErrors;

  /// Creates a [BloomRpcHttpException] with status code, response body, and endpoint details.
  BloomRpcHttpException({
    required this.statusCode,
    this.responseBody,
    this.responseHeaders,
    this.contract,
    this.uri,
    String? message,
  }) : message = message ??
            'HTTP $statusCode ${contract != null ? "on ${contract.method.value} ${contract.pathTemplate}" : ""}' {
    if (isValidationError && responseBody != null) {
      validationErrors = BloomRpcValidationErrors.fromResponse(responseBody);
    } else {
      validationErrors = null;
    }
  }

  /// Whether the status code represents a 404 Not Found error.
  bool get isNotFound => statusCode == 404;

  /// Whether the status code represents a 401 Unauthorized authentication failure.
  bool get isUnauthorized => statusCode == 401;

  /// Whether the status code represents a 403 Forbidden access denial.
  bool get isForbidden => statusCode == 403;

  /// Whether the status code represents a 400 Bad Request or 422 Unprocessable Entity validation error.
  bool get isValidationError => statusCode == 422 || statusCode == 400;

  /// Whether the status code is a client error in the 4xx range.
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether the status code is a server error in the 5xx range.
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  @override
  String toString() => 'BloomRpcHttpException: $message (status: $statusCode)';
}

/// Exception thrown when an RPC call fails due to low-level transport, DNS, or socket errors.
///
/// Distinguishes network disconnects and unreachable hosts from server response errors.
///
/// ```dart
/// try {
///   await client.call(getTasksContract, null);
/// } on BloomRpcTransportException catch (e) {
///   print('Network down: ${e.message}');
/// }
/// ```
class BloomRpcTransportException implements BloomRpcException {
  @override
  final String message;

  @override
  final BloomRpcContract<dynamic, dynamic>? contract;

  @override
  final Uri? uri;

  /// Underlying transport error (e.g. [http.ClientException] or socket failure).
  final Object cause;

  /// Stack trace from the underlying failure.
  final StackTrace? stackTrace;

  /// Creates a [BloomRpcTransportException] wrapping a lower-level transport [cause].
  BloomRpcTransportException({
    required this.cause,
    this.contract,
    this.uri,
    this.stackTrace,
    String? message,
  }) : message = message ?? 'Transport error: $cause';

  @override
  String toString() => 'BloomRpcTransportException: $message';
}

/// Exception thrown when a 2xx response payload fails to decode into the expected output type [TOutput].
///
/// Distinguishes contract mismatches ("the server returned unexpected data") from network or HTTP errors.
///
/// ```dart
/// try {
///   await client.call(getUserContract, null);
/// } on BloomRpcDecodeException catch (e) {
///   print('Contract mismatch: ${e.message}');
///   print('Raw data was: ${e.rawData}');
/// }
/// ```
class BloomRpcDecodeException implements BloomRpcException {
  @override
  final String message;

  @override
  final BloomRpcContract<dynamic, dynamic>? contract;

  @override
  final Uri? uri;

  /// The underlying decode or cast error thrown by [BloomRpcContract.decodeOutput].
  final Object cause;

  /// The raw decoded JSON object or string that failed to match the contract.
  final dynamic rawData;

  /// Stack trace from the decoder failure.
  final StackTrace? stackTrace;

  /// Creates a [BloomRpcDecodeException] with decode [cause] and offending [rawData].
  BloomRpcDecodeException({
    required this.cause,
    required this.rawData,
    this.contract,
    this.uri,
    this.stackTrace,
    String? message,
  }) : message = message ??
            'Failed to decode RPC response for ${contract?.method.value ?? ""} ${contract?.pathTemplate ?? ""}: $cause';

  @override
  String toString() => 'BloomRpcDecodeException: $message';
}

/// Exception thrown when serializing input data into a request payload fails before transmission.
class BloomRpcEncodeException implements BloomRpcException {
  @override
  final String message;

  @override
  final BloomRpcContract<dynamic, dynamic>? contract;

  @override
  final Uri? uri;

  /// The underlying encoding error.
  final Object cause;

  /// Stack trace from the encoder failure.
  final StackTrace? stackTrace;

  /// Creates a [BloomRpcEncodeException] with encoding [cause].
  BloomRpcEncodeException({
    required this.cause,
    this.contract,
    this.uri,
    this.stackTrace,
    String? message,
  }) : message = message ?? 'Failed to encode RPC input: $cause';

  @override
  String toString() => 'BloomRpcEncodeException: $message';
}

/// Exception thrown when an RPC request exceeds the configured network timeout duration.
class BloomRpcTimeoutException implements BloomRpcException {
  @override
  final String message;

  @override
  final BloomRpcContract<dynamic, dynamic>? contract;

  @override
  final Uri? uri;

  /// The duration limit that was exceeded.
  final Duration timeout;

  /// Creates a [BloomRpcTimeoutException] for [timeout].
  BloomRpcTimeoutException({
    required this.timeout,
    this.contract,
    this.uri,
    String? message,
  }) : message = message ??
            'RPC request exceeded timeout of ${timeout.inSeconds}s for ${contract?.method.value ?? ""} ${contract?.pathTemplate ?? ""}';

  @override
  String toString() => 'BloomRpcTimeoutException: $message';
}

/// Exception thrown when an in-flight RPC request is aborted via [BloomRpcCancelToken].
class BloomRpcCancelledException implements BloomRpcException {
  @override
  final String message;

  @override
  final BloomRpcContract<dynamic, dynamic>? contract;

  @override
  final Uri? uri;

  /// Optional cancellation reason.
  final String reason;

  /// Creates a [BloomRpcCancelledException] with cancellation [reason].
  BloomRpcCancelledException({
    this.reason = 'Request was cancelled',
    this.contract,
    this.uri,
  }) : message = 'RPC request cancelled: $reason';

  @override
  String toString() => 'BloomRpcCancelledException: $message';
}

/// Exception thrown when a required path parameter in a contract path template is missing.
class BloomRpcPathParameterException implements BloomRpcException {
  @override
  final String message;

  @override
  final BloomRpcContract<dynamic, dynamic>? contract;

  @override
  final Uri? uri;

  /// The name of the missing path parameter.
  final String paramName;

  /// The path template where the parameter was declared.
  final String pathTemplate;

  /// The HTTP method of the endpoint.
  final String method;

  /// Creates a [BloomRpcPathParameterException] naming the missing [paramName].
  BloomRpcPathParameterException({
    required this.paramName,
    required this.pathTemplate,
    required this.method,
    this.contract,
    this.uri,
  }) : message =
            'Missing required path parameter ":$paramName" for endpoint $method $pathTemplate';

  @override
  String toString() => 'BloomRpcPathParameterException: $message';
}

// ─── RPC Client ─────────────────────────────────────────────────────────────

/// High-level typed RPC client that executes [BloomRpcContract] endpoints over HTTP.
///
/// [BloomRpcClient] coordinates contract execution:
/// - **Path Interpolation**: Replaces `:params` with checked, percent-encoded values.
/// - **Query & Body Handling**: Routes input to query parameters on GETs and JSON bodies on POST/PUT/PATCH.
/// - **Authentication**: Injects Bearer tokens dynamically via [authTokenProvider] or statically via [authToken].
/// - **Structured Errors**: Catches network failures and translates them into strongly typed
///   [BloomRpcHttpException], [BloomRpcTransportException], or [BloomRpcDecodeException] instances.
/// - **Cancellation & Timeout**: Supports per-request cancellation tokens ([BloomRpcCancelToken]) and timeouts.
///
/// ### Example
/// ```dart
/// final rpcClient = BloomRpcClient(
///   baseUrl: 'https://api.example.com/v1',
///   authTokenProvider: () => authStore.token.value,
///   timeout: Duration(seconds: 10),
/// );
///
/// // Execute typed contract with full output type inference
/// final Task task = await rpcClient.call(
///   getTaskContract,
///   null,
///   pathParams: {'id': 'task-123'},
/// );
/// ```
class BloomRpcClient {
  /// The underlying HTTP client transport.
  final BloomHttpClient httpClient;

  /// Base URL prefix for relative contract paths.
  final String? baseUrl;

  /// Default timeout applied to RPC calls.
  final Duration timeout;

  /// Default headers attached to outgoing RPC requests.
  final Map<String, String> defaultHeaders;

  /// Static Bearer authentication token.
  String? authToken;

  /// Dynamic Bearer authentication token provider callback.
  String? Function()? authTokenProvider;

  /// Ordered list of request interceptors executed prior to dispatching requests.
  List<RequestInterceptor> get requestInterceptors =>
      httpClient.requestInterceptors;

  /// Ordered list of response interceptors executed upon receiving responses.
  List<ResponseInterceptor> get responseInterceptors =>
      httpClient.responseInterceptors;

  /// Creates a [BloomRpcClient] configured with [baseUrl], [timeout], and authentication options.
  ///
  /// If [httpClient] is omitted, automatically creates a new [BloomHttpClient].
  BloomRpcClient({
    BloomHttpClient? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 15),
    Map<String, String>? defaultHeaders,
    this.authToken,
    this.authTokenProvider,
  })  : baseUrl = baseUrl ??
            BloomEnv.getOrNull('API_BASE_URL') ??
            BloomEnv.getOrNull('API_URL'),
        defaultHeaders = defaultHeaders ?? const {},
        httpClient = httpClient ??
            BloomHttpClient(
              baseUrl: baseUrl,
              timeout: timeout,
              authToken: authToken,
              authTokenProvider: authTokenProvider,
            ) {
    if (authToken != null) this.httpClient.authToken = authToken;
    if (authTokenProvider != null) {
      this.httpClient.authTokenProvider = authTokenProvider;
    }
  }

  /// Executes a typed [contract] with [input], returning the decoded [TOutput].
  ///
  /// - [pathParams]: Map of path parameter substitutions for tokens in the contract path template.
  /// - [queryParameters]: Additional query parameters appended to the URL.
  /// - [headers]: Custom headers merged into request headers for this call.
  /// - [timeout]: Custom timeout duration overriding [BloomRpcClient.timeout].
  /// - [cancelToken]: Token used to abort the request while in-flight.
  ///
  /// Throws:
  /// - [BloomRpcHttpException]: On non-2xx HTTP responses from the server.
  /// - [BloomRpcTransportException]: On network disconnects or socket failures.
  /// - [BloomRpcDecodeException]: When the server payload does not match [TOutput].
  /// - [BloomRpcCancelledException]: If aborted via [cancelToken].
  /// - [BloomRpcTimeoutException]: If the call exceeds [timeout].
  ///
  /// ```dart
  /// final user = await client.call(
  ///   getUserContract,
  ///   null,
  ///   pathParams: {'id': '42'},
  /// );
  /// ```
  Future<TOutput> call<TInput, TOutput>(
    BloomRpcContract<TInput, TOutput> contract,
    TInput input, {
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    BloomRpcCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled(contract);

    // 1. Resolve path template
    final String resolvedPath;
    try {
      resolvedPath =
          contract.resolvePath(pathParams: pathParams, input: input);
    } catch (e) {
      if (e is BloomRpcException) rethrow;
      throw BloomRpcEncodeException(cause: e, contract: contract);
    }

    // 2. Prepare merged headers
    final mergedHeaders = <String, String>{
      ...defaultHeaders,
      if (headers != null) ...headers,
    };

    // 3. Prepare payload and query parameters based on HTTP method
    final isGetStyle = contract.method == BloomHttpMethod.get ||
        contract.method == BloomHttpMethod.head ||
        contract.method == BloomHttpMethod.options;

    final mergedQueryParams = <String, dynamic>{};
    if (queryParameters != null) {
      mergedQueryParams.addAll(queryParameters);
    }

    dynamic bodyPayload;

    if (isGetStyle) {
      if (input != null) {
        dynamic encoded;
        if (contract.encodeInput != null) {
          try {
            encoded = contract.encodeInput!(input);
          } catch (e, st) {
            throw BloomRpcEncodeException(
                cause: e, contract: contract, stackTrace: st);
          }
        } else {
          encoded = input;
        }

        if (encoded is Map) {
          final pathKeys = contract.pathParameters.toSet();
          for (final entry in encoded.entries) {
            final keyStr = entry.key.toString();
            if (!pathKeys.contains(keyStr)) {
              mergedQueryParams[keyStr] = entry.value;
            }
          }
        }
      }
    } else {
      if (input != null) {
        if (contract.encodeInput != null) {
          try {
            bodyPayload = contract.encodeInput!(input);
          } catch (e, st) {
            throw BloomRpcEncodeException(
                cause: e, contract: contract, stackTrace: st);
          }
        } else {
          bodyPayload = input;
        }
      }
    }

    final effectiveTimeout = timeout ?? this.timeout;

    // 4. Dispatch request
    Future<dynamic> requestFuture;
    switch (contract.method) {
      case BloomHttpMethod.get:
      case BloomHttpMethod.head:
      case BloomHttpMethod.options:
        requestFuture = httpClient.get(
          resolvedPath,
          headers: mergedHeaders,
          queryParameters:
              mergedQueryParams.isNotEmpty ? mergedQueryParams : null,
        );
        break;
      case BloomHttpMethod.post:
        requestFuture = httpClient.post(
          resolvedPath,
          body: bodyPayload,
          headers: mergedHeaders,
          queryParameters:
              mergedQueryParams.isNotEmpty ? mergedQueryParams : null,
        );
        break;
      case BloomHttpMethod.put:
        requestFuture = httpClient.put(
          resolvedPath,
          body: bodyPayload,
          headers: mergedHeaders,
          queryParameters:
              mergedQueryParams.isNotEmpty ? mergedQueryParams : null,
        );
        break;
      case BloomHttpMethod.patch:
        requestFuture = httpClient.patch(
          resolvedPath,
          body: bodyPayload,
          headers: mergedHeaders,
          queryParameters:
              mergedQueryParams.isNotEmpty ? mergedQueryParams : null,
        );
        break;
      case BloomHttpMethod.delete:
        requestFuture = httpClient.delete(
          resolvedPath,
          body: bodyPayload,
          headers: mergedHeaders,
          queryParameters:
              mergedQueryParams.isNotEmpty ? mergedQueryParams : null,
        );
        break;
    }

    // 5. Wrap with cancellation token and timeout
    final dynamic rawResponse;
    try {
      rawResponse = await _raceWithCancellation(
        requestFuture.timeout(effectiveTimeout),
        cancelToken,
        contract,
      );
    } on TimeoutException {
      throw BloomRpcTimeoutException(
        timeout: effectiveTimeout,
        contract: contract,
      );
    } on BloomRpcException {
      rethrow;
    } on http.ClientException catch (e, st) {
      // Inspect message for HTTP status pattern "HTTP <statusCode>: <body>"
      final httpMatch =
          RegExp(r'^HTTP\s+(\d{3}):\s*(.*)$', dotAll: true).firstMatch(e.message);
      if (httpMatch != null) {
        final statusCode = int.parse(httpMatch.group(1)!);
        final rawBody = httpMatch.group(2) ?? '';
        dynamic decodedBody;
        try {
          decodedBody = jsonDecode(rawBody);
        } catch (_) {
          decodedBody = rawBody;
        }

        throw BloomRpcHttpException(
          statusCode: statusCode,
          responseBody: decodedBody,
          contract: contract,
          uri: e.uri,
        );
      }

      throw BloomRpcTransportException(
        cause: e,
        contract: contract,
        uri: e.uri,
        stackTrace: st,
      );
    } catch (e, st) {
      throw BloomRpcTransportException(
        cause: e,
        contract: contract,
        stackTrace: st,
      );
    }

    // 6. Decode output
    try {
      // A void/nullable output with no body decodes to null. `TOutput == void`
      // is not valid Dart; `null is TOutput` is the correct way to ask whether
      // the output type admits null.
      if (rawResponse == null && null is TOutput) {
        return null as TOutput;
      }
      final decode = contract.decodeOutput ?? _defaultDecode<TOutput>;
      return decode(rawResponse);
    } catch (e, st) {
      throw BloomRpcDecodeException(
        cause: e,
        rawData: rawResponse,
        contract: contract,
        stackTrace: st,
      );
    }
  }

  /// Alias for [call].
  Future<TOutput> invoke<TInput, TOutput>(
    BloomRpcContract<TInput, TOutput> contract,
    TInput input, {
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    BloomRpcCancelToken? cancelToken,
  }) =>
      call(
        contract,
        input,
        pathParams: pathParams,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
        cancelToken: cancelToken,
      );

  /// Creates a reactive [BloomQuery] bound to this client and [contract].
  ///
  /// ```dart
  /// final userQuery = client.query(getUserContract, null, pathParams: {'id': '123'});
  /// ```
  BloomQuery<TOutput> query<TInput, TOutput>(
    BloomRpcContract<TInput, TOutput> contract,
    TInput input, {
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration staleTime = const Duration(minutes: 5),
    Duration cacheTime = const Duration(minutes: 30),
    bool enabled = true,
    TOutput? initialData,
    List<dynamic>? customKey,
    Duration? timeout,
  }) =>
      rpcQuery(
        this,
        contract,
        input,
        pathParams: pathParams,
        queryParameters: queryParameters,
        headers: headers,
        staleTime: staleTime,
        cacheTime: cacheTime,
        enabled: enabled,
        initialData: initialData,
        customKey: customKey,
        timeout: timeout,
      );

  /// Creates a declarative [BloomMutation] bound to this client and [contract].
  ///
  /// ```dart
  /// final createTaskMutation = client.mutation(createTaskContract);
  /// ```
  BloomMutation<TOutput, TInput> mutation<TInput, TOutput>(
    BloomRpcContract<TInput, TOutput> contract, {
    List<List<dynamic>> invalidateKeys = const [],
    List<BloomRpcContract<dynamic, dynamic>> invalidateContracts = const [],
    Map<String, dynamic>? Function(TInput input)? pathParamsBuilder,
    Map<String, dynamic>? defaultPathParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    List<dynamic>? optimisticKey,
    OptimisticUpdater<TOutput, TInput>? optimisticData,
    OnMutateCallback<TInput>? onMutate,
    OnSuccessCallback<TOutput, TInput>? onSuccess,
    OnErrorCallback<TInput>? onError,
    OnSettledCallback<TOutput, TInput>? onSettled,
  }) =>
      rpcMutation(
        this,
        contract,
        invalidateKeys: invalidateKeys,
        invalidateContracts: invalidateContracts,
        pathParamsBuilder: pathParamsBuilder,
        defaultPathParams: defaultPathParams,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
        optimisticKey: optimisticKey,
        optimisticData: optimisticData,
        onMutate: onMutate,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
      );

  /// Helper racing a [future] against a [cancelToken].
  Future<T> _raceWithCancellation<T>(
    Future<T> future,
    BloomRpcCancelToken? cancelToken,
    BloomRpcContract<dynamic, dynamic>? contract,
  ) {
    if (cancelToken == null) return future;
    if (cancelToken.isCancelled) {
      throw BloomRpcCancelledException(
        reason: cancelToken.reason ?? 'Request was cancelled',
        contract: contract,
      );
    }

    final completer = Completer<T>();

    cancelToken.onCancelled.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          BloomRpcCancelledException(
            reason: cancelToken.reason ?? 'Request was cancelled',
            contract: contract,
          ),
        );
      }
    });

    future.then((val) {
      if (!completer.isCompleted) {
        completer.complete(val);
      }
    }).catchError((Object err, StackTrace st) {
      if (!completer.isCompleted) {
        completer.completeError(err, st);
      }
    });

    return completer.future;
  }

  /// Closes the underlying HTTP client transport.
  void close() => httpClient.close();
}

// ─── Data Layer Integration ─────────────────────────────────────────────────

/// Creates a reactive [BloomQuery] bound to an RPC [contract] and [input].
///
/// Automatically derives a normalized cache key via [BloomRpcContract.cacheKey] and
/// executes [client.call] during fetches, providing automatic caching, request
/// deduplication, background revalidation, and reactive signal state ([BloomQuery.data],
/// [BloomQuery.status], [BloomQuery.error]).
///
/// ```dart
/// final userQuery = rpcQuery<void, User>(
///   client,
///   getUserContract,
///   null,
///   pathParams: {'id': 'user-123'},
///   staleTime: Duration(minutes: 2),
/// );
///
/// BloomNode renderUser() => Live(() => switch (userQuery.status.value) {
///   QueryStatus.loading => P(text: 'Loading user...'),
///   QueryStatus.error => P(text: 'Error: ${userQuery.error.value}'),
///   QueryStatus.success => H1(text: userQuery.data.value?.name ?? 'Anonymous'),
///   QueryStatus.idle => P(text: 'Idle'),
/// });
/// ```
///
/// See also:
/// - [BloomQuery], the underlying reactive query coordinator.
/// - [rpcMutation], for state-modifying mutations.
BloomQuery<TOutput> rpcQuery<TInput, TOutput>(
  BloomRpcClient client,
  BloomRpcContract<TInput, TOutput> contract,
  TInput input, {
  Map<String, dynamic>? pathParams,
  Map<String, dynamic>? queryParameters,
  Map<String, String>? headers,
  Duration staleTime = const Duration(minutes: 5),
  Duration cacheTime = const Duration(minutes: 30),
  bool enabled = true,
  TOutput? initialData,
  List<dynamic>? customKey,
  Duration? timeout,
}) {
  final key = customKey ??
      contract.cacheKey(
        input,
        pathParams: pathParams,
        queryParameters: queryParameters,
      );

  return BloomQuery<TOutput>(
    key: key,
    fetch: () => client.call(
      contract,
      input,
      pathParams: pathParams,
      queryParameters: queryParameters,
      headers: headers,
      timeout: timeout,
    ),
    staleTime: staleTime,
    cacheTime: cacheTime,
    enabled: enabled,
    initialData: initialData,
  );
}

/// Creates a declarative [BloomMutation] bound to an RPC [contract].
///
/// Automatically executes [client.call] on [BloomMutation.mutate], with support for:
/// - **Automated Cache Invalidation**: Invalidates cache queries matching [invalidateKeys]
///   or [invalidateContracts] upon successful resolution.
/// - **Optimistic Updates & Rollback**: Writes anticipated state changes to [optimisticKey]
///   before network response and automatically rolls back if the mutation fails.
/// - **Reactive Signals**: Exposes reactive [BloomMutation.status], [BloomMutation.data],
///   and [BloomMutation.error] signals.
///
/// ```dart
/// final createTodo = rpcMutation<CreateTodoInput, Todo>(
///   client,
///   createTodoContract,
///   invalidateContracts: [getTodoListContract],
///   onError: (err, input, ctx) => print('Failed to create todo: $err'),
/// );
///
/// await createTodo.mutate(CreateTodoInput(title: 'New task'));
/// ```
///
/// See also:
/// - [BloomMutation], the underlying mutation state machine.
/// - [rpcQuery], for fetching and caching query data.
BloomMutation<TOutput, TInput> rpcMutation<TInput, TOutput>(
  BloomRpcClient client,
  BloomRpcContract<TInput, TOutput> contract, {
  List<List<dynamic>> invalidateKeys = const [],
  List<BloomRpcContract<dynamic, dynamic>> invalidateContracts = const [],
  Map<String, dynamic>? Function(TInput input)? pathParamsBuilder,
  Map<String, dynamic>? defaultPathParams,
  Map<String, dynamic>? queryParameters,
  Map<String, String>? headers,
  Duration? timeout,
  List<dynamic>? optimisticKey,
  OptimisticUpdater<TOutput, TInput>? optimisticData,
  OnMutateCallback<TInput>? onMutate,
  OnSuccessCallback<TOutput, TInput>? onSuccess,
  OnErrorCallback<TInput>? onError,
  OnSettledCallback<TOutput, TInput>? onSettled,
}) {
  final combinedInvalidateKeys = <List<dynamic>>[
    ...invalidateKeys,
    for (final c in invalidateContracts)
      ['rpc', c.method.value.toLowerCase(), c.pathTemplate],
  ];

  return BloomMutation<TOutput, TInput>(
    mutateFn: (params) {
      final pathParams = pathParamsBuilder != null
          ? pathParamsBuilder(params)
          : defaultPathParams;
      return client.call(
        contract,
        params,
        pathParams: pathParams,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
      );
    },
    optimisticKey: optimisticKey,
    optimisticData: optimisticData,
    invalidateKeys: combinedInvalidateKeys,
    onMutate: onMutate,
    onSuccess: onSuccess,
    onError: onError,
    onSettled: onSettled,
  );
}

// ─── Server-Side Binding & Router ───────────────────────────────────────────

/// Pure-Dart abstraction representing an incoming HTTP server request for RPC routing.
///
/// Decoupled from specific server runtimes (such as `bloom_server` or Shelf), allowing
/// contract bindings to be executed in any server environment or during SSR testing.
class BloomRpcServerRequest {
  /// HTTP method of the request (e.g. `'GET'`, `'POST'`).
  final String method;

  /// Target path of the request (e.g. `'/api/v1/tasks/123'`).
  final String path;

  /// Request headers map.
  final Map<String, String> headers;

  /// Parsed query parameters map.
  final Map<String, String> queryParams;

  /// Raw request body string or decoded JSON object.
  final dynamic body;

  /// Ambient server request object (e.g. `BloomRequest` or context token).
  final Object? rawRequest;

  /// Arbitrary request context attributes (e.g. authenticated user, trace IDs).
  final Map<String, Object?> context;

  /// Creates a [BloomRpcServerRequest] representing an incoming HTTP request.
  const BloomRpcServerRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.queryParams = const {},
    this.body,
    this.rawRequest,
    this.context = const {},
  });
}

/// Pure-Dart abstraction representing an outgoing HTTP server response for RPC routing.
class BloomRpcServerResponse {
  /// HTTP status code (e.g. 200, 201, 400, 404, 422, 500).
  final int statusCode;

  /// Serialized response payload (string or JSON-encodable map/list).
  final dynamic body;

  /// Outgoing response headers.
  final Map<String, String> headers;

  /// Creates a [BloomRpcServerResponse] with [statusCode], [body], and [headers].
  const BloomRpcServerResponse({
    required this.statusCode,
    this.body,
    this.headers = const {'content-type': 'application/json; charset=utf-8'},
  });

  /// Factory for a successful JSON response (status 200).
  factory BloomRpcServerResponse.ok(dynamic body,
          {Map<String, String>? headers}) =>
      BloomRpcServerResponse(
        statusCode: 200,
        body: body,
        headers: headers ??
            const {'content-type': 'application/json; charset=utf-8'},
      );

  /// Factory for a created JSON response (status 201).
  factory BloomRpcServerResponse.created(dynamic body,
          {Map<String, String>? headers}) =>
      BloomRpcServerResponse(
        statusCode: 201,
        body: body,
        headers: headers ??
            const {'content-type': 'application/json; charset=utf-8'},
      );

  /// Factory for a bad request response (status 400).
  factory BloomRpcServerResponse.badRequest(dynamic body,
          {Map<String, String>? headers}) =>
      BloomRpcServerResponse(
        statusCode: 400,
        body: body,
        headers: headers ??
            const {'content-type': 'application/json; charset=utf-8'},
      );

  /// Factory for a validation error response (status 422).
  factory BloomRpcServerResponse.validationError(dynamic errors,
          {Map<String, String>? headers}) =>
      BloomRpcServerResponse(
        statusCode: 422,
        body: errors is Map ? errors : {'errors': errors},
        headers: headers ??
            const {'content-type': 'application/json; charset=utf-8'},
      );

  /// Factory for an internal server error response (status 500).
  factory BloomRpcServerResponse.serverError(String message,
          {Map<String, String>? headers}) =>
      BloomRpcServerResponse(
        statusCode: 500,
        body: {'error': message, 'statusCode': 500},
        headers: headers ??
            const {'content-type': 'application/json; charset=utf-8'},
      );
}

/// Request execution context passed to server-side [BloomRpcHandler] implementations.
///
/// Exposes extracted path parameters, query parameters, headers, and ambient context.
class BloomRpcServerContext {
  /// The matched contract being handled.
  final BloomRpcContract<dynamic, dynamic> contract;

  /// Extracted path parameters from the URL template (e.g. `{'id': '123'}`).
  final Map<String, String> pathParams;

  /// Request query parameters.
  final Map<String, String> queryParams;

  /// Request headers.
  final Map<String, String> headers;

  /// The original incoming server request.
  final BloomRpcServerRequest request;

  /// Arbitrary contextual attributes (e.g. authenticated user, database executor).
  final Map<String, Object?> context;

  /// Creates a [BloomRpcServerContext] wrapping request metadata.
  const BloomRpcServerContext({
    required this.contract,
    required this.pathParams,
    required this.queryParams,
    required this.headers,
    required this.request,
    this.context = const {},
  });
}

/// Server-side handler callback signature that implements a [BloomRpcContract].
///
/// Accepts a [BloomRpcServerContext] and the typed, decoded [input], returning the
/// typed [TOutput] result asynchronously.
///
/// ```dart
/// BloomRpcHandler<CreateTaskInput, Task> createTaskHandler = (ctx, input) async {
///   final db = ctx.context['db'] as DbExecutor;
///   return taskService.createTask(db, input.title);
/// };
/// ```
typedef BloomRpcHandler<TInput, TOutput> = FutureOr<TOutput> Function(
  BloomRpcServerContext context,
  TInput input,
);

/// Associates a [BloomRpcContract] with its server-side [BloomRpcHandler] implementation.
class BloomRpcBinding<TInput, TOutput> {
  /// The contract specification defining method, path, and codecs.
  final BloomRpcContract<TInput, TOutput> contract;

  /// The server handler callback executing the business logic.
  final BloomRpcHandler<TInput, TOutput> handler;

  /// Creates a binding between [contract] and [handler].
  const BloomRpcBinding(this.contract, this.handler);

  /// Executes this binding against [context] with raw input [rawInput].
  Future<BloomRpcServerResponse> execute(
    BloomRpcServerContext context,
    dynamic rawInput,
  ) async {
    try {
      final TInput typedInput;
      if (contract.decodeInput != null) {
        typedInput = contract.decodeInput!(rawInput);
      } else if (rawInput is TInput) {
        typedInput = rawInput;
      } else if (rawInput == null && null is TInput) {
        typedInput = null as TInput;
      } else {
        typedInput = rawInput as TInput;
      }

      final result = await handler(context, typedInput);

      final dynamic encodedOutput;
      if (contract.encodeOutput != null) {
        encodedOutput = contract.encodeOutput!(result);
      } else {
        encodedOutput = result;
      }

      return BloomRpcServerResponse.ok(encodedOutput);
    } catch (e) {
      if (e is BloomRpcHttpException) {
        return BloomRpcServerResponse(
          statusCode: e.statusCode,
          body: e.responseBody,
        );
      }
      return BloomRpcServerResponse.serverError(e.toString());
    }
  }
}

/// Server-side RPC router and registry mapping [BloomRpcContract] endpoints to [BloomRpcHandler] callbacks.
///
/// Provides a unified registry for declaring server implementations of shared RPC contracts,
/// matching incoming requests, extracting typed parameters, and invoking handlers.
///
/// ### Server Integration Example
/// ```dart
/// // 1. Define shared contract
/// const getTask = BloomRpcContract<void, Task>.get(
///   '/tasks/:id',
///   decodeOutput: Task.fromJson,
/// );
///
/// // 2. Register server implementation
/// final rpcRouter = BloomRpcRouter();
/// rpcRouter.bind(getTask, (ctx, _) async {
///   final taskId = ctx.pathParams['id']!;
///   return taskRepository.findById(taskId);
/// });
///
/// // 3. Mount onto server / bloom_server adapter
/// // In a bloom_server application:
/// for (final binding in rpcRouter.bindings) {
///   serverRouter.add(binding.contract.method.value, binding.contract.pathTemplate, (req) async {
///     final rpcReq = BloomRpcServerRequest(
///       method: req.method,
///       path: req.path,
///       headers: req.headers,
///       queryParams: req.queryParams,
///       body: req.bodyJson,
///       rawRequest: req,
///     );
///     final res = await rpcRouter.handle(rpcReq);
///     return BloomResponse.json(res.body, statusCode: res.statusCode);
///   });
/// }
/// ```
class BloomRpcRouter {
  final List<BloomRpcBinding<dynamic, dynamic>> _bindings = [];

  /// An unmodifiable list of all registered RPC endpoint bindings.
  List<BloomRpcBinding<dynamic, dynamic>> get bindings =>
      List.unmodifiable(_bindings);

  /// Registers a server handler for [contract].
  ///
  /// ```dart
  /// rpcRouter.bind(getTaskContract, (ctx, input) async {
  ///   final taskId = ctx.pathParams['id']!;
  ///   return taskDb.get(taskId);
  /// });
  /// ```
  void bind<TInput, TOutput>(
    BloomRpcContract<TInput, TOutput> contract,
    BloomRpcHandler<TInput, TOutput> handler,
  ) {
    _bindings.add(BloomRpcBinding<TInput, TOutput>(contract, handler));
  }

  /// Dispatches an incoming [request] to the matching registered contract binding.
  ///
  /// Matches HTTP verb and path template, extracts path parameters, decodes input,
  /// executes the handler, and returns a [BloomRpcServerResponse].
  ///
  /// ```dart
  /// final response = await rpcRouter.handle(serverRequest);
  /// ```
  Future<BloomRpcServerResponse> handle(BloomRpcServerRequest request) async {
    for (final binding in _bindings) {
      if (binding.contract.method.value.toUpperCase() !=
          request.method.toUpperCase()) {
        continue;
      }

      final pathParams = binding.contract.matchPath(request.path);
      if (pathParams == null) continue;

      final serverContext = BloomRpcServerContext(
        contract: binding.contract,
        pathParams: pathParams,
        queryParams: request.queryParams,
        headers: request.headers,
        request: request,
        context: request.context,
      );

      dynamic rawInput;
      if (binding.contract.method == BloomHttpMethod.get ||
          binding.contract.method == BloomHttpMethod.head ||
          binding.contract.method == BloomHttpMethod.options) {
        rawInput = {...request.queryParams, ...pathParams};
      } else {
        rawInput = request.body;
      }

      return binding.execute(serverContext, rawInput);
    }

    return BloomRpcServerResponse(
      statusCode: 404,
      body: {
        'error':
            'No RPC handler found for ${request.method} ${request.path}',
        'statusCode': 404,
      },
    );
  }
}
