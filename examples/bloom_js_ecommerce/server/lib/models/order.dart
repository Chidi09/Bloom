import 'package:bloom_db/bloom_db.dart';
import 'user.dart';

/// Order lifecycle status. Stored as a plain string column ('pending',
/// 'paid', 'shipped') rather than a native enum type — keeps the schema
/// simple and avoids a Postgres ENUM migration dance for this example.
@BloomModel(app: 'ecommerce', tableName: 'ecommerce_orders')
class Order extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(column: 'user_id', kind: FieldKind.bigInt)
  final int userId;

  @BloomField(kind: FieldKind.char, maxLength: 32)
  final String status;

  @BloomField(column: 'total_cents', kind: FieldKind.integer)
  final int totalCents;

  @BloomField(column: 'created_at', kind: FieldKind.dateTime)
  final DateTime createdAt;

  Order({
    this.id = 0,
    required this.userId,
    this.status = 'pending',
    required this.totalCents,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  static final meta = ModelMeta(
    structName: 'Order',
    appLabel: 'ecommerce',
    tableName: 'ecommerce_orders',
    fields: [
      FieldMeta(
        name: 'id',
        columnName: 'id',
        kind: FieldKind.bigInt,
        primaryKey: true,
        auto: true,
      ),
      FieldMeta(
        name: 'userId',
        columnName: 'user_id',
        kind: FieldKind.bigInt,
      ),
      FieldMeta(
        name: 'status',
        columnName: 'status',
        kind: FieldKind.char,
        maxLength: 32,
      ),
      FieldMeta(
        name: 'totalCents',
        columnName: 'total_cents',
        kind: FieldKind.integer,
      ),
      FieldMeta(
        name: 'createdAt',
        columnName: 'created_at',
        kind: FieldKind.dateTime,
      ),
    ],
    relations: [
      RelationMeta(
        fieldName: 'userId',
        kind: RelationKind.foreignKey,
        target: () => User.meta,
        onDelete: OnDelete.cascade,
      ),
    ],
    ordering: ['-createdAt', 'id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('userId', BloomValue.i64(userId)),
        ('status', BloomValue.text(status)),
        ('totalCents', BloomValue.i64(totalCents)),
        ('createdAt', BloomValue.dateTime(createdAt)),
      ];

  static Order fromRow(DbRow row) {
    return Order(
      id: row.tryIntByName('id') ?? 0,
      userId: row.tryIntByName('user_id') ?? 0,
      status: row.tryStringByName('status') ?? 'pending',
      totalCents: row.tryIntByName('total_cents') ?? 0,
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
    );
  }

  static QuerySet<Order> objects() {
    return QuerySet<Order>(
      meta: meta,
      fromRow: fromRow,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'status': status,
        'totalCents': totalCents,
        'createdAt': createdAt.toIso8601String(),
      };
}
