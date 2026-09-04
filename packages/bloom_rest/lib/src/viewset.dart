// lib/src/viewset.dart
import 'dart:async';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_server/bloom_server.dart';
import 'filters.dart';
import 'pagination.dart';
import 'permissions.dart';
import 'serializers.dart';
import 'throttling.dart';

/// Configuration options for a ViewSet endpoint.
///
/// Configures filtering allowlists, ordering allowlists, and pagination parameters.
///
/// Example:
/// ```dart
/// const config = BloomViewSetConfig(
///   filterableFields: ['status', 'category_id', 'created_at'],
///   orderableFields: ['created_at', 'title', 'views'],
///   defaultPageSize: 20,
///   maxPageSize: 100,
/// );
/// ```
///
/// Mirrors `djangors_rest::ViewSetConfig`.
class BloomViewSetConfig {
  /// Allowlist of field names that can be filtered via `?field=value` or `?field__lookup=value`.
  final List<String> filterableFields;

  /// Allowlist of field names that can be ordered via `?ordering=field` / `?ordering=-field`.
  final List<String> orderableFields;

  /// Enables keyset cursor pagination when requested.
  final bool cursorPagination;

  /// Default rows per page for this endpoint.
  final int defaultPageSize;

  /// Maximum allowed page size if client requests `?page_size=`.
  ///
  /// Defaults to [kRestPerPage] so an uncapped `?page_size=1000000` cannot
  /// turn `list()` into a full-table scan plus uncached `count()`.
  final int? maxPageSize;

  /// Creates a [BloomViewSetConfig] with optional filtering, ordering, and pagination controls.
  const BloomViewSetConfig({
    this.filterableFields = const [],
    this.orderableFields = const [],
    this.cursorPagination = false,
    this.defaultPageSize = kRestPerPage,
    this.maxPageSize = kRestPerPage,
  });

  /// Resolves the page size for a [req] using [defaultPageSize] and [maxPageSize].
  int resolveRequestPageSize(BloomRequest req) {
    return resolvePageSize(req, defaultPageSize, maxPageSize);
  }
}

/// Full options configuring a [BloomViewSet]: serializer, pagination, permissions,
/// filters, and throttling.
///
/// All ViewSets are **SECURE BY DEFAULT** and require authentication ([IsAuthenticated])
/// unless explicitly configured otherwise.
///
/// Example:
/// ```dart
/// final options = BloomViewSetOptions<Article>(
///   serializer: BloomModelSerializer<Article>(meta: Article.meta),
///   permission: const IsAuthenticated(),
///   pagination: const PageNumberPagination(defaultPageSize: 20),
///   filterBackends: [
///     BloomSearchFilter(['title', 'summary']),
///     BloomOrderingFilter(['created_at']),
///   ],
/// );
/// ```
///
/// Mirrors `djangors_rest::ViewSetOptions`.
class BloomViewSetOptions<T extends Model> {
  /// Filtering and ordering config.
  final BloomViewSetConfig config;

  /// Shapes response bodies and validates request bodies.
  final BloomSerializer<T> serializer;

  /// Decides query limits/offsets and response envelope.
  final BloomPagination pagination;

  /// Security and access control policy (SECURE BY DEFAULT: [IsAuthenticated]).
  final BloomRestPermission permission;

  /// Composable query filter backends.
  final List<BloomFilterBackend<T>> filterBackends;

  /// Optional per-user / per-IP rate limiter.
  final BloomThrottle? throttle;

  /// Server-side sink for unexpected internal errors (5xx).
  ///
  /// 5xx response bodies are always generic (`Internal Server Error`) so raw
  /// DB/driver text never reaches clients; the caught error and stack trace
  /// are routed here instead. Defaults to a `print` fallback when null.
  final void Function(Object error, StackTrace stackTrace)? onInternalError;

  /// Creates a [BloomViewSetOptions] bundle.
  BloomViewSetOptions({
    BloomViewSetConfig? config,
    required this.serializer,
    BloomPagination? pagination,
    BloomRestPermission? permission,
    List<BloomFilterBackend<T>>? filterBackends,
    this.throttle,
    this.onInternalError,
  })  : config = config ?? const BloomViewSetConfig(),
        pagination = pagination ?? const PageNumberPagination(),
        // SECURE BY DEFAULT: require authentication unless explicitly overridden
        permission = permission ?? const IsAuthenticated(),
        filterBackends = filterBackends ?? const [];

