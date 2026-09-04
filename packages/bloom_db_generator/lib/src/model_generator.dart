// lib/src/model_generator.dart
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// Code generator that processes classes annotated with [@BloomModel].
///
/// [ModelGenerator] inspects Dart classes annotated with [BloomModel]
/// and generates ORM boilerplate code into a part file (`.g.dart`).
///
/// ### Generated Code Components
///
/// For each annotated class (e.g. `User`), [ModelGenerator] produces:
///
/// 1. **Metadata Definition (`_$UserModelMeta`)**: A `const ModelMeta` instance
///    capturing struct name, application namespace, table name, primary key ordering,
///    and a list of [FieldMeta] descriptors (with columns, [FieldKind] mappings,
///    nullability, primary key, auto-increment, unique, and index flags).
/// 2. **ORM Mixin (`_$UserMixin`)**: A mixin implementing `Model` which defines
///    abstract getters for every model field, provides [modelMeta], and implements
///    `fieldValues()` and `toRow()`.
/// 3. **ORM Extension (`UserOrmExtension`)**: An extension on `User` adding:
///    - `static ModelMeta meta()`: Static metadata accessor.
///    - `static List<String> fieldNames()`: List of field names in declaration order.
///    - `static User fromRow(DbRow row)`: Type-safe instantiation from a database row.
///    - `static QuerySet<User> objects()`: Creates a new [QuerySet] configured with model metadata and `fromRow`.
///    - `Future<User> save(DbExecutor db)`: Inserts the record using `RETURNING *` and returns a refreshed instance.
///    - `Future<void> update(DbExecutor db)`: Updates non-primary-key columns matching the record's primary key.
///    - `Future<void> delete(DbExecutor db)`: Deletes the database row matching the record's primary key.
///
/// ### Field Discovery & Type Inference
///
/// Model fields are extracted from non-static, non-synthetic class fields. Column properties
/// can be customized via `@BloomField`:
///
/// - **Column Name**: Uses `BloomField.column` or defaults to the field's snake_case name.
/// - **Primary Key**: Uses `BloomField.primaryKey` or defaults to `true` if field name is `id`.
/// - **Auto-increment**: Uses `BloomField.auto` or defaults to `true` for integer primary keys.
/// - **Nullability**: Uses `BloomField.nullable` or checks the Dart type's nullability suffix.
/// - **Field Kind**: Uses `BloomField.kind` or infers standard mappings:
///   - `int` -> `FieldKind.bigInt`
///   - `double` / `num` -> `FieldKind.float`
///   - `bool` -> `FieldKind.boolean`
///   - `DateTime` -> `FieldKind.dateTime`
///   - `String` / other -> `FieldKind.text`
///   - `decimal` -> `FieldKind.decimal(precision: ..., scale: ...)`
///
/// Example:
/// ```dart
/// import 'package:bloom_db/bloom_db.dart';
///
/// part 'user.g.dart';
///
/// @BloomModel(app: 'auth', tableName: 'auth_users')
/// class User with _$UserMixin {
///   @idField
///   final int id;
///
///   final String name;
///
///   @BloomField(column: 'email_address', unique: true, dbIndex: true)
///   final String email;
///
///   User({this.id = 0, required this.name, required this.email});
/// }
/// ```
class ModelGenerator extends GeneratorForAnnotation<BloomModel> {
  /// Creates a [ModelGenerator] instance.
  ///
  /// Can be passed directly to a [SharedPartBuilder] or used in custom
  /// `build_runner` generator pipelines.
  ///
  /// Example:
  /// ```dart
  /// final generator = ModelGenerator();
  /// ```
  const ModelGenerator();

