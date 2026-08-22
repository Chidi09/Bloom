import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_validate/bloom_validate.dart';
import 'models/order.dart';
import 'models/order_item.dart';
import 'models/product.dart';
import 'models/user.dart';
import 'permissions.dart';
import 'serializers.dart';

/// Handlers for authentication routes.
class AuthApiHandlers {
  final DbExecutor db;

  AuthApiHandlers({required this.db});

  /// POST /api/auth/signup
  Future<BloomResponse> handleSignup(BloomRequest req) async {
    final SignupRequestSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(SignupRequestSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    final email = schema.email.trim().toLowerCase();
    final name = schema.name.trim();
    final password = schema.password;

    final existing = await User.objects().filter(Q('email', email)).first(db);
    if (existing != null) {
      throw BloomConflictException('An account with email "$email" already exists.');
    }

    final passwordHash = hashPassword(password, cost: 12);

    final insertedId = await QuerySet.insertRaw(db, User.meta, {
      'email': email,
      'password_hash': passwordHash,
      'name': name,
      'created_at': DateTime.now().toUtc(),
    });

    final savedUser = await User.objects().filter(Q('id', insertedId)).get(db);

    final token = issueSessionToken(
      userId: savedUser.id.toString(),
      email: savedUser.email,
      roles: const ['user'],
      ttl: const Duration(days: 7),
    );

    return BloomResponse.json({
      'token': token,
      'user': savedUser.toJson(),
      'message': 'Signup successful.',
    }, statusCode: 201);
  }

  /// POST /api/auth/login
  Future<BloomResponse> handleLogin(BloomRequest req) async {
    final LoginRequestSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(LoginRequestSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    final email = schema.email.trim().toLowerCase();
    final password = schema.password;

    try {
      authLimiter.verifyAllowed(email);
    } on AccountLockedException catch (e) {
      throw BloomForbiddenException(
        'Account is temporarily locked due to consecutive failed attempts.',
        {'retryAfterSeconds': e.retryAfterSeconds},
      );
    } on RateLimitException catch (e) {
      throw BloomTooManyRequestsException(
        'Too many login attempts. Please try again later.',
        Duration(seconds: e.retryAfterSeconds),
      );
    }

    final user = await User.objects().filter(Q('email', email)).first(db);

    if (user == null) {
      dummyVerifyPassword(password);
      authLimiter.recordFailure(email);
      throw BloomUnauthorizedException('Invalid email or password');
    }

    final isValid = verifyPassword(password, user.passwordHash);
    if (!isValid) {
      authLimiter.recordFailure(email);
      throw BloomUnauthorizedException('Invalid email or password');
    }

    authLimiter.recordSuccess(email);

    final token = issueSessionToken(
      userId: user.id.toString(),
      email: user.email,
      roles: const ['user'],
      ttl: const Duration(days: 7),
    );

    return BloomResponse.json({
      'token': token,
      'user': user.toJson(),
      'message': 'Login successful.',
    });
  }

  /// GET /api/auth/me (Protected route)
  Future<BloomResponse> handleMe(BloomRequest req) async {
    final userIdStr = req.authUserId;
    if (userIdStr == null) {
      throw BloomUnauthorizedException('Authentication required.');
    }

    final userId = int.tryParse(userIdStr) ?? 0;
    final user = await User.objects().filter(Q('id', userId)).first(db);
    if (user == null) {
      throw BloomNotFoundException('User account not found.');
    }

    return BloomResponse.json({
      'user': user.toJson(),
      'claims': req.auth?.toMap(),
    });
  }
}

/// Handlers for order placement and lookup. Never trusts client-submitted
/// prices — every order's line-item price and total are computed
/// server-side from the current [Product] rows at checkout time.
class OrderApiHandlers {
  final DbExecutor db;

  OrderApiHandlers({required this.db});

  int _resolveUserId(BloomRequest req) {
    final uidStr = req.authUserId;
    if (uidStr == null || uidStr.isEmpty) {
      throw BloomUnauthorizedException('Authentication required');
    }
    final uid = int.tryParse(uidStr);
    if (uid == null) {
      throw BloomUnauthorizedException('Invalid session token identity');
    }
    return uid;
  }

  /// POST /api/orders
  Future<BloomResponse> handleCreateOrder(BloomRequest req) async {
    final userId = _resolveUserId(req);

    final CreateOrderSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(CreateOrderSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    // 1. Resolve current product rows and validate stock — sequential
    // awaited queries (bloom_db's DbExecutor has no transaction primitive
    // exposed to application code today).
    final resolvedItems = <(Product product, int quantity)>[];
    for (final line in schema.items) {
      final product = await Product.objects().filter(Q('id', line.productId)).first(db);
      if (product == null) {
        throw BloomNotFoundException('Product ${line.productId} not found');
      }
      if (product.stockQuantity < line.quantity) {
        throw BloomBadRequestException(
          'Insufficient stock for "${product.name}": requested ${line.quantity}, available ${product.stockQuantity}',
        );
      }
      resolvedItems.add((product, line.quantity));
    }

    // 2. Compute total server-side from live product prices — never trust
    // client-sent prices.
    final totalCents = resolvedItems.fold<int>(
      0,
      (sum, entry) => sum + entry.$1.priceCents * entry.$2,
    );

    // 3. Insert the order.
    final orderId = await QuerySet.insertRaw(db, Order.meta, {
      'user_id': userId,
      'status': 'pending',
      'total_cents': totalCents,
      'created_at': DateTime.now().toUtc(),
    });

    // 4. Insert order items and decrement stock.
    final createdItems = <OrderItem>[];
    for (final (product, quantity) in resolvedItems) {
      final itemId = await QuerySet.insertRaw(db, OrderItem.meta, {
        'order_id': orderId,
        'product_id': product.id,
        'quantity': quantity,
        'unit_price_cents': product.priceCents,
      });
      createdItems.add(OrderItem(
        id: itemId,
        orderId: orderId,
        productId: product.id,
        quantity: quantity,
        unitPriceCents: product.priceCents,
      ));

      await Product.objects()
          .filter(Q('id', product.id))
          .update(db, {'stockQuantity': product.stockQuantity - quantity});
    }

    final order = await Order.objects().filter(Q('id', orderId)).get(db);

    return BloomResponse.json({
      'order': order.toJson(),
      'items': createdItems.map((i) => i.toJson()).toList(),
    }, statusCode: 201);
  }

  /// GET /api/orders/mine
  Future<BloomResponse> handleListMyOrders(BloomRequest req) async {
    final userId = _resolveUserId(req);

    final orders = await Order.objects().filter(Q('userId', userId)).orderBy('-createdAt').all(db);

    final results = <Map<String, dynamic>>[];
    for (final order in orders) {
      final items = await OrderItem.objects().filter(Q('orderId', order.id)).orderBy('id').all(db);
      results.add({
        ...order.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
      });
    }

    return BloomResponse.json({
      'count': results.length,
      'results': results,
    });
  }
}
