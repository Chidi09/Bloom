import 'dart:convert';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:web/web.dart' as web;

class CartItem {
  final String id;
  final String title;
  final String slug;
  final int priceCents;
  final String currency;
  final String? imageUrl;
  final int quantity;

  const CartItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.priceCents,
    required this.currency,
    this.imageUrl,
    required this.quantity,
  });

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      title: title,
      slug: slug,
      priceCents: priceCents,
      currency: currency,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'price_cents': priceCents,
        'currency': currency,
        'image_url': imageUrl,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      priceCents: (json['price_cents'] ?? json['priceCents']) as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}

const String _cartStorageKey = 'marketplace_cart_v1';

Map<String, CartItem> _loadCartFromStorage() {
  try {
    final raw = web.window.localStorage.getItem(_cartStorageKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final result = <String, CartItem>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          result[entry.key] = CartItem.fromJson(entry.value as Map<String, dynamic>);
        }
      }
      return result;
    }
  } catch (_) {}
  return {};
}

void _saveCartToStorage(Map<String, CartItem> items) {
  try {
    if (items.isEmpty) {
      web.window.localStorage.removeItem(_cartStorageKey);
    } else {
      final map = items.map((k, v) => MapEntry(k, v.toJson()));
      web.window.localStorage.setItem(_cartStorageKey, jsonEncode(map));
    }
  } catch (_) {}
}

final Signal<Map<String, CartItem>> cart = signal<Map<String, CartItem>>(_loadCartFromStorage());

int get cartItemCount => cart.value.values.fold(0, (sum, item) => sum + item.quantity);

int get cartTotalCents => cart.value.values.fold(0, (sum, item) => sum + (item.priceCents * item.quantity));

void addToCart(
  String productId, {
  required String title,
  required String slug,
  required int priceCents,
  String currency = 'USD',
  String? imageUrl,
  int qty = 1,
}) {
  if (qty <= 0) return;
  final next = Map<String, CartItem>.from(cart.value);
  final existing = next[productId];
  if (existing != null) {
    next[productId] = existing.copyWith(quantity: existing.quantity + qty);
  } else {
    next[productId] = CartItem(
      id: productId,
      title: title,
      slug: slug,
      priceCents: priceCents,
      currency: currency,
      imageUrl: imageUrl,
      quantity: qty,
    );
  }
  cart.value = next;
  _saveCartToStorage(next);
}

void removeFromCart(String productId) {
  final next = Map<String, CartItem>.from(cart.value);
  if (next.remove(productId) != null) {
    cart.value = next;
    _saveCartToStorage(next);
  }
}

void setCartQuantity(String productId, int qty) {
  final next = Map<String, CartItem>.from(cart.value);
  if (qty <= 0) {
    next.remove(productId);
  } else {
    final existing = next[productId];
    if (existing != null) {
      next[productId] = existing.copyWith(quantity: qty);
    }
  }
  cart.value = next;
  _saveCartToStorage(next);
}

void clearCart() {
  cart.value = {};
  _saveCartToStorage({});
}