  /// Returns a copy with updated [serializer].
  BloomViewSetOptions<T> withSerializer(BloomSerializer<T> serializer) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: filterBackends,
      throttle: throttle,
      onInternalError: onInternalError,
    );
  }

  /// Returns a copy with updated [pagination] strategy.
  BloomViewSetOptions<T> withPagination(BloomPagination pagination) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: filterBackends,
      throttle: throttle,
      onInternalError: onInternalError,
    );
  }

  /// Returns a copy with updated [permission] policy.
  BloomViewSetOptions<T> withPermission(BloomRestPermission permission) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: filterBackends,
      throttle: throttle,
      onInternalError: onInternalError,
    );
  }

  /// Returns a copy with an added filter [backend].
  BloomViewSetOptions<T> withFilterBackend(BloomFilterBackend<T> backend) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: [...filterBackends, backend],
      throttle: throttle,
      onInternalError: onInternalError,
    );
  }

  /// Returns a copy with a [throttle] attached.
  BloomViewSetOptions<T> withThrottle(BloomThrottle throttle) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: filterBackends,
      throttle: throttle,
      onInternalError: onInternalError,
    );
  }
}

/// Generic DRF-style ViewSet controller providing full CRUD over a [Model].
///
/// Implements standard REST actions:
/// - `list` (GET `/`): Paginated, filtered, and ordered list of records
/// - `retrieve` (GET `/:pk`): Single record details by primary key
/// - `create` (POST `/`): Create new record with validation (201 Created or 422 Unprocessable Entity)
/// - `update` (PUT / PATCH `/:pk`): Full or partial update of record
/// - `destroy` (DELETE `/:pk`): Delete record by primary key (204 No Content)
///
/// Security posture:
/// Endpoints are **AUTHENTICATED BY DEFAULT** using [IsAuthenticated].
/// Public access requires explicitly specifying [AllowAny].
///
/// WARNING: request-level [BloomRestPermission.hasPermission] alone does NOT
/// scope rows to owners/tenants. Detail actions additionally enforce
/// [BloomRestPermission.hasObjectPermission] after fetching the row (deny ->
/// 404), but the stock permission allows all objects. Override
/// `hasObjectPermission` (or scope via `getDb`/filter backends for `list`)
/// before exposing user-owned or multi-tenant data, or any authenticated
/// user can read/write/delete any row by id.
///
/// Example:
/// ```dart
/// final viewSet = BloomViewSet<Article>(
///   meta: Article.meta,
///   fromRow: Article.fromRow,
///   getDb: (req) => database,
/// );
/// viewSet.mount(router, '/api/articles');
/// ```
///
/// Mirrors `djangors_rest::ViewSet<M>`.
class BloomViewSet<T extends Model> {
  /// Model metadata describing database schema, columns, and relations.
  final ModelMeta meta;

  /// Row deserializer mapping a database row to a model instance.
  final ModelFromRow<T> fromRow;

  /// Database executor provider callback for a given request.
  final DbExecutor Function(BloomRequest req) getDb;

  /// ViewSet options configuring serializers, pagination, permissions, filters, and throttles.
  final BloomViewSetOptions<T> options;

  /// Creates a [BloomViewSet] for model [meta].
  ///
  /// - [meta]: Target model metadata.
  /// - [fromRow]: Model instantiation function from a [DbRow].
  /// - [getDb]: Database executor provider function for an incoming request.
  /// - [options]: Optional [BloomViewSetOptions] (defaults to authenticated model serializer).
  BloomViewSet({
    required this.meta,
    required this.fromRow,
    required this.getDb,
    BloomViewSetOptions<T>? options,
  }) : options = options ??
            BloomViewSetOptions<T>(
              serializer: BloomModelSerializer<T>(meta: meta),
              permission: const IsAuthenticated(),
            );

