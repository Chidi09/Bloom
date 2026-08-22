// lib/src/pagination.dart
import 'dart:convert';
import 'dart:math';
import 'package:bloom_server/bloom_server.dart';

/// Default page size for REST ViewSet list pagination.
/// Matches DRF and Bloom convention (100).
const int kRestPerPage = 100;

/// How many rows to fetch, and from where.
///
/// Mirrors `djangors_rest::PageSlice`.
class BloomPageSlice {
  /// Maximum rows to return.
  final int limit;

  /// Rows to skip.
  final int offset;

  const BloomPageSlice({
    required this.limit,
    required this.offset,
  });

  @override
  String toString() => 'BloomPageSlice(limit: $limit, offset: $offset)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomPageSlice &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(limit, offset);
}

/// A pluggable pagination strategy: decides the query window and shapes the response envelope.
///
/// Mirrors `djangors_rest::Pagination`.
abstract class BloomPagination {
  const BloomPagination();

  /// Resolves the page size for this request.
  int pageSize(BloomRequest req);

  /// The window of rows this request should receive.
  BloomPageSlice slice(BloomRequest req, int total);

  /// Build the response envelope around the serialized results.
  Map<String, dynamic> envelope(
    BloomRequest req,
    int total,
    List<Map<String, dynamic>> results,
  );
}

/// Helper function to resolve requested page size with an optional ceiling.
int resolvePageSize(
  BloomRequest req,
  int defaultSize,
  int? maxSize,
) {
  final def = max(1, defaultSize);
  final raw = req.queryParams['page_size'];
  if (raw == null) return def;

  final parsed = int.tryParse(raw);
  if (parsed == null || parsed < 1) return def;

  if (maxSize != null) {
    return min(parsed, max(1, maxSize));
  }
  return parsed;
}

/// Helper function to parse requested page number (`?page=`), clamped to at least 1.
int requestedPage(BloomRequest req) {
  final raw = req.queryParams['page'];
  if (raw == null) return 1;
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed < 1) return 1;
  return parsed;
}

/// Page-number pagination: reads `?page=` and reports `count`, `page`, `total_pages`, and `results`.
///
/// Mirrors `djangors_rest::PageNumberPagination`.
class PageNumberPagination extends BloomPagination {
  /// Rows per page when the client does not specify `?page_size=`.
  final int defaultPageSize;

  /// Maximum allowed `?page_size=`, if client overrides are allowed.
  final int? maxPageSize;

  const PageNumberPagination({
    this.defaultPageSize = kRestPerPage,
    this.maxPageSize,
  });

  @override
  int pageSize(BloomRequest req) {
    return resolvePageSize(req, defaultPageSize, maxPageSize);
  }

  @override
  BloomPageSlice slice(BloomRequest req, int total) {
    final limit = resolvePageSize(req, defaultPageSize, maxPageSize);
    final page = requestedPage(req);
    final offset = (page - 1) * limit;
    return BloomPageSlice(limit: limit, offset: max(0, offset));
  }

  @override
  Map<String, dynamic> envelope(
    BloomRequest req,
    int total,
    List<Map<String, dynamic>> results,
  ) {
    final limit = resolvePageSize(req, defaultPageSize, maxPageSize);
    final totalPages = limit > 0 ? (total / limit).ceil() : 0;
    return {
      'count': total,
      'page': requestedPage(req),
      'total_pages': max(1, totalPages),
      'results': results,
    };
  }
}

/// Limit-offset pagination: reads `?limit=` and `?offset=` directly.
///
/// Mirrors `djangors_rest::LimitOffsetPagination`.
class LimitOffsetPagination extends BloomPagination {
  /// Rows per page when `?limit=` is absent.
  final int defaultLimit;

  /// Ceiling applied to `?limit=`.
  final int maxLimit;

  const LimitOffsetPagination({
    this.defaultLimit = kRestPerPage,
    this.maxLimit = kRestPerPage,
  });

