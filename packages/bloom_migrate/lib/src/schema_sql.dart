// lib/src/schema_sql.dart
import 'package:bloom_db/bloom_db.dart';
import 'errors.dart';

/// Mapping of a model field's [FieldKind] to the corresponding SQL column type string for a given [Dialect].
///
/// Handles database dialect differences between PostgreSQL and SQLite:
/// - In PostgreSQL: maps [FieldKind.dateTime] to `TIMESTAMPTZ`, [FieldKind.json] to `JSONB`,
///   [FieldKind.uuid] to `UUID`, [FieldKind.binary] to `BYTEA`, [FieldKind.char] to `VARCHAR(maxLength)`,
///   and auto-increment integers to `SERIAL`/`BIGSERIAL`.
/// - In SQLite: maps text/date/json/uuid kinds to `TEXT`, integers to `INTEGER`, floats to `REAL`,
///   and binary to `BLOB`.
///
/// Example:
/// ```dart
/// final sqlType = fieldToSqlType(fieldMeta, Dialect.postgres);
/// print(sqlType); // e.g. 'VARCHAR(255)' or 'TIMESTAMPTZ'
/// ```
String fieldToSqlType(
  FieldMeta field,
  Dialect dialect, {
  String? modelName,
}) {
  final kind = field.kind;
  final isPostgres = dialect.type == DialectType.postgres;

  if (isPostgres) {
    if (kind == FieldKind.char) {
      final len = field.maxLength ?? 255;
      return 'VARCHAR($len)';
    } else if (kind == FieldKind.text) {
      return 'TEXT';
    } else if (kind == FieldKind.fileField) {
      final len = field.maxLength ?? 500;
      return 'VARCHAR($len)';
    } else if (kind == FieldKind.integer) {
      return field.auto ? 'SERIAL' : 'INTEGER';
    } else if (kind == FieldKind.bigInt) {
      return field.auto ? 'BIGSERIAL' : 'BIGINT';
    } else if (kind == FieldKind.float) {
      return 'DOUBLE PRECISION';
    } else if (kind == FieldKind.boolean) {
      return 'BOOLEAN';
    } else if (kind == FieldKind.date) {
      return 'DATE';
    } else if (kind == FieldKind.dateTime) {
      return 'TIMESTAMPTZ';
    } else if (kind == FieldKind.time) {
      return 'TIME';
    } else if (kind == FieldKind.duration) {
      return 'INTERVAL';
    } else if (kind == FieldKind.uuid) {
      return 'UUID';
    } else if (kind == FieldKind.email) {
      final len = field.maxLength ?? 254;
      return 'VARCHAR($len)';
    } else if (kind == FieldKind.url) {
      final len = field.maxLength ?? 2000;
      return 'VARCHAR($len)';
    } else if (kind == FieldKind.slug) {
      final len = field.maxLength ?? 50;
      return 'VARCHAR($len)';
    } else if (kind == FieldKind.ip) {
      return 'INET';
    } else if (kind == FieldKind.binary) {
      return 'BYTEA';
    } else if (kind == FieldKind.json) {
      return 'JSONB';
    } else if (kind is DecimalFieldKind) {
      return 'NUMERIC(${kind.precision}, ${kind.scale})';
    } else {
      return 'TEXT';
    }
  } else {
    // SQLite dialect
    if (kind == FieldKind.char ||
        kind == FieldKind.text ||
        kind == FieldKind.fileField ||
        kind == FieldKind.email ||
        kind == FieldKind.url ||
        kind == FieldKind.slug ||
        kind == FieldKind.date ||
        kind == FieldKind.dateTime ||
        kind == FieldKind.time ||
        kind == FieldKind.duration ||
        kind == FieldKind.uuid ||
        kind == FieldKind.ip ||
        kind == FieldKind.json) {
      return 'TEXT';
    } else if (kind == FieldKind.integer || kind == FieldKind.bigInt) {
      return 'INTEGER';
    } else if (kind == FieldKind.float) {
      return 'REAL';
    } else if (kind == FieldKind.boolean) {
      return 'INTEGER';
    } else if (kind == FieldKind.binary) {
      return 'BLOB';
    } else if (kind is DecimalFieldKind) {
      return 'NUMERIC';
    } else {
      return 'TEXT';
    }
  }
}