  /// Helper to enforce throttling and permissions before action execution.
  ///
  /// Ordering decision: throttle runs **before** permission checks on purpose.
  /// Throttling protects the auth-verification path itself (login/brute-force
  /// endpoints must be rate-limited before identity is known), and per-client
  /// budgets only work when evaluated pre-auth. Tradeoff: 429-before-401 can
  /// confirm endpoint existence to unauthenticated probers, and anonymous
  /// callers without a wired `peerExtractor` share one budget (see
  /// [ByUserOrIp]). Mitigate with per-scope throttle budgets and by wiring
  /// `peerExtractor` from the server adapter.
  Future<BloomResponse?> _guard(BloomRequest req) async {
    // 1. Check throttle rate first
    if (options.throttle != null) {
      final allowed = await options.throttle!.allowRequest(req);
      if (!allowed) {
        return BloomResponse.json(
          {'error': 'Too Many Requests', 'statusCode': 429},
          statusCode: 429,
        );
      }
    }

    // 2. Enforce permission check (401 for unauthenticated, 403 for authenticated but denied)
    final hasPerm = await options.permission.hasPermission(req);
    if (!hasPerm) {
      final userId = resolveCurrentUserId(req);
      if (userId == null || userId.isEmpty) {
        return BloomResponse.unauthorized(
          'Authentication credentials were not provided or are invalid.',
        );
      } else {
        return BloomResponse.forbidden('Permission denied.');
      }
    }

    return null;
  }

  /// Enforces the object-level permission for a fetched detail row.
  ///
  /// Returns a 404 response when [options.permission.hasObjectPermission]
  /// denies, so denied ids are indistinguishable from missing ids.
  /// Returns `null` when allowed.
  Future<BloomResponse?> _guardObject(BloomRequest req, Object item) async {
    final allowed = await options.permission.hasObjectPermission(req, item);
    if (!allowed) return BloomResponse.notFound('Record not found');
    return null;
  }

  /// Logs an unexpected internal error server-side and returns a generic
  /// 500 that never embeds raw exception text.
  BloomResponse _internalError(Object error, StackTrace stackTrace) {
    final sink = options.onInternalError;
    if (sink != null) {
      sink(error, stackTrace);
    } else {
      // No logging backend configured; keep it on the server console so
      // the failure is still diagnosable without leaking to clients.
      // ignore: avoid_print
      print('[bloom_rest] internal error: $error\n$stackTrace');
    }
    return BloomResponse.error('Internal Server Error', statusCode: 500);
  }

  /// `GET /` — Paginated and filtered list of records.
  ///
  /// Evaluates configured [options] permissions, throttles, field filters, search filters,
  /// ordering, and pagination strategy.
  Future<BloomResponse> list(BloomRequest req) async {
    final guardRes = await _guard(req);
    if (guardRes != null) return guardRes;

    final db = getDb(req);
    var qs = QuerySet<T>(meta: meta, fromRow: fromRow);

    // 1. Apply allowlisted field filters
    if (options.config.filterableFields.isNotEmpty) {
      final fieldFilter = BloomFieldFilter<T>(options.config.filterableFields);
      qs = fieldFilter.filterQuerySet(req, qs, meta);
    }

    // 2. Apply configured filter backends (search, ordering, custom)
    qs = applyFilterBackends(options.filterBackends, req, qs, meta);

    final isCursorPagination = options.config.cursorPagination ||
        options.pagination is CursorPagination;

    // 3. Resolve ordering
    final orderingParam = req.queryParams['ordering'];
    String? cursorOrderField;
    bool cursorDescending = false;

    if (orderingParam != null && orderingParam.trim().isNotEmpty) {
      for (final part in orderingParam
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)) {
        final isDesc = part.startsWith('-');
        final cleanField = isDesc ? part.substring(1) : part;
        if (options.config.orderableFields.contains(cleanField) &&
            meta.findField(cleanField) != null) {
          if (cursorOrderField == null) {
            cursorOrderField = cleanField;
            cursorDescending = isDesc;
          }
          if (!isCursorPagination) {
            qs = qs.orderBy(part);
          }
        }
      }
    }

    final total = await qs.count(db);

