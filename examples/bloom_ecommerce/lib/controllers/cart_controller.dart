// lib/controllers/cart_controller.dart
import 'package:bloom_framework/bloom.dart';
import '../models/product.dart';

class CartController extends BloomController {
  final _items = signal<Map<String, CartItem>>({});

  ReadonlySignal<Map<String, CartItem>> get items => _items.readonly();

  late final itemCount = computed(() {
    return _items.value.values.fold<int>(0, (sum, i) => sum + i.quantity);
  });

  late final totalPrice = computed(() {
    return _items.value.values.fold<double>(0.0, (sum, i) => sum + i.subtotal);
  });

  void addItem(Product product) {
    final current = Map<String, CartItem>.from(_items.value);
    if (current.containsKey(product.id)) {
      final existing = current[product.id]!;
      current[product.id] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      current[product.id] = CartItem(product: product, quantity: 1);
    }
    _items.value = current;
  }

  void removeItem(String productId) {
    final current = Map<String, CartItem>.from(_items.value);
    current.remove(productId);
    _items.value = current;
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final current = Map<String, CartItem>.from(_items.value);
    if (current.containsKey(productId)) {
      current[productId] = current[productId]!.copyWith(quantity: quantity);
      _items.value = current;
    }
  }

  void clear() {
    _items.value = {};
  }
}
