import 'dart:convert';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:http/http.dart' as http_pkg;

/// BloomHttpClient throws http.ClientException with the raw response body
/// baked into its message ('HTTP 401: {"error":{"code":...,"message":...}}')
/// on non-2xx responses. The server (via bloom_errors' BloomErrorMiddleware)
/// always sends that body as {"error":{"code","message","details"}} JSON, so
/// unwrap it here instead of showing the raw HTTP-status-plus-JSON string.
String describeApiError(Object error) {
  if (error is http_pkg.ClientException) {
    final message = error.message;
    final jsonStart = message.indexOf('{');
    if (jsonStart != -1) {
      try {
        final decoded = jsonDecode(message.substring(jsonStart));
        final nested = (decoded as Map<String, dynamic>)['error'];
        if (nested is Map<String, dynamic> && nested['message'] is String) {
          return nested['message'] as String;
        }
      } catch (_) {
        // Not the expected bloom_errors shape — fall through to raw message.
      }
    }
    return message;
  }
  return error.toString();
}

/// The API base URL. The ecommerce server (`bloom_ecommerce_server`) is
/// expected to be running locally on port 8080.
const String apiBaseUrl = 'http://localhost:8080/api';

/// Central app store: auth state, cart state, and the BloomHttpClient used
/// to talk to `bloom_ecommerce_server`. Signals-based, mirroring
/// `bloom_showcase_web`'s `ShowcaseStore` pattern.
class EcommerceStore {
  static final EcommerceStore instance = EcommerceStore._();
  EcommerceStore._() {
    http.authTokenProvider = () => authToken.value;
  }

  final http = BloomHttpClient(baseUrl: apiBaseUrl);

  // ── Auth state ──────────────────────────────────────────────────────
  // bloom_js_native exposes no browser localStorage helper today, so the
  // session token is held in an in-memory signal only (cleared on reload).
  final authToken = signal<String?>(null);
  final currentUser = signal<Map<String, dynamic>?>(null);
  final authError = signal<String?>(null);
  final authBusy = signal<bool>(false);

  bool get isLoggedIn => authToken.value != null;

  // ── Cart state: productId -> quantity ──────────────────────────────
  final cart = signal<Map<int, int>>({});

  int get cartItemCount => cart.value.values.fold(0, (a, b) => a + b);

  // ── Product catalog query ──────────────────────────────────────────
  late final productsQuery = BloomQuery<List<dynamic>>(
    key: const ['products'],
    fetch: () async {
      final res = await http.get<Map<String, dynamic>>('/products');
      return (res['results'] as List<dynamic>?) ?? const [];
    },
  );

  // ── My orders query ─────────────────────────────────────────────────
  late final ordersQuery = BloomQuery<List<dynamic>>(
    key: const ['orders', 'mine'],
    enabled: false,
    fetch: () async {
      final res = await http.get<Map<String, dynamic>>('/orders/mine');
      return (res['results'] as List<dynamic>?) ?? const [];
    },
  );

  // ── Checkout mutation ────────────────────────────────────────────────
  late final checkoutMutation = BloomMutation<Map<String, dynamic>, List<Map<String, dynamic>>>(
    mutateFn: (items) => http.post<Map<String, dynamic>>('/orders', body: {'items': items}),
    invalidateKeys: const [
      ['orders', 'mine'],
    ],
  );

  // ── Cart mutations ──────────────────────────────────────────────────
  void addToCart(int productId) {
    final next = Map<int, int>.from(cart.value);
    next[productId] = (next[productId] ?? 0) + 1;
    cart.value = next;
  }

  void removeFromCart(int productId) {
    final next = Map<int, int>.from(cart.value);
    next.remove(productId);
    cart.value = next;
  }

  void setQuantity(int productId, int quantity) {
    final next = Map<int, int>.from(cart.value);
    if (quantity <= 0) {
      next.remove(productId);
    } else {
      next[productId] = quantity;
    }
    cart.value = next;
  }

  void clearCart() {
    cart.value = {};
  }

  /// Resolves the cart into the `{productId, quantity}` line-item shape
  /// expected by `POST /api/orders`.
  List<Map<String, dynamic>> cartAsOrderItems() {
    return cart.value.entries
        .map((e) => {'productId': e.key, 'quantity': e.value})
        .toList();
  }

  Map<String, dynamic>? findProduct(int productId) {
    final products = productsQuery.data.value;
    if (products == null) return null;
    for (final p in products) {
      if (p is Map<String, dynamic> && p['id'] == productId) return p;
    }
    return null;
  }

  /// Running cart total in cents, computed client-side from the currently
  /// cached product list (for display only — the server always
  /// recomputes the authoritative total from live product rows).
  int get cartTotalCents {
    var total = 0;
    for (final entry in cart.value.entries) {
      final product = findProduct(entry.key);
      final priceCents = product?['priceCents'] as int? ?? 0;
      total += priceCents * entry.value;
    }
    return total;
  }

  // ── Auth actions ─────────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    authBusy.value = true;
    authError.value = null;
    try {
      final res = await http.post<Map<String, dynamic>>('/auth/login', body: {
        'email': email,
        'password': password,
      });
      authToken.value = res['token'] as String?;
      currentUser.value = res['user'] as Map<String, dynamic>?;
      ordersQuery.refetch();
    } catch (e) {
      authError.value = 'Login failed: ${describeApiError(e)}';
    } finally {
      authBusy.value = false;
    }
  }

  Future<void> signup(String name, String email, String password) async {
    authBusy.value = true;
    authError.value = null;
    try {
      final res = await http.post<Map<String, dynamic>>('/auth/signup', body: {
        'name': name,
        'email': email,
        'password': password,
      });
      authToken.value = res['token'] as String?;
      currentUser.value = res['user'] as Map<String, dynamic>?;
      ordersQuery.refetch();
    } catch (e) {
      authError.value = 'Signup failed: ${describeApiError(e)}';
    } finally {
      authBusy.value = false;
    }
  }

  void logout() {
    authToken.value = null;
    currentUser.value = null;
  }
}
