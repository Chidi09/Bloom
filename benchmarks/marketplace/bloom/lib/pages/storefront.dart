import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_server/bloom_server.dart';
import '../components/layout.dart';
import '../components/ui.dart';
import '../models/models.dart';
import '../models/repository.dart';

BloomNode _sortBar(String? current) {
  final opts = {'newest': 'Newest', 'oldest': 'Oldest', 'price_asc': 'Price ↑', 'price_desc': 'Price ↓'};
  return Div(
    className: 'flex items-center gap-2 text-sm',
    children: [
      Span(className: 'text-[var(--text-muted)]', text: 'Sort:'),
      ...opts.entries.map((e) => Link(
            href: '?sort=${e.key}',
            className: e.key == (current ?? 'newest')
                ? 'px-2 py-1 rounded-md bg-[var(--brand-600)] text-white'
                : 'px-2 py-1 rounded-md border border-[var(--border)] hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
            text: e.value,
          )),
    ],
  );
}

Future<BloomNode> homePage(BloomRequest req) async {
  final cursor = req.queryParams['cursor'];
  final sort = req.queryParams['sort'];
  final limit = int.tryParse(req.queryParams['limit'] ?? '') ?? 24;
  final data = await fetchProducts(cursor: cursor, limit: limit, sort: sort, publishedOnly: true);
  // Note: req type is from pages? We'll handle via dynamic to avoid import cycle; assume map
  return appShell(
    Div(children: [
      Div(className: 'flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6', children: [
        Div(children: [
          H1(className: 'text-h1', text: 'Marketplace'),
          P(className: 'text-sm text-[var(--text-muted)] mt-1', text: '${data.total} products • Cursor-paginated • 24 per page'),
        ]),
        _sortBar(sort),
      ]),
      productGrid(data.items),
      if (data.items.isEmpty)
        Div(className: 'py-16 text-center', children: [
          P(className: 'text-display', text: 'No products found'),
          P(className: 'text-[var(--text-muted)] mt-2', text: 'Try a different filter or check back soon.'),
        ])
      else
        Div(className: 'flex items-center justify-between gap-4 mt-8', children: [
          Span(className: 'text-sm text-[var(--text-muted)]', text: data.nextCursor == null ? 'End of results' : 'More results available'),
          if (data.nextCursor != null)
            Link(
              href: _withCursor(req, data.nextCursor!),
              className: 'inline-flex items-center gap-1.5 px-4 py-2 rounded-md bg-[var(--brand-600)] text-white text-sm font-medium hover:bg-[var(--brand-700)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
              children: [Span(text: 'Next'), hugeIcon('chevron-right')],
            )
          else
            Span(className: 'px-4 py-2 rounded-md bg-[var(--bg-muted)] text-[var(--text-muted)] text-sm', text: 'No more pages'),
        ]),
    ]),
  );
}

String _withCursor(dynamic req, String cursor) {
  final uri = req.uri as Uri;
  final qp = Map<String, String>.from(uri.queryParameters);
  qp['cursor'] = cursor;
  final qs = qp.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
  return '${uri.path}?$qs';
}

Future<BloomNode> categoryPage(BloomRequest req) async {
  final slug = req.params['slug'] ?? '';
  final sort = req.queryParams['sort'];
  final cursor = req.queryParams['cursor'];
  final cat = await fetchCategoryBySlug(slug);
  if (cat == null) {
    return appShell(Div(children: [H1(text: 'Category not found'), P(text: 'No category matches "$slug".')]));
  }
  final data = await fetchProducts(cursor: cursor, limit: 24, sort: sort, categorySlug: slug, publishedOnly: true);
  return appShell(Div(children: [
    Div(className: 'mb-6', children: [
      Div(className: 'flex items-center gap-2 text-sm text-[var(--text-muted)]', children: [
        Link(href: '/', className: 'hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]', text: 'Home'),
        Span(text: '/'),
        Span(className: 'text-[var(--text)] font-medium', text: cat.name),
      ]),
      H1(className: 'text-h1 mt-2', text: cat.name),
      P(className: 'text-sm text-[var(--text-muted)]', text: '${data.total} products in this category'),
    ]),
    _sortBar(sort),
    Div(className: 'mt-4', children: [productGrid(data.items)]),
    if (data.nextCursor != null)
      Div(className: 'mt-8 flex justify-end', children: [
        Link(href: _withCursor(req, data.nextCursor!), className: 'px-4 py-2 rounded-md bg-[var(--brand-600)] text-white text-sm font-medium hover:bg-[var(--brand-700)]', text: 'Next'),
      ]),
  ]));
}

