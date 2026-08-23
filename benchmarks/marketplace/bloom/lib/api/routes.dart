import 'package:bloom_server/bloom_server.dart';
import '../db.dart';
import '../models/db_models.dart';
import '../models/repository.dart';

Future<BloomResponse> listProductsHandler(BloomRequest req) async {
  final cursor = req.queryParams['cursor'];
  final limitRaw = req.queryParams['limit'];
  final category = req.queryParams['category'];
  final sort = req.queryParams['sort'];
  final limit = int.tryParse(limitRaw ?? '') ?? 24;
  final data = await fetchProducts(cursor: cursor, limit: limit, categorySlug: category, sort: sort, publishedOnly: true);
  return BloomResponse.json({
    'count': data.total,
    'results': data.items.map((p) => p.toJson()).toList(),
    'next_cursor': data.nextCursor,
    'previous_cursor': null,
  });
}

Future<BloomResponse> singleProductHandler(BloomRequest req) async {
  final slug = req.params['slug'] ?? '';
  final product = await fetchProductBySlug(slug);
  if (product == null) return BloomResponse.notFound('Product not found');
  final images = await fetchImages(product.id);
  final json = product.toJson();
  json['images'] = images.map((i) => i.toJson()).toList();
  return BloomResponse.json(json);
}

Future<BloomResponse> productImagesHandler(BloomRequest req) async {
  final slug = req.params['slug'] ?? '';
  final product = await fetchProductBySlug(slug);
  if (product == null) return BloomResponse.notFound('Product not found');
  final images = await fetchImages(product.id);
  return BloomResponse.json(images.map((i) => i.toJson()).toList());
}

Future<BloomResponse> singleCategoryHandler(BloomRequest req) async {
  final slug = req.params['slug'] ?? '';
  final category = await fetchCategoryBySlug(slug);
  if (category == null) return BloomResponse.notFound('Category not found');
  return BloomResponse.json(category.toJson());
}

Future<BloomResponse> adminListProductsHandler(BloomRequest req) async {
  final cursor = req.queryParams['cursor'];
  final limitRaw = req.queryParams['limit'];
  final sort = req.queryParams['sort'];
  final status = req.queryParams['status'];
  final limit = int.tryParse(limitRaw ?? '') ?? 24;
  final sortParam = (sort == 'price_asc' || sort == 'price_desc' || sort == 'oldest') ? sort : null;
  final data = await fetchProducts(
    cursor: cursor,
    limit: limit,
    sort: sortParam,
    publishedOnly: false,
    statusFilter: status,
  );
  return BloomResponse.json({
    'count': data.total,
    'results': data.items.map((p) => p.toJson()).toList(),
    'next_cursor': data.nextCursor,
    'previous_cursor': null,
  });
}

Future<BloomResponse> adminSingleProductHandler(BloomRequest req) async {
  final id = req.params['id'] ?? '';
  final product = await _fetchProductById(id);
  if (product == null) return BloomResponse.notFound('Product not found');
  return BloomResponse.json(product.toJson());
}

Future<BloomResponse> adminStatsHandler(BloomRequest req) async {
  final counts = await fetchProductCountsByStatus();
  return BloomResponse.json(counts);
}

Future<Product?> _fetchProductById(String id) async {
  final db = await getDb();
  final row = await db.fetchOptional('''
    SELECT p.*, v.name as vendor_name, v.slug as vendor_slug,
           c.name as category_name, c.slug as category_slug
    FROM products p
    JOIN vendors v ON v.id = p.vendor_id
    JOIN categories c ON c.id = p.category_id
    WHERE p.id = \$1
  ''', [id]);
  if (row == null) return null;
  return Product.fromRow(row);
}
