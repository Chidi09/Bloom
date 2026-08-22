/// Strongly-typed HTTP error hierarchy, sibling package exception mapping registry, and
/// HTTP error-rendering middleware for Bloom applications.
///
/// Designed to sit as the outermost middleware for `BloomApiRouter`, catching typed domain
/// exceptions and formatting standard JSON error payloads with environment-aware masking.
///
/// ```dart
/// import 'package:bloom_server/bloom_server.dart';
/// import 'package:bloom_errors/bloom_errors.dart';
///
/// void main() async {
///   final router = BloomApiRouter();
///
///   // Register BloomErrorMiddleware as the FIRST global middleware
///   router.use(const BloomErrorMiddleware());
///
///   // Downstream route handler throwing strongly-typed HTTP exceptions
///   router.get('/api/users/:id', (req) async {
///     final id = req.params['id'];
///     if (id != '42') {
///       throw BloomNotFoundException('User with ID $id was not found', {'user_id': id});
///     }
///     return BloomResponse.json({'id': id, 'name': 'Jane Doe'});
///   });
/// }
/// ```
library;

export 'src/error_mapper.dart';
export 'src/error_middleware.dart';
export 'src/http_exception.dart';
