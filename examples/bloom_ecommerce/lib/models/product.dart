// lib/models/product.dart

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final String imageUrl;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'imageUrl': imageUrl,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        category: json['category'] as String,
        imageUrl: json['imageUrl'] as String,
      );
}

class CartItem {
  final Product product;
  final int quantity;

  const CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get subtotal => product.price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
      );
}

class Order {
  final String id;
  final List<CartItem> items;
  final double totalAmount;
  final DateTime createdAt;
  final String status;

  Order({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
    this.status = 'Pending',
  });
}
