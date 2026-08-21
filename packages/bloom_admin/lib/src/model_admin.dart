import 'dart:async';
import 'package:bloom_db/bloom_db.dart';

/// Struct containing page data for a model's changelist view.
class BloomChangelistPage {
  /// Field names to display as columns in declaration order.
  final List<String> columns;

  /// Display-rendered row strings.
  final List<List<String>> rows;

  /// Primary key strings corresponding to each row.
  final List<String> pks;

  /// Total count of matching items across all pages.
  final int total;

  /// 1-based current page number.
  final int page;

  /// Number of items displayed per page.
  final int perPage;

  /// Creates a [BloomChangelistPage] containing paginated rows and metadata.
  const BloomChangelistPage({
    required this.columns,
    required this.rows,
    required this.pks,
    required this.total,
    required this.page,
    required this.perPage,
  });
}

/// Bulk admin action definition.
class BloomAdminAction {
  /// Unique identifier/name of the action (e.g. `'delete_selected'`).
  final String name;

  /// Human-readable label displayed in the changelist action dropdown.
  final String label;

  /// Whether running this action requires explicit user confirmation.
  final bool requiresConfirm;

  /// Handler callback executed when the action is triggered with selected primary keys.
  final Future<void> Function(DbExecutor db, List<int> pks) handler;

  /// Creates a [BloomAdminAction] definition.
  const BloomAdminAction({
    required this.name,
    required this.label,
    this.requiresConfirm = false,
    required this.handler,
  });
}

/// Configuration for inline child model display on admin forms.
class BloomInlineConfig {
  /// Struct name of the related child model.
  final String structName;

  /// Name of the foreign key relation field pointing back to the parent model.
  final String relationField;

  /// Field names of the child model to display in the inline table.
  final List<String> fields;

  /// Creates a [BloomInlineConfig] for displaying related child models.
  const BloomInlineConfig({
    required this.structName,
    required this.relationField,
    required this.fields,
  });
}

/// Configuration options for custom model admin registration.
class BloomModelAdminConfig {
  /// Subset / reorder of field names to show as changelist columns.
  final List<String>? listDisplay;

  /// Real, text-like field names to ILIKE-match against `?q=`.
  final List<String>? searchFields;

  /// Boolean field names for sidebar / top filtering.
  final List<String>? listFilter;

  /// Date or datetime field name to display date hierarchy navigation bar.
  final String? dateHierarchy;

  /// List of field names that are editable inline on the changelist table.
  final List<String>? listEditable;

  /// Bulk actions available on the changelist page.
  final List<BloomAdminAction>? actions;

  /// Groupings of fields into fieldsets on the change form: `[(section_title, [field_names])]`.
  final List<(String, List<String>)>? fieldsets;

  /// List of field names rendered as read-only on the change form.
  final List<String>? readonlyFields;

  /// List of foreign key field names rendered as raw ID inputs with quick lookup links.
  final List<String>? rawIdFields;

  /// Base filter expression automatically applied to all admin queries.
  final dynamic baseFilter;

  /// Inline child model configurations rendered below the add/change form.
  final List<BloomInlineConfig>? inlines;

  /// Creates a [BloomModelAdminConfig] with customizable changelist and form settings.
  const BloomModelAdminConfig({
    this.listDisplay,
    this.searchFields,
    this.listFilter,
    this.dateHierarchy,
    this.listEditable,
    this.actions,
    this.fieldsets,
    this.readonlyFields,
    this.rawIdFields,
    this.baseFilter,
    this.inlines,
  });
}


/// Pluggable administration interface for managing ORM models.
///
/// Mirrors `djangors-admin`'s `ModelAdmin` trait.
abstract class BloomModelAdmin<T extends Model> {
  /// Runtime metadata for the administered model.
  ModelMeta get modelMeta;

  /// Field names in declaration order.
  List<String> get fieldNames;

  /// Search field names for this model admin.
  List<String> get searchFields;

  /// List filter field names for this model admin.
  List<String> get listFilterFields;

  /// Date hierarchy field name if configured.
  String? get dateHierarchyField;