    // 4. Cursor Pagination path
    if (isCursorPagination) {
      // Honor CursorPagination.orderingField when request query param ordering is absent
      if (cursorOrderField == null && options.pagination is CursorPagination) {
        final cpOrdering =
            (options.pagination as CursorPagination).orderingField.trim();
        final isDesc = cpOrdering.startsWith('-');
        final cleanField = isDesc ? cpOrdering.substring(1) : cpOrdering;
        if (meta.findField(cleanField) != null) {
          cursorOrderField = cleanField;
          cursorDescending = isDesc;
        }
      }

      final pkField = meta.primaryKeyField.name;
      cursorOrderField ??= pkField;

      // Apply deterministic ordering with primary-key tie-breaker
      if (cursorOrderField != pkField) {
        qs = qs.orderBy(
            cursorDescending ? '-$cursorOrderField' : cursorOrderField);
        qs = qs.orderBy(cursorDescending ? '-$pkField' : pkField);
      } else {
        qs = qs.orderBy(cursorDescending ? '-$pkField' : pkField);
      }

      final perPage = options.pagination.pageSize(req);

      final rawCursor = req.queryParams['cursor'];
      if (rawCursor != null && rawCursor.isNotEmpty) {
        final decoded = decodeCursor(rawCursor);
        if (decoded != null) {
          final (cursorPk, rawVal) = decoded;
          final pkBloomVal =
              parseTypedValue(meta, pkField, cursorPk.toString()) ??
                  (cursorPk is int
                      ? BloomValue.i64(cursorPk)
                      : BloomValue.text(cursorPk.toString()));
          if (rawVal != null && cursorOrderField != pkField) {
            final parsedVal = parseTypedValue(meta, cursorOrderField, rawVal);
            if (parsedVal != null) {
              final op = cursorDescending ? CompareOp.lt : CompareOp.gt;
              final pkOp = cursorDescending ? CompareOp.lt : CompareOp.gt;
              qs = qs.filter(BloomExpr.or([
                BloomExpr.compare(
                    field: cursorOrderField, op: op, value: parsedVal),
                BloomExpr.and([
                  BloomExpr.compare(
                      field: cursorOrderField,
                      op: CompareOp.eq,
                      value: parsedVal),
                  BloomExpr.compare(
                    field: pkField,
                    op: pkOp,
                    value: pkBloomVal,
                  ),
                ]),
              ]));
            } else {
              final op = cursorDescending ? CompareOp.lt : CompareOp.gt;
              qs = qs.filter(
                BloomExpr.compare(field: pkField, op: op, value: pkBloomVal),
              );
            }
          } else {
            final op = cursorDescending ? CompareOp.lt : CompareOp.gt;
            qs = qs.filter(
              BloomExpr.compare(field: pkField, op: op, value: pkBloomVal),
            );
          }
        }
      }

      final fetchItems = await qs.limit(perPage + 1).all(db);
      final hasNext = fetchItems.length > perPage;
      final items = fetchItems.take(perPage).toList();

      String? nextCursor;
      if (hasNext && items.isNotEmpty) {
        final lastItem = items.last;
        final values = lastItem.fieldValues();
        final pkVal = values
            .firstWhere((v) => v.$1 == pkField,
                orElse: () => (pkField, const BloomValue.nullVal()))
            .$2
            .raw;
        final sortVal = values
            .firstWhere((v) => v.$1 == cursorOrderField,
                orElse: () => (cursorOrderField!, const BloomValue.nullVal()))
            .$2
            .raw;
        nextCursor = encodeCursor(pkVal ?? 0, sortVal);
      }

      final results = options.serializer.toRepresentationMany(items);
      final pagination = options.pagination is CursorPagination
          ? options.pagination as CursorPagination
          : CursorPagination(
              defaultPageSize: perPage,
              orderingField:
                  cursorDescending ? '-$cursorOrderField' : cursorOrderField,
            );

      return BloomResponse.json(
        pagination.envelopeWithCursor(total, results, nextCursor: nextCursor),
      );
    }

    // 5. Standard Page-number or Limit-offset pagination
    final slice = options.pagination.slice(req, total);
    final items = await qs.limit(slice.limit).offset(slice.offset).all(db);
    final results = options.serializer.toRepresentationMany(items);
    final body = options.pagination.envelope(req, total, results);

