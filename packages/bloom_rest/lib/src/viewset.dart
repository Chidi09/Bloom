// lib/src/viewset.dart
import 'dart:async';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_framework/bloom_server.dart';
import 'filters.dart';
import 'pagination.dart';
import 'permissions.dart';
import 'serializers.dart';
import 'throttling.dart';

/// Configuration options for a ViewSet endpoint.
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
  final int? maxPageSize;

  const BloomViewSetConfig({
    this.filterableFields = const [],
    this.orderableFields = const [],
    this.cursorPagination = false,
    this.defaultPageSize = kRestPerPage,
    this.maxPageSize,
  });

  /// Resolves the page size for a request.
  int resolveRequestPageSize(BloomRequest req) {
    return resolvePageSize(req, defaultPageSize, maxPageSize);
  }
}

/// Full options configuring a [BloomViewSet]: serializer, pagination, permissions,
/// filters, and throttling.
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

  BloomViewSetOptions({
    BloomViewSetConfig? config,
    required this.serializer,
    BloomPagination? pagination,
    BloomRestPermission? permission,
    List<BloomFilterBackend<T>>? filterBackends,
    this.throttle,
  })  : config = config ?? const BloomViewSetConfig(),
        pagination = pagination ?? const PageNumberPagination(),
        // SECURE BY DEFAULT: require authentication unless explicitly overridden
        permission = permission ?? const IsAuthenticated(),
        filterBackends = filterBackends ?? const [];

  /// Returns a copy with updated serializer.
  BloomViewSetOptions<T> withSerializer(BloomSerializer<T> serializer) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: filterBackends,
      throttle: throttle,
    );
  }

  /// Returns a copy with updated pagination strategy.
  BloomViewSetOptions<T> withPagination(BloomPagination pagination) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: filterBackends,
      throttle: throttle,
    );
  }

  /// Returns a copy with updated permission policy.
  BloomViewSetOptions<T> withPermission(BloomRestPermission permission) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: filterBackends,
      throttle: throttle,
    );
  }

  /// Returns a copy with an added filter backend.
  BloomViewSetOptions<T> withFilterBackend(BloomFilterBackend<T> backend) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: [...filterBackends, backend],
      throttle: throttle,
    );
  }

  /// Returns a copy with a throttle attached.
  BloomViewSetOptions<T> withThrottle(BloomThrottle throttle) {
    return BloomViewSetOptions<T>(
      config: config,
      serializer: serializer,
      pagination: pagination,
      permission: permission,
      filterBackends: filterBackends,
      throttle: throttle,
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
/// Mirrors `djangors_rest::ViewSet<M>`.
class BloomViewSet<T extends Model> {
  final ModelMeta meta;
  final ModelFromRow<T> fromRow;
  final DbExecutor Function(BloomRequest req) getDb;
  final BloomViewSetOptions<T> options;

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

    // 2. Enforce permission check
    final hasPerm = await options.permission.hasPermission(req);
    if (!hasPerm) {
      return BloomResponse.unauthorized('Permission denied');
    }

    return null;
  }

  /// `GET /` — Paginated and filtered list of records.
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

    // 3. Apply orderable_fields allowlist if ordering param present and not already handled
    final orderingParam = req.queryParams['ordering'];
    String? cursorOrderField;
    bool cursorDescending = false;

    if (orderingParam != null && orderingParam.trim().isNotEmpty) {
      for (final part in orderingParam.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty)) {
        final isDesc = part.startsWith('-');
        final cleanField = isDesc ? part.substring(1) : part;
        if (options.config.orderableFields.contains(cleanField) && meta.findField(cleanField) != null) {
          if (cursorOrderField == null) {
            cursorOrderField = cleanField;
            cursorDescending = isDesc;
          }
          qs = qs.orderBy(part);
        }
      }
    }

    final total = await qs.count(db);

    // 4. Cursor Pagination path
    if (options.config.cursorPagination || options.pagination is CursorPagination) {
      final orderField = cursorOrderField ?? meta.primaryKeyField.name;
      final pkField = meta.primaryKeyField.name;
      final perPage = options.pagination.pageSize(req);

      final rawCursor = req.queryParams['cursor'];
      if (rawCursor != null && rawCursor.isNotEmpty) {
        final decoded = decodeCursor(rawCursor);
        if (decoded != null) {
          final (cursorPk, rawVal) = decoded;
          if (rawVal != null) {
            final parsedVal = parseTypedValue(meta, orderField, rawVal);
            if (parsedVal != null) {
              final op = cursorDescending ? CompareOp.lt : CompareOp.gt;
              qs = qs.filter(BloomExpr.or([
                BloomExpr.compare(field: orderField, op: op, value: parsedVal),
                BloomExpr.and([
                  BloomExpr.compare(field: orderField, op: CompareOp.eq, value: parsedVal),
                  BloomExpr.compare(
                    field: pkField,
                    op: cursorDescending ? CompareOp.lt : CompareOp.gt,
                    value: BloomValue.i64(cursorPk),
                  ),
                ]),
              ]));
            }
          } else {
            final op = cursorDescending ? CompareOp.lt : CompareOp.gt;
            qs = qs.filter(
              BloomExpr.compare(field: pkField, op: op, value: BloomValue.i64(cursorPk)),
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
        final pkVal = values.firstWhere((v) => v.$1 == pkField, orElse: () => (pkField, const BloomValue.i64(0))).$2.raw;
        final sortVal = values.firstWhere((v) => v.$1 == orderField, orElse: () => (orderField, const BloomValue.nullVal())).$2.raw;
        nextCursor = encodeCursor(pkVal is int ? pkVal : 0, sortVal);
      }

      final results = options.serializer.toRepresentationMany(items);
      final pagination = options.pagination is CursorPagination
          ? options.pagination as CursorPagination
          : CursorPagination(defaultPageSize: perPage);

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

  /// `GET /:pk` — Retrieve single record details.
  Future<BloomResponse> retrieve(BloomRequest req) async {
    final guardRes = await _guard(req);
    if (guardRes != null) return guardRes;

    final db = getDb(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    if (pkStr == null) {
      return BloomResponse.error('Missing primary key parameter', statusCode: 400);
    }
    final pk = int.tryParse(pkStr);
    if (pk == null) {
      return BloomResponse.error('Invalid primary key', statusCode: 400);
    }

    final pkField = meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: meta, fromRow: fromRow).filter({pkField: pk});

    try {
      final item = await qs.get(db);
      return BloomResponse.json(options.serializer.toRepresentation(item));
    } on BloomOrmNotFoundError {
      return BloomResponse.notFound('Record not found');
    } catch (e) {
      return BloomResponse.error('Database query failed: $e', statusCode: 500);
    }
  }

  /// `POST /` — Create new record from JSON body.
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
          .filter({pkField: pk})
          .get(db);

      return BloomResponse.json(
        options.serializer.toRepresentation(createdItem),
        statusCode: 201,
      );
    } catch (e) {
      return BloomResponse.error('Failed to create record: $e', statusCode: 500);
    }
  }

  /// `PUT /:pk` or `PATCH /:pk` — Update record.
  Future<BloomResponse> update(BloomRequest req) async {
    final guardRes = await _guard(req);
    if (guardRes != null) return guardRes;

    final db = getDb(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    if (pkStr == null) {
      return BloomResponse.error('Missing primary key parameter', statusCode: 400);
    }
    final pk = int.tryParse(pkStr);
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
    final (values, errors) = options.serializer.parse(bodyJson, partial: isPartial);
    if (errors != null && errors.isNotEmpty) {
      return BloomResponse.json(
        {'errors': errors.toJson()},
        statusCode: 422,
      );
    }

    final pkField = meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: meta, fromRow: fromRow).filter({pkField: pk});

    try {
      final updatedCount = await qs.update(db, values ?? {});
      if (updatedCount == 0) {
        return BloomResponse.notFound('Record not found');
      }
      final updatedItem = await qs.get(db);
      return BloomResponse.json(options.serializer.toRepresentation(updatedItem));
    } catch (e) {
      return BloomResponse.error('Failed to update record: $e', statusCode: 500);
    }
  }

  /// `DELETE /:pk` — Delete record by primary key.
  Future<BloomResponse> destroy(BloomRequest req) async {
    final guardRes = await _guard(req);
    if (guardRes != null) return guardRes;

    final db = getDb(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    if (pkStr == null) {
      return BloomResponse.error('Missing primary key parameter', statusCode: 400);
    }
    final pk = int.tryParse(pkStr);
    if (pk == null) {
      return BloomResponse.error('Invalid primary key', statusCode: 400);
    }

    final pkField = meta.primaryKeyField.name;
    final qs = QuerySet<T>(meta: meta, fromRow: fromRow).filter({pkField: pk});

    try {
      final deletedCount = await qs.delete(db);
      if (deletedCount == 0) {
        return BloomResponse.notFound('Record not found');
      }
      return BloomResponse.noContent();
    } catch (e) {
      return BloomResponse.error('Failed to delete record: $e', statusCode: 500);
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
/// Secure by default: endpoints require authentication.
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