  /// List editable field names for this model admin.
  List<String> get listEditableFields;

  /// Bulk admin actions for this model admin.
  List<BloomAdminAction> get actions;

  /// Change form fieldsets configuration.
  List<(String, List<String>)>? get fieldsets;

  /// Read-only field names for the change form.
  List<String> get readonlyFields;

  /// Raw ID field names for foreign keys.
  List<String> get rawIdFields;

  /// Inline child model configurations.
  List<BloomInlineConfig> get inlinesConfig;

  /// Queries and returns a paginated [BloomChangelistPage] for this model.
  Future<BloomChangelistPage> changelist({
    required DbExecutor db,
    String? order,
    required int page,
    required int perPage,
    String? search,
    Map<String, bool>? filters,
  });

  /// Queries and returns headers and rows for CSV export.
  Future<(List<String>, List<List<String>>)> exportCsvRows({
    required DbExecutor db,
    String? order,
    String? search,
    Map<String, bool>? filters,
  });

  /// Fetches a single object by primary key as name/value map.
  Future<Map<String, dynamic>?> getByPk(DbExecutor db, int pk);

  /// Updates an existing object from form parameters.
  /// Returns `null` on success, or a map of field name -> error message on validation failure.
  Future<Map<String, String>?> updateFromForm(DbExecutor db, int pk, Map<String, String> formData);

  /// Updates specific fields of an existing object from changelist inline edits.
  Future<Map<String, String>?> updateFieldsFromForm(DbExecutor db, int pk, Map<String, String> formData);

  /// Creates a new model instance from form parameters.
  /// Returns `(newPk, null)` on success, or `(null, errorsMap)` on validation failure.
  Future<(int?, Map<String, String>?)> createFromForm(DbExecutor db, Map<String, String> formData);

  /// Deletes a single object by primary key.
  Future<bool> deleteByPk(DbExecutor db, int pk);
}

/// Default implementation of [BloomModelAdmin] for model [T].
class DefaultBloomModelAdmin<T extends Model> extends BloomModelAdmin<T> {
  final ModelMeta _meta;
  final ModelFromRow<T> _fromRow;

  /// Custom administration configuration options.
  final BloomModelAdminConfig config;

  /// Creates a [DefaultBloomModelAdmin] for model [T] using its [meta] definition,
  /// row deserializer [fromRow], and optional [config].
  DefaultBloomModelAdmin({
    required ModelMeta meta,
    required ModelFromRow<T> fromRow,
    this.config = const BloomModelAdminConfig(),
  })  : _meta = meta,
        _fromRow = fromRow;


  @override
  ModelMeta get modelMeta => _meta;

  @override
  List<String> get fieldNames => _meta.fields.map((f) => f.name).toList();

  @override
  List<String> get searchFields => config.searchFields ?? const [];

  @override
  List<String> get listFilterFields => config.listFilter ?? const [];

  @override
  String? get dateHierarchyField => config.dateHierarchy;

  @override
  List<String> get listEditableFields => config.listEditable ?? const [];

  @override
  List<BloomAdminAction> get actions {
    final list = <BloomAdminAction>[...?config.actions];
    list.add(BloomAdminAction(
      name: 'delete_selected',
      label: 'Delete selected',
      requiresConfirm: true,
      handler: (db, pks) async {
        for (final pk in pks) {
          await deleteByPk(db, pk);
        }
      },
    ));
    return list;
  }

  @override
  List<(String, List<String>)>? get fieldsets => config.fieldsets;

  @override
  List<String> get readonlyFields => config.readonlyFields ?? const [];

  @override
  List<String> get rawIdFields => config.rawIdFields ?? const [];

  @override
  List<BloomInlineConfig> get inlinesConfig => config.inlines ?? const [];

  /// Returns the effective column names to display, falling back to [fieldNames].
  List<String> get effectiveColumns => config.listDisplay ?? fieldNames;

