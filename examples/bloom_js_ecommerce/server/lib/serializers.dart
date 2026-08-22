import 'package:bloom_validate/bloom_validate.dart';

/// Request body schema for user registration.
class SignupRequestSchema extends BloomRequestSchema {
  SignupRequestSchema(super.data);
  SignupRequestSchema.fromRequest(super.request) : super.fromRequest();

  late final String name = requireStringLength('name', min: 2, max: 100, description: 'User full name');
  late final String email = requireEmail('email', description: 'Account email address');
  late final String password = requireStringLength('password', min: 8, max: 128, description: 'Account password');

  @override
  void validate() {
    name;
    email;
    password;
  }
}

/// Request body schema for user login.
class LoginRequestSchema extends BloomRequestSchema {
  LoginRequestSchema(super.data);
  LoginRequestSchema.fromRequest(super.request) : super.fromRequest();

  late final String email = requireEmail('email', description: 'Account email address');
  late final String password = requireString('password', description: 'Account password');

  @override
  void validate() {
    email;
    password;
  }
}

/// A single `{productId, quantity}` line item inside a [CreateOrderSchema].
class OrderItemInputSchema extends BloomRequestSchema {
  OrderItemInputSchema(super.data);

  late final int productId = requireInt('productId', description: 'Product ID');
  late final int quantity = requireInt('quantity', description: 'Quantity ordered');

  @override
  void validate() {
    productId;
    if (quantity <= 0) {
      fail('Field "quantity" must be a positive integer (got $quantity).');
    }
  }
}

/// Request body schema for order creation: a non-empty list of line items.
class CreateOrderSchema extends BloomRequestSchema {
  CreateOrderSchema(super.data);
  CreateOrderSchema.fromRequest(super.request) : super.fromRequest();

  late final List<OrderItemInputSchema> items = requireList<OrderItemInputSchema>(
    'items',
    (item) => OrderItemInputSchema(item),
    minLength: 1,
    description: 'Order line items ({productId, quantity})',
  );

  @override
  void validate() {
    items;
  }
}