  /// Generates ORM metadata, mixins, and extensions for a single [@BloomModel] annotated [element].
  ///
  /// Inspects the [ClassElement] metadata and fields, resolves the application label
  /// and database table name from [annotation] (falling back to package name inference and
  /// snake_case class name), and produces the generated Dart source code string.
  ///
  /// Throws [InvalidGenerationSourceError] if [element] is not a [ClassElement] or
  /// if no field on the class is designated as a primary key.
  ///
  /// - [element]: The annotated Dart AST element, which must be a [ClassElement].
  /// - [annotation]: The constant representation of the `@BloomModel` annotation.
  /// - [buildStep]: The current build execution context used for asset resolution.
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '`@BloomModel` can only be applied to classes.',
        element: element,
      );
    }

    final className = element.name;
    final appLabel =
        annotation.peek('app')?.stringValue ?? _inferAppLabel(buildStep);
    final rawTableName = annotation.peek('tableName')?.stringValue;
    final tableName = rawTableName ?? '${appLabel}_${_snakeCase(className)}';

    final fields = <_ParsedField>[];

    for (final field in element.fields) {
      if (field.isStatic || field.isSynthetic) continue;

      final fieldName = field.name;
      final fieldType = field.type;

      final fieldAnn = _getFieldAnnotation(field);
      final columnName = fieldAnn?.columnName ?? _snakeCase(fieldName);
      final isPk = fieldAnn?.primaryKey ?? (fieldName == 'id');
      final isAuto = fieldAnn?.auto ?? (isPk && _isInt(fieldType));
      final isNullable = fieldAnn?.nullable ??
          (fieldType.nullabilitySuffix == NullabilitySuffix.question);
      final kindStr = fieldAnn?.kindString ?? _inferFieldKind(fieldType);

      fields.add(_ParsedField(
        name: fieldName,
        columnName: columnName,
        type: fieldType,
        kindString: kindStr,
        primaryKey: isPk,
        auto: isAuto,
        nullable: isNullable,
        dbIndex: fieldAnn?.dbIndex ?? false,
        unique: fieldAnn?.unique ?? false,
        maxLength: fieldAnn?.maxLength,
        defaultVal: fieldAnn?.defaultVal,
      ));
    }

    final pkField = fields.firstWhere(
      (f) => f.primaryKey,
      orElse: () => throw InvalidGenerationSourceError(
        'Class $className must have at least one primary key field (e.g. `id`).',
        element: element,
      ),
    );

    return _generateModelCode(
      className: className,
      appLabel: appLabel,
      tableName: tableName,
      fields: fields,
      pkField: pkField,
    );
  }

  static String _inferAppLabel(BuildStep buildStep) {
    final pkg = buildStep.inputId.package;
    return _snakeCase(pkg.replaceAll('bloom_', ''));
  }

  static _FieldAnnotationData? _getFieldAnnotation(FieldElement field) {
    for (final meta in field.metadata) {
      final value = meta.computeConstantValue();
      if (value == null) continue;
      final typeName = value.type?.element?.name;
      if (typeName == 'BloomField') {
        final reader = ConstantReader(value);
        final src = meta.toSource();

        if (!src.contains('(')) {
          final isIdField = src.contains('idField');
          return _FieldAnnotationData(
            columnName: reader.peek('column')?.stringValue,
            primaryKey: isIdField ? true : reader.peek('primaryKey')?.boolValue,
            auto: isIdField ? true : reader.peek('auto')?.boolValue,
            nullable: isIdField ? null : reader.peek('nullable')?.boolValue,
            unique: isIdField ? null : reader.peek('unique')?.boolValue,
            dbIndex: isIdField ? null : reader.peek('dbIndex')?.boolValue,
            kindString: _readKind(reader.peek('kind')),
            maxLength: isIdField ? null : reader.peek('maxLength')?.intValue,
            defaultVal:
                isIdField ? null : _readDefaultValue(reader.peek('defaultVal')),
          );
        }

        final namedArgs = _parseAnnotationNamedArgs(src);
        return _FieldAnnotationData(
          columnName: namedArgs.contains('column')
              ? reader.peek('column')?.stringValue
              : null,
          primaryKey: namedArgs.contains('primaryKey')
              ? reader.peek('primaryKey')?.boolValue
              : null,
          auto: namedArgs.contains('auto')
              ? reader.peek('auto')?.boolValue
              : null,
          nullable: namedArgs.contains('nullable')
              ? reader.peek('nullable')?.boolValue
              : null,
          unique: namedArgs.contains('unique')
              ? reader.peek('unique')?.boolValue
              : null,
          dbIndex: namedArgs.contains('dbIndex')
              ? reader.peek('dbIndex')?.boolValue
              : null,
          kindString: namedArgs.contains('kind')
              ? _readKind(reader.peek('kind'))
              : null,
          maxLength: namedArgs.contains('maxLength')
              ? reader.peek('maxLength')?.intValue
              : null,
          defaultVal: namedArgs.contains('defaultVal')
              ? _readDefaultValue(reader.peek('defaultVal'))
              : null,
        );
      }
    }
    return null;
  }

  static Set<String> _parseAnnotationNamedArgs(String src) {
    try {
      final parsed = parseString(content: '$src final _dummy = 0;');
      if (parsed.unit.declarations.isNotEmpty) {
        final decl = parsed.unit.declarations.first;
        if (decl is TopLevelVariableDeclaration && decl.metadata.isNotEmpty) {
          final ann = decl.metadata.first;
          final args = ann.arguments?.arguments;
          if (args != null) {
            final set = <String>{};
            for (final arg in args) {
              if (arg is NamedExpression) {
                set.add(arg.name.label.name);
              }
            }
            return set;
          }
        }
      }
    } catch (_) {}
    return const {};
  }

  static String? _readKind(ConstantReader? reader) {
    if (reader == null || reader.isNull) return null;
    final obj = reader.objectValue;
    final typeName = obj.type?.element?.name;
    if (typeName == 'DecimalFieldKind') {
      final prec = obj.getField('precision')?.toIntValue() ?? 10;
      final scale = obj.getField('scale')?.toIntValue() ?? 2;
      return 'const FieldKind.decimal(precision: $prec, scale: $scale)';
    }
    final nameField = obj.getField('name')?.toStringValue();
    if (nameField != null) {
      if (nameField == 'decimal') {
        final prec = obj.getField('precision')?.toIntValue() ?? 10;
        final scale = obj.getField('scale')?.toIntValue() ?? 2;
        return 'const FieldKind.decimal(precision: $prec, scale: $scale)';
      }
      return 'FieldKind.$nameField';
    }
    return null;
  }

  static String? _readDefaultValue(ConstantReader? reader) {
    if (reader == null || reader.isNull) return null;
    final obj = reader.objectValue;
    final typeName = obj.type?.element?.name ?? '';
    if (typeName.endsWith('NoneDefaultValue')) {
      return 'const DefaultValue.none()';
    }
    final value = obj.getField('value');
    if (value == null) return null;
    if (typeName.endsWith('I64DefaultValue')) {
      final intValue = value.toIntValue();
      return intValue == null ? null : 'const DefaultValue.i64($intValue)';
    }
    if (typeName.endsWith('F64DefaultValue')) {
      final doubleValue = value.toDoubleValue();
      return doubleValue == null
          ? null
          : 'const DefaultValue.f64($doubleValue)';
    }
    if (typeName.endsWith('BoolDefaultValue')) {
      final boolValue = value.toBoolValue();
      return boolValue == null
          ? null
          : 'const DefaultValue.boolVal($boolValue)';
    }
    if (typeName.endsWith('TextDefaultValue')) {
      final stringValue = value.toStringValue();
      if (stringValue == null) return null;
      final escaped =
          stringValue.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      return "const DefaultValue.text('$escaped')";
    }
    return null;
  }

  static bool _isInt(DartType type) {
    return type.getDisplayString(withNullability: false) == 'int';
  }

  static String _inferFieldKind(DartType type) {
    final name = type.getDisplayString(withNullability: false);
    switch (name) {
      case 'int':
        return 'FieldKind.bigInt';
      case 'double':
      case 'num':
        return 'FieldKind.float';
      case 'bool':
        return 'FieldKind.boolean';
      case 'DateTime':
        return 'FieldKind.dateTime';
      case 'String':
        return 'FieldKind.text';
      default:
        return 'FieldKind.text';
    }
  }

  static String _generateModelCode({
    required String className,
    required String appLabel,
    required String tableName,
    required List<_ParsedField> fields,
    required _ParsedField pkField,
  }) {
    final metaFieldsBuffer = StringBuffer();
    for (final f in fields) {
      final maxLengthLine =
          f.maxLength == null ? '' : '      maxLength: ${f.maxLength},\n';
      final defaultValLine =
          f.defaultVal == null || f.defaultVal == 'const DefaultValue.none()'
              ? ''
              : '      defaultVal: ${f.defaultVal},\n';
      metaFieldsBuffer.writeln('''
    FieldMeta(
      name: '${f.name}',
      columnName: '${f.columnName}',
      kind: ${f.kindString},
      nullable: ${f.nullable},
      primaryKey: ${f.primaryKey},
      auto: ${f.auto},
      unique: ${f.unique},
      dbIndex: ${f.dbIndex},
${maxLengthLine}${defaultValLine}    ),''');
    }

    final abstractGetters = StringBuffer();
    for (final f in fields) {
      final typeDisplay = f.type.getDisplayString(withNullability: true);
      abstractGetters.writeln('  $typeDisplay get ${f.name};');
    }

    final fromRowAssignments = StringBuffer();
    for (final f in fields) {
      final typeStr = f.type.getDisplayString(withNullability: false);
      final nullable = f.nullable;

      final decodeExpr = switch (typeStr) {
        'int' => nullable
            ? "row.tryIntByName('${f.columnName}')"
            : "row.tryIntByName('${f.columnName}') ?? 0",
        'double' => nullable
            ? "row.tryDoubleByName('${f.columnName}')"
            : "row.tryDoubleByName('${f.columnName}') ?? 0.0",
        'num' => nullable
            ? "row.tryDoubleByName('${f.columnName}')"
            : "row.tryDoubleByName('${f.columnName}') ?? 0",
        'bool' => nullable
            ? "row.tryBoolByName('${f.columnName}')"
            : "row.tryBoolByName('${f.columnName}') ?? false",
        'DateTime' => nullable
            ? "row.tryDateTimeByName('${f.columnName}')"
            : "row.tryDateTimeByName('${f.columnName}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)",
        _ => nullable
            ? "row.tryStringByName('${f.columnName}')"
            : "row.tryStringByName('${f.columnName}') ?? ''",
      };

      fromRowAssignments.writeln('      ${f.name}: $decodeExpr,');
    }

    final fieldValuesList = StringBuffer();
    for (final f in fields) {
      fieldValuesList.writeln(
        "        ('${f.name}', BloomValue.from(${f.name})),",
      );
    }

    final fieldNamesList = StringBuffer();
    for (final f in fields) {
      fieldNamesList.writeln("        '${f.name}',");
    }

    final saveCols = fields.where((f) => !f.auto).toList();
    final saveColsList = saveCols.map((f) => "'${f.columnName}'").join(', ');

    final updateCols = fields.where((f) => !f.primaryKey).toList();
    final updateFieldsList = updateCols
        .map((f) => "_\$${className}ModelMeta.findField('${f.name}')!")
        .join(', ');

    return '''
// **************************************************************************
// BloomModelGenerator
// **************************************************************************

/// Static metadata for [$className].
const ModelMeta _\$${className}ModelMeta = ModelMeta(
  structName: '$className',
  appLabel: '$appLabel',
  tableName: '$tableName',
  fields: [
$metaFieldsBuffer  ],
  ordering: ['${pkField.name}'],
);

/// Generated ORM mixin for [$className].
mixin _\$${className}Mixin implements Model {
$abstractGetters
  @override
  ModelMeta get modelMeta => _\$${className}ModelMeta;

  @override
  List<(String, BloomValue)> fieldValues() => [
$fieldValuesList      ];

  @override
  Map<String, dynamic> toRow() {
    final values = fieldValues();
    final meta = modelMeta;
    final map = <String, dynamic>{};
    for (final (fieldName, val) in values) {
      final f = meta.findField(fieldName);
      final colName = f != null ? f.columnName : fieldName;
      map[colName] = val.raw;
    }
    return map;
  }
}

/// Generated extension providing ORM operations for [$className].
extension ${className}OrmExtension on $className {
  /// Static accessor for [$className] metadata.
  static ModelMeta meta() => _\$${className}ModelMeta;

  /// Every field's name in declaration order.
  static List<String> fieldNames() => [
$fieldNamesList      ];

  /// Constructs a [$className] instance from a [DbRow].
  static $className fromRow(DbRow row) {
    return $className(
$fromRowAssignments    );
  }

  /// Creates a new [QuerySet] for [$className].
  static QuerySet<$className> objects() {
    return QuerySet<$className>(
      meta: _\$${className}ModelMeta,
      fromRow: fromRow,
    );
  }

  /// Saves a new record into the database (INSERT-only).
  ///
  /// Fields with `auto: true` are excluded from the column list.
  /// Uses `RETURNING *` and returns a NEW [$className] instance populated from the inserted database row.
  Future<$className> save(DbExecutor db) async {
    final dialect = db.dialect;
    final saveCols = <String>[$saveColsList];
    final placeholders = <String>[];
    final params = <dynamic>[];
    var paramIdx = 1;

    final valuesMap = {for (final (k, v) in fieldValues()) k: v.raw};
    for (final col in saveCols) {
      final f = _\$${className}ModelMeta.findField(col)!;
      placeholders.add(dialect.placeholder(paramIdx++));
      params.add(valuesMap[f.name]);
    }

    final colsQuoted = saveCols.map((c) => '"\$c"').join(', ');
    final sql = saveCols.isEmpty
        ? 'INSERT INTO "$tableName" DEFAULT VALUES RETURNING *'
        : 'INSERT INTO "$tableName" (\$colsQuoted) VALUES (\${placeholders.join(', ')}) RETURNING *';

    final row = await db.fetchOne(sql, params);
    return fromRow(row);
  }

  /// Updates the database record matching this instance's primary key.
  ///
  /// Sets every non-primary-key column to the current instance values.
  /// Throws [BloomOrmNotFoundError] if no row was updated (0 affected rows).
  Future<void> update(DbExecutor db) async {
    final dialect = db.dialect;
    final updateFields = <FieldMeta>[
      $updateFieldsList
    ];

    final setClauses = <String>[];
    final params = <dynamic>[];
    var paramIdx = 1;

    final valuesMap = {for (final (k, v) in fieldValues()) k: v.raw};
    for (final f in updateFields) {
      setClauses.add('"\${f.columnName}" = \${dialect.placeholder(paramIdx++)}');
      params.add(valuesMap[f.name]);
    }

    final pkPlaceholder = dialect.placeholder(paramIdx++);
    params.add(${pkField.name});

    final sql =
        'UPDATE "$tableName" SET \${setClauses.join(', ')} WHERE "${pkField.columnName}" = \$pkPlaceholder';
    final rowsAffected = await db.execute(sql, params);
    if (rowsAffected == 0) {
      throw BloomOrmNotFoundError(model: '$className');
    }
  }

  /// Deletes the database record matching this instance's primary key.
  ///
  /// Throws [BloomOrmNotFoundError] if no row was deleted (0 affected rows).
  Future<void> delete(DbExecutor db) async {
    final dialect = db.dialect;
    final pkPlaceholder = dialect.placeholder(1);
    final sql = 'DELETE FROM "$tableName" WHERE "${pkField.columnName}" = \$pkPlaceholder';
    final rowsAffected = await db.execute(sql, [${pkField.name}]);
    if (rowsAffected == 0) {
      throw BloomOrmNotFoundError(model: '$className');
    }
  }
}
''';
  }

  static String _snakeCase(String s) {
    final sb = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c.toUpperCase() == c && c.toLowerCase() != c) {
        if (i > 0) sb.write('_');
        sb.write(c.toLowerCase());
      } else {
        sb.write(c);
      }
    }
    return sb.toString();
  }
}

class _FieldAnnotationData {
  final String? columnName;
  final bool? primaryKey;
  final bool? auto;
  final bool? nullable;
  final bool? unique;
  final bool? dbIndex;
  final String? kindString;
  final int? maxLength;
  final String? defaultVal;

  _FieldAnnotationData({
    this.columnName,
    this.primaryKey,
    this.auto,
    this.nullable,
    this.unique,
    this.dbIndex,
    this.kindString,
    this.maxLength,
    this.defaultVal,
  });
}

class _ParsedField {
  final String name;
  final String columnName;
  final DartType type;
  final String kindString;
  final bool primaryKey;
  final bool auto;
  final bool nullable;
  final bool dbIndex;
  final bool unique;
  final int? maxLength;
  final String? defaultVal;

  _ParsedField({
    required this.name,
    required this.columnName,
    required this.type,
    required this.kindString,
    required this.primaryKey,
    required this.auto,
    required this.nullable,
    required this.dbIndex,
    required this.unique,
    this.maxLength,
    this.defaultVal,
  });
}
