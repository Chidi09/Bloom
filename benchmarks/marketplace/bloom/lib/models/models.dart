// Client-safe plain data classes — no `package:bloom_db` dependency.
//
// The server-side ORM classes (Model/ModelMeta/DbRow-backed, with
// `fromRow`/`fieldValues`) live in db_models.dart and are used only by
// lib/models/repository.dart and lib/api/routes.dart, which never run in
// the browser. These classes are used by the client-side pages
// (lib/pages/*.dart) to deserialize JSON responses from the JSON API —
// keeping bloom_db (and its native sqlite3 FFI dependency) out of the
// dart2js compile graph entirely.

class Category {
  final String id;
  final String name;
  final String slug;
  final String? parentId;
  final DateTime createdAt;

  Category({required this.id, required this.name, required this.slug, this.parentId, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'parent_id': parentId,
      };
}

class Product {
  final String id;
  final String vendorId;
  final String categoryId;
  final String title;
  final String slug;
  final String description;
  final int priceCents;
  final String currency;
  final String status;
  final int stock;
  final DateTime createdAt;
  final DateTime updatedAt;
  // joined
  final String? vendorName;
  final String? vendorSlug;
  final String? categoryName;
  final String? categorySlug;

  Product({
    required this.id,
    required this.vendorId,
    required this.categoryId,
    required this.title,
    required this.slug,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.status,
    required this.stock,
    required this.createdAt,
    required this.updatedAt,
    this.vendorName,
    this.vendorSlug,
    this.categoryName,
    this.categorySlug,
  });

  String get priceDisplay {
    final dollars = priceCents / 100;
    return '\$${dollars.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendor_id': vendorId,
        'category_id': categoryId,
        'title': title,
        'slug': slug,
        'description': description,
        'price_cents': priceCents,
        'currency': currency,
        'status': status,
        'stock': stock,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'vendor': vendorName == null ? null : {'name': vendorName, 'slug': vendorSlug},
        'category': categoryName == null ? null : {'name': categoryName, 'slug': categorySlug},
      };
}

class ProductImage {
  final String id;
  final String productId;
  final String url;
  final String alt;
  final int position;

  ProductImage({required this.id, required this.productId, required this.url, required this.alt, required this.position});

  Map<String, dynamic> toJson() => {'id': id, 'product_id': productId, 'url': url, 'alt': alt, 'position': position};
}