/// Converts a [DefaultValue] to its SQL literal string for the target [Dialect].
///
/// Formats integers, floats, booleans (`TRUE`/`FALSE` for PostgreSQL, `1`/`0` for SQLite),
/// and single-quote escaped strings. Returns `null` if [defaultValue] has no raw value.
///
/// Example:
/// ```dart
/// final sql = defaultValueToSql(DefaultValue.value('active'), Dialect.postgres);
/// print(sql); // "'active'"
/// ```
String? defaultValueToSql(DefaultValue defaultValue, Dialect dialect) {
  final isPostgres = dialect.type == DialectType.postgres;
  final raw = defaultValue.rawValue;
  if (raw == null) return null;

  if (raw is int || raw is double) {
    return '$raw';
  } else if (raw is bool) {
    if (isPostgres) {
      return raw ? 'TRUE' : 'FALSE';
    } else {
      return raw ? '1' : '0';
    }
  } else if (raw is String) {
    final escaped = raw.replaceAll("'", "''");
    return "'$escaped'";
  }
  return null;
}

/// Converts an [OnDelete] referential integrity action to SQL syntax.
///
/// Maps [OnDelete.cascade] to `CASCADE`, [OnDelete.protect] / [OnDelete.restrict] to `RESTRICT`,
/// [OnDelete.setNull] to `SET NULL`, and [OnDelete.doNothing] to `NO ACTION`.
///
/// Example:
/// ```dart
/// final clause = onDeleteToSql(OnDelete.cascade);
/// print(clause); // 'CASCADE'
/// ```
String onDeleteToSql(OnDelete onDelete) {
  switch (onDelete) {
    case OnDelete.cascade:
      return 'CASCADE';
    case OnDelete.protect:
    case OnDelete.restrict:
      return 'RESTRICT';
    case OnDelete.setNull:
      return 'SET NULL';
    case OnDelete.doNothing:
      return 'NO ACTION';
  }
}

/// Generates a single column definition clause for `CREATE TABLE`.
///
/// Composes the column name, dialect-specific SQL type, `PRIMARY KEY`, `AUTOINCREMENT`
/// (SQLite) or `SERIAL` (PostgreSQL), `NOT NULL`, `UNIQUE`, and `DEFAULT` value constraints.
///
/// Example:
/// ```dart
/// final columnClause = generateColumnDefinition(fieldMeta, Dialect.postgres);
/// print(columnClause); // 'email VARCHAR(254) NOT NULL UNIQUE'
/// ```
String generateColumnDefinition(
  FieldMeta field,
  Dialect dialect, {
  String? modelName,
}) {
  final isSqlite = dialect.type == DialectType.sqlite;
  final isPostgres = dialect.type == DialectType.postgres;
  final colName = field.columnName;
  final sqlType = fieldToSqlType(field, dialect, modelName: modelName);

  // SQLite AUTOINCREMENT handling
  if (isSqlite && field.primaryKey && field.auto) {
    return '$colName INTEGER PRIMARY KEY AUTOINCREMENT';
  }

  // Postgres BIGSERIAL / SERIAL handling
  if (isPostgres && field.primaryKey && field.auto) {
    return '$colName $sqlType PRIMARY KEY';
  }

  final buffer = StringBuffer('$colName $sqlType');

  if (field.primaryKey) {
    buffer.write(' PRIMARY KEY');
  }

  if (!field.nullable && !field.primaryKey) {
    buffer.write(' NOT NULL');
  }

  if (field.unique && !field.primaryKey) {
    buffer.write(' UNIQUE');
  }

  final defaultSql = defaultValueToSql(field.defaultVal, dialect);
  if (defaultSql != null) {
    buffer.write(' DEFAULT $defaultSql');
  }

  return buffer.toString();
}

