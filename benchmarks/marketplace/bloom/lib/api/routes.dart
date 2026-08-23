import 'package:bloom_server/bloom_server.dart';
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
