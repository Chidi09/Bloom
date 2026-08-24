// lib/src/expr.dart

/// A dynamic, strongly-typed SQL value container used in ORM expressions, query filters, and parameters.
///
/// Encapsulates primitive Dart values (integers, doubles, strings, booleans, timestamps, lists, null)
/// into a uniform AST node for SQL compilation and parameter sanitization.
///
/// Mirrors `djangors_orm::expr::Value`.
///
/// Example:
/// ```dart
/// final v1 = BloomValue.from(42);
/// final v2 = BloomValue.from('hello');
/// final vList = BloomValue.from([1, 2, 3]);
/// ```
sealed class BloomValue {
  /// Base const constructor for ORM expression values.
  const BloomValue();

  /// 64-bit integer value container wrapping [value].
  const factory BloomValue.i64(int value) = BloomI64Value;

  /// 64-bit floating point value container wrapping [value].
  const factory BloomValue.f64(double value) = BloomF64Value;

  /// Text string value container wrapping [value].
  const factory BloomValue.text(String value) = BloomTextValue;

  /// Boolean value container wrapping [value].
  const factory BloomValue.boolVal(bool value) = BloomBoolValue;

  /// UTC timestamp value container wrapping [value].
  const factory BloomValue.dateTime(DateTime value) = BloomDateTimeValue;

  /// Database `NULL` value representation.
  const factory BloomValue.nullVal() = BloomNullValue;

  /// A list of expression [items], used as the right-hand side of an `IN (...)` lookup.
  const factory BloomValue.list(List<BloomValue> items) = BloomListValue;

  /// Unwraps the underlying raw Dart value (e.g. `int`, `String`, `List<dynamic>`, or `null`).
  dynamic get raw;

  /// Converts an arbitrary Dart value [val] into a strongly typed [BloomValue].
  ///
  /// Handles `null`, [BloomValue], `int`, `double`, `bool`, `String`, `DateTime`, and `List`.
  ///
  /// Example:
  /// ```dart
  /// final val = BloomValue.from('active');
  /// assert(val is BloomTextValue);
  /// ```
  static BloomValue from(dynamic val) {
    if (val == null) return const BloomValue.nullVal();
    if (val is BloomValue) return val;
    if (val is int) return BloomValue.i64(val);
    if (val is double) return BloomValue.f64(val);
    if (val is bool) return BloomValue.boolVal(val);
    if (val is String) return BloomValue.text(val);
    if (val is DateTime) return BloomValue.dateTime(val.toUtc());
    if (val is List) {
      return BloomValue.list(val.map(BloomValue.from).toList());
    }
    return BloomValue.text(val.toString());
  }
}

/// 64-bit integer value expression wrapper.
///
/// Example:
/// ```dart
/// const val = BloomI64Value(100);
/// assert(val.raw == 100);
/// ```
class BloomI64Value extends BloomValue {
  /// The underlying 64-bit integer value.
  final int value;

  /// Creates an integer [BloomValue] wrapping [value].
  const BloomI64Value(this.value);

  @override
  int get raw => value;

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BloomI64Value && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// 64-bit floating point value expression wrapper.
///
/// Example:
/// ```dart
/// const val = BloomF64Value(3.14);
/// assert(val.raw == 3.14);
/// ```
class BloomF64Value extends BloomValue {
  /// The underlying floating point value.
  final double value;

  /// Creates a floating point [BloomValue] wrapping [value].
  const BloomF64Value(this.value);

  @override
  double get raw => value;

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BloomF64Value && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Text string value expression wrapper.
///
/// Example:
/// ```dart
/// const val = BloomTextValue('active');
/// assert(val.raw == 'active');
/// ```
class BloomTextValue extends BloomValue {
  /// The underlying text string value.
  final String value;

  /// Creates a text [BloomValue] wrapping [value].
  const BloomTextValue(this.value);

  @override
  String get raw => value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BloomTextValue && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Boolean value expression wrapper.
///
/// Example:
/// ```dart
/// const val = BloomBoolValue(true);
/// assert(val.raw == true);
/// ```
class BloomBoolValue extends BloomValue {
  /// The underlying boolean value.
  final bool value;

