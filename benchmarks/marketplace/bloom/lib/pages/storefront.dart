import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/button_variants.dart';
import '../components/layout.dart';
import '../components/toast.dart';
import '../components/ui.dart';
import '../main.dart';
import '../models/models.dart';
import '../state/cart.dart';

class _PaginatedData {
  final List<Product> items;
  final int total;
  final String? nextCursor;
  _PaginatedData({required this.items, required this.total, this.nextCursor});
}

Product _productFromJson(Map<String, dynamic> json) {
  final vendor = json['vendor'] as Map<String, dynamic>?;
  final category = json['category'] as Map<String, dynamic>?;
  return Product(
    id: json['id'] as String? ?? '',
    vendorId: json['vendor_id'] as String? ?? '',
    categoryId: json['category_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    description: json['description'] as String? ?? '',
    priceCents: json['price_cents'] as int? ?? 0,
    currency: json['currency'] as String? ?? 'USD',
    status: json['status'] as String? ?? 'draft',
    stock: json['stock'] as int? ?? 0,
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now().toUtc() : DateTime.now().toUtc(),
    updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now().toUtc() : DateTime.now().toUtc(),
    vendorName: vendor?['name'] as String?,
    vendorSlug: vendor?['slug'] as String?,
    categoryName: category?['name'] as String?,
    categorySlug: category?['slug'] as String?,
  );
}

ProductImage _productImageFromJson(Map<String, dynamic> json) {
  return ProductImage(
    id: json['id'] as String? ?? '',
    productId: json['product_id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    alt: json['alt'] as String? ?? '',
    position: json['position'] as int? ?? 0,
  );
}

Category _categoryFromJson(Map<String, dynamic> json) {
  return Category(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    parentId: json['parent_id'] as String?,
    createdAt: DateTime.now().toUtc(),
  );
}

BloomNode _sortBar(String? current) {
  final opts = {'newest': 'Newest', 'oldest': 'Oldest', 'price_asc': 'Price ↑', 'price_desc': 'Price ↓'};
  final activeKey = current ?? 'newest';
  return Div(
    className: 'flex items-center gap-2 text-sm',
    children: [
      Span(className: 'text-[var(--text-muted)]', text: 'Sort:'),
      segmentedControl(
        options: opts.entries.map((e) => (
          label: e.value,
          href: '?sort=${e.key}',
          active: e.key == activeKey,
        )).toList(),
      ),
    ],
  );
}

BloomNode homePage(Map<String, String> params) {
  final query = routerController.currentQuery.value;
  final cursor = query['cursor'];
  final sort = query['sort'];
  final inStock = query['in_stock'];
  final limit = int.tryParse(query['limit'] ?? '') ?? 24;

  Future<({_PaginatedData data, List<Category> categories})> fetch() async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      if (inStock == 'true') 'in_stock': 'true',
    };
    final res = await httpClient.get<Map<String, dynamic>>('/api/products', queryParameters: queryParams);
    final rawResults = (res['results'] as List<dynamic>?) ?? const [];
    final items = rawResults.map((j) => _productFromJson(j as Map<String, dynamic>)).toList();
    final total = res['count'] as int? ?? items.length;
    final nextCursor = res['next_cursor'] as String?;
    List<Category> categories = [];
    try {
      final catRes = await httpClient.get<List<dynamic>>('/api/categories');
      categories = catRes.map((j) => _categoryFromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {}
    return (data: _PaginatedData(items: items, total: total, nextCursor: nextCursor), categories: categories);
  }

  return Suspense<({_PaginatedData data, List<Category> categories})>(
    resource: fetch,
    fallback: appShell(
      Div(children: [
        Div(className: 'py-12 sm:py-16 border-b border-[var(--border)] mb-8 animate-pulse', children: [
          Div(className: 'h-6 bg-[var(--bg-muted)] rounded-full w-48 mb-4'),
          Div(className: 'h-10 bg-[var(--bg-muted)] rounded w-2/3 mb-3'),
          Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-1/2 mb-6'),
          Div(className: 'h-10 bg-[var(--bg-muted)] rounded-md w-36'),
        ]),
        Div(
          className: 'grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4',
          children: List.generate(8, (_) => skeletonCard()),
        ),
      ]),
    ),
    builder: (result) {
      final data = result.data;
      final categories = result.categories;
      return appShell(
        Div(children: [
          // Landing hero section above catalog
          Div(
            className: 'py-12 sm:py-16 border-b border-[var(--border)] mb-8',
            children: [
              Div(
                className: 'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-[var(--bg-muted)] text-[var(--text-muted)] border border-[var(--border)] mb-4',
                children: [
                  Span(className: 'w-1.5 h-1.5 rounded-full bg-[var(--brand-600)]'),
                  Span(text: '${formatNumber(data.total)} verified items in catalog'),
                ],
              ),
              H1(
                className: 'text-display tracking-tight',
                text: 'Curated goods for modern living',
              ),
              P(
                className: 'text-body text-[var(--text-muted)] max-w-[56ch] mt-2.5',
                text: 'Discover handcrafted objects, timeless apparel, and functional design pieces from independent makers worldwide.',
              ),
              Div(
                className: 'flex flex-wrap items-center gap-4 mt-6',
                children: [
                  button(
                    text: 'Explore collection',
                    variant: ButtonVariant.primary,
                    href: '#catalog',
                  ),
                ],
              ),
            ],
          ),
          // Product catalog section
          Div(
            attrs: const {'id': 'catalog'},
            className: 'scroll-mt-20',
            children: [
              Div(className: 'flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6', children: [
                Div(children: [
                  H2(className: 'text-h2', text: 'Marketplace'),
                  P(className: 'text-sm text-[var(--text-muted)] mt-1', text: '${formatNumber(data.total)} products • 24 per page'),
                ]),
                _sortBar(sort),
              ]),
              filterBar(
                currentPath: routerController.currentPath.value,
                currentQuery: routerController.currentQuery.value,
                categories: categories,
              ),
              productGrid(data.items),
              if (data.items.isEmpty)
                emptyState(
                  title: 'No products found',
                  description: 'Try a different filter or check back soon.',
                  icon: 'search',
                )
              else
                paginationBar(
                  currentPath: routerController.currentPath.value,
                  currentQuery: routerController.currentQuery.value,
                  total: data.total,
                  itemCount: data.items.length,
                  nextCursor: data.nextCursor,
                  pageSize: 24,
                ),
            ],
          ),
        ]),
      );
    },
  );
}

BloomNode categoryPage(Map<String, String> params) {
  final slug = params['slug'] ?? '';
  final query = routerController.currentQuery.value;
  final sort = query['sort'];
  final cursor = query['cursor'];
  final inStock = query['in_stock'];

  Future<({Category? category, _PaginatedData data, List<Category> categories})> fetch() async {
    Category? cat;
    try {
      final catRes = await httpClient.get<Map<String, dynamic>>('/api/categories/$slug');
      cat = _categoryFromJson(catRes);
    } catch (_) {
      cat = null;
    }
    List<Category> allCategories = [];
    try {
      final allCatRes = await httpClient.get<List<dynamic>>('/api/categories');
      allCategories = allCatRes.map((j) => _categoryFromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {}
    if (cat == null) {
      return (category: null, data: _PaginatedData(items: [], total: 0), categories: allCategories);
    }
    final queryParams = <String, dynamic>{
      'category': slug,
      'limit': 24,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      if (inStock == 'true') 'in_stock': 'true',
    };
    final res = await httpClient.get<Map<String, dynamic>>('/api/products', queryParameters: queryParams);
    final rawResults = (res['results'] as List<dynamic>?) ?? const [];
    final items = rawResults.map((j) => _productFromJson(j as Map<String, dynamic>)).toList();
    final total = res['count'] as int? ?? items.length;
    final nextCursor = res['next_cursor'] as String?;
    return (category: cat, data: _PaginatedData(items: items, total: total, nextCursor: nextCursor), categories: allCategories);
  }

  return Suspense<({Category? category, _PaginatedData data, List<Category> categories})>(
    resource: fetch,
    fallback: appShell(
      Div(children: [
        Div(className: 'mb-6 animate-pulse', children: [
          Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-32 mb-2'),
          Div(className: 'h-8 bg-[var(--bg-muted)] rounded w-48 mb-2'),
          Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-40'),
        ]),
        Div(
          className: 'grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-4',
          children: List.generate(8, (_) => skeletonCard()),
        ),
      ]),
    ),
    builder: (result) {
      final cat = result.category;
      if (cat == null) {
        return appShell(Div(children: [H1(text: 'Category not found'), P(text: 'No category matches "$slug".')]));
      }
      final data = result.data;
      final categories = result.categories;
      return appShell(Div(children: [
        Div(className: 'mb-6', children: [
          breadcrumb([
            (label: 'Catalog', href: '/'),
            (label: cat.name, href: null),
          ]),
          H1(className: 'text-h1 mt-2', text: cat.name),
          P(className: 'text-sm text-[var(--text-muted)]', text: '${formatNumber(data.total)} products in this category'),
        ]),
        Div(className: 'flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-4', children: [
          Div(),
          _sortBar(sort),
        ]),
        filterBar(
          currentPath: routerController.currentPath.value,
          currentQuery: routerController.currentQuery.value,
          categories: categories,
          currentCategorySlug: slug,
        ),
        Div(className: 'mt-4', children: [productGrid(data.items)]),
        if (data.items.isEmpty)
          emptyState(
            title: 'No products found',
            description: 'No items currently in this category.',
            icon: 'search',
          )
        else
          paginationBar(
            currentPath: routerController.currentPath.value,
            currentQuery: routerController.currentQuery.value,
            total: data.total,
            itemCount: data.items.length,
            nextCursor: data.nextCursor,
            pageSize: 24,
          ),
      ]));
    },
  );
}

BloomNode productDetailPage(Map<String, String> params) {
  final slug = params['slug'] ?? '';

  Future<({Product? product, List<ProductImage> images})> fetch() async {
    try {
      final res = await httpClient.get<Map<String, dynamic>>('/api/products/$slug');
      final prod = _productFromJson(res);
      final rawImages = (res['images'] as List<dynamic>?) ?? const [];
      final imgs = rawImages.map((i) => _productImageFromJson(i as Map<String, dynamic>)).toList();
      return (product: prod, images: imgs);
    } catch (_) {
      return (product: null, images: <ProductImage>[]);
    }
  }

  return Suspense<({Product? product, List<ProductImage> images})>(
    resource: fetch,
    fallback: appShell(skeletonDetail()),
    builder: (result) {
      final product = result.product;
      if (product == null) {
        return appShell(Div(children: [H1(text: 'Product not found'), P(text: 'No product matches "$slug".')]));
      }
      final images = result.images;
      final stockLabel = product.stock == 0 ? 'Out of stock' : product.stock < 5 ? 'Low stock • ${product.stock} left' : 'In stock';
      final stockColor = product.stock == 0 ? 'text-[var(--danger)]' : product.stock < 5 ? 'text-[var(--warning)]' : 'text-[var(--success)]';
      final qty = signal<int>(1);
      return appShell(Div(children: [
        Div(className: 'mb-4', children: [
          breadcrumb([
            (label: 'Catalog', href: '/'),
            (label: product.categoryName ?? 'Category', href: '/c/${product.categorySlug}'),
            (label: product.title, href: null),
          ]),
        ]),
        Div(className: 'grid lg:grid-cols-2 gap-8', children: [
          // Images
          productGallery(images),
          Div(className: 'flex flex-col gap-4', children: [
            Div(children: [
              P(className: 'text-xs uppercase tracking-widest text-[var(--text-muted)]', text: product.vendorName ?? ''),
              H1(className: 'text-h1 mt-1', text: product.title),
              Div(className: 'flex items-center gap-3 mt-2', children: [
                Span(className: 'text-sm $stockColor', text: stockLabel),
              ]),
            ]),
            Div(className: 'flex items-baseline gap-3', children: [
              Span(className: 'price tabular text-2xl font-semibold', style: 'font-variant-numeric:tabular-nums', text: product.priceDisplay),
              Span(className: 'text-sm text-[var(--text-muted)]', text: product.currency),
            ]),
            P(className: 'text-body leading-relaxed max-w-[68ch]', text: product.description),
            Div(className: 'flex items-center gap-3 mt-2 flex-wrap', children: [
              if (product.stock > 0)
                Live(() => quantityStepper(
                  quantity: qty.value,
                  min: 1,
                  onChange: (q) => qty.value = q,
                )),
              El('button',
                attrs: {
                  'type': 'button',
                  if (product.stock == 0) 'disabled': '',
                },
                className: product.stock == 0
                    ? 'px-6 py-3 rounded-md bg-[var(--bg-muted)] text-[var(--text-muted)] text-sm font-medium cursor-not-allowed'
                    : 'px-6 py-3 rounded-md bg-[var(--brand-600)] text-white text-sm font-medium hover:bg-[var(--brand-700)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
                onClick: (BloomEvent e) {
                  if (product.stock == 0) return;
                  final addedQty = qty.value;
                  addToCart(
                    product.id,
                    title: product.title,
                    slug: product.slug,
                    priceCents: product.priceCents,
                    currency: product.currency,
                    imageUrl: images.isNotEmpty ? images.first.url : null,
                    qty: addedQty,
                  );
                  qty.value = 1;
                  showToast(
                    addedQty > 1 ? 'Added $addedQty to cart' : 'Added to cart',
                    ToastVariant.success,
                  );
                },
                children: [Span(text: product.stock == 0 ? 'Out of stock' : 'Add to cart')],
              ),
              Link(href: '/c/${product.categorySlug}', className: 'px-6 py-3 rounded-md border border-[var(--border)] text-sm font-medium hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]', text: 'More in ${product.categoryName ?? 'category'}'),
            ]),
            // JSON-LD
            Raw('<script type="application/ld+json">${_productJsonLd(product)}</script>'),
          ]),
        ]),
      ]));
    },
  );
}

String _productJsonLd(Product p) {
  final price = (p.priceCents / 100).toStringAsFixed(2);
  final avail = p.stock > 0 ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock';
  return '{"@context":"https://schema.org","@type":"Product","name":"${_esc(p.title)}","description":"${_esc(p.description)}","sku":"${p.slug}","offers":{"@type":"Offer","price":"$price","priceCurrency":"${p.currency}","availability":"$avail"}}';
}

String _esc(String s) => s.replaceAll('"', '&quot;').replaceAll('\n', ' ');
