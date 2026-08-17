// lib/src/filters.dart
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_framework/bloom_server.dart';

/// The lookup suffixes a client may attach to a filterable field in query parameters.
///
/// Mirrors `djangors_rest::ALLOWED_LOOKUPS`.
const List<String> kAllowedLookups = [
  'eq',
  'ne',
  'lt',
  'lte',
  'gt',
  'gte',
  'contains',
  'icontains',
  'startswith',
  'endswith',
  'iexact',
  'in',
  'isnull',
];

/// Narrows a [QuerySet] based on the request's query parameters.
///
/// Mirrors `djangors_rest::FilterBackend<M>`.
abstract class BloomFilterBackend<T extends Model> {
  const BloomFilterBackend();

  /// Applies this backend's constraints to [qs].
  QuerySet<T> filterQuerySet(BloomRequest req, QuerySet<T> qs, ModelMeta meta);
}

/// Applies all filter backends in [backends] to [qs] in order.
QuerySet<T> applyFilterBackends<T extends Model>(
  List<BloomFilterBackend<T>> backends,
  BloomRequest req,
  QuerySet<T> qs,
  ModelMeta meta,
) {
  var currentQs = qs;
  for (final backend in backends) {
    currentQs = backend.filterQuerySet(req, currentQs, meta);
  }
  return currentQs;
}

/// Parses a query-string string into a typed [BloomValue] matching the field's declared type.
BloomValue? parseTypedValue(ModelMeta meta, String fieldName, String raw) {
  final field = meta.findField(fieldName);
  if (field == null) {
    // If relation field or unknown, try int ID fallback
    final n = int.tryParse(raw);
    if (n != null) return BloomValue.i64(n);
    return BloomValue.text(raw);
  }

  final kind = field.kind;
  if (kind == FieldKind.integer || kind == FieldKind.bigInt) {
    final n = int.tryParse(raw);
    return n != null ? BloomValue.i64(n) : null;
  } else if (kind == FieldKind.float || kind is DecimalFieldKind) {
    final d = double.tryParse(raw);
    return d != null ? BloomValue.f64(d) : null;
  } else if (kind == FieldKind.boolean) {
    final s = raw.toLowerCase().trim();
    if (s == 'true' || s == '1') return const BloomValue.boolVal(true);
    if (s == 'false' || s == '0') return const BloomValue.boolVal(false);
    return null;
  } else if (kind == FieldKind.dateTime) {
    final dt = DateTime.tryParse(raw);
    return dt != null ? BloomValue.dateTime(dt.toUtc()) : null;
  } else {
    return BloomValue.text(raw);
  }
}

/// Field filtering with Django-style lookup suffixes (e.g. `?age__gte=18`, `?status=active`).
///
/// Mirrors `djangors_rest::FieldFilter`.
class BloomFieldFilter<T extends Model> extends BloomFilterBackend<T> {
  final List<String> fields;

  const BloomFieldFilter(this.fields);

  @override
  QuerySet<T> filterQuerySet(BloomRequest req, QuerySet<T> qs, ModelMeta meta) {
    var filteredQs = qs;
    final queryParams = req.queryParams;

    for (final field in fields) {
      // 1. Check exact parameter match (?field=val)
      if (queryParams.containsKey(field)) {
        final rawVal = queryParams[field]!;
        final val = parseTypedValue(meta, field, rawVal);
        if (val != null) {
          filteredQs = filteredQs.filter(UnresolvedExpr.compare(field, val));
        }
      }

      // 2. Check suffix lookups (?field__lookup=val)
      for (final lookup in kAllowedLookups) {
        final paramName = '${field}__$lookup';
        if (queryParams.containsKey(paramName)) {
          final rawVal = queryParams[paramName]!;
          if (lookup == 'in') {
            final items = rawVal
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .map((s) => parseTypedValue(meta, field, s))
                .whereType<BloomValue>()
                .toList();
            if (items.isNotEmpty) {
              filteredQs = filteredQs.filter(
                UnresolvedExpr.compare(paramName, BloomValue.list(items)),
              );
            }
          } else if (lookup == 'isnull') {
            final s = rawVal.toLowerCase().trim();
            final isNull = s != 'false' && s != '0';
            filteredQs = filteredQs.filter(
              UnresolvedExpr.compare(paramName, BloomValue.boolVal(isNull)),
            );
          } else if (lookup == 'contains' ||
              lookup == 'icontains' ||
              lookup == 'startswith' ||
              lookup == 'endswith' ||
              lookup == 'iexact') {
            filteredQs = filteredQs.filter(
              UnresolvedExpr.compare(paramName, BloomValue.text(rawVal)),
            );
          } else {
            final val = parseTypedValue(meta, field, rawVal);
            if (val != null) {
              filteredQs = filteredQs.filter(
                UnresolvedExpr.compare(paramName, val),
              );
            }
          }
        }
      }
    }

    return filteredQs;
  }
}

/// Free-text search across several text fields (e.g. `?search=query`).
///
/// Mirrors `djangors_rest::SearchFilter`.
class BloomSearchFilter<T extends Model> extends BloomFilterBackend<T> {
  final List<String> searchFields;
  final String searchParam;

  const BloomSearchFilter(
    this.searchFields, {
    this.searchParam = 'search',
  });

  @override
  QuerySet<T> filterQuerySet(BloomRequest req, QuerySet<T> qs, ModelMeta meta) {
    final term = req.queryParams[searchParam];
    if (term == null || term.trim().isEmpty || searchFields.isEmpty) {
      return qs;
    }

    final trimmed = term.trim();
    // Construct OR disjunction across configured search fields: field__icontains=term
    final orNodes = <UnresolvedExpr>[];
    for (final field in searchFields) {
      if (meta.findField(field) != null) {
        orNodes.add(
          UnresolvedExpr.compare('${field}__icontains', BloomValue.text(trimmed)),
        );
      }
    }

    if (orNodes.isEmpty) {
      return qs;
    }

    return qs.filter(UnresolvedExpr.any(orNodes));
  }
}

/// Client-controlled ordering restricted to an allowlist (e.g. `?ordering=-created_at,title`).
///
/// Mirrors `djangors_rest::OrderingFilter`.
class BloomOrderingFilter<T extends Model> extends BloomFilterBackend<T> {
  final List<String> orderableFields;
  final String orderingParam;

  const BloomOrderingFilter(
    this.orderableFields, {
    this.orderingParam = 'ordering',
  });

  @override
  QuerySet<T> filterQuerySet(BloomRequest req, QuerySet<T> qs, ModelMeta meta) {
    final raw = req.queryParams[orderingParam];
    if (raw == null || raw.trim().isEmpty || orderableFields.isEmpty) {
      return qs;
    }

    var orderedQs = qs;
    final parts = raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
    for (final part in parts) {
      final isDesc = part.startsWith('-');
      final cleanField = isDesc ? part.substring(1) : part;
      if (orderableFields.contains(cleanField) && meta.findField(cleanField) != null) {
        orderedQs = orderedQs.orderBy(part);
      }
    }

    return orderedQs;
  }
}