  /// Creates a boolean [BloomValue] wrapping [value].
  const BloomBoolValue(this.value);

  @override
  bool get raw => value;

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BloomBoolValue && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// UTC timestamp value expression wrapper.
///
/// Example:
/// ```dart
/// final val = BloomDateTimeValue(DateTime.utc(2026, 1, 1));
/// assert(val.raw.isUtc);
/// ```
class BloomDateTimeValue extends BloomValue {
  /// The underlying timestamp value in UTC.
  final DateTime value;

  /// Creates a UTC timestamp [BloomValue] wrapping [value].
  const BloomDateTimeValue(this.value);

  @override
  DateTime get raw => value;

  @override
  String toString() => value.toIso8601String();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomDateTimeValue && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Database `NULL` value expression wrapper.
///
/// Example:
/// ```dart
/// const val = BloomNullValue();
/// assert(val.raw == null);
/// ```
class BloomNullValue extends BloomValue {
  /// Creates a database `NULL` [BloomValue].
  const BloomNullValue();

  @override
  Null get raw => null;

  @override
  String toString() => 'NULL';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BloomNullValue;

  @override
  int get hashCode => 0;
}

/// List of expression values wrapper for `IN (...)` queries.
///
/// Example:
/// ```dart
/// final val = BloomListValue([BloomValue.i64(1), BloomValue.i64(2)]);
/// assert(val.raw.length == 2);
/// ```
class BloomListValue extends BloomValue {
  /// The list of items contained in this value list.
  final List<BloomValue> items;

  /// Creates a list [BloomValue] containing [items].
  const BloomListValue(this.items);


  @override
  List<dynamic> get raw => items.map((i) => i.raw).toList();

