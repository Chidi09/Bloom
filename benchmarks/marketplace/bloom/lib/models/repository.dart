import 'dart:convert';
import '../api/cursor.dart' as cur;
import '../db.dart';
import 'db_models.dart';

class PaginatedProducts {
  final List<Product> items;
  final String? nextCursor;
  final int total;
  PaginatedProducts({required this.items, this.nextCursor, required this.total});
}

String _encodePriceCursor(String id, int price) => cur.encodeCursor(id, price.toString());

({String id, int price})? _decodePriceCursor(String raw) {
  try {
    var n = raw;
    while (n.length % 4 != 0) n += '=';
    final s = utf8.decode(base64Url.decode(n));
    final m = jsonDecode(s) as Map;
    final id = m['id']?.toString();
    final t = m['t']?.toString();
    if (id == null || t == null) return null;
    final p = int.tryParse(t);
    if (p == null) return null;
    return (id: id, price: p);
  } catch (_) {
    return null;
  }
}

Future<PaginatedProducts> fetchProducts({
  String? cursor,
  int limit = 24,
  String? categorySlug,
  String? sort,
  bool publishedOnly = true,
  String? statusFilter,
}) async {
  final db = await getDb();
  final lim = limit.clamp(1, 100);
  String orderBy;
  bool priceSort = false;
  switch (sort) {
    case 'price_asc':
      orderBy = 'p.price_cents ASC, p.id ASC';
      priceSort = true;
      break;
    case 'price_desc':
      orderBy = 'p.price_cents DESC, p.id DESC';
      priceSort = true;
      break;
    case 'oldest':
      orderBy = 'p.created_at ASC, p.id ASC';
      break;
    default:
      orderBy = 'p.created_at DESC, p.id DESC';
  }

  // Resolve category ids once
  List<String>? catIds;
  if (categorySlug != null && categorySlug.isNotEmpty) {
    final catRow = await db.fetchOptional('SELECT id FROM categories WHERE slug = \$1', [categorySlug]);
    if (catRow == null) return PaginatedProducts(items: [], total: 0);
    final catId = catRow.tryStringByName('id') ?? catRow[0].toString();
    final children = await db.fetchAll('SELECT id FROM categories WHERE parent_id = \$1', [catId]);
    catIds = [catId, ...children.map((r) => r.tryStringByName('id') ?? r[0].toString())];
  }

  // Build count query (no cursor)
  final countWheres = <String>[];
  final countParams = <dynamic>[];
  var cIdx = 1;
  String cph(dynamic v) {
    countParams.add(v);
    return '\$${cIdx++}';
  }

  if (publishedOnly && statusFilter == null) countWheres.add("p.status = ${cph('published')}");
  else if (statusFilter != null) countWheres.add("p.status = ${cph(statusFilter)}");
  if (catIds != null) {
    final phs = catIds.map((id) => cph(id)).toList();
    countWheres.add('p.category_id IN (${phs.join(', ')})');
  }
  final countWhereSql = countWheres.isEmpty ? '' : 'WHERE ${countWheres.join(' AND ')}';
  final countRow = await db.fetchOne('SELECT COUNT(*) as c FROM products p $countWhereSql', countParams);
  final total = countRow.tryIntByName('c') ?? countRow.tryInt(0) ?? 0;

  // Build data query
  final wheres = <String>[];
  final params = <dynamic>[];
  var idx = 1;
  String ph(dynamic v) {
    params.add(v);
    return '\$${idx++}';
  }

  if (publishedOnly && statusFilter == null) wheres.add("p.status = ${ph('published')}");
  else if (statusFilter != null) wheres.add("p.status = ${ph(statusFilter)}");
  if (catIds != null) {
    final phs = catIds.map((id) => ph(id)).toList();
    wheres.add('p.category_id IN (${phs.join(', ')})');
  }

  if (cursor != null && cursor.isNotEmpty) {
    if (priceSort) {
      final d = _decodePriceCursor(cursor);
      if (d != null) {
        if (sort == 'price_asc') {
          wheres.add('(p.price_cents, p.id) > (${ph(d.price)}, ${ph(d.id)})');
        } else {
          wheres.add('(p.price_cents, p.id) < (${ph(d.price)}, ${ph(d.id)})');
        }
      }
    } else {
      final d = cur.decodeCursor(cursor);
      if (d != null) {
        if (sort == 'oldest') {
          wheres.add('(p.created_at, p.id) > (${ph(d.time.toUtc())}, ${ph(d.id)})');
        } else {
          wheres.add('(p.created_at, p.id) < (${ph(d.time.toUtc())}, ${ph(d.id)})');
        }
      }
    }
  }

  final whereSql = wheres.isEmpty ? '' : 'WHERE ${wheres.join(' AND ')}';
  final sql = '''
    SELECT p.*, v.name as vendor_name, v.slug as vendor_slug,
           c.name as category_name, c.slug as category_slug
    FROM products p
    JOIN vendors v ON v.id = p.vendor_id
    JOIN categories c ON c.id = p.category_id
    $whereSql
    ORDER BY $orderBy
    LIMIT ${ph(lim + 1)}
  ''';
  final rows = await db.fetchAll(sql, params);
  final hasMore = rows.length > lim;
  final pageRows = hasMore ? rows.sublist(0, lim) : rows;
  final items = pageRows.map(Product.fromRow).toList();

  String? next;
  if (hasMore && items.isNotEmpty) {
    final last = items.last;
    if (priceSort) {
      next = _encodePriceCursor(last.id, last.priceCents);
    } else {
      next = cur.encodeCursor(last.id, last.createdAt.toIso8601String());
    }
  }
  return PaginatedProducts(items: items, nextCursor: next, total: total);
}

Future<Product?> fetchProductBySlug(String slug) async {
  final db = await getDb();
  final row = await db.fetchOptional('''
    SELECT p.*, v.name as vendor_name, v.slug as vendor_slug,
           c.name as category_name, c.slug as category_slug
    FROM products p
    JOIN vendors v ON v.id = p.vendor_id
    JOIN categories c ON c.id = p.category_id
    WHERE p.slug = \$1
  ''', [slug]);
  if (row == null) return null;
  return Product.fromRow(row);
}

Future<List<ProductImage>> fetchImages(String productId) async {
  final db = await getDb();
  final rows = await db.fetchAll('SELECT * FROM product_images WHERE product_id = \$1 ORDER BY position ASC', [productId]);
  return rows.map(ProductImage.fromRow).toList();
}

Future<List<Category>> fetchAllCategories() async {
  final db = await getDb();
  final rows = await db.fetchAll('SELECT * FROM categories ORDER BY name ASC', []);
  return rows.map(Category.fromRow).toList();
}

Future<Category?> fetchCategoryBySlug(String slug) async {
  final db = await getDb();
  final row = await db.fetchOptional('SELECT * FROM categories WHERE slug = \$1', [slug]);
  if (row == null) return null;
  return Category.fromRow(row);
}

Future<Map<String, int>> fetchProductCountsByStatus() async {
  final db = await getDb();
  final rows = await db.fetchAll("SELECT status, COUNT(*) as c FROM products GROUP BY status", []);
  final m = <String, int>{'published': 0, 'draft': 0, 'archived': 0};
  for (final r in rows) {
    final s = r.tryStringByName('status') ?? '';
    final c = r.tryIntByName('c') ?? 0;
    m[s] = c;
  }
  return m;
}