    return BloomResponse.json(body);
  }

  dynamic _parsePk(String? pkStr) {
    if (pkStr == null || pkStr.trim().isEmpty) return null;
    final pkField = meta.primaryKeyField;
    if (pkField.kind == FieldKind.integer || pkField.kind == FieldKind.bigInt) {
      return int.tryParse(pkStr.trim());
    }
    return pkStr.trim();
  }

  /// `GET /:pk` — Retrieve single record details.
  ///
  /// Looks up record by the `:pk` route parameter. Returns HTTP 200 with serialized record,
  /// or HTTP 404 if not found.
  Future<BloomResponse> retrieve(BloomRequest req) async {
    final guardRes = await _guard(req);
    if (guardRes != null) return guardRes;

    final db = getDb(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    if (pkStr == null) {
      return BloomResponse.error('Missing primary key parameter',
          statusCode: 400);
    }
    final pk = _parsePk(pkStr);
    if (pk == null) {
      return BloomResponse.error('Invalid primary key', statusCode: 400);
    }

    final pkField = meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: meta, fromRow: fromRow).filter({pkField: pk});

    try {
      final item = await qs.get(db);
      final denied = await _guardObject(req, item);
      if (denied != null) return denied;
      return BloomResponse.json(options.serializer.toRepresentation(item));
    } on BloomOrmNotFoundError {
      return BloomResponse.notFound('Record not found');
    } catch (e, st) {
      return _internalError(e, st);
    }
  }

  /// `POST /` — Create new record from JSON body.
  ///
  /// Deserializes and validates [BloomRequest.bodyJson] using [BloomSerializer.parse].
  /// Returns HTTP 201 Created with the new record, or HTTP 422 if validation fails.
  Future<BloomResponse> create(BloomRequest req) async {
    final guardRes = await _guard(req);
    if (guardRes != null) return guardRes;

    final db = getDb(req);
    final bodyJson = req.bodyJson;
    if (bodyJson == null) {
      return BloomResponse.json(
        {'error': 'Invalid JSON body', 'statusCode': 400},
        statusCode: 400,
      );
    }

    final (values, errors) = options.serializer.parse(bodyJson, partial: false);
    if (errors != null && errors.isNotEmpty) {
      return BloomResponse.json(
        {'errors': errors.toJson()},
        statusCode: 422,
      );
    }

    try {
      final pk = await QuerySet.insertRaw(db, meta, values ?? {});
      final pkField = meta.primaryKeyField.name;
      final createdItem = await QuerySet<T>(meta: meta, fromRow: fromRow)
          .filter({pkField: pk}).get(db);

      return BloomResponse.json(
        options.serializer.toRepresentation(createdItem),
        statusCode: 201,
      );
    } catch (e, st) {
      return _internalError(e, st);
    }
  }

  /// `PUT /:pk` or `PATCH /:pk` — Update record.
  ///
  /// Performs full (`PUT`) or partial (`PATCH`) update of the record identified by `:pk`.
  /// Returns HTTP 200 with updated record, HTTP 422 on validation failure, or HTTP 404 if not found.
  Future<BloomResponse> update(BloomRequest req) async {
    final guardRes = await _guard(req);
    if (guardRes != null) return guardRes;

    final db = getDb(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    if (pkStr == null) {
      return BloomResponse.error('Missing primary key parameter',
          statusCode: 400);
    }
    final pk = _parsePk(pkStr);
    if (pk == null) {
      return BloomResponse.error('Invalid primary key', statusCode: 400);
    }

    final bodyJson = req.bodyJson;
    if (bodyJson == null) {
      return BloomResponse.json(
        {'error': 'Invalid JSON body', 'statusCode': 400},
        statusCode: 400,
      );
    }

    final isPartial = req.method.toUpperCase() == 'PATCH';
    final (values, errors) =
        options.serializer.parse(bodyJson, partial: isPartial);
    if (errors != null && errors.isNotEmpty) {
      return BloomResponse.json(
        {'errors': errors.toJson()},
        statusCode: 422,
      );
    }

    final pkField = meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: meta, fromRow: fromRow).filter({pkField: pk});

    try {
      // Fetch first so object-level authz runs before any mutation.
      late T existing;
      try {
        existing = await qs.get(db);
      } on BloomOrmNotFoundError {
        return BloomResponse.notFound('Record not found');
      }
      final denied = await _guardObject(req, existing);
      if (denied != null) return denied;

      final updatedCount = await qs.update(db, values ?? {});
      if (updatedCount == 0) {
        return BloomResponse.notFound('Record not found');
      }
      final updatedItem = await qs.get(db);
      return BloomResponse.json(
          options.serializer.toRepresentation(updatedItem));
    } catch (e, st) {
      return _internalError(e, st);
    }
  }

  /// `DELETE /:pk` — Delete record by primary key.
  ///
  /// Deletes the record identified by `:pk`. Returns HTTP 204 No Content on success,
  /// or HTTP 404 if not found.
  Future<BloomResponse> destroy(BloomRequest req) async {
    final guardRes = await _guard(req);
    if (guardRes != null) return guardRes;

    final db = getDb(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    if (pkStr == null) {
      return BloomResponse.error('Missing primary key parameter',
          statusCode: 400);
    }
    final pk = _parsePk(pkStr);
    if (pk == null) {
      return BloomResponse.error('Invalid primary key', statusCode: 400);
    }

    final pkField = meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: meta, fromRow: fromRow).filter({pkField: pk});

    try {
      // Fetch first so object-level authz runs before any mutation.
      try {
        final existing = await qs.get(db);
        final denied = await _guardObject(req, existing);
        if (denied != null) return denied;
      } on BloomOrmNotFoundError {
        return BloomResponse.notFound('Record not found');
      }
      final deletedCount = await qs.delete(db);
      if (deletedCount == 0) {
        return BloomResponse.notFound('Record not found');
      }
      return BloomResponse.noContent();
    } catch (e, st) {
      return _internalError(e, st);
    }
  }

  /// Mounts standard REST routes for this ViewSet onto [router] at [basePath].
  ///
  /// Routes mounted:
  /// - `GET {basePath}` -> `list`
  /// - `POST {basePath}` -> `create`
  /// - `GET {basePath}/:pk` -> `retrieve`
  /// - `PUT {basePath}/:pk` -> `update`
  /// - `PATCH {basePath}/:pk` -> `update`
  /// - `DELETE {basePath}/:pk` -> `destroy`
  void mount(BloomApiRouter router, String basePath) {
    final clean = basePath.endsWith('/') && basePath.length > 1
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final listPath = clean.isEmpty ? '/' : clean;
    final detailPath = clean == '/' ? '/:pk' : '$clean/:pk';

    router.get(listPath, list);
    router.post(listPath, create);
    router.get(detailPath, retrieve);
    router.put(detailPath, update);
    router.patch(detailPath, update);
    router.delete(detailPath, destroy);
  }
}