  @override
  String toString() => items.map((i) => i.toString()).join(', ');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BloomListValue || other.items.length != items.length) {
      return false;
    }
    for (var i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

/// Comparison operators for query filtering expressions.
///
/// Used by [BloomCompareExpr], [UnresolvedCompare], and lookup suffixes in `.filter()`.
///
/// Mirrors `djangors_orm::expr::CompareOp`.
enum CompareOp {
  /// Exact equality comparison (`=`). Lookup suffix `eq`.
  eq,

  /// Less-than comparison (`<`). Lookup suffix `lt`.
  lt,

  /// Less-than-or-equal comparison (`<=`). Lookup suffix `lte`.
  lte,

  /// Greater-than comparison (`>`). Lookup suffix `gt`.
  gt,

  /// Greater-than-or-equal comparison (`>=`). Lookup suffix `gte`.
  gte,

  /// Case-sensitive substring search (`LIKE '%val%'`). Lookup suffix `contains`.
  contains,

  /// Case-insensitive substring search (`ILIKE '%val%'` or `LIKE '%val%'`). Lookup suffix `icontains`.
  icontains,

  /// Prefix string match (`LIKE 'val%'`). Lookup suffix `startswith`.
  startsWith,

  /// Suffix string match (`LIKE '%val'`). Lookup suffix `endswith`.
  endsWith,

  /// Inequality comparison (`<>`). Lookup suffix `ne`.
  ne,

  /// Case-insensitive exact match (`ILIKE 'val'`, no wildcards). Lookup suffix `iexact`.
  iexact,

  /// Membership test (`IN (...)`). Lookup suffix `in`.
  isIn,

  /// NULL test (`IS NULL` / `IS NOT NULL`). Lookup suffix `isnull`.
  isNull,

  /// Case-sensitive POSIX regular-expression match (`~`). Lookup suffix `regex`.
  regex,

  /// Case-insensitive POSIX regular-expression match (`~*`). Lookup suffix `iregex`.
  iregex,
}

/// Arithmetic operators for in-database UPDATE set expressions.
///
/// Used with [F] field references to perform atomic database updates.
///
/// Mirrors `djangors_orm::expr::ArithOp`.
enum ArithOp {
  /// Addition operator (`+`).
  add,

  /// Subtraction operator (`-`).
  sub,

  /// Multiplication operator (`*`).
  mul,

  /// Division operator (`/`).
  div,
}

/// Resolved boolean expression tree for query `WHERE` clauses.
///
/// Represents validated, column-mapped expressions that can be compiled to SQL.
///
/// Mirrors `djangors_orm::expr::Expr`.
///
/// Example:
/// ```dart
/// final expr = BloomExpr.compare(
///   field: 'age',
///   op: CompareOp.gte,
///   value: BloomValue.i64(18),
/// );
/// ```
sealed class BloomExpr {
  /// Base const constructor for resolved expressions.
  const BloomExpr();

  /// Creates a single field comparison expression between [field] and [value] using [op].
  const factory BloomExpr.compare({
    required String field,
    required CompareOp op,
    required BloomValue value,
  }) = BloomCompareExpr;

  /// Creates a conjunction of multiple [exprs] combined with `AND`.
  const factory BloomExpr.and(List<BloomExpr> exprs) = BloomAndExpr;

  /// Creates a disjunction of multiple [exprs] combined with `OR`.
  const factory BloomExpr.or(List<BloomExpr> exprs) = BloomOrExpr;

  /// Creates a negation of the [inner] expression (`NOT`).
  const factory BloomExpr.not(BloomExpr inner) = BloomNotExpr;

  /// Creates a comparison between [left] column and [right] column on the same row using [op].
  const factory BloomExpr.compareField({
    required String left,
    required CompareOp op,
    required String right,
  }) = BloomCompareFieldExpr;

  /// Bitwise `AND` operator combining this expression with [rhs].
  BloomExpr operator &(BloomExpr rhs) {
    final leftList = this is BloomAndExpr
        ? (this as BloomAndExpr).exprs
        : <BloomExpr>[this];
    final rightList =
        rhs is BloomAndExpr ? rhs.exprs : <BloomExpr>[rhs];
    return BloomExpr.and([...leftList, ...rightList]);
  }

  /// Bitwise `OR` operator combining this expression with [rhs].
  BloomExpr operator |(BloomExpr rhs) {
    final leftList =
        this is BloomOrExpr ? (this as BloomOrExpr).exprs : <BloomExpr>[this];
    final rightList =
        rhs is BloomOrExpr ? rhs.exprs : <BloomExpr>[rhs];
    return BloomExpr.or([...leftList, ...rightList]);
  }

  /// Unary bitwise `NOT` operator negating this expression.
  BloomExpr operator ~() => BloomExpr.not(this);
}

/// Resolved comparison expression between a database column [field] and a literal [value].
///
/// Example:
/// ```dart
/// final expr = BloomCompareExpr(
///   field: 'score',
///   op: CompareOp.gt,
///   value: BloomValue.i64(50),
/// );
/// ```
class BloomCompareExpr extends BloomExpr {
  /// The database column name to compare.
  final String field;

  /// The comparison operator.
  final CompareOp op;

  /// The value compared against.
  final BloomValue value;

  /// Creates a resolved field comparison expression.
  const BloomCompareExpr({
    required this.field,
    required this.op,
    required this.value,
  });

  @override
  String toString() => 'BloomCompare($field $op $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomCompareExpr &&
          field == other.field &&
          op == other.op &&
          value == other.value;

  @override
  int get hashCode => Object.hash(field, op, value);
}

/// Resolved conjunction of multiple expressions combined with `AND`.
///
/// Example:
/// ```dart
/// final expr = BloomAndExpr([e1, e2]);
/// ```
class BloomAndExpr extends BloomExpr {
  /// The child expressions combined with `AND`.
  final List<BloomExpr> exprs;

  /// Creates a resolved `AND` conjunction of [exprs].
  const BloomAndExpr(this.exprs);

  @override
  String toString() => 'BloomAnd(${exprs.join(" AND ")})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomAndExpr &&
          exprs.length == other.exprs.length &&
          List.generate(exprs.length, (i) => exprs[i] == other.exprs[i])
              .every((b) => b);

  @override
  int get hashCode => Object.hashAll(exprs);
}

/// Resolved disjunction of multiple expressions combined with `OR`.
///
/// Example:
/// ```dart
/// final expr = BloomOrExpr([e1, e2]);
/// ```
class BloomOrExpr extends BloomExpr {
  /// The child expressions combined with `OR`.
  final List<BloomExpr> exprs;

  /// Creates a resolved `OR` disjunction of [exprs].
  const BloomOrExpr(this.exprs);

  @override
  String toString() => 'BloomOr(${exprs.join(" OR ")})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomOrExpr &&
          exprs.length == other.exprs.length &&
          List.generate(exprs.length, (i) => exprs[i] == other.exprs[i])
              .every((b) => b);

  @override
  int get hashCode => Object.hashAll(exprs);
}

/// Resolved negation of an expression (`NOT`).
///
/// Example:
/// ```dart
/// final expr = BloomNotExpr(innerExpr);
/// ```
class BloomNotExpr extends BloomExpr {
  /// The inner expression being negated.
  final BloomExpr inner;

  /// Creates a resolved `NOT` expression wrapping [inner].
  const BloomNotExpr(this.inner);

  @override
  String toString() => 'BloomNot($inner)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomNotExpr && inner == other.inner;

  @override
  int get hashCode => inner.hashCode;
}

/// Resolved column-to-column comparison on the same database row.
///
/// Example:
/// ```dart
/// final expr = BloomCompareFieldExpr(
///   left: 'updated_at',
///   op: CompareOp.gt,
///   right: 'created_at',
/// );
/// ```
class BloomCompareFieldExpr extends BloomExpr {
  /// The left-hand column name.
  final String left;

  /// The comparison operator.
  final CompareOp op;

  /// The right-hand column name.
  final String right;

  /// Creates a column-to-column comparison expression.
  const BloomCompareFieldExpr({
    required this.left,
    required this.op,
    required this.right,
  });

  @override
  String toString() => 'BloomCompareField($left $op $right)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomCompareFieldExpr &&
          left == other.left &&
          op == other.op &&
          right == other.right;

  @override
  int get hashCode => Object.hash(left, op, right);
}

/// Unresolved filter expression AST before model metadata validation and column resolution.
///
/// Constructed via [Q] and [QF] helper functions or fluent operators (`&`, `|`, `~`).
/// During query compilation, the [QuerySet] validates that all referenced fields exist on the model
/// and transforms the tree into a resolved [BloomExpr].
///
/// Mirrors `djangors_orm::expr::UnresolvedExpr`.
///
/// Example:
/// ```dart
/// final expr = Q('age__gte', 18) & (Q('is_active', true) | Q('is_staff', true));
/// ```
sealed class UnresolvedExpr {
  /// Base const constructor for unresolved expressions.
  const UnresolvedExpr();

  /// Conjunction of unresolved field comparisons between [field] and [value].
  const factory UnresolvedExpr.compare(String field, BloomValue value) =
      UnresolvedCompare;

  /// Conjunction of column-to-column comparisons between [left] and [right].
  const factory UnresolvedExpr.fieldCompare(String left, String right) =
      UnresolvedFieldCompare;

  /// Conjunction of [nodes] combined with `AND`.
  const factory UnresolvedExpr.all(List<UnresolvedExpr> nodes) = UnresolvedAll;

  /// Disjunction of [nodes] combined with `OR`.
  const factory UnresolvedExpr.any(List<UnresolvedExpr> nodes) = UnresolvedAny;

  /// Negation of [inner] expression (`NOT`).
  const factory UnresolvedExpr.negate(UnresolvedExpr inner) = UnresolvedNegate;

  /// Bitwise `AND` operator combining this expression with [rhs].
  UnresolvedExpr operator &(UnresolvedExpr rhs) {
    final l = this is UnresolvedAll
        ? (this as UnresolvedAll).nodes
        : <UnresolvedExpr>[this];
    final r = rhs is UnresolvedAll
        ? rhs.nodes
        : <UnresolvedExpr>[rhs];
    return UnresolvedExpr.all([...l, ...r]);
  }

  /// Bitwise `OR` operator combining this expression with [rhs].
  UnresolvedExpr operator |(UnresolvedExpr rhs) {
    final l = this is UnresolvedAny
        ? (this as UnresolvedAny).nodes
        : <UnresolvedExpr>[this];
    final r = rhs is UnresolvedAny
        ? rhs.nodes
        : <UnresolvedExpr>[rhs];
    return UnresolvedExpr.any([...l, ...r]);
  }

  /// Unary bitwise `NOT` operator negating this unresolved expression.
  UnresolvedExpr operator ~() => UnresolvedExpr.negate(this);
}

/// Unresolved comparison node representing `field = value` or `field__lookup = value`.
///
/// Created by the [Q] helper function.
///
/// Example:
/// ```dart
/// final node = UnresolvedCompare('email__icontains', BloomValue.text('example.com'));
/// ```
class UnresolvedCompare extends UnresolvedExpr {
  /// The field lookup string (e.g. `'age__gte'`, `'name__icontains'`).
  final String field;

  /// The comparison value.
  final BloomValue value;

  /// Creates an unresolved field comparison with [field] lookup and [value].
  const UnresolvedCompare(this.field, this.value);

  @override
  String toString() => 'Q($field: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnresolvedCompare &&
          field == other.field &&
          value == other.value;

  @override
  int get hashCode => Object.hash(field, value);
}

/// Unresolved column-to-column comparison node on the same row.
///
/// Created by the [QF] helper function.
///
/// Example:
/// ```dart
/// final node = UnresolvedFieldCompare('created_at__lte', 'expires_at');
/// ```
class UnresolvedFieldCompare extends UnresolvedExpr {
  /// The left-hand field lookup string (e.g. `'updated_at__gt'`).
  final String left;

  /// The right-hand field name.
  final String right;

  /// Creates an unresolved column-to-column comparison between [left] and [right].
  const UnresolvedFieldCompare(this.left, this.right);

  @override
  String toString() => 'QF($left, $right)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnresolvedFieldCompare &&
          left == other.left &&
          right == other.right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// Unresolved conjunction of sub-expressions combined with `AND`.
///
/// Example:
/// ```dart
/// final allExpr = UnresolvedAll([q1, q2]);
/// ```
class UnresolvedAll extends UnresolvedExpr {
  /// The child nodes combined with `AND`.
  final List<UnresolvedExpr> nodes;

  /// Creates an unresolved `AND` conjunction of [nodes].
  const UnresolvedAll(this.nodes);

  @override
  String toString() => 'QAll(${nodes.join(" & ")})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnresolvedAll &&
          nodes.length == other.nodes.length &&
          List.generate(nodes.length, (i) => nodes[i] == other.nodes[i])
              .every((b) => b);

  @override
  int get hashCode => Object.hashAll(nodes);
}

/// Unresolved disjunction of sub-expressions combined with `OR`.
///
/// Example:
/// ```dart
/// final anyExpr = UnresolvedAny([q1, q2]);
/// ```
class UnresolvedAny extends UnresolvedExpr {
  /// The child nodes combined with `OR`.
  final List<UnresolvedExpr> nodes;

  /// Creates an unresolved `OR` disjunction of [nodes].
  const UnresolvedAny(this.nodes);

  @override
  String toString() => 'QAny(${nodes.join(" | ")})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnresolvedAny &&
          nodes.length == other.nodes.length &&
          List.generate(nodes.length, (i) => nodes[i] == other.nodes[i])
              .every((b) => b);

  @override
  int get hashCode => Object.hashAll(nodes);
}

/// Unresolved negation of a sub-expression (`NOT`).
///
/// Example:
/// ```dart
/// final notExpr = UnresolvedNegate(q);
/// ```
class UnresolvedNegate extends UnresolvedExpr {
  /// The inner node being negated.
  final UnresolvedExpr inner;

  /// Creates an unresolved negation wrapping [inner].
  const UnresolvedNegate(this.inner);

  @override
  String toString() => 'QNot($inner)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnresolvedNegate && inner == other.inner;

  @override
  int get hashCode => inner.hashCode;
}

/// Helper function to construct an [UnresolvedExpr] filter node — Django's `Q()` object.
///
/// Supports lookup suffixes such as `__gte`, `__lte`, `__icontains`, `__in`, `__isnull`, `__ne`, etc.
///
/// Example:
/// ```dart
/// final expr = Q('age__gte', 18) & Q('is_active', true);
/// final inExpr = Q('status__in', ['pending', 'approved']);
/// ```
UnresolvedExpr Q(String field, dynamic value) {
  return UnresolvedExpr.compare(field, BloomValue.from(value));
}

/// Helper function to construct column-to-column comparisons on the same database row — Django's `q_f!`.
///
/// Compares [leftField] with [rightField], supporting lookup suffixes on [leftField].
///
/// Example:
/// ```dart
/// final expr = QF('modified_at__gt', 'created_at');
/// ```
UnresolvedExpr QF(String leftField, String rightField) {
  return UnresolvedExpr.fieldCompare(leftField, rightField);
}

/// Expression specifying a value update in an `UPDATE` query.
///
/// Supports literal updates via [LiteralSetExpr] and in-database column arithmetic via [FieldOpSetExpr] (using [F]).
///
/// Mirrors `djangors_orm::expr::SetExpr`.
///
/// Example:
/// ```dart
/// final lit = SetExpr.literal(BloomValue.i64(10));
/// final fieldOp = F('count') + 1; // Produces FieldOpSetExpr
/// ```
sealed class SetExpr {
  /// Base const constructor for `UPDATE` assignment expressions.
  const SetExpr();

  /// A literal new [value] assignment.
  const factory SetExpr.literal(BloomValue value) = LiteralSetExpr;

  /// An in-database field arithmetic operation on [field] with [op] and [operand].
  const factory SetExpr.fieldOp({
    required String field,
    required ArithOp op,
    required BloomValue operand,
  }) = FieldOpSetExpr;

  /// Converts or wraps an arbitrary dynamic value [val] into a [SetExpr].
  ///
  /// Returns [val] directly if already a [SetExpr], or wraps in [SetExpr.literal].
  ///
  /// Example:
  /// ```dart
  /// final s1 = SetExpr.from(42);
  /// final s2 = SetExpr.from(F('views') + 1);
  /// ```
  static SetExpr from(dynamic val) {
    if (val is SetExpr) return val;
    return SetExpr.literal(BloomValue.from(val));
  }
}

/// Literal value assignment in an `UPDATE` query (`col = $1`).
///
/// Example:
/// ```dart
/// final setExpr = LiteralSetExpr(BloomValue.text('Alice'));
/// ```
class LiteralSetExpr extends SetExpr {
  /// The literal value to assign.
  final BloomValue value;

  /// Creates a literal update assignment with [value].
  const LiteralSetExpr(this.value);

  @override
  String toString() => 'SetExpr.literal($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiteralSetExpr && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// In-database field arithmetic update operation (e.g. `col = col + 1`).
///
/// Example:
/// ```dart
/// final setExpr = FieldOpSetExpr(
///   field: 'views',
///   op: ArithOp.add,
///   operand: BloomValue.i64(1),
/// );
/// ```
class FieldOpSetExpr extends SetExpr {
  /// The source field name for arithmetic.
  final String field;

  /// The arithmetic operator (`+`, `-`, `*`, `/`).
  final ArithOp op;

  /// The operand value.
  final BloomValue operand;

  /// Creates a field arithmetic assignment expression.
  const FieldOpSetExpr({
    required this.field,
    required this.op,
    required this.operand,
  });

  @override
  String toString() => 'SetExpr.fieldOp($field $op $operand)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldOpSetExpr &&
          field == other.field &&
          op == other.op &&
          operand == other.operand;

  @override
  int get hashCode => Object.hash(field, op, operand);
}

/// Django's `F()` expression — a reference to a field's existing value in the database.
///
/// Used for atomic database-side calculations in updates to avoid race conditions:
///
/// Example:
/// ```dart
/// await queryset.filter(Q('id', 1)).update(db, {
///   'score': F('score') + 10,
///   'attempts': F('attempts') + 1,
/// });
/// ```
class F {
  /// The referenced database field name.
  final String field;

  /// Creates an `F()` expression referencing [field].
  const F(this.field);

  /// Addition operator generating `field = field + rhs`.
  SetExpr operator +(num rhs) => SetExpr.fieldOp(
        field: field,
        op: ArithOp.add,
        operand: rhs is int ? BloomValue.i64(rhs) : BloomValue.f64(rhs.toDouble()),
      );

  /// Subtraction operator generating `field = field - rhs`.
  SetExpr operator -(num rhs) => SetExpr.fieldOp(
        field: field,
        op: ArithOp.sub,
        operand: rhs is int ? BloomValue.i64(rhs) : BloomValue.f64(rhs.toDouble()),
      );

  /// Multiplication operator generating `field = field * rhs`.
  SetExpr operator *(num rhs) => SetExpr.fieldOp(
        field: field,
        op: ArithOp.mul,
        operand: rhs is int ? BloomValue.i64(rhs) : BloomValue.f64(rhs.toDouble()),
      );

  /// Division operator generating `field = field / rhs`.
  SetExpr operator /(num rhs) => SetExpr.fieldOp(
        field: field,
        op: ArithOp.div,
        operand: rhs is int ? BloomValue.i64(rhs) : BloomValue.f64(rhs.toDouble()),
      );
}

/// Splits a field lookup string (e.g. `"age__gte"`) into field name `"age"` and suffix `"gte"`.
///
/// Returns `(fieldName, suffix)` tuple. If no recognizable suffix is present, returns `(s, 'eq')`.
///
/// Example:
/// ```dart
/// final (field, suffix) = splitFieldLookup('age__gte');
/// assert(field == 'age');
/// assert(suffix == 'gte');
/// ```
(String, String) splitFieldLookup(String s) {
  final idx = s.lastIndexOf('__');
  if (idx != -1) {
    final field = s.substring(0, idx);
    final suffix = s.substring(idx + 2);
    switch (suffix) {
      case 'eq':
      case 'lt':
      case 'lte':
      case 'gt':
      case 'gte':
      case 'contains':
      case 'icontains':
      case 'startswith':
      case 'endswith':
      case 'ne':
      case 'iexact':
      case 'in':
      case 'isnull':
      case 'regex':
      case 'iregex':
        return (field, suffix);
      default:
        return (s, 'eq');
    }
  }
  return (s, 'eq');
}

/// Converts a lookup suffix string (e.g. `'gte'`, `'icontains'`, `'in'`) into the corresponding [CompareOp].
///
/// Defaults to [CompareOp.eq] if the suffix is unrecognized.
///
/// Example:
/// ```dart
/// final op = suffixToOp('icontains');
/// assert(op == CompareOp.icontains);
/// ```
CompareOp suffixToOp(String suffix) {
  switch (suffix) {
    case 'eq':
      return CompareOp.eq;
    case 'ne':
      return CompareOp.ne;
    case 'lt':
      return CompareOp.lt;
    case 'lte':
      return CompareOp.lte;
    case 'gt':
      return CompareOp.gt;
    case 'gte':
      return CompareOp.gte;
    case 'contains':
      return CompareOp.contains;
    case 'icontains':
      return CompareOp.icontains;
    case 'startswith':
      return CompareOp.startsWith;
    case 'endswith':
      return CompareOp.endsWith;
    case 'iexact':
      return CompareOp.iexact;
    case 'in':
      return CompareOp.isIn;
    case 'isnull':
      return CompareOp.isNull;
    case 'regex':
      return CompareOp.regex;
    case 'iregex':
      return CompareOp.iregex;
    default:
      return CompareOp.eq;
  }
}


