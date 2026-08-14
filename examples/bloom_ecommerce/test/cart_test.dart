// test/cart_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_ecommerce/controllers/cart_controller.dart';
import 'package:bloom_ecommerce/models/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bloom Commerce: CartController Signals & Computations', () {
    late CartController cart;
    const testProduct1 = Product(
      id: 'p1',
      title: 'Aero Keyboard',
      description: 'Mechanical keyboard',
      price: 100.0,
      category: 'Peripherals',
      imageUrl: '',
    );
    const testProduct2 = Product(
      id: 'p2',
      title: 'Studio Display',
      description: '4K Display',
      price: 500.0,
      category: 'Displays',
      imageUrl: '',
    );

    setUp(() {
      cart = CartController();
    });

    test('Initializes with empty cart and zero totals', () {
      expect(cart.items.value, isEmpty);
      expect(cart.itemCount.value, 0);
      expect(cart.totalPrice.value, 0.0);
    });

    test('Adding products computes item counts and total prices reactively', () {
      cart.addItem(testProduct1);
      expect(cart.itemCount.value, 1);
      expect(cart.totalPrice.value, 100.0);

      cart.addItem(testProduct1); // Second of same item
      expect(cart.itemCount.value, 2);
      expect(cart.totalPrice.value, 200.0);

      cart.addItem(testProduct2); // New product
      expect(cart.itemCount.value, 3);
      expect(cart.totalPrice.value, 700.0);
    });

    test('Updating quantities or removing items updates signals', () {
      cart.addItem(testProduct1);
      cart.addItem(testProduct2);

      cart.updateQuantity('p1', 5);
      expect(cart.itemCount.value, 6);
      expect(cart.totalPrice.value, 1000.0);

      cart.removeItem('p1');
      expect(cart.itemCount.value, 1);
      expect(cart.totalPrice.value, 500.0);

      cart.clear();
      expect(cart.itemCount.value, 0);
      expect(cart.totalPrice.value, 0.0);
    });
  });
}
