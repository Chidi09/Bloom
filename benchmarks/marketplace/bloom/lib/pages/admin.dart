import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/button_variants.dart';
import '../components/layout.dart';
import '../components/ui.dart';
import '../main.dart';
import '../models/models.dart';

class _PaginatedAdminData {
  final List<Product> items;
  final int total;
  final String? nextCursor;
  _PaginatedAdminData({required this.items, required this.total, this.nextCursor});
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

BloomNode adminDashboard(Map<String, String> params) {
  Future<Map<String, int>> fetch() async {
    try {
      final res = await httpClient.get<Map<String, dynamic>>('/api/admin/stats');
      return res.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {'published': 0, 'draft': 0, 'archived': 0};
    }
  }

  return Suspense<Map<String, int>>(
    resource: fetch,
    fallback: adminShell(
      Div(className: 'py-16 text-center text-[var(--text-muted)]', text: 'Loading overview...'),
    ),
    builder: (counts) => adminShell(
      Div(children: [
        H1(className: 'text-h1', text: 'Overview'),
        P(className: 'text-sm text-[var(--text-muted)] mt-1', text: 'Product counts by status — TODO: Auth (Stage 2)'),
        Div(className: 'grid sm:grid-cols-3 gap-4 mt-6', children: [
          _metricCard('Published', counts['published'] ?? 0, 'check', 'var(--success)'),
          _metricCard('Draft', counts['draft'] ?? 0, 'draft', 'var(--warning)'),
          _metricCard('Archived', counts['archived'] ?? 0, 'archive', 'var(--n-500)'),
        ]),
        Div(className: 'mt-8 rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4', children: [
          H3(className: 'text-h3', text: 'Next steps'),
          P(className: 'text-sm text-[var(--text-muted)] mt-1', text: 'Stage 1: list and manage products. Stage 2 will add auth, audit log, and destructive-action guards.'),
          button(text: 'Go to products', href: '/admin/products', extraClassName: 'inline-flex mt-3'),
        ]),
      ]),
    ),
  );
}

BloomNode _metricCard(String label, int value, String icon, String color) {
  return Div(
    className: 'rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 shadow-sm',
    children: [
      Div(className: 'flex items-center justify-between', children: [
        Span(className: 'text-xs uppercase tracking-widest text-[var(--text-muted)]', text: label),
        Span(className: 'w-8 h-8 rounded-md grid place-items-center', style: 'background: $color; color: white', children: [hugeIcon(icon, className: 'w-4 h-4')]),
      ]),
      Div(className: 'mt-3 text-3xl font-semibold tabular', style: 'font-family:var(--font-display); font-variant-numeric:tabular-nums', text: '$value'),
    ],
  );
}

BloomNode adminProducts(Map<String, String> params) {
  final query = routerController.currentQuery.value;
  final cursor = query['cursor'];
  final sort = query['sort'] ?? 'newest';

  Future<_PaginatedAdminData> fetch() async {
    final qp = <String, dynamic>{
      'limit': 24,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (sort != 'newest') 'sort': sort,
    };
    final res = await httpClient.get<Map<String, dynamic>>('/api/admin/products', queryParameters: qp);
    final rawResults = (res['results'] as List<dynamic>?) ?? const [];
    final items = rawResults.map((j) => _productFromJson(j as Map<String, dynamic>)).toList();
    final total = res['count'] as int? ?? items.length;
    final nextCursor = res['next_cursor'] as String?;
    return _PaginatedAdminData(items: items, total: total, nextCursor: nextCursor);
  }

  return Suspense<_PaginatedAdminData>(
    resource: fetch,
    fallback: adminShell(
      Div(className: 'py-16 text-center text-[var(--text-muted)]', text: 'Loading products...'),
    ),
    builder: (data) {
      final rows = data.items.map((p) => tableRow([
            Div(children: [
              P(className: 'font-medium line-clamp-1', text: p.title),
              P(className: 'text-xs text-[var(--text-muted)]', text: p.slug),
            ]),
            priceText(p.priceCents),
            Span(className: 'tabular', text: '${p.stock}'),
            statusPill(p.status),
            Link(href: '/admin/products/${p.id}', className: 'text-sm text-[var(--brand-600)] hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]', text: 'Edit'),
          ])).toList();

      return adminShell(
        Div(children: [
          Div(className: 'flex items-center justify-between gap-4', children: [
            H1(className: 'text-h1', text: 'Products'),
            button(text: 'New product', href: '/admin/products/new'),
          ]),
          Div(className: 'flex items-center gap-2 text-sm mt-3', children: [
            Span(className: 'text-[var(--text-muted)]', text: 'Sort:'),
            Link(href: '/admin/products?sort=newest', className: 'px-2 py-1 rounded-md border border-[var(--border)] ${sort=='newest'?'bg-[var(--brand-600)] text-white border-transparent':''}', text: 'Newest'),
            Link(href: '/admin/products?sort=price_asc', className: 'px-2 py-1 rounded-md border border-[var(--border)] ${sort=='price_asc'?'bg-[var(--brand-600)] text-white border-transparent':''}', text: 'Price ↑'),
            Link(href: '/admin/products?sort=price_desc', className: 'px-2 py-1 rounded-md border border-[var(--border)] ${sort=='price_desc'?'bg-[var(--brand-600)] text-white border-transparent':''}', text: 'Price ↓'),
          ]),
          Div(className: 'mt-4', children: [
            adminTable(
              headers: ['Product', 'Price', 'Stock', 'Status', ''],
              rows: rows,
              empty: Div(className: 'py-12 text-center text-[var(--text-muted)]', text: 'No products'),
            ),
          ]),
          if (data.nextCursor != null)
            Div(className: 'mt-4 flex justify-end', children: [
              Link(href: '/admin/products?cursor=${Uri.encodeComponent(data.nextCursor!)}&sort=$sort', className: 'px-4 py-2 rounded-md bg-[var(--brand-600)] text-white text-sm', text: 'Next'),
            ])
          else
            Div(className: 'mt-4 text-sm text-[var(--text-muted)] text-right', text: 'End of results'),
        ]),
      );
    },
  );
}

BloomNode adminProductNew(Map<String, String> params) => _renderForm(null, isNew: true);

BloomNode adminProductForm(Map<String, String> params, {bool isNew = false}) {
  if (isNew) return _renderForm(null, isNew: true);
  final id = params['id'] ?? '';
  Future<Product?> fetch() async {
    try {
      final res = await httpClient.get<Map<String, dynamic>>('/api/admin/products/$id');
      return _productFromJson(res);
    } catch (_) {
      return null;
    }
  }

  return Suspense<Product?>(
    resource: fetch,
    fallback: adminShell(
      Div(className: 'py-16 text-center text-[var(--text-muted)]', text: 'Loading product...'),
    ),
    builder: (prod) => _renderForm(prod, isNew: false, id: id),
  );
}

BloomNode _renderForm(Product? prod, {required bool isNew, String? id}) {
  final idOrSlug = id ?? prod?.id ?? '';
  return adminShell(
    Div(children: [
      Link(href: '/admin/products', className: 'text-sm text-[var(--brand-600)] hover:underline', text: '← Back to products'),
      H1(className: 'text-h1 mt-2', text: isNew ? 'New product' : 'Edit product'),
      P(className: 'text-sm text-[var(--text-muted)]', text: isNew ? 'Create a new product — TODO: server mutation (Stage 2)' : 'Editing ${prod?.title ?? idOrSlug} — TODO: auth'),
      El('form',
        attrs: {'method': 'post', 'action': isNew ? '/admin/products' : '/admin/products/$idOrSlug'},
        className: 'mt-6 flex flex-col gap-4 max-w-[640px]',
        children: [
          _field('Title', 'title', prod?.title ?? '', required: true),
          _field('Slug', 'slug', prod?.slug ?? '', help: 'Stable, unique, used in URLs'),
          _field('Description', 'description', prod?.description ?? '', textarea: true),
          Div(className: 'grid grid-cols-2 gap-4', children: [
            _field('Price (cents)', 'price_cents', prod?.priceCents.toString() ?? '', help: 'Integer cents, e.g. 1999 = \$19.99'),
            _field('Stock', 'stock', prod?.stock.toString() ?? ''),
          ]),
          Div(className: 'grid grid-cols-2 gap-4', children: [
            _select('Status', 'status', prod?.status ?? 'draft', ['draft', 'published', 'archived']),
            _field('Currency', 'currency', prod?.currency ?? 'USD'),
          ]),
          Div(className: 'flex gap-3 mt-2', children: [
            button(text: isNew ? 'Create' : 'Save', attrs: const {'type': 'submit'}),
            button(text: 'Cancel', variant: ButtonVariant.secondary, href: '/admin/products'),
          ]),
        ],
      ),
    ]),
  );
}

BloomNode _field(String label, String name, String value, {bool required = false, bool textarea = false, String? help}) {
  final id = 'f-$name';
  return Div(className: 'flex flex-col gap-1.5', children: [
    El('label', attrs: {'for': id}, className: 'text-label', text: label),
    if (textarea)
      El('textarea', attrs: {'id': id, 'name': name, if (required) 'required': '' , 'rows': '4', 'aria-describedby': help != null ? '$id-help' : ''}, className: 'w-full px-3 py-2 rounded-[6px] border border-[var(--border)] bg-[var(--bg)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--brand-600)]', text: value)
    else
      El('input', attrs: {'id': id, 'name': name, 'value': value, if (required) 'required': '', 'aria-describedby': help != null ? '$id-help' : ''}, className: 'w-full px-3 py-2 rounded-[6px] border border-[var(--border)] bg-[var(--bg)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--brand-600)]'),
    if (help != null) P(attrs: {'id': '$id-help'}, className: 'text-xs text-[var(--text-muted)]', text: help),
  ]);
}

BloomNode _select(String label, String name, String value, List<String> opts) {
  final id = 'f-$name';
  return Div(className: 'flex flex-col gap-1.5', children: [
    El('label', attrs: {'for': id}, className: 'text-label', text: label),
    El('select', attrs: {'id': id, 'name': name}, className: 'w-full px-3 py-2 rounded-[6px] border border-[var(--border)] bg-[var(--bg)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--brand-600)]', children: opts.map((o) => El('option', attrs: {'value': o, if (o==value) 'selected': ''}, text: o)).toList()),
  ]);
}