  /// Constructs a filtered and ordered [QuerySet] based on active search, filters, and ordering parameters.
  QuerySet<T> buildFilteredQuerySet({
    String? order,
    String? search,
    Map<String, bool>? filters,
  }) {
    var qs = QuerySet<T>(meta: _meta, fromRow: _fromRow);

    if (order != null && order.isNotEmpty) {
      qs = qs.orderBy(order);
    }

    if (search != null && search.isNotEmpty && searchFields.isNotEmpty) {
      final subExprs = <BloomExpr>[];
      for (final fName in searchFields) {
        final f = _meta.findField(fName);
        if (f != null) {
          subExprs.add(BloomExpr.compare(
            field: f.columnName,
            op: CompareOp.icontains,
            value: BloomValue.text(search),
          ));
        }
      }
      if (subExprs.isNotEmpty) {
        qs = qs.filter(BloomExpr.or(subExprs));
      }
    }

    if (filters != null && filters.isNotEmpty) {
      final subExprs = <BloomExpr>[];
      for (final entry in filters.entries) {
        final f = _meta.findField(entry.key);
        if (f != null) {
          subExprs.add(BloomExpr.compare(
            field: f.columnName,
            op: CompareOp.eq,
            value: BloomValue.boolVal(entry.value),
          ));
        }
      }
      if (subExprs.isNotEmpty) {
        qs = qs.filter(BloomExpr.and(subExprs));
      }
    }

    if (config.baseFilter != null) {
      qs = qs.filter(config.baseFilter);
    }

    return qs;
  }

  List<String> _extractRowValues(T item, List<String> columns) {
    final fieldVals = item.fieldValues();
    final map = {for (final (k, v) in fieldVals) k: v.raw?.toString() ?? ''};
    return columns.map((col) => map[col] ?? '').toList();
  }

  @override
  Future<BloomChangelistPage> changelist({
    required DbExecutor db,
    String? order,
    required int page,
    required int perPage,
    String? search,
    Map<String, bool>? filters,
  }) async {
    var qs = buildFilteredQuerySet(order: order, search: search, filters: filters);

    final total = await qs.count(db);
    final offset = (page - 1) * perPage;
    qs = qs.limit(perPage).offset(offset);

    final items = await qs.all(db);
    final cols = effectiveColumns;
    final pkName = _meta.primaryKeyField.name;

    final rows = <List<String>>[];
    final pks = <String>[];

    for (final item in items) {
      rows.add(_extractRowValues(item, cols));
      final valMap = {for (final (k, v) in item.fieldValues()) k: v.raw?.toString() ?? ''};
      pks.add(valMap[pkName] ?? '');
    }

    return BloomChangelistPage(
      columns: cols,
      rows: rows,
      pks: pks,
      total: total,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<(List<String>, List<List<String>>)> exportCsvRows({
    required DbExecutor db,
    String? order,
    String? search,
    Map<String, bool>? filters,
  }) async {
    final qs = buildFilteredQuerySet(order: order, search: search, filters: filters);
    final items = await qs.all(db);
    final cols = effectiveColumns;
    final rows = items.map((item) => _extractRowValues(item, cols)).toList();
    return (cols, rows);
  }

  @override
  Future<Map<String, dynamic>?> getByPk(DbExecutor db, int pk) async {
    final pkCol = _meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: _meta, fromRow: _fromRow).filter({pkCol: pk});
    final item = await qs.first(db);
    if (item == null) return null;
    return {for (final (k, v) in item.fieldValues()) k: v.raw};
  }

  @override
  Future<Map<String, String>?> updateFromForm(DbExecutor db, int pk, Map<String, String> formData) async {
    final errors = <String, String>{};
    final sets = <String, dynamic>{};

    for (final field in _meta.fields) {
      if (field.auto || field.primaryKey) continue;
      final raw = formData[field.name];
      final (parsedVal, err) = parseFieldValue(field, raw);
      if (err != null) {
        errors[field.name] = err;
      } else {
        sets[field.name] = parsedVal;
      }
    }

    for (final rel in _meta.relations) {
      final raw = formData[rel.fieldName];
      final (parsedVal, err) = parseRelationValue(rel, raw);
      if (err != null) {
        errors[rel.fieldName] = err;
      } else {
        sets[rel.fieldName] = parsedVal;
      }
    }

    if (errors.isNotEmpty) return errors;

    final pkCol = _meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: _meta, fromRow: _fromRow).filter({pkCol: pk});
    await qs.update(db, sets);
    return null;
  }

