import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'ecommerce', tableName: 'ecommerce_products')
class Product extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(kind: FieldKind.char, maxLength: 255)
  final String name;

  @BloomField(kind: FieldKind.text)
  final String description;

  @BloomField(column: 'price_cents', kind: FieldKind.integer)
  final int priceCents;

  @BloomField(column: 'image_url', kind: FieldKind.char, maxLength: 1024)
  final String imageUrl;

  @BloomField(column: 'stock_quantity', kind: FieldKind.integer)
  final int stockQuantity;

  @BloomField(column: 'created_at', kind: FieldKind.dateTime)
  final DateTime createdAt;

  Product({
    this.id = 0,
    required this.name,
    required this.description,
    required this.priceCents,
    this.imageUrl = '',
    required this.stockQuantity,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  static const meta = ModelMeta(
    structName: 'Product',
    appLabel: 'ecommerce',
    tableName: 'ecommerce_products',
    fields: [
      FieldMeta(
        name: 'id',
        columnName: 'id',
        kind: FieldKind.bigInt,
        primaryKey: true,
        auto: true,
      ),
      FieldMeta(
        name: 'name',
        columnName: 'name',
        kind: FieldKind.char,
        maxLength: 255,
      ),
      FieldMeta(
        name: 'description',
        columnName: 'description',
        kind: FieldKind.text,
      ),
      FieldMeta(
        name: 'priceCents',
        columnName: 'price_cents',
        kind: FieldKind.integer,
      ),
      FieldMeta(
        name: 'imageUrl',
        columnName: 'image_url',
        kind: FieldKind.char,
        maxLength: 1024,
      ),
      FieldMeta(
        name: 'stockQuantity',
        columnName: 'stock_quantity',
        kind: FieldKind.integer,
      ),
      FieldMeta(
        name: 'createdAt',
        columnName: 'created_at',
        kind: FieldKind.dateTime,
      ),
    ],
    ordering: ['-createdAt', 'id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('name', BloomValue.text(name)),
        ('description', BloomValue.text(description)),
        ('priceCents', BloomValue.i64(priceCents)),
        ('imageUrl', BloomValue.text(imageUrl)),
        ('stockQuantity', BloomValue.i64(stockQuantity)),
        ('createdAt', BloomValue.dateTime(createdAt)),
      ];

  static Product fromRow(DbRow row) {
    return Product(
      id: row.tryIntByName('id') ?? 0,
      name: row.tryStringByName('name') ?? '',
      description: row.tryStringByName('description') ?? '',
      priceCents: row.tryIntByName('price_cents') ?? 0,
      imageUrl: row.tryStringByName('image_url') ?? '',
      stockQuantity: row.tryIntByName('stock_quantity') ?? 0,
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
    );
  }

  static QuerySet<Product> objects() {
    return QuerySet<Product>(
      meta: meta,
      fromRow: fromRow,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'priceCents': priceCents,
        'imageUrl': imageUrl,
        'stockQuantity': stockQuantity,
        'createdAt': createdAt.toIso8601String(),
      };
}
