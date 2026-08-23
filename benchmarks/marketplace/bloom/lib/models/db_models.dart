import 'package:bloom_db/bloom_db.dart';

class Vendor extends Model {
  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;

  Vendor({required this.id, required this.name, required this.slug, required this.createdAt});

  static final ModelMeta meta = ModelMeta(
    structName: 'Vendor',
    appLabel: 'marketplace',
    tableName: 'vendors',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.uuid, primaryKey: true),
      FieldMeta(name: 'name', columnName: 'name', kind: FieldKind.text),
      FieldMeta(name: 'slug', columnName: 'slug', kind: FieldKind.slug, unique: true),
      FieldMeta(name: 'created_at', columnName: 'created_at', kind: FieldKind.dateTime),
    ],
    ordering: ['name'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.text(id)),
        ('name', BloomValue.text(name)),
        ('slug', BloomValue.text(slug)),
        ('created_at', BloomValue.dateTime(createdAt)),
      ];

  static Vendor fromRow(DbRow row) => Vendor(
        id: row.tryStringByName('id') ?? row[0].toString(),
        name: row.tryStringByName('name') ?? '',
        slug: row.tryStringByName('slug') ?? '',
        createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'created_at': createdAt.toIso8601String(),
      };
}

class Category extends Model {
  final String id;
  final String name;
  final String slug;
  final String? parentId;
  final DateTime createdAt;

  Category({required this.id, required this.name, required this.slug, this.parentId, required this.createdAt});

  static final ModelMeta meta = ModelMeta(
    structName: 'Category',
    appLabel: 'marketplace',
    tableName: 'categories',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.uuid, primaryKey: true),
      FieldMeta(name: 'name', columnName: 'name', kind: FieldKind.text),
      FieldMeta(name: 'slug', columnName: 'slug', kind: FieldKind.slug, unique: true),
      FieldMeta(name: 'parent_id', columnName: 'parent_id', kind: FieldKind.uuid, nullable: true),
      FieldMeta(name: 'created_at', columnName: 'created_at', kind: FieldKind.dateTime),
    ],
    ordering: ['name'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.text(id)),
        ('name', BloomValue.text(name)),
        ('slug', BloomValue.text(slug)),
        ('parent_id', parentId == null ? const BloomValue.nullVal() : BloomValue.text(parentId!)),
        ('created_at', BloomValue.dateTime(createdAt)),
      ];

  static Category fromRow(DbRow row) => Category(
        id: row.tryStringByName('id') ?? row[0].toString(),
        name: row.tryStringByName('name') ?? '',
        slug: row.tryStringByName('slug') ?? '',
        parentId: row.tryStringByName('parent_id'),
        createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'parent_id': parentId,
      };
}

class Product extends Model {
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

  static final ModelMeta meta = ModelMeta(
    structName: 'Product',
    appLabel: 'marketplace',
    tableName: 'products',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.uuid, primaryKey: true),
      FieldMeta(name: 'vendor_id', columnName: 'vendor_id', kind: FieldKind.uuid),
      FieldMeta(name: 'category_id', columnName: 'category_id', kind: FieldKind.uuid),
      FieldMeta(name: 'title', columnName: 'title', kind: FieldKind.text),
      FieldMeta(name: 'slug', columnName: 'slug', kind: FieldKind.slug, unique: true),
      FieldMeta(name: 'description', columnName: 'description', kind: FieldKind.text),
      FieldMeta(name: 'price_cents', columnName: 'price_cents', kind: FieldKind.integer),
      FieldMeta(name: 'currency', columnName: 'currency', kind: FieldKind.char),
      FieldMeta(name: 'status', columnName: 'status', kind: FieldKind.text),
      FieldMeta(name: 'stock', columnName: 'stock', kind: FieldKind.integer),
      FieldMeta(name: 'created_at', columnName: 'created_at', kind: FieldKind.dateTime),
      FieldMeta(name: 'updated_at', columnName: 'updated_at', kind: FieldKind.dateTime),
    ],
    indexes: [
      IndexMeta(name: 'idx_products_status_created', fields: ['status', 'created_at']),
      IndexMeta(name: 'idx_products_category', fields: ['category_id']),
      IndexMeta(name: 'idx_products_vendor', fields: ['vendor_id']),
      IndexMeta(name: 'idx_products_slug', fields: ['slug']),
    ],
    ordering: ['-created_at'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.text(id)),
        ('vendor_id', BloomValue.text(vendorId)),
        ('category_id', BloomValue.text(categoryId)),
        ('title', BloomValue.text(title)),
        ('slug', BloomValue.text(slug)),
        ('description', BloomValue.text(description)),
        ('price_cents', BloomValue.i64(priceCents)),
        ('currency', BloomValue.text(currency)),
        ('status', BloomValue.text(status)),
        ('stock', BloomValue.i64(stock)),
        ('created_at', BloomValue.dateTime(createdAt)),
        ('updated_at', BloomValue.dateTime(updatedAt)),
      ];

  static Product fromRow(DbRow row) => Product(
        id: row.tryStringByName('id') ?? row[0].toString(),
        vendorId: row.tryStringByName('vendor_id') ?? '',
        categoryId: row.tryStringByName('category_id') ?? '',
        title: row.tryStringByName('title') ?? '',
        slug: row.tryStringByName('slug') ?? '',
        description: row.tryStringByName('description') ?? '',
        priceCents: row.tryIntByName('price_cents') ?? 0,
        currency: row.tryStringByName('currency') ?? 'USD',
        status: row.tryStringByName('status') ?? 'draft',
        stock: row.tryIntByName('stock') ?? 0,
        createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
        updatedAt: row.tryDateTimeByName('updated_at') ?? DateTime.now().toUtc(),
        vendorName: row.tryStringByName('vendor_name'),
        vendorSlug: row.tryStringByName('vendor_slug'),
        categoryName: row.tryStringByName('category_name'),
        categorySlug: row.tryStringByName('category_slug'),
      );

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

class ProductImage extends Model {
  final String id;
  final String productId;
  final String url;
  final String alt;
  final int position;

  ProductImage({required this.id, required this.productId, required this.url, required this.alt, required this.position});

  static final ModelMeta meta = ModelMeta(
    structName: 'ProductImage',
    appLabel: 'marketplace',
    tableName: 'product_images',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.uuid, primaryKey: true),
      FieldMeta(name: 'product_id', columnName: 'product_id', kind: FieldKind.uuid),
      FieldMeta(name: 'url', columnName: 'url', kind: FieldKind.text),
      FieldMeta(name: 'alt', columnName: 'alt', kind: FieldKind.text),
      FieldMeta(name: 'position', columnName: 'position', kind: FieldKind.integer),
    ],
    ordering: ['position'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.text(id)),
        ('product_id', BloomValue.text(productId)),
        ('url', BloomValue.text(url)),
        ('alt', BloomValue.text(alt)),
        ('position', BloomValue.i64(position)),
      ];

  static ProductImage fromRow(DbRow row) => ProductImage(
        id: row.tryStringByName('id') ?? '',
        productId: row.tryStringByName('product_id') ?? '',
        url: row.tryStringByName('url') ?? '',
        alt: row.tryStringByName('alt') ?? '',
        position: row.tryIntByName('position') ?? 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'product_id': productId, 'url': url, 'alt': alt, 'position': position};
}
