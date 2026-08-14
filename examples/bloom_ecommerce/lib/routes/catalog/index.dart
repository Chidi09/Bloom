// lib/routes/catalog/index.dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter/material.dart';
import '../../controllers/cart_controller.dart';
import '../../data/product_repository.dart';
import '../../models/product.dart';

class CatalogIndexRoute extends StatefulWidget {
  const CatalogIndexRoute({super.key});

  @override
  State<CatalogIndexRoute> createState() => _CatalogIndexRouteState();
}

class _CatalogIndexRouteState extends State<CatalogIndexRoute> {
  final _repo = ProductRepository();
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final list = await _repo.getProducts();
    if (mounted) {
      setState(() {
        _products = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = inject<CartController>();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Add to Cart'),
                      onPressed: () {
                        cart.addItem(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "${product.title}" to cart!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