/// Generates the `CREATE TABLE` DDL SQL string for a given [ModelMeta].
///
/// Assembles column definitions, foreign key and one-to-one relation constraints,
/// `CHECK` constraints for choices, and multi-column unique constraints (`unique_together`).
/// When [ifNotExists] is `true` (the default), prepends `IF NOT EXISTS`.
///
/// Example:
/// ```dart
/// final sql = generateCreateTableSql(userModelMeta, Dialect.postgres);
/// print(sql);
/// ```
String generateCreateTableSql(
  ModelMeta model,
  Dialect dialect, {
  bool ifNotExists = true,
}) {
  final ifNotExistsClause = ifNotExists ? 'IF NOT EXISTS ' : '';
  final lines = <String>[];

  // Standard fields
  for (final field in model.fields) {
    lines.add('    ${generateColumnDefinition(field, dialect, modelName: model.structName)}');
  }

  // Relations (ForeignKey and OneToOne fields)
  for (final relation in model.relations) {
    if (relation.kind == RelationKind.manyToMany) continue;

    final target = relation.target();
    final targetPk = target.primaryKeyField;
    final fkType = fieldToSqlType(targetPk, dialect, modelName: target.structName);

    final nullable = relation.onDelete == OnDelete.setNull;
    final nullClause = nullable ? '' : ' NOT NULL';
    final uniqueClause = relation.kind == RelationKind.oneToOne ? ' UNIQUE' : '';
    final onDeleteStr = onDeleteToSql(relation.onDelete);

    final line =
        '    ${relation.fieldName} $fkType$nullClause$uniqueClause REFERENCES ${target.tableName}(${targetPk.columnName}) ON DELETE $onDeleteStr';
    lines.add(line);
  }

  // Check constraints for choices
  for (final field in model.fields) {
    if (field.choices.isNotEmpty) {
      final choiceList = field.choices
          .map((c) => "'${c.$1.replaceAll("'", "''")}'")
          .join(', ');
      lines.add('    CONSTRAINT chk_${model.tableName}_${field.columnName} CHECK (${field.columnName} IN ($choiceList))');
    }
  }

  // Multi-column unique constraints (unique_together)
  for (var i = 0; i < model.uniqueTogether.length; i++) {
    final cols = model.uniqueTogether[i];
    final colList = cols.join(', ');
    final constraintName = 'uniq_${model.tableName}_${cols.join("_")}';
    lines.add('    CONSTRAINT $constraintName UNIQUE ($colList)');
  }

  return 'CREATE TABLE $ifNotExistsClause${model.tableName} (\n${lines.join(',\n')}\n);';
}

/// Generates all explicit and implied index SQL statements for a [ModelMeta].
///
/// Includes:
/// - Explicit composite indexes defined on [ModelMeta.indexes]
/// - Single-column indexes for fields with `dbIndex: true`
/// - Performance indexes on foreign key relation columns
///
/// Example:
/// ```dart
/// final indexStatements = generateIndexesSql(userModelMeta, Dialect.postgres);
/// for (final stmt in indexStatements) {
///   print(stmt);
/// }
/// ```
List<String> generateIndexesSql(ModelMeta model, Dialect dialect) {
  final stmts = <String>[];
  final ifNotExists = 'IF NOT EXISTS ';

  // Explicit model indexes
  for (final idx in model.indexes) {
    if (idx.fields.isEmpty) continue;
    final colList = idx.fields.join(', ');
    stmts.add('CREATE INDEX $ifNotExists${idx.name} ON ${model.tableName}($colList);');
  }

  // Field-level db_index
  for (final field in model.fields) {
    if (field.dbIndex && !field.primaryKey && !field.unique) {
      final idxName = '${model.tableName}_${field.columnName}_idx';
      stmts.add('CREATE INDEX $ifNotExists$idxName ON ${model.tableName}(${field.columnName});');
    }
  }

  // Foreign key relation indexes (standard practice for performance)
  for (final relation in model.relations) {
    if (relation.kind == RelationKind.foreignKey) {
      final idxName = '${model.tableName}_${relation.fieldName}_idx';
      stmts.add('CREATE INDEX $ifNotExists$idxName ON ${model.tableName}(${relation.fieldName});');
    }
  }

  return stmts;
}

/// Generates join tables for `ManyToMany` relations on a [ModelMeta].
///
/// For each many-to-many relationship, constructs a junction table named `<model.tableName>_<relation.fieldName>`
/// containing foreign keys referencing both participating tables with `CASCADE` delete actions,
/// a unique pair constraint, and indexes on both foreign key columns.
///
/// Example:
/// ```dart
/// final joinTableSqls = generateManyToManyTablesSql(userModelMeta, Dialect.postgres);
/// for (final sql in joinTableSqls) {
///   print(sql);
/// }
/// ```
List<String> generateManyToManyTablesSql(ModelMeta model, Dialect dialect) {
  final stmts = <String>[];

  for (final relation in model.relations) {
    if (relation.kind != RelationKind.manyToMany) continue;

    final target = relation.target();
    final sourcePk = model.primaryKeyField;
    final targetPk = target.primaryKeyField;

    final sourceType = fieldToSqlType(sourcePk, dialect, modelName: model.structName);
    final targetType = fieldToSqlType(targetPk, dialect, modelName: target.structName);

    final joinTableName = '${model.tableName}_${relation.fieldName}';
    final sourceCol = '${model.structName.toLowerCase()}_id';
    final targetCol = '${target.structName.toLowerCase()}_id';

    final sql = '''CREATE TABLE IF NOT EXISTS $joinTableName (
    id ${dialect.autoPkType},
    $sourceCol $sourceType NOT NULL REFERENCES ${model.tableName}(${sourcePk.columnName}) ON DELETE CASCADE,
    $targetCol $targetType NOT NULL REFERENCES ${target.tableName}(${targetPk.columnName}) ON DELETE CASCADE,
    CONSTRAINT uniq_${joinTableName}_pair UNIQUE ($sourceCol, $targetCol)
);''';
    stmts.add(sql);
    stmts.add('CREATE INDEX IF NOT EXISTS ${joinTableName}_${sourceCol}_idx ON $joinTableName($sourceCol);');
    stmts.add('CREATE INDEX IF NOT EXISTS ${joinTableName}_${targetCol}_idx ON $joinTableName($targetCol);');
  }

  return stmts;
}

/// Topologically sorts [models] based on foreign key relationships.
///
/// Ensures that tables referenced by foreign keys appear earlier in the returned list
/// than the models that depend on them.
///
/// Throws a [MigrationCyclicDependencyException] if a circular foreign key cycle is detected.
///
/// Example:
/// ```dart
/// final sorted = sortModelsTopologically([postModelMeta, userModelMeta]);
/// print(sorted.map((m) => m.structName).toList()); // ['User', 'Post']
/// ```
List<ModelMeta> sortModelsTopologically(List<ModelMeta> models) {
  final modelMap = {for (final m in models) m.structName: m};
  final visited = <String>{};
  final visiting = <String>{};
  final sorted = <ModelMeta>[];

  void visit(ModelMeta m) {
    if (visited.contains(m.structName)) return;
    if (visiting.contains(m.structName)) {
      throw MigrationCyclicDependencyException(visiting.toList());
    }

    visiting.add(m.structName);

    for (final rel in m.relations) {
      if (rel.kind == RelationKind.manyToMany) continue;
      final target = rel.target();
      final dep = modelMap[target.structName];
      if (dep != null && dep.structName != m.structName) {
        visit(dep);
      }
    }

    visiting.remove(m.structName);
    visited.add(m.structName);
    sorted.add(m);
  }

  for (final m in models) {
    visit(m);
  }

  return sorted;
}

/// Generates the complete `-- up` section SQL for a list of [ModelMeta]s.
///
/// Sorts [models] topologically, then emits `CREATE TABLE`, `CREATE INDEX`, and many-to-many
/// join table DDL statements.
///
/// Example:
/// ```dart
/// final upSql = generateUpSql([userModelMeta, postModelMeta], Dialect.postgres);
/// print(upSql);
/// ```
String generateUpSql(List<ModelMeta> models, Dialect dialect) {
  final sortedModels = sortModelsTopologically(models);
  final blocks = <String>[];

  for (final model in sortedModels) {
    final tableSql = generateCreateTableSql(model, dialect);
    final indexSqls = generateIndexesSql(model, dialect);
    final m2mSqls = generateManyToManyTablesSql(model, dialect);

    final parts = <String>[tableSql, ...indexSqls, ...m2mSqls];
    blocks.add(parts.join('\n'));
  }

  return blocks.join('\n\n');
}

/// Generates the complete `-- down` section SQL for a list of [ModelMeta]s.
///
/// Emits `DROP TABLE IF EXISTS` statements in reverse topological order, dropping
/// many-to-many join tables first, followed by entity tables.
///
/// Example:
/// ```dart
/// final downSql = generateDownSql([userModelMeta, postModelMeta], Dialect.postgres);
/// print(downSql);
/// ```
String generateDownSql(List<ModelMeta> models, Dialect dialect) {
  // Drop in reverse topological order
  final sortedModels = sortModelsTopologically(models).reversed.toList();
  final stmts = <String>[];

  for (final model in sortedModels) {
    for (final relation in model.relations) {
      if (relation.kind == RelationKind.manyToMany) {
        final joinTableName = '${model.tableName}_${relation.fieldName}';
        stmts.add('DROP TABLE IF EXISTS $joinTableName;');
      }
    }
    stmts.add('DROP TABLE IF EXISTS ${model.tableName};');
  }

  return stmts.join('\n');
}

/// Generates a complete migration file content with `-- up` and `-- down` sections.
///
/// Uses [generateUpSql] and [generateDownSql] to build the standard migration file format.
///
/// Example:
/// ```dart
/// final fileContent = generateMigrationFileContent(
///   models: [userModelMeta, postModelMeta],
///   dialect: Dialect.postgres,
/// );
/// ```
String generateMigrationFileContent({
  required List<ModelMeta> models,
  required Dialect dialect,
}) {
  final up = generateUpSql(models, dialect);
  final down = generateDownSql(models, dialect);

  return '''-- up
$up

-- down
$down
''';
}
