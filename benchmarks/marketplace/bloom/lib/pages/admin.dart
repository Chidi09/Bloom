import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:web/web.dart' as web;
import '../components/button_variants.dart';
import '../components/dropdown.dart';
import '../components/layout.dart';
import '../components/toast.dart';
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

String slugify(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'[\s-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
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
      Div(className: 'animate-pulse', children: [
        Div(className: 'h-8 bg-[var(--bg-muted)] rounded w-36 mb-2'),
        Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-64 mb-6'),
        Div(className: 'grid sm:grid-cols-3 gap-4', children: [
          Div(className: 'h-24 rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 shadow-[var(--shadow-card)]'),
          Div(className: 'h-24 rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 shadow-[var(--shadow-card)]'),
          Div(className: 'h-24 rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 shadow-[var(--shadow-card)]'),
        ]),
        Div(className: 'mt-8 h-32 rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 shadow-[var(--shadow-card)]'),
      ]),
    ),
    builder: (counts) => adminShell(
      Div(children: [
        H1(className: 'text-h1', text: 'Overview'),
        P(className: 'text-sm text-[var(--text-muted)] mt-1', text: 'Product counts by status — Stage 1 administration'),
        Div(className: 'grid sm:grid-cols-3 gap-4 mt-6', children: [
          _metricCard('Published', counts['published'] ?? 0, 'check', 'bg-[#16A34A]/12', 'text-[#16A34A]', 'published'),
          _metricCard('Draft', counts['draft'] ?? 0, 'draft', 'bg-[#D97706]/12', 'text-[#D97706]', 'draft'),
          _metricCard('Archived', counts['archived'] ?? 0, 'archive', 'bg-[#78716C]/15', 'text-[var(--n-400)]', 'archived'),
        ]),
        Div(className: 'mt-8 rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 shadow-[var(--shadow-card)]', children: [
          H3(className: 'text-h3', text: 'Catalog Overview'),
          P(className: 'text-sm text-[var(--text-muted)] mt-1', text: 'Manage product listings, inventory levels, and publication status across the marketplace catalog.'),
          button(text: 'View all products', href: '/admin/products', extraClassName: 'inline-flex mt-3'),
        ]),
      ]),
    ),
  );
}

BloomNode _metricCard(String label, int value, String icon, String colorBg, String colorFg, String statusKey) {
  return Link(
    href: '/admin/products?status=$statusKey',
    className: 'block rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 shadow-[var(--shadow-card)] hover:border-[var(--brand-600)] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
    children: [
      Div(className: 'flex items-center justify-between', children: [
        Span(className: 'text-xs uppercase tracking-widest text-[var(--text-muted)] font-medium', text: label),
        Span(className: 'w-8 h-8 rounded-md grid place-items-center $colorBg $colorFg', children: [hugeIcon(icon, className: 'w-4 h-4')]),
      ]),
      Div(className: 'mt-3 text-3xl font-semibold tabular text-[var(--text)]', style: 'font-family:var(--font-display); font-variant-numeric:tabular-nums', text: formatNumber(value)),
    ],
  );
}

