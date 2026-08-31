// lib/src/filters.dart
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_server/bloom_server.dart';

/// The lookup suffixes a client may attach to a filterable field in query parameters.
///
/// Supported suffixes include:
/// - `eq`: Exact equality (`?status__eq=published` or `?status=published`)
/// - `ne`: Not equal (`?status__ne=draft`)
/// - `lt`: Less than (`?age__lt=30`)
/// - `lte`: Less than or equal (`?price__lte=99.99`)
/// - `gt`: Greater than (`?score__gt=80`)
/// - `gte`: Greater than or equal (`?rating__gte=4.5`)
/// - `contains`: Case-sensitive substring (`?title__contains=Bloom`)
/// - `icontains`: Case-insensitive substring (`?title__icontains=bloom`)
/// - `startswith`: Case-sensitive prefix match (`?slug__startswith=v1`)
/// - `endswith`: Case-sensitive suffix match (`?email__endswith=@example.com`)
/// - `iexact`: Case-insensitive exact match (`?username__iexact=admin`)
/// - `in`: Comma-separated list membership (`?id__in=1,2,3`)
/// - `isnull`: Null or non-null check (`?deleted_at__isnull=true`)
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
/// Implement this interface to create custom query filtering logic for ViewSets.
///
/// Example:
/// ```dart
/// class ActiveTenantFilter<T extends Model> extends BloomFilterBackend<T> {
///   const ActiveTenantFilter();
///
///   @override
///   QuerySet<T> filterQuerySet(BloomRequest req, QuerySet<T> qs, ModelMeta meta) {
///     final tenantId = req.headers['x-tenant-id'];
///     if (tenantId == null) return qs;
///     return qs.filter({'tenant_id': tenantId});
///   }
/// }
/// ```
///
/// Mirrors `djangors_rest::FilterBackend<M>`.
abstract class BloomFilterBackend<T extends Model> {
  /// Creates a [BloomFilterBackend].
  const BloomFilterBackend();

  /// Applies this backend's constraints to [qs] using query parameters from [req] and [meta].
  ///
  /// Returns the refined [QuerySet].
  QuerySet<T> filterQuerySet(BloomRequest req, QuerySet<T> qs, ModelMeta meta);
}

/// Applies all filter backends in [backends] to [qs] in order.
///
/// Evaluates each backend in [backends] against [req] and [meta], threading the
/// resulting [QuerySet] through each step and returning the final query.
///
/// Example:
/// ```dart
/// final filteredQs = applyFilterBackends(
///   [BloomSearchFilter(['title', 'body']), BloomOrderingFilter(['created_at'])],
///   request,
///   initialQuerySet,
///   Article.meta,
/// );
/// ```
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
///
/// Inspects [fieldName] within [meta] to convert the [raw] query string into:
/// - [BloomValue.i64] for integer and bigint fields,
/// - [BloomValue.f64] for float and decimal fields,
/// - [BloomValue.boolVal] for boolean values (`"true"`, `"1"`, `"false"`, `"0"`),
/// - [BloomValue.dateTime] for ISO-8601 UTC timestamps,
/// - [BloomValue.text] for string and other fields.
///
/// Returns `null` if the value cannot be parsed into the field's declared type.
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
/// Matches URL query parameters against the configured [fields] allowlist,
/// evaluating both direct equality parameters (e.g. `?status=published`) and
/// lookup-suffixed parameters (e.g. `?price__lte=50`).
///
/// Example:
/// ```dart
/// final filter = BloomFieldFilter<Product>(['category', 'price', 'is_active']);
/// final refinedQs = filter.filterQuerySet(request, productQs, Product.meta);
/// ```
///
/// Mirrors `djangors_rest::FieldFilter`.
class BloomFieldFilter<T extends Model> extends BloomFilterBackend<T> {
  /// List of field names allowed for filtering.
  final List<String> fields;

  /// Creates a [BloomFieldFilter] restricting lookups to the specified allowed [fields].
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
/// Constructs a case-insensitive substring search (`field__icontains`) across all
/// configured [searchFields], combining them with OR disjunction.
///
/// Example:
/// ```dart
/// final search = BloomSearchFilter<Article>(['title', 'summary', 'body']);
/// final searchedQs = search.filterQuerySet(request, articleQs, Article.meta);
/// ```
///
/// Mirrors `djangors_rest::SearchFilter`.
class BloomSearchFilter<T extends Model> extends BloomFilterBackend<T> {
  /// List of model text field names searched by this filter.
  final List<String> searchFields;

  /// Query parameter name containing the search query (defaults to `'search'`).
  final String searchParam;

  /// Creates a [BloomSearchFilter] targeting [searchFields] with optional [searchParam].
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
          UnresolvedExpr.compare(
              '${field}__icontains', BloomValue.text(trimmed)),
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
/// Parses comma-separated field tokens from the [orderingParam] query parameter.
/// A leading `-` specifies descending order (e.g. `-created_at`). Only fields present
/// in [orderableFields] and verified in [ModelMeta] are applied.
///
/// Example:
/// ```dart
/// final ordering = BloomOrderingFilter<Article>(['created_at', 'title', 'views']);
/// final orderedQs = ordering.filterQuerySet(request, articleQs, Article.meta);
/// ```
///
/// Mirrors `djangors_rest::OrderingFilter`.
class BloomOrderingFilter<T extends Model> extends BloomFilterBackend<T> {
  /// List of field names allowed for client-requested ordering.
  final List<String> orderableFields;

  /// Query parameter name containing the ordering specification (defaults to `'ordering'`).
  final String orderingParam;

  /// Creates a [BloomOrderingFilter] allowing ordering over [orderableFields].
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
    final parts =
        raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
    for (final part in parts) {
      final isDesc = part.startsWith('-');
      final cleanField = isDesc ? part.substring(1) : part;
      if (orderableFields.contains(cleanField) &&
          meta.findField(cleanField) != null) {
        orderedQs = orderedQs.orderBy(part);
      }
    }

    return orderedQs;
  }
}