/// Convenience top-level mounting function mirroring Rust `viewset_routes`.
///
/// Registers standard CRUD routes (`list`, `create`, `retrieve`, `update`, `destroy`)
/// on [router] under [basePath].
///
/// Secure by default: endpoints require authentication unless [BloomViewSetOptions.permission]
/// is explicitly configured with [AllowAny].
///
/// WARNING: authentication alone does not scope rows. Override
/// [BloomRestPermission.hasObjectPermission] (and/or scope `getDb`/filters
/// for `list`) for owner/tenant data — otherwise any authenticated user can
/// address any row by id on detail routes.
///
/// Example:
/// ```dart
/// mountViewSet<Article>(
///   router: router,
///   basePath: '/api/articles',
///   meta: Article.meta,
///   fromRow: Article.fromRow,
///   getDb: (req) => db,
///   options: BloomViewSetOptions<Article>(
///     serializer: BloomModelSerializer<Article>(meta: Article.meta),
///     permission: const AllowAny(),
///     pagination: const PageNumberPagination(defaultPageSize: 25),
///   ),
/// );
/// ```
void mountViewSet<T extends Model>({
  required BloomApiRouter router,
  required String basePath,
  required ModelMeta meta,
  required ModelFromRow<T> fromRow,
  required DbExecutor Function(BloomRequest req) getDb,
  BloomViewSetOptions<T>? options,
}) {
  final viewSet = BloomViewSet<T>(
    meta: meta,
    fromRow: fromRow,
    getDb: getDb,
    options: options,
  );
  viewSet.mount(router, basePath);
}