  @override
  Future<Map<String, String>?> updateFieldsFromForm(DbExecutor db, int pk, Map<String, String> formData) async {
    final errors = <String, String>{};
    final sets = <String, dynamic>{};

    for (final field in _meta.fields) {
      if (field.auto || field.primaryKey) continue;
      if (!formData.containsKey(field.name)) continue;
      final raw = formData[field.name];
      final (parsedVal, err) = parseFieldValue(field, raw);
      if (err != null) {
        errors[field.name] = err;
      } else {
        sets[field.name] = parsedVal;
      }
    }

    if (errors.isNotEmpty) return errors;
    if (sets.isEmpty) return null;

    final pkCol = _meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: _meta, fromRow: _fromRow).filter({pkCol: pk});
    await qs.update(db, sets);
    return null;
  }

  @override
  Future<(int?, Map<String, String>?)> createFromForm(DbExecutor db, Map<String, String> formData) async {
    final errors = <String, String>{};
    final values = <String, dynamic>{};

    for (final field in _meta.fields) {
      if (field.auto || field.primaryKey) continue;
      final raw = formData[field.name];
      final (parsedVal, err) = parseFieldValue(field, raw);
      if (err != null) {
        errors[field.name] = err;
      } else {
        values[field.name] = parsedVal;
      }
    }

    for (final rel in _meta.relations) {
      final raw = formData[rel.fieldName];
      final (parsedVal, err) = parseRelationValue(rel, raw);
      if (err != null) {
        errors[rel.fieldName] = err;
      } else {
        values[rel.fieldName] = parsedVal;
      }
    }

    if (errors.isNotEmpty) {
      return (null, errors);
    }

    final newPk = await QuerySet.insertRaw(db, _meta, values);
    return (newPk, null);
  }

  @override
  Future<bool> deleteByPk(DbExecutor db, int pk) async {
    final pkCol = _meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: _meta, fromRow: _fromRow).filter({pkCol: pk});
    final count = await qs.delete(db);
    return count > 0;
  }
}

/// Parses and validates a form string input according to a [FieldMeta] specification.
///
/// Returns a tuple `(parsedValue, errorMessage)`:
/// - On success: `(parsedValue, null)`
/// - On failure: `(null, errorMessage)`
(dynamic, String?) parseFieldValue(FieldMeta field, String? raw) {
  if (field.kind == FieldKind.boolean) {
    if (raw != null && raw.isNotEmpty && (raw == 'on' || raw == 'true' || raw == '1')) {
      return (true, null);
    }
    return (false, null);
  }

  if (raw == null || raw.trim().isEmpty) {
    if (field.nullable) {
      return (null, null);
    }
    return (null, "Field '${field.name}' is required.");
  }

  final val = raw.trim();

  if (field.kind == FieldKind.integer || field.kind == FieldKind.bigInt) {
    final parsed = int.tryParse(val);
    if (parsed == null) {
      return (null, "Field '${field.name}' must be a valid integer.");
    }
    return (parsed, null);
  }

  if (field.kind == FieldKind.float || field.kind is DecimalFieldKind) {
    final parsed = double.tryParse(val);
    if (parsed == null) {
      return (null, "Field '${field.name}' must be a valid number.");
    }
    return (parsed, null);
  }

  if (field.kind == FieldKind.dateTime) {
    final parsed = DateTime.tryParse(val);
    if (parsed == null) {
      return (null, "Field '${field.name}' must be a valid date/time.");
    }
    return (parsed, null);
  }

  return (val, null);
}

/// Parses and validates a form string input for a relation foreign key.
///
/// Returns a tuple `(parsedPk, errorMessage)`:
/// - On success: `(parsedPk, null)`
/// - On failure: `(null, errorMessage)`
(dynamic, String?) parseRelationValue(RelationMeta relation, String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return (null, null);
  }
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    return (null, "Field '${relation.fieldName}' must be a valid integer ID.");
  }
  return (parsed, null);
}

