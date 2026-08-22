import 'package:bloom_db/bloom_db.dart';
import 'order.dart';
import 'product.dart';

@BloomModel(app: 'ecommerce', tableName: 'ecommerce_order_items')
class OrderItem extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(column: 'order_id', kind: FieldKind.bigInt)
  final int orderId;

  @BloomField(column: 'product_id', kind: FieldKind.bigInt)
  final int productId;

  @BloomField(kind: FieldKind.integer)
  final int quantity;

  @BloomField(column: 'unit_price_cents', kind: FieldKind.integer)
  final int unitPriceCents;

  OrderItem({
    this.id = 0,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPriceCents,
  });

  static final meta = ModelMeta(
    structName: 'OrderItem',
    appLabel: 'ecommerce',
    tableName: 'ecommerce_order_items',
    fields: [
      FieldMeta(
        name: 'id',
        columnName: 'id',
        kind: FieldKind.bigInt,
        primaryKey: true,
        auto: true,
      ),
      FieldMeta(
        name: 'orderId',
        columnName: 'order_id',
        kind: FieldKind.bigInt,
      ),
      FieldMeta(
        name: 'productId',
        columnName: 'product_id',
        kind: FieldKind.bigInt,
      ),
      FieldMeta(
        name: 'quantity',
        columnName: 'quantity',
        kind: FieldKind.integer,
      ),
      FieldMeta(
        name: 'unitPriceCents',
        columnName: 'unit_price_cents',
        kind: FieldKind.integer,
      ),
    ],
    relations: [
      RelationMeta(
        fieldName: 'orderId',
        kind: RelationKind.foreignKey,
        target: () => Order.meta,
        onDelete: OnDelete.cascade,
      ),
      RelationMeta(
        fieldName: 'productId',
        kind: RelationKind.foreignKey,
        target: () => Product.meta,
        onDelete: OnDelete.cascade,
      ),
    ],
    ordering: ['id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('orderId', BloomValue.i64(orderId)),
        ('productId', BloomValue.i64(productId)),
        ('quantity', BloomValue.i64(quantity)),
        ('unitPriceCents', BloomValue.i64(unitPriceCents)),
      ];

  static OrderItem fromRow(DbRow row) {
    return OrderItem(
      id: row.tryIntByName('id') ?? 0,
      orderId: row.tryIntByName('order_id') ?? 0,
      productId: row.tryIntByName('product_id') ?? 0,
      quantity: row.tryIntByName('quantity') ?? 0,
      unitPriceCents: row.tryIntByName('unit_price_cents') ?? 0,
    );
  }

  static QuerySet<OrderItem> objects() {
    return QuerySet<OrderItem>(
      meta: meta,
      fromRow: fromRow,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'productId': productId,
        'quantity': quantity,
        'unitPriceCents': unitPriceCents,
      };
}