BloomNode adminProducts(Map<String, String> params) {
  final query = routerController.currentQuery.value;
  final cursor = query['cursor'];
  final sort = query['sort'] ?? 'newest';
  final status = query['status'];

  Future<_PaginatedAdminData> fetch() async {
    final qp = <String, dynamic>{
      'limit': 24,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (sort != 'newest') 'sort': sort,
      if (status != null && status.isNotEmpty) 'status': status,
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
      Div(children: [
        Div(className: 'h-8 bg-[var(--bg-muted)] rounded w-36 mb-4 animate-pulse'),
        Div(className: 'h-6 bg-[var(--bg-muted)] rounded w-56 mb-4 animate-pulse'),
        skeletonTable(),
      ]),
    ),
    builder: (data) {
      final rows = data.items.map((p) => tableRow([
            Div(
              className: 'flex items-center gap-3',
              children: [
                bloomImage(
                  src: 'https://picsum.photos/seed/${p.slug}-1/100/100',
                  alt: p.title,
                  widths: [100, 200],
                  sizes: '36px',
                  className: 'w-9 h-9 object-cover rounded-md border border-[var(--border)] shrink-0 bg-[var(--bg-muted)]',
                ),
                Div(
                  className: 'min-w-0',
                  children: [
                    P(className: 'font-medium line-clamp-1', text: p.title),
                    P(className: 'text-xs text-[var(--text-muted)] font-mono truncate', text: p.slug),
                  ],
                ),
              ],
            ),
            Div(className: 'text-right tabular', children: [priceText(p.priceCents)]),
            Div(className: 'text-right tabular', children: [Span(className: 'tabular', text: '${p.stock}')]),
            statusPill(p.status),
            Div(
              className: 'text-right',
              children: [
                dropdownMenu(
                  trigger: El(
                    'button',
                    attrs: {
                      'type': 'button',
                      'aria-label': 'Actions for ${p.title}',
                    },
                    className:
                        'p-1.5 rounded-md text-[var(--text-muted)] hover:text-[var(--text)] hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] transition-colors inline-flex items-center justify-center',
                    children: [
                      hugeIcon('more', className: 'w-4 h-4'),
                    ],
                  ),
                  items: [
                    MenuItemConfig(
                      label: 'Edit',
                      href: '/admin/products/${p.id}',
                    ),
                    MenuItemConfig(
                      label: 'View on storefront',
                      href: '/p/${p.slug}',
                    ),
                    MenuItemConfig(
                      label: 'Copy slug',
                      onClick: () {
                        try {
                          web.window.navigator.clipboard.writeText(p.slug);
                          showToast('Slug copied', ToastVariant.success);
                        } catch (_) {
                          showToast('Failed to copy slug', ToastVariant.error);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ])).toList();

      return adminShell(
        Div(children: [
          H1(className: 'text-h1', text: 'Products'),
          Div(className: 'flex items-center gap-2 text-sm mt-3 flex-wrap', children: [
            if (status != null && status.isNotEmpty) ...[
              Span(className: 'text-[var(--text-muted)]', text: 'Status:'),
              Span(
                className: 'px-2 py-1 rounded-md bg-[var(--brand-600)] text-white text-xs font-medium inline-flex items-center gap-1.5',
                children: [
                  Text(status),
                  Link(
                    href: '/admin/products${sort != 'newest' ? '?sort=$sort' : ''}',
                    className: 'hover:text-black focus-visible:outline-none',
                    children: [hugeIcon('x', className: 'w-3 h-3')],
                  ),
                ],
              ),
              Span(className: 'text-[var(--border)]', text: '•'),
            ],
            Span(className: 'text-[var(--text-muted)]', text: 'Sort:'),
            segmentedControl(
              options: [
                (
                  label: 'Newest',
                  href: '/admin/products?sort=newest${status != null && status.isNotEmpty ? '&status=$status' : ''}',
                  active: sort == 'newest',
                ),
                (
                  label: 'Price ↑',
                  href: '/admin/products?sort=price_asc${status != null && status.isNotEmpty ? '&status=$status' : ''}',
                  active: sort == 'price_asc',
                ),
                (
                  label: 'Price ↓',
                  href: '/admin/products?sort=price_desc${status != null && status.isNotEmpty ? '&status=$status' : ''}',
                  active: sort == 'price_desc',
                ),
              ],
            ),
          ]),
          Div(className: 'mt-4', children: [
            adminTable(
              headers: ['Product', 'Price', 'Stock', 'Status', ''],
              rows: rows,
              empty: emptyState(
                title: 'No products found',
                description: 'No products match the selected criteria.',
                icon: 'package',
              ),
            ),
          ]),
          if (data.items.isNotEmpty)
            paginationBar(
              currentPath: routerController.currentPath.value,
              currentQuery: routerController.currentQuery.value,
              total: data.total,
              itemCount: data.items.length,
              nextCursor: data.nextCursor,
              pageSize: 24,
            ),
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
      Div(className: 'animate-pulse flex flex-col gap-4 max-w-[640px]', children: [
        Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-32 mb-2'),
        Div(className: 'h-8 bg-[var(--bg-muted)] rounded w-48'),
        Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-64 mb-4'),
        Div(className: 'h-10 bg-[var(--bg-muted)] rounded-[6px] w-full'),
        Div(className: 'h-10 bg-[var(--bg-muted)] rounded-[6px] w-full'),
        Div(className: 'h-24 bg-[var(--bg-muted)] rounded-[6px] w-full'),
        Div(className: 'grid grid-cols-2 gap-4', children: [
          Div(className: 'h-10 bg-[var(--bg-muted)] rounded-[6px]'),
          Div(className: 'h-10 bg-[var(--bg-muted)] rounded-[6px]'),
        ]),
        Div(className: 'flex gap-3 mt-2', children: [
          Div(className: 'h-10 bg-[var(--bg-muted)] rounded-[6px] w-24'),
          Div(className: 'h-10 bg-[var(--bg-muted)] rounded-[6px] w-24'),
        ]),
      ]),
    ),
    builder: (prod) => _renderForm(prod, isNew: false, id: id),
  );
}

BloomNode _renderForm(Product? prod, {required bool isNew, String? id}) {
  final idOrSlug = id ?? prod?.id ?? '';
  final isSubmitting = signal<bool>(false);
  var slugManuallyEdited = false;

  return adminShell(
    Div(children: [
      Link(href: '/admin/products', className: 'text-sm text-[var(--brand-600)] hover:underline', text: '← Back to products'),
      H1(className: 'text-h1 mt-2', text: isNew ? 'New product' : 'Edit product'),
      P(className: 'text-sm text-[var(--text-muted)]', text: isNew ? 'Create a new marketplace product' : 'Editing ${prod?.title ?? idOrSlug}'),
      Form(
        onSubmit: (BloomEvent e) async {
          e.preventDefault();
          if (isSubmitting.value) return;

          final titleEl = web.document.getElementById('f-title') as web.HTMLInputElement?;
          final slugEl = web.document.getElementById('f-slug') as web.HTMLInputElement?;
          final descEl = web.document.getElementById('f-description') as web.HTMLTextAreaElement?;
          final priceEl = web.document.getElementById('f-price') as web.HTMLInputElement?;
          final stockEl = web.document.getElementById('f-stock') as web.HTMLInputElement?;
          final statusEl = web.document.getElementById('f-status') as web.HTMLSelectElement?;
          final currEl = web.document.getElementById('f-currency') as web.HTMLInputElement?;

          final title = titleEl?.value.trim() ?? '';
          final slug = slugEl?.value.trim() ?? '';
          final description = descEl?.value.trim() ?? '';
          final priceRaw = priceEl?.value.trim().replaceAll('\$', '') ?? '';
          final priceDouble = double.tryParse(priceRaw);
          final priceCents = priceDouble != null ? (priceDouble * 100).round() : null;
          final stock = int.tryParse(stockEl?.value.trim() ?? '');
          final status = statusEl?.value.trim() ?? 'draft';
          final currency = (currEl?.value.trim() ?? '').isNotEmpty ? currEl!.value.trim() : 'USD';

          if (title.isEmpty) {
            showToast('Title is required', ToastVariant.error);
            return;
          }
          if (slug.isEmpty) {
            showToast('Slug is required', ToastVariant.error);
            return;
          }
          if (priceCents == null || priceCents < 0) {
            showToast('Price must be a non-negative number', ToastVariant.error);
            return;
          }
          if (stock == null || stock < 0) {
            showToast('Stock must be a non-negative integer', ToastVariant.error);
            return;
          }

          final payload = {
            'title': title,
            'slug': slug,
            'description': description,
            'price_cents': priceCents,
            'stock': stock,
            'status': status,
            'currency': currency,
          };

          isSubmitting.value = true;
          try {
            if (isNew) {
              await httpClient.post<Map<String, dynamic>>('/api/admin/products', body: payload);
              showToast('Product created successfully', ToastVariant.success);
            } else {
              await httpClient.put<Map<String, dynamic>>('/api/admin/products/$idOrSlug', body: payload);
              showToast('Product updated successfully', ToastVariant.success);
            }
            await routerController.navigate('/admin/products');
          } catch (err) {
            final msg = err.toString().replaceFirst('ClientException: ', '').replaceFirst('HTTP ', '');
            showToast('Failed to save product: $msg', ToastVariant.error);
          } finally {
            isSubmitting.value = false;
          }
        },
        className: 'mt-6 flex flex-col gap-4 max-w-[640px]',
        children: [
          formField(
            label: 'Title',
            id: 'f-title',
            required: true,
            control: textInput(
              id: 'f-title',
              name: 'title',
              value: prod?.title ?? '',
              required: true,
              onInput: isNew
                  ? (BloomEvent e) {
                      if (slugManuallyEdited) return;
                      final val = e.value ?? (web.document.getElementById('f-title') as web.HTMLInputElement?)?.value ?? '';
                      final slugInput = web.document.getElementById('f-slug') as web.HTMLInputElement?;
                      if (slugInput != null) {
                        slugInput.value = slugify(val);
                      }
                    }
                  : null,
            ),
          ),
          formField(
            label: 'Slug',
            id: 'f-slug',
            help: 'Stable, unique, used in URLs',
            control: textInput(
              id: 'f-slug',
              name: 'slug',
              value: prod?.slug ?? '',
              ariaDescribedBy: 'f-slug-help',
              onInput: isNew
                  ? (BloomEvent e) {
                      slugManuallyEdited = true;
                    }
                  : null,
            ),
          ),
          formField(
            label: 'Description',
            id: 'f-description',
            control: textArea(
              id: 'f-description',
              name: 'description',
              value: prod?.description ?? '',
            ),
          ),
          Div(className: 'grid grid-cols-2 gap-4', children: [
            formField(
              label: 'Price',
              id: 'f-price',
              control: textInput(
                id: 'f-price',
                name: 'price',
                value: prod != null ? (prod.priceCents / 100).toStringAsFixed(2) : '',
                prefix: '\$',
                step: '0.01',
                type: 'number',
              ),
            ),
            formField(
              label: 'Stock',
              id: 'f-stock',
              control: textInput(
                id: 'f-stock',
                name: 'stock',
                value: prod?.stock.toString() ?? '',
                type: 'number',
              ),
            ),
          ]),
          Div(className: 'grid grid-cols-2 gap-4', children: [
            formField(
              label: 'Status',
              id: 'f-status',
              control: selectInput(
                id: 'f-status',
                name: 'status',
                value: prod?.status ?? 'draft',
                options: const ['draft', 'published', 'archived'],
              ),
            ),
            formField(
              label: 'Currency',
              id: 'f-currency',
              control: textInput(
                id: 'f-currency',
                name: 'currency',
                value: prod?.currency ?? 'USD',
              ),
            ),
          ]),
          Div(className: 'flex gap-3 mt-2', children: [
            Live(() => button(
              text: isSubmitting.value ? 'Saving…' : (isNew ? 'Create' : 'Save'),
              attrs: {
                'type': 'submit',
                if (isSubmitting.value) 'disabled': '',
              },
            )),
            button(text: 'Cancel', variant: ButtonVariant.secondary, href: '/admin/products'),
          ]),
        ],
      ),
    ]),
  );
}



