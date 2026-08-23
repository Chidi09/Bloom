import 'package:bloom_server/bloom_server.dart';
import '../models/repository.dart';

Future<BloomResponse> listProductsHandler(BloomRequest req) async {
  final cursor = req.queryParams['cursor'];
  final limitRaw = req.queryParams['limit'];
  final category = req.queryParams['category'];
  final sort = req.queryParams['sort'];
  final inStockOnly = req.queryParams['in_stock'] == 'true';
  final limit = int.tryParse(limitRaw ?? '') ?? 24;
  final data = await fetchProducts(
    cursor: cursor,
    limit: limit,
    categorySlug: category,
    sort: sort,
    publishedOnly: true,
    inStockOnly: inStockOnly,
  );
  return BloomResponse.json({
    'count': data.total,
    'results': data.items.map((p) => p.toJson()).toList(),
    'next_cursor': data.nextCursor,
    'previous_cursor': null,
  });
}

Future<BloomResponse> listCategoriesHandler(BloomRequest req) async {
  final categories = await fetchAllCategories();
  return BloomResponse.json(categories.map((c) => c.toJson()).toList());
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
  final product = await fetchProductById(id);
  if (product == null) return BloomResponse.notFound('Product not found');
  return BloomResponse.json(product.toJson());
}

Future<BloomResponse> adminStatsHandler(BloomRequest req) async {
  final counts = await fetchProductCountsByStatus();
  return BloomResponse.json(counts);
}

Future<BloomResponse> adminCreateProductHandler(BloomRequest req) async {
  final body = req.bodyJson;
  if (body is! Map) {
    return BloomResponse.json({'error': 'Invalid JSON body'}, statusCode: 400);
  }

  final title = body['title']?.toString().trim() ?? '';
  final slug = body['slug']?.toString().trim() ?? '';
  final description = body['description']?.toString().trim() ?? '';
  final priceCents = body['price_cents'] is int
      ? body['price_cents'] as int
      : int.tryParse(body['price_cents']?.toString().trim() ?? '');
  final stock = body['stock'] is int
      ? body['stock'] as int
      : int.tryParse(body['stock']?.toString().trim() ?? '');
  final status = body['status']?.toString().trim() ?? 'draft';
  final currency = body['currency']?.toString().trim() ?? 'USD';
  final vendorId = body['vendor_id']?.toString().trim();
  final categoryId = body['category_id']?.toString().trim();

  if (title.isEmpty) {
    return BloomResponse.json({'error': 'Title is required'}, statusCode: 400);
  }
  if (slug.isEmpty) {
    return BloomResponse.json({'error': 'Slug is required'}, statusCode: 400);
  }
  if (priceCents == null || priceCents < 0) {
    return BloomResponse.json({'error': 'Price must be a non-negative integer'}, statusCode: 400);
  }
  if (stock == null || stock < 0) {
    return BloomResponse.json({'error': 'Stock must be a non-negative integer'}, statusCode: 400);
  }
  if (status != 'draft' && status != 'published' && status != 'archived') {
    return BloomResponse.json({'error': 'Status must be one of: draft, published, archived'}, statusCode: 400);
  }

  try {
    final product = await createProduct(
      title: title,
      slug: slug,
      description: description,
      priceCents: priceCents,
      currency: currency.isNotEmpty ? currency : 'USD',
      status: status,
      stock: stock,
      vendorId: vendorId,
      categoryId: categoryId,
    );
    return BloomResponse.json(product.toJson(), statusCode: 201);
  } catch (e) {
    return BloomResponse.json({'error': 'Failed to create product: $e'}, statusCode: 400);
  }
}

Future<BloomResponse> adminUpdateProductHandler(BloomRequest req) async {
  final id = req.params['id'] ?? '';
  if (id.isEmpty) {
    return BloomResponse.json({'error': 'Product ID is required'}, statusCode: 400);
  }

  final existing = await fetchProductById(id);
  if (existing == null) {
    return BloomResponse.notFound('Product not found');
  }

  final body = req.bodyJson;
  if (body is! Map) {
    return BloomResponse.json({'error': 'Invalid JSON body'}, statusCode: 400);
  }

  final title = body['title']?.toString().trim() ?? existing.title;
  final slug = body['slug']?.toString().trim() ?? existing.slug;
  final description = body['description']?.toString().trim() ?? existing.description;
  final priceCents = body['price_cents'] != null
      ? (body['price_cents'] is int ? body['price_cents'] as int : int.tryParse(body['price_cents']?.toString().trim() ?? ''))
      : existing.priceCents;
  final stock = body['stock'] != null
      ? (body['stock'] is int ? body['stock'] as int : int.tryParse(body['stock']?.toString().trim() ?? ''))
      : existing.stock;
  final status = body['status']?.toString().trim() ?? existing.status;
  final currency = body['currency']?.toString().trim() ?? existing.currency;

  if (title.isEmpty) {
    return BloomResponse.json({'error': 'Title cannot be empty'}, statusCode: 400);
  }
  if (slug.isEmpty) {
    return BloomResponse.json({'error': 'Slug cannot be empty'}, statusCode: 400);
  }
  if (priceCents == null || priceCents < 0) {
    return BloomResponse.json({'error': 'Price must be a non-negative integer'}, statusCode: 400);
  }
  if (stock == null || stock < 0) {
    return BloomResponse.json({'error': 'Stock must be a non-negative integer'}, statusCode: 400);
  }
  if (status != 'draft' && status != 'published' && status != 'archived') {
    return BloomResponse.json({'error': 'Status must be one of: draft, published, archived'}, statusCode: 400);
  }

  try {
    final updated = await updateProduct(
      id,
      title: title,
      slug: slug,
      description: description,
      priceCents: priceCents,
      currency: currency.isNotEmpty ? currency : 'USD',
      status: status,
      stock: stock,
    );
    if (updated == null) return BloomResponse.notFound('Product not found');
    return BloomResponse.json(updated.toJson());
  } catch (e) {
    return BloomResponse.json({'error': 'Failed to update product: $e'}, statusCode: 400);
  }
}