Future<BloomNode> productDetailPage(BloomRequest req) async {
  final slug = req.params['slug'] ?? '';
  final product = await fetchProductBySlug(slug);
  if (product == null) {
    return appShell(Div(children: [H1(text: 'Product not found'), P(text: 'No product matches "$slug".')]));
  }
  final images = await fetchImages(product.id);
  final stockLabel = product.stock == 0 ? 'Out of stock' : product.stock < 5 ? 'Low stock • ${product.stock} left' : 'In stock';
  final stockColor = product.stock == 0 ? 'text-[var(--danger)]' : product.stock < 5 ? 'text-[var(--warning)]' : 'text-[var(--success)]';
  return appShell(Div(children: [
    Div(className: 'flex items-center gap-2 text-sm text-[var(--text-muted)] mb-4', children: [
      Link(href: '/', className: 'hover:underline', text: 'Catalog'),
      Span(text: '/'),
      Link(href: '/c/${product.categorySlug}', className: 'hover:underline', text: product.categoryName ?? 'Category'),
      Span(text: '/'),
      Span(className: 'text-[var(--text)] truncate', text: product.title),
    ]),
    Div(className: 'grid lg:grid-cols-2 gap-8', children: [
      // Images
      Div(className: 'flex flex-col gap-3', children: [
        if (images.isNotEmpty)
          bloomImage(
            src: images.first.url,
            alt: images.first.alt,
            widths: [600, 800, 1200],
            sizes: '(max-width:1024px) 100vw, 50vw',
            className: 'w-full aspect-square object-cover rounded-[10px] border border-[var(--border)] bg-[var(--bg-muted)]',
            priority: true,
          )
        else
          Div(className: 'aspect-square rounded-[10px] bg-[var(--bg-muted)] grid place-items-center text-[var(--text-muted)]', text: 'No image'),
        if (images.length > 1)
          Div(className: 'grid grid-cols-3 gap-2', children: images.skip(1).map((im) => bloomImage(
                src: im.url,
                alt: im.alt,
                widths: [300, 600],
                sizes: '200px',
                className: 'w-full aspect-square object-cover rounded-md border border-[var(--border)]',
              )).toList()),
      ]),
      Div(className: 'flex flex-col gap-4', children: [
        Div(children: [
          P(className: 'text-xs uppercase tracking-widest text-[var(--text-muted)]', text: product.vendorName ?? ''),
          H1(className: 'text-h1 mt-1', text: product.title),
          Div(className: 'flex items-center gap-3 mt-2', children: [
            statusPill(product.status),
            Span(className: 'text-sm $stockColor', text: stockLabel),
          ]),
        ]),
        Div(className: 'flex items-baseline gap-3', children: [
          Span(className: 'price tabular text-2xl font-semibold', style: 'font-variant-numeric:tabular-nums', text: product.priceDisplay),
          Span(className: 'text-sm text-[var(--text-muted)]', text: product.currency),
        ]),
        P(className: 'text-body leading-relaxed max-w-[68ch]', text: product.description),
        Div(className: 'flex gap-3 mt-2', children: [
          El('button',
            attrs: {'type': 'button', 'disabled': product.stock == 0 ? 'true' : ''},
            className: product.stock == 0
                ? 'px-6 py-3 rounded-md bg-[var(--bg-muted)] text-[var(--text-muted)] text-sm font-medium cursor-not-allowed'
                : 'px-6 py-3 rounded-md bg-[var(--brand-600)] text-white text-sm font-medium hover:bg-[var(--brand-700)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
            children: [Span(text: product.stock == 0 ? 'Out of stock' : 'Add to cart')],
          ),
          Link(href: '/c/${product.categorySlug}', className: 'px-6 py-3 rounded-md border border-[var(--border)] text-sm font-medium hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]', text: 'More in ${product.categoryName ?? 'category'}'),
        ]),
        // JSON-LD
        Raw('<script type="application/ld+json">${_productJsonLd(product)}</script>'),
      ]),
    ]),
  ]));
}

String _productJsonLd(Product p) {
  final price = (p.priceCents / 100).toStringAsFixed(2);
  final avail = p.stock > 0 ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock';
  return '{"@context":"https://schema.org","@type":"Product","name":"${_esc(p.title)}","description":"${_esc(p.description)}","sku":"${p.slug}","offers":{"@type":"Offer","price":"$price","priceCurrency":"${p.currency}","availability":"$avail"}}';
}

String _esc(String s) => s.replaceAll('"', '&quot;').replaceAll('\n', ' ');
