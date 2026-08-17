# bloom_validate

Declarative, strictly-typed request body and DTO validation for Bloom full-stack applications and API routes.

`bloom_validate` brings the declarative, zero-codegen validation pattern of `BloomEnvironmentSchema` to HTTP request bodies and JSON payloads.

---

## Features

- **Zero-Codegen**: Pure, lightweight Dart with zero code-generation dependencies.
- **Fail-Fast Error Accumulation**: Mirrors `BloomEnvironmentSchema` error-collection semantics.
- **HTTP 400 Ready**: Built-in `BloomValidationException.toResponse()` for instant RFC-compliant JSON error responses.
- **Rich Rule Set**: Built-in validators for strings, numbers, booleans, URIs, emails, length constraints, number ranges, enums, nested JSON objects, and item lists.

---

## Usage Examples

### 1. Basic Signup Request DTO

Define a schema subclass extending `BloomRequestSchema` and declare required and optional fields:

```dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_validate/bloom_validate.dart';

class SignupRequestSchema extends BloomRequestSchema {
  SignupRequestSchema(super.data);
  SignupRequestSchema.fromRequest(super.request) : super.fromRequest();

  late final String name = requireStringLength('name', min: 2, max: 50, description: 'Full name');
  late final String email = requireEmail('email', description: 'User email address');
  late final String password = requireStringLength('password', min: 8, max: 128, description: 'Account password');
  late final String? referralCode = optionalString('referralCode');

  @override
  void validate() {
    name;
    email;
    password;
    referralCode;
  }
}
```

Use the schema inside a `BloomRouteHandler`:

```dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_validate/bloom_validate.dart';

Future<BloomResponse> handleSignup(BloomRequest request) async {
  final SignupRequestSchema schema;
  try {
    schema = BloomRequestSchema.validateSchema(SignupRequestSchema.fromRequest(request));
  } on BloomValidationException catch (e) {
    // Automatically returns HTTP 400 Bad Request with {"error": "...", "errors": [...]}
    return e.toResponse();
  }

  // Access strongly-typed, validated values directly:
  final name = schema.name;
  final email = schema.email;
  final password = schema.password;

  return BloomResponse.json({
    'message': 'User registered successfully',
    'email': email,
    'name': name,
  }, statusCode: 201);
}
```

---

### 2. Task & List Creation with Defaults and Ranges

```dart
class CreateTaskSchema extends BloomRequestSchema {
  CreateTaskSchema(super.data);
  CreateTaskSchema.fromRequest(super.request) : super.fromRequest();

  late final String title = requireStringLength('title', min: 1, max: 200);
  late final int priority = optionalIntRange('priority', min: 1, max: 5, defaultValue: 3)!;
  late final bool done = optionalBool('done', defaultValue: false);
  late final Uri? callbackUrl = optionalUri('callbackUrl');

  @override
  void validate() {
    title;
    priority;
    done;
    callbackUrl;
  }
}

Future<BloomResponse> handleCreateTask(BloomRequest request) async {
  try {
    final schema = BloomRequestSchema.validateSchema(CreateTaskSchema.fromRequest(request));

    return BloomResponse.json({
      'title': schema.title,
      'priority': schema.priority,
      'done': schema.done,
      'callbackUrl': schema.callbackUrl?.toString(),
    }, statusCode: 201);
  } on BloomValidationException catch (e) {
    return e.toResponse();
  }
}
```

---

### 3. Nested Objects, Enums, and Lists

```dart
enum OrderStatus { pending, processing, shipped, delivered }

class OrderItemSchema extends BloomRequestSchema {
  OrderItemSchema(super.data);

  late final String productId = requireString('productId');
  late final int quantity = requireIntRange('quantity', min: 1, max: 99);
  late final double price = requireDouble('price');

  @override
  void validate() {
    productId;
    quantity;
    price;
  }
}

class CreateOrderSchema extends BloomRequestSchema {
  CreateOrderSchema(super.data);
  CreateOrderSchema.fromRequest(super.request) : super.fromRequest();

  late final String customerId = requireString('customerId');
  late final OrderStatus status = optionalEnum<OrderStatus>(
    'status',
    OrderStatus.values,
    defaultValue: OrderStatus.pending,
  )!;
  late final List<OrderItemSchema> items = requireList(
    'items',
    (json) => OrderItemSchema(json),
    minLength: 1,
    description: 'Order line items',
  );

  @override
  void validate() {
    customerId;
    status;
    items;
  }
}
```

---

## Error Response Format

When validation fails, `e.toResponse()` produces a standard structured JSON response:

```json
{
  "error": "Field \"email\" is not a valid email address: \"invalid-email\".",
  "errors": [
    "Field \"email\" is not a valid email address: \"invalid-email\"."
  ],
  "statusCode": 400
}
```
