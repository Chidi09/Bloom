/// Declarative, strictly-typed request body and DTO validation for Bloom applications.
///
/// Provides zero-codegen validation for HTTP request bodies, query params, and JSON payloads
/// with fail-fast error accumulation, built-in validation rules, and direct conversion
/// of validation errors into standard HTTP 400 Bad Request responses.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_server.dart';
/// import 'package:bloom_validate/bloom_validate.dart';
///
/// class SignupRequestSchema extends BloomRequestSchema {
///   SignupRequestSchema(super.data);
///   SignupRequestSchema.fromRequest(super.request) : super.fromRequest();
///
///   late final String name = requireStringLength('name', min: 2, max: 50, description: 'Full name');
///   late final String email = requireEmail('email', description: 'User email address');
///   late final String password = requireStringLength('password', min: 8, max: 128, description: 'Account password');
///   late final String? referralCode = optionalString('referralCode');
///
///   @override
///   void validate() {
///     name;
///     email;
///     password;
///     referralCode;
///   }
/// }
///
/// Future<BloomResponse> handleSignup(BloomRequest request) async {
///   try {
///     final schema = BloomRequestSchema.validateSchema(SignupRequestSchema.fromRequest(request));
///     return BloomResponse.json({
///       'message': 'User registered successfully',
///       'email': schema.email,
///       'name': schema.name,
///     }, statusCode: 201);
///   } on BloomValidationException catch (e) {
///     return e.toResponse();
///   }
/// }
/// ```
library bloom_validate;

export 'src/errors.dart';
export 'src/rules.dart';
export 'src/schema.dart';