  BloomPageSlice _resolved(BloomRequest req) {
    final limitRaw = req.queryParams['limit'];
    var limit = defaultLimit;
    if (limitRaw != null) {
      final parsed = int.tryParse(limitRaw);
      if (parsed != null && parsed >= 1) {
        limit = min(parsed, max(1, maxLimit));
      }
    }

    final offsetRaw = req.queryParams['offset'];
    var offset = 0;
    if (offsetRaw != null) {
      final parsed = int.tryParse(offsetRaw);
      if (parsed != null && parsed >= 0) {
        offset = parsed;
      }
    }

    return BloomPageSlice(limit: max(1, limit), offset: offset);
  }

  @override
  int pageSize(BloomRequest req) {
    return _resolved(req).limit;
  }

  @override
  BloomPageSlice slice(BloomRequest req, int total) {
    return _resolved(req);
  }

  @override
  Map<String, dynamic> envelope(
    BloomRequest req,
    int total,
    List<Map<String, dynamic>> results,
  ) {
    final sl = _resolved(req);
    return {
      'count': total,
      'limit': sl.limit,
      'offset': sl.offset,
      'results': results,
    };
  }
}

/// Opaque cursor encoding and decoding for keyset pagination.
///
/// Encodes a tuple of `(pk, sortValue)` into a base64 string.
/// Format in JSON: `{"pk": 123, "v": "2026-08-17T15:00:00Z"}`.
String encodeCursor(dynamic pk, dynamic sortValue) {
  final payload = <String, dynamic>{
    'pk': pk,
    if (sortValue != null) 'v': sortValue.toString(),
  };
  return base64Url.encode(utf8.encode(jsonEncode(payload)));
}

/// Decodes a base64 cursor string into `(dynamic pk, String? sortValue)`.
/// Returns `null` if the cursor is malformed.
(dynamic, String?)? decodeCursor(String rawCursor) {
  try {
    // Add padding if missing
    var normalized = rawCursor;
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    final decodedStr = utf8.decode(base64Url.decode(normalized));
    final map = jsonDecode(decodedStr);
    if (map is! Map) return null;
    final pk = map['pk'];
    if (pk == null) return null;
    final v = map['v']?.toString();
    return (pk, v);
  } catch (_) {
    return null;
  }
}

/// Keyset pagination over an ordered field, reporting `next_cursor` and `previous_cursor`.
///
/// Stable under concurrent insertions/deletions.
///
/// Mirrors `djangors_rest::CursorPagination`.
class CursorPagination extends BloomPagination {
  /// Rows per page.
  final int defaultPageSize;

  /// Optional maximum page size ceiling.
  final int? maxPageSize;

  /// Ordering field name (e.g. `'id'`, `'created_at'`).
  final String orderingField;

  const CursorPagination({
    this.defaultPageSize = kRestPerPage,
    this.maxPageSize,
    this.orderingField = 'id',
  });

  @override
  int pageSize(BloomRequest req) {
    return resolvePageSize(req, defaultPageSize, maxPageSize);
  }

  @override
  BloomPageSlice slice(BloomRequest req, int total) {
    return BloomPageSlice(
      limit: resolvePageSize(req, defaultPageSize, maxPageSize),
      offset: 0,
    );
  }

  @override
  Map<String, dynamic> envelope(
    BloomRequest req,
    int total,
    List<Map<String, dynamic>> results,
  ) {
    return envelopeWithCursor(total, results, nextCursor: null);
  }

  /// Builds the cursor response envelope.
  Map<String, dynamic> envelopeWithCursor(
    int total,
    List<Map<String, dynamic>> results, {
    String? nextCursor,
    String? previousCursor,
  }) {
    return {
      'count': total,
      'results': results,
      'next_cursor': nextCursor,
      'previous_cursor': previousCursor,
    };
  }
}
