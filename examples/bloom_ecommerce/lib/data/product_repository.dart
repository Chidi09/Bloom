// lib/data/product_repository.dart
import 'dart:async';
import 'package:bloom_framework/bloom.dart';
import '../models/product.dart';

class ProductRepository {
  static const List<Product> _mockCatalog = [
    Product(
      id: 'prod_1',
      title: 'Bloom Aero Mechanical Keyboard',
      description: 'Custom gasket-mounted wireless mechanical keyboard with hot-swappable tactile switches.',
      price: 149.99,
      category: 'Peripherals',
      imageUrl: 'https://images.bloom.dev/products/keyboard.webp',
    ),
    Product(
      id: 'prod_2',
      title: 'Bloom Studio Display Pro',
      description: '27-inch 5K Retina IPS display with 99% DCI-P3 color gamut and 90W USB-C charging.',
      price: 699.00,
      category: 'Displays',
      imageUrl: 'https://images.bloom.dev/products/display.webp',
    ),
    Product(
      id: 'prod_3',
      title: 'Bloom Precision ANC Headphones',
      description: 'Active noise-cancelling planar magnetic headphones with 40-hour battery life.',
      price: 279.50,
      category: 'Audio',
      imageUrl: 'https://images.bloom.dev/products/headphones.webp',
    ),
  ];

  /// Query product catalog with stale-while-revalidate caching.
  Future<List<Product>> getProducts({String? category}) async {
    return BloomData.deduplicate(['products', category ?? 'all'], () async {
      final cached = BloomData.getQueryData<List<Product>>(['products', category ?? 'all']);
      if (cached != null) return cached;

      // Simulate API latency
      await Future.delayed(const Duration(milliseconds: 50));
      var result = _mockCatalog;
      if (category != null && category.isNotEmpty && category != 'all') {
        result = _mockCatalog.where((p) => p.category.toLowerCase() == category.toLowerCase()).toList();
      }

      BloomData.setQueryData(['products', category ?? 'all'], (_) => result);
      return result;
    });
  }

  /// Places an order, queueing for offline sync if device has no connection.
  Future<Order> placeOrder(List<CartItem> items, double total) async {
    final order = Order(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
      items: items,
      totalAmount: total,
      createdAt: DateTime.now(),
      status: 'Confirmed',
    );

    // Enqueue mutation in Bloom offline queue
    await OfflineMutationQueue.instance.enqueue(
      mutationType: 'create_order',
      payload: {
        'id': order.id,
        'total': total,
        'itemCount': items.length,
        'createdAt': order.createdAt.toIso8601String(),
      },
    );

    return order;
  }
}
